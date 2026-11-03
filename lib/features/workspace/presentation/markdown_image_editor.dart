import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnote/l10n/l10n.dart';

import 'markdown_image_size.dart';
import 'markdown_rendered_block.dart';

/// Edits a block that is a single picture: drag its corner or type a size,
/// with the proportions locked or free. The size is written into the alt
/// text of [controller]'s Markdown, see [MarkdownImageSize].
class MarkdownImageEditor extends StatefulWidget {
  const MarkdownImageEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onEditAsMarkdown,
    this.imageDirectory,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEditAsMarkdown;
  final String? imageDirectory;

  @override
  State<MarkdownImageEditor> createState() => _MarkdownImageEditorState();
}

class _MarkdownImageEditorState extends State<MarkdownImageEditor> {
  static const _minSide = 16;

  final _imageKey = GlobalKey();

  /// The size shown while the corner is being dragged, before it is written.
  MarkdownImageSize? _dragSize;
  Size _dragStart = Size.zero;
  Offset _dragDelta = Offset.zero;

  /// Width over height of the picture itself, once it has been seen.
  double? _naturalRatio;

  MarkdownImageLink? get _link =>
      MarkdownImageLink.parse(widget.controller.text);

  /// A picture with no height keeps its own proportions.
  bool get _locked => _link?.size?.height == null;

  Size? _shownSize() {
    final box = _imageKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return null;
    return box.size;
  }

  void _measureNaturalRatio() {
    final shown = _shownSize();
    if (shown != null && _locked) _naturalRatio = shown.width / shown.height;
  }

  /// The proportions to keep when the width or height alone changes.
  double _ratio() {
    final size = _link?.size;
    if (_naturalRatio != null) return _naturalRatio!;
    if (size?.height != null) return size!.width / size.height!;
    final shown = _shownSize();
    return shown == null ? 1 : shown.width / shown.height;
  }

