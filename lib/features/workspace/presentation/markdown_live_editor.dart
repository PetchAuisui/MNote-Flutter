import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'markdown_document_style.dart';
import 'markdown_rendered_block.dart';

/// History belongs to the workspace so switching views does not discard it.
class MarkdownEditHistory {
  final past = <TextEditingValue>[];
  final future = <TextEditingValue>[];

  void clear() {
    past.clear();
    future.clear();
  }
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
  });
  final TextEditingController controller;
  final MarkdownEditHistory? history;
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
  int? _start;
  int _end = 0;
  bool _updating = false;
  late String _source;
  final _localHistory = MarkdownEditHistory();
  List<TextEditingValue> get _past => (widget.history ?? _localHistory).past;
  List<TextEditingValue> get _future =>
      (widget.history ?? _localHistory).future;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _source = widget.controller.text;
    _updateHistory();
    if (widget.controller.text.isEmpty) _start = 0;
    widget.controller.addListener(_sync);
    widget.undoController?.onUndo.addListener(_undo);
    widget.undoController?.onRedo.addListener(_redo);
    _blockController.addListener(_edit);
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) return;
    // Focus can change while Flutter moves the editor between document blocks.
    // Finish only after that move has completed, never during a rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus && _start != null) {
        setState(() => _start = null);
      }
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

  void _activate(int start, int end) {
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

  Widget _editor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return KeyedSubtree(
      key: _activeEditorKey,
      child: Container(
        key: const Key('markdown-live-active-block'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3.5,
              child: ColoredBox(color: colorScheme.primary),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: TextField(
                key: const Key('markdown-live-block-editor'),
                controller: _blockController,
                focusNode: _focus,
                maxLines: null,
                onTapOutside: (_) => _focus.unfocus(),
                style: const TextStyle(
                  fontSize: 17,
                  height: MarkdownDocumentStyle.lineHeight,
                  color: Color(0xFF202124),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'เริ่มเขียน Markdown…',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
          ],
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

    for (final range in ranges) {
      if (_start != null && range.end <= _start!) {
        children.add(
          GestureDetector(
            key: ValueKey('markdown-block-${range.start}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _activate(range.start, range.end),
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
          onTap: () => _activate(range.start, range.end),
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
          child: const Text('เริ่มเขียน Markdown…'),
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
    return Theme(
      data: documentTheme,
      child: ColoredBox(
        color: Colors.white,
        child: SingleChildScrollView(
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
    widget.controller.removeListener(_sync);
    widget.undoController?.onUndo.removeListener(_undo);
    widget.undoController?.onRedo.removeListener(_redo);
    _blockController.dispose();
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }
}
