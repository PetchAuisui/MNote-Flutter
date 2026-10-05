import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Renders a document in place, exposing Markdown only in the active block.
class MarkdownLiveEditor extends StatefulWidget {
  const MarkdownLiveEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    this.imageDirectory,
    this.builders = const {},
    this.undoController,
  });
  final TextEditingController controller;
  final UndoHistoryController? undoController;
  final ValueChanged<String> onChanged;
  final String? imageDirectory;
  final Map<String, MarkdownElementBuilder> builders;

  @override
  State<MarkdownLiveEditor> createState() => _MarkdownLiveEditorState();
}

class _MarkdownLiveEditorState extends State<MarkdownLiveEditor> {
  final _blockController = TextEditingController();
  final _focus = FocusNode();
  int? _start;
  int _end = 0;
  bool _updating = false;
  late String _source;
  final _past = <TextEditingValue>[];
  final _future = <TextEditingValue>[];
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _source = widget.controller.text;
    if (widget.controller.text.isEmpty) _start = 0;
    widget.controller.addListener(_sync);
    widget.undoController?.onUndo.addListener(_undo);
    widget.undoController?.onRedo.addListener(_redo);
    _blockController.addListener(_edit);
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

  Widget _editor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const Key('finish-live-block'),
          onPressed: () {
            _focus.unfocus();
            setState(() => _start = null);
          },
          icon: const Icon(Icons.check, size: 16),
          label: const Text('เสร็จ'),
        ),
      ),
      TextField(
        key: const Key('markdown-live-block-editor'),
        controller: _blockController,
        focusNode: _focus,
        maxLines: null,
        style: const TextStyle(
          fontSize: 17,
          height: 1.65,
          color: Color(0xFF202124),
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'เริ่มเขียน Markdown…',
          isDense: true,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final source = widget.controller.text;
    final documentTheme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Theme.of(context).colorScheme.primary,
      ),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: const Color(0xFF202124),
        displayColor: const Color(0xFF202124),
      ),
      useMaterial3: true,
    );
    final children = <Widget>[];
    var offset = 0;
    while (offset < source.length) {
      if (_start == offset) {
        children.add(_editor());
        offset = _end;
        if (offset >= source.length) break;
      }
      final start = offset;
      // Keep fenced code (including Mermaid) together across blank lines.
      String? fence;
      do {
        final newline = source.indexOf('\n', offset);
        final end = newline < 0 ? source.length : newline + 1;
        final line = source.substring(offset, end).trim();
        final match = RegExp(r'^(`{3,}|~{3,})').firstMatch(line);
        if (match != null) {
          if (fence == null) {
            fence = match.group(1)!;
          } else if (line.startsWith(fence)) {
            fence = null;
          }
        }
        offset = end;
        if (line.isEmpty && fence == null) break;
      } while (offset < source.length);
      final end = offset;
      children.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _activate(start, end),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: MarkdownBody(
              data: source.substring(start, end),
              imageDirectory: widget.imageDirectory,
              builders: widget.builders,
              styleSheet: MarkdownStyleSheet.fromTheme(documentTheme).copyWith(
                p: const TextStyle(
                  fontSize: 17,
                  height: 1.65,
                  color: Color(0xFF202124),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_start == source.length) children.add(_editor());
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
        onTap: _appendBlock,
        child: const SizedBox(
          key: Key('append-live-block'),
          height: 120,
          width: double.infinity,
        ),
      ),
    );
    return Theme(
      data: documentTheme,
      child: ColoredBox(
        color: Colors.white,
        child: SingleChildScrollView(
          key: const Key('markdown-live-preview'),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
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
    _focus.dispose();
    super.dispose();
  }
}