  void _write(MarkdownImageSize? size) {
    final link = _link;
    if (link == null) return;
    final text = link.withSize(size);
    if (text == widget.controller.text) return;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// The size written now, or the size the picture is drawn at without one.
  MarkdownImageSize? _currentSize() {
    final size = _link?.size;
    if (size != null && size.height != null) return size;
    final shown = _shownSize();
    if (shown == null) return size;
    return MarkdownImageSize(
      size?.width ?? shown.width.round(),
      shown.height.round(),
    );
  }

  void _toggleLock() {
    final current = _currentSize();
    if (current == null) return;
    _measureNaturalRatio();
    _write(
      _locked
          ? MarkdownImageSize(current.width, current.height)
          : MarkdownImageSize(current.width),
    );
  }

  void _dragStarted(DragStartDetails details) {
    _measureNaturalRatio();
    final size = _link?.size;
    _dragStart =
        _shownSize() ??
        Size(
          (size?.width ?? 200).toDouble(),
          (size?.height ?? size?.width ?? 200).toDouble(),
        );
    _dragDelta = Offset.zero;
  }

  void _dragUpdated(DragUpdateDetails details, double maxWidth) {
    _dragDelta += details.delta;
    final width = (_dragStart.width + _dragDelta.dx)
        .clamp(_minSide.toDouble(), math.max(maxWidth, _minSide.toDouble()))
        .round();
    setState(() {
      if (_locked) {
        _dragSize = MarkdownImageSize(width);
      } else {
        final height = math.max(
          _minSide,
          (_dragStart.height + _dragDelta.dy).round(),
        );
        _dragSize = MarkdownImageSize(width, height);
      }
    });
  }

  void _dragEnded() {
    final size = _dragSize;
    setState(() => _dragSize = null);
    if (size != null) _write(size);
  }

  Future<void> _openDialog() async {
    _measureNaturalRatio();
    final current = _currentSize();
    final result = await showDialog<({MarkdownImageSize? size})>(
      context: context,
      builder: (context) => MarkdownImageSizeDialog(
        initialSize: current,
        locked: _locked,
        aspectRatio: _ratio(),
      ),
    );
    if (result == null || !mounted) return;
    _write(result.size);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final link = _link;
    if (link == null) return const SizedBox();
    final size = _dragSize ?? link.size;
    final locked = _locked;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dragSize == null) _measureNaturalRatio();
    });
    return Focus(
      focusNode: widget.focusNode,
      skipTraversal: true,
      child: TextFieldTapRegion(
        onTapOutside: (_) => widget.focusNode.unfocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  key: const Key('markdown-image-lock-ratio'),
                  tooltip: l10n.imageLockAspectRatio,
                  icon: Icon(
                    locked ? Icons.lock_outline : Icons.lock_open,
                    size: 20,
                  ),
                  isSelected: locked,
                  visualDensity: VisualDensity.compact,
                  onPressed: _toggleLock,
                ),
                TextButton.icon(
                  key: const Key('markdown-image-size'),
                  onPressed: _openDialog,
                  icon: const Icon(Icons.photo_size_select_large, size: 18),
                  label: Text(
                    size == null
                        ? l10n.imageOriginalSize
                        : '$size'.replaceFirst('x', ' × '),
                  ),
                ),
                IconButton(
                  key: const Key('markdown-image-reset-size'),
                  tooltip: l10n.imageResetSize,
                  icon: const Icon(Icons.restart_alt, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: link.size == null ? null : () => _write(null),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('markdown-image-edit-markdown'),
                  onPressed: widget.onEditAsMarkdown,
                  icon: const Icon(Icons.code, size: 18),
                  label: Text(l10n.imageEditMarkdown),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 8),
                      // Room for the handle while the picture loads.
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        child: KeyedSubtree(
                          key: _imageKey,
                          child: MarkdownImage(
                            key: const Key('markdown-image-editor-picture'),
                            uri:
                                Uri.tryParse(link.src.split('#').first) ??
                                Uri(),
                            directory: widget.imageDirectory,
                            alt: link.alt,
                            width: size?.width.toDouble(),
                            height: size?.height?.toDouble(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeDownRight,
                        child: GestureDetector(
                          key: const Key('markdown-image-resize-handle'),
                          behavior: HitTestBehavior.opaque,
                          // Track the finger from where it went down.
                          dragStartBehavior: DragStartBehavior.down,
                          onPanStart: _dragStarted,
                          onPanUpdate: (details) =>
                              _dragUpdated(details, constraints.maxWidth - 8),
                          onPanEnd: (_) => _dragEnded(),
                          onPanCancel: _dragEnded,
                          child: Tooltip(
                            message: l10n.imageDragToResize,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// Asks for a picture's width and height. Pops `(size: ...)` with the new
/// size, `(size: null)` to reset it, or nothing when cancelled.
class MarkdownImageSizeDialog extends StatefulWidget {
  const MarkdownImageSizeDialog({
    super.key,
    required this.initialSize,
    required this.locked,
    required this.aspectRatio,
  });

  final MarkdownImageSize? initialSize;
  final bool locked;

  /// Width over height, kept while [locked].
  final double aspectRatio;

  @override
  State<MarkdownImageSizeDialog> createState() =>
      _MarkdownImageSizeDialogState();
}

class _MarkdownImageSizeDialogState extends State<MarkdownImageSizeDialog> {
  late final _width = TextEditingController(
    text: widget.initialSize?.width.toString() ?? '',
  );
  late final _height = TextEditingController(
    text: widget.initialSize?.height?.toString() ?? '',
  );
  late bool _locked = widget.locked;

  /// Set while one field is filled in from the other.
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _width.addListener(() => _changed(_width, _height, 1 / widget.aspectRatio));
    _height.addListener(() => _changed(_height, _width, widget.aspectRatio));
    if (_locked && _height.text.isEmpty) {
      _follow(_width, _height, 1 / widget.aspectRatio);
    }
  }

  void _changed(
    TextEditingController from,
    TextEditingController to,
    double factor,
  ) {
    _follow(from, to, factor);
    setState(() {});
  }

  /// Keeps [to] in proportion with [from] while the ratio is locked.
  void _follow(
    TextEditingController from,
    TextEditingController to,
    double factor,
  ) {
    if (_following || !_locked) return;
    final value = int.tryParse(from.text);
    _following = true;
    to.text = value == null
        ? ''
        : math.max(1, (value * factor).round()).toString();
    _following = false;
  }

  int? get _widthValue {
    final value = int.tryParse(_width.text);
    return value == null || value <= 0 ? null : value;
  }

  int? get _heightValue {
    final value = int.tryParse(_height.text);
    return value == null || value <= 0 ? null : value;
  }

  MarkdownImageSize? get _result {
    final width = _widthValue;
    if (width == null) return null;
    if (_locked || _height.text.isEmpty) return MarkdownImageSize(width);
    final height = _heightValue;
    return height == null ? null : MarkdownImageSize(width, height);
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  Widget _field(Key key, TextEditingController controller, String label) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, suffixText: 'px'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;
    return AlertDialog(
      title: Text(l10n.imageSizeTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _field(
                    const Key('markdown-image-size-width'),
                    _width,
                    l10n.imageWidth,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    const Key('markdown-image-size-height'),
                    _height,
                    l10n.imageHeight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('markdown-image-size-lock'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.imageLockAspectRatio),
              value: _locked,
              onChanged: (value) => setState(() {
                _locked = value ?? false;
                _follow(_width, _height, 1 / widget.aspectRatio);
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('markdown-image-size-reset'),
          onPressed: () => Navigator.pop(context, (size: null)),
          child: Text(l10n.imageResetSize),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('markdown-image-size-apply'),
          onPressed: result == null
              ? null
              : () {
                  // Read again: the last keystroke may not be built yet.
                  final size = _result;
                  if (size != null) Navigator.pop(context, (size: size));
                },
          child: Text(l10n.apply),
        ),
      ],
    );
  }
}
