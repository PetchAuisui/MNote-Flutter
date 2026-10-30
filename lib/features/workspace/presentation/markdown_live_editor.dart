import 'package:mnote/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'editor_settings.dart';
import 'markdown_document_style.dart';
import 'markdown_outline.dart';
import 'markdown_rendered_block.dart';
import 'markdown_table_editor.dart';

/// History belongs to the workspace so switching views does not discard it.
class MarkdownEditHistory {
  final past = <TextEditingValue>[];
  final future = <TextEditingValue>[];

  void clear() {
    past.clear();
    future.clear();
  }
}

/// Lets the workspace move the live editor to a heading and follow its scroll.
class MarkdownOutlineController {
  Future<void> Function(int offset)? _scrollTo;

  /// Called by the view that currently shows the document.
  void attach(Future<void> Function(int offset) scrollTo) =>
      _scrollTo = scrollTo;

  void detach(Future<void> Function(int offset) scrollTo) {
    if (_scrollTo == scrollTo) _scrollTo = null;
  }

  /// Source offset of the heading the reader is currently in, if any.
  final activeOffset = ValueNotifier<int?>(null);

  /// Scrolls the heading that starts at [offset] to the top of the editor.
  Future<void> scrollToOffset(int offset) async => _scrollTo?.call(offset);

  void dispose() => activeOffset.dispose();
}

/// Renders a document in place, exposing Markdown only in the active block.
class MarkdownLiveEditor extends StatefulWidget {
  const MarkdownLiveEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    this.imageDirectory,
    this.builders = const {},
    this.undoController,
    this.onTapLink,
    this.history,
    this.outline,
  });
  final TextEditingController controller;
  final MarkdownEditHistory? history;
  final MarkdownOutlineController? outline;
  final UndoHistoryController? undoController;
  final ValueChanged<String> onChanged;
  final void Function(String, String?, String?)? onTapLink;
  final String? imageDirectory;
  final Map<String, MarkdownElementBuilder> builders;

  @override
  State<MarkdownLiveEditor> createState() => _MarkdownLiveEditorState();
}

class _MarkdownLiveEditorState extends State<MarkdownLiveEditor> {
  final _blockController = TextEditingController();
  final _focus = FocusNode();
  final _activeEditorKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final _scroll = ScrollController();
  final _blockKeys = <int, GlobalKey>{};
  String? _headingsSource;
  List<MarkdownHeading> _headings = const [];
  bool _jumping = false;
  int? _start;
  int _end = 0;

  /// The table cell to open on, when the active block is a table.
  (int, int)? _tableCell;

  /// Shows the active table's Markdown instead of its cells.
  bool _rawTable = false;
  bool _updating = false;
  late String _source;
  final _localHistory = MarkdownEditHistory();
  List<TextEditingValue> get _past => (widget.history ?? _localHistory).past;
  List<TextEditingValue> get _future =>
      (widget.history ?? _localHistory).future;
  bool _restoring = false;

  DocumentTextOptions get _textOptions => EditorSettings.instance.textOptions;

  void _onEditorSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    EditorSettings.instance.addListener(_onEditorSettingsChanged);
    _source = widget.controller.text;
    _updateHistory();
    if (widget.controller.text.isEmpty) _start = 0;
    widget.controller.addListener(_sync);
    widget.undoController?.onUndo.addListener(_undo);
    widget.undoController?.onRedo.addListener(_redo);
    _blockController.addListener(_edit);
    _focus.addListener(_onFocusChanged);
    _scroll.addListener(_trackActiveHeading);
    widget.outline?.attach(_scrollToOffset);
  }

  List<MarkdownHeading> _headingsOf(String source) {
    if (_headingsSource != source) {
      _headings = parseMarkdownHeadings(source);
      _headingsSource = source;
    }
    return _headings;
  }

  BuildContext? _contextFor(int offset) {
    final start = _start;
    if (start != null && offset >= start && offset < _end) {
      return _activeEditorKey.currentContext;
    }
    return _blockKeys[offset]?.currentContext;
  }

  void _trackActiveHeading() {
    final outline = widget.outline;
    if (_jumping || outline == null) return;
    final headings = _headingsOf(_source);
    final viewport = _viewportKey.currentContext?.findRenderObject();
    int? active = headings.isEmpty ? null : headings.first.offset;
    if (viewport is RenderBox && viewport.attached) {
      for (final heading in headings) {
        final box = _contextFor(heading.offset)?.findRenderObject();
        if (box is! RenderBox || !box.attached) continue;
        // A heading counts as reached once it is near the top of the view.
        if (box.localToGlobal(Offset.zero, ancestor: viewport).dy > 48) break;
        active = heading.offset;
      }
    }
    outline.activeOffset.value = active;
  }

  Future<void> _scrollToOffset(int offset) async {
    final target = _contextFor(offset);
    if (target == null) return;
    _jumping = true;
    widget.outline?.activeOffset.value = offset;
    try {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    } finally {
      _jumping = false;
    }
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) return;
    // Focus can change while Flutter moves the editor between document blocks.
    // Finish only after that move has completed, never during a rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focus.hasFocus || _start == null) return;
      // A menu or dialog opened from the toolbar takes focus while it is up
      // and hands it back when it closes, so keep the block open meanwhile.
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused != null &&
          focused.mounted &&
          ModalRoute.of(focused) != ModalRoute.of(context)) {
        return;
      }
      setState(() => _start = null);
    });
  }

  @override
  void didUpdateWidget(MarkdownLiveEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _source = widget.controller.text;
      _start = null;
      _past.clear();
      _future.clear();
    }
    if (oldWidget.outline != widget.outline) {
      oldWidget.outline?.detach(_scrollToOffset);
      widget.outline?.attach(_scrollToOffset);
    }
    if (oldWidget.undoController != widget.undoController) {
      oldWidget.undoController?.onUndo.removeListener(_undo);
      oldWidget.undoController?.onRedo.removeListener(_redo);
      widget.undoController?.onUndo.addListener(_undo);
      widget.undoController?.onRedo.addListener(_redo);
    }
  }

  void _updateHistory() {
    widget.undoController?.value = UndoHistoryValue(
      canUndo: _past.isNotEmpty,
      canRedo: _future.isNotEmpty,
    );
  }

  void _undo() {
    if (_past.isEmpty) return;
    _future.add(widget.controller.value);
    _restore(_past.removeLast());
  }

  void _redo() {
    if (_future.isEmpty) return;
    _past.add(widget.controller.value);
    _restore(_future.removeLast());
  }

  void _restore(TextEditingValue value) {
    _restoring = true;
    _start = null;
    _focus.unfocus();
    widget.controller.value = value;
    widget.onChanged(value.text);
    _restoring = false;
    _updateHistory();
  }

  void _remember() {
    if (_restoring) return;
    _past.add(
      TextEditingValue(
        text: _source,
        selection: TextSelection.collapsed(
          offset: (_start ?? 0).clamp(0, _source.length),
        ),
      ),
    );
    if (_past.length > 100) _past.removeAt(0);
    _future.clear();
    _updateHistory();
  }

  void _sync() {
    if (_updating) return;
    final source = widget.controller.text;
    if (source != _source) {
      _remember();
      if (_start != null) {
        // A toolbar edit must be contained in the active block. Opening or
        // replacing a document instead returns the whole page to preview.
        final suffix = _source.substring(_end);
        if (source.startsWith(_source.substring(0, _start!)) &&
            source.endsWith(suffix) &&
            source.length >= _start! + suffix.length) {
          _end = source.length - suffix.length;
          _updating = true;
          final selection = widget.controller.selection;
          _blockController.value = TextEditingValue(
            text: source.substring(_start!, _end),
            selection: TextSelection(
              baseOffset: (selection.baseOffset - _start!).clamp(
                0,
                _end - _start!,
              ),
              extentOffset: (selection.extentOffset - _start!).clamp(
                0,
                _end - _start!,
              ),
            ),
          );
          _updating = false;
        } else {
          _start = null;
          _focus.unfocus();
        }
      }
    }
    _source = source;
    setState(() {});
  }

  void _edit() {
    if (_updating || _start == null) return;
    _updating = true;
    final source = widget.controller.text;
    final replacement = _blockController.text;
    final textChanged = source.substring(_start!, _end) != replacement;
    if (textChanged) _remember();
    final selection = _blockController.selection;
    widget.controller.value = TextEditingValue(
      text: source.replaceRange(_start!, _end, replacement),
      selection: TextSelection(
        baseOffset: _start! + selection.baseOffset.clamp(0, replacement.length),
        extentOffset:
            _start! + selection.extentOffset.clamp(0, replacement.length),
      ),
    );
    _end = _start! + replacement.length;
    _source = widget.controller.text;
    _updating = false;
    if (textChanged) widget.onChanged(widget.controller.text);
    setState(() {});
  }

  void _appendBlock() {
    final source = widget.controller.text;
    if (source.isNotEmpty && !source.endsWith('\n\n')) {
      final separator = source.endsWith('\n') ? '\n' : '\n\n';
      widget.controller.text = '$source$separator';
      widget.onChanged(widget.controller.text);
    }
    final offset = widget.controller.text.length;
    _activate(offset, offset);
  }

  void _activateAt(TextRange range, TapUpDetails details) {
    final block = _blockKeys[range.start]?.currentContext;
    _activate(
      range.start,
      range.end,
      tableCell: block == null
          ? null
          : renderedTableCellAt(block, details.globalPosition),
    );
  }

  void _activate(int start, int end, {(int, int)? tableCell}) {
    _tableCell = tableCell;
    _rawTable = false;
    _updating = true;
    _start = start;
    _end = end;
    _source = widget.controller.text;
    _blockController.value = TextEditingValue(
      text: widget.controller.text.substring(start, end),
      selection: TextSelection.collapsed(offset: end - start),
    );
    widget.controller.selection = TextSelection.collapsed(offset: end);
    _updating = false;
    setState(() {});
    _focus.requestFocus();
  }

  void _editTableAsMarkdown() {
    // Hand focus to the block itself so the switch does not close it.
    _focus.requestFocus();
    setState(() => _rawTable = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _start != null) _focus.requestFocus();
    });
  }

  Widget _editor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = _textOptions.apply(
      TextStyle(
        fontSize: _textOptions.bodySize,
        height: _textOptions.lineHeight,
        color: const Color(0xFF202124),
      ),
    );
    final table =
        !_rawTable && MarkdownTable.parse(_blockController.text) != null;
    return KeyedSubtree(
      key: _activeEditorKey,
      child: Container(
        key: const Key('markdown-live-active-block'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        // A white, fully outlined box: a blockquote is a grey fill with a bar
        // on the left, so the block being edited must not look like one.
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.primary, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: table
              ? MarkdownTableEditor(
                  key: ValueKey('markdown-table-editor-$_start'),
                  controller: _blockController,
                  focusNode: _focus,
                  style: style,
                  initialCell: _tableCell,
                  onEditAsMarkdown: _editTableAsMarkdown,
                )
              : TextField(
                  key: const Key('markdown-live-block-editor'),
                  controller: _blockController,
                  focusNode: _focus,
                  maxLines: null,
                  onTapOutside: (_) => _focus.unfocus(),
                  style: style,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: context.l10n.startWriting,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.controller.text;
    final documentTheme = MarkdownDocumentStyle.theme(context);
    final children = <Widget>[];
    final ranges = markdownBlockRanges(source);
    final blockContext = MarkdownBlockContext(source, ranges);

    var editorAdded = false;
    final blockStarts = {for (final range in ranges) range.start};
    _blockKeys.removeWhere((start, _) => !blockStarts.contains(start));
    GlobalKey blockKey(int start) =>
        _blockKeys.putIfAbsent(start, GlobalKey.new);

    for (final range in ranges) {
      if (_start != null && range.end <= _start!) {
        children.add(
          GestureDetector(
            key: ValueKey('markdown-block-${range.start}'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _activateAt(range, details),
            child: KeyedSubtree(
              key: blockKey(range.start),
              child: IgnorePointer(
                ignoring: RegExp(
                  r'^\s*(`{3,}|~{3,})',
                ).hasMatch(range.textInside(source)),
                child: MarkdownRenderedBlock(
                  markdown: range.textInside(source),
                  references: blockContext.references,
                  orderedNumber: blockContext.orderedNumbers[range.start],
                  theme: documentTheme,
                  imageDirectory: widget.imageDirectory,
                  builders: widget.builders,
                  onTapLink: widget.onTapLink,
                  textOptions: _textOptions,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      if (_start != null && !editorAdded && range.start >= _start!) {
        children.add(_editor());
        editorAdded = true;
      }

      if (_start != null && range.start < _end && range.end > _start!) {
        continue;
      }

      children.add(
        GestureDetector(
          key: ValueKey('markdown-block-${range.start}'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _activateAt(range, details),
          child: KeyedSubtree(
            key: blockKey(range.start),
            child: IgnorePointer(
              ignoring: RegExp(
                r'^\s*(`{3,}|~{3,})',
              ).hasMatch(range.textInside(source)),
              child: MarkdownRenderedBlock(
                markdown: range.textInside(source),
                references: blockContext.references,
                orderedNumber: blockContext.orderedNumbers[range.start],
                theme: documentTheme,
                imageDirectory: widget.imageDirectory,
                builders: widget.builders,
                onTapLink: widget.onTapLink,
                textOptions: _textOptions,
              ),
            ),
          ),
        ),
      );
    }

    if (_start != null && !editorAdded) {
      children.add(_editor());
    }

    if (source.isEmpty && _start == null) {
      children.add(
        TextButton(
          onPressed: () => _activate(0, 0),
          child: Text(context.l10n.startWriting),
        ),
      );
    }
    children.add(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        key: const Key('append-live-block'),
        onTap: _appendBlock,
        child: const SizedBox(height: 120, width: double.infinity),
      ),
    );
    if (widget.outline != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _trackActiveHeading();
      });
    }
    return Theme(
      data: documentTheme,
      child: ColoredBox(
        key: _viewportKey,
        color: Colors.white,
        child: SingleChildScrollView(
          controller: _scroll,
          key: const Key('markdown-live-preview'),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MarkdownDocumentStyle.maxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    EditorSettings.instance.removeListener(_onEditorSettingsChanged);
    widget.controller.removeListener(_sync);
    widget.undoController?.onUndo.removeListener(_undo);
    widget.undoController?.onRedo.removeListener(_redo);
    widget.outline?.detach(_scrollToOffset);
    _scroll.dispose();
    _blockController.dispose();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }
}
