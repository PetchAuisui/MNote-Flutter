import 'package:mnote/l10n/l10n.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/presentation/workspace_toolbar_metrics.dart';
import 'package:scribble/scribble.dart';

import 'editor_settings.dart';
import 'ink_session.dart';
import 'ink_storage_scope.dart';
import 'markdown_document_canvas.dart';
import 'markdown_live_editor.dart';
import 'markdown_outline.dart';
import 'mermaid/mermaid_element_builder.dart';

/// Lets a toolbar outside [InkPage] fit the page to the view width.
class InkFitController {
  VoidCallback? _fit;

  /// Called by the [InkPage] that currently shows the page.
  void attach(VoidCallback fit) => _fit = fit;

  void detach(VoidCallback fit) {
    if (_fit == fit) _fit = null;
  }

  /// Fits the page to the view width, keeping the current scroll position.
  void fit() => _fit?.call();
}

class InkPage extends StatefulWidget {
  const InkPage({
    super.key,
    required this.session,
    required this.markdown,
    required this.name,
    this.imageDirectory,
    this.fileStorage,
    this.transformationController,
    this.showToolbar = true,
    this.fitController,
    this.outline,
  });
  final InkSession session;
  final String markdown;
  final String name;
  final String? imageDirectory;

  /// Defaults to the storage from [InkStorageScope], then the device.
  final InkFileStorage? fileStorage;
  final TransformationController? transformationController;
  final bool showToolbar;
  final InkFitController? fitController;

  /// Lets the outline panel jump to headings and follow the visible one.
  final MarkdownOutlineController? outline;

  @override
  State<InkPage> createState() => _InkPageState();
}

class _InkPageState extends State<InkPage> with SingleTickerProviderStateMixin {
  late TransformationController _transform;
  bool _ownsTransform = false;
  final _pageKey = GlobalKey();
  final _blockKeys = <int, GlobalKey>{};
  late final _scrollAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  double _viewportHeight = 0;
  bool _jumping = false;
  VoidCallback? _jumpStep;
  String? _headingsSource;
  List<MarkdownHeading> _headings = const [];
  InkTool _tool = InkTool.pen;
  Color _penColor = const Color(0xFF202124);
  double _penWidth = 3;
  bool get _touch =>
      widget.session.pen.value.allowedPointersMode == ScribblePointerMode.all;
  double _viewportWidth = 0;
  Timer? _autoSaveInkTimer;
  late InkFileStorage _storage;

  @override
  void initState() {
    super.initState();
    _storage = widget.fileStorage ?? const DeviceInkFileStorage();
    widget.session.pen.addListener(_onPenChanged);
    EditorSettings.instance.addListener(_onEditorSettingsChanged);
    _attachTransform();
  }

  void _onEditorSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onPenChanged() {
    if (widget.session.isDirty) {
      _autoSaveInkTimer?.cancel();
      _autoSaveInkTimer = Timer(const Duration(milliseconds: 600), () async {
        if (!mounted) return;
        final snapshot = widget.session.encode();
        final saved = await _storage.autoSave(
          name: widget.name,
          bytes: Uint8List.fromList(utf8.encode(snapshot)),
        );
        if (saved && mounted) {
          widget.session.markSaved(snapshot);
        }
      });
    }
  }

  Future<void> _autoLoadInkIfAvailable() async {
    if (widget.session.pen.currentSketch.lines.isEmpty) {
      final bytes = await _storage.autoLoad(name: widget.name);
      if (bytes != null && mounted) {
        try {
          widget.session.load(utf8.decode(bytes));
        } catch (_) {}
      }
    }
  }

  bool _loadedInk = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage =
        widget.fileStorage ?? InkStorageScope.maybeOf(context) ?? _storage;
    if (!_loadedInk) {
      _loadedInk = true;
      _autoLoadInkIfAvailable();
    }
  }

  void _attachTransform() {
    final external = widget.transformationController;
    _ownsTransform = external == null;
    _transform = external ?? TransformationController();
    _transform.addListener(_clampHorizontal);
    _transform.addListener(_trackActiveHeading);
    widget.outline?.attach(_scrollToOffset);
    widget.fitController?.attach(_fit);
  }

  @override
  void didUpdateWidget(InkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outline != widget.outline) {
      oldWidget.outline?.detach(_scrollToOffset);
      widget.outline?.attach(_scrollToOffset);
    }
    if (oldWidget.fitController != widget.fitController) {
      oldWidget.fitController?.detach(_fit);
      widget.fitController?.attach(_fit);
    }
    if (oldWidget.transformationController != widget.transformationController) {
      _transform.removeListener(_clampHorizontal);
      _transform.removeListener(_trackActiveHeading);
      if (_ownsTransform) _transform.dispose();
      _attachTransform();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
  }

  @override
  void dispose() {
    _transform.removeListener(_clampHorizontal);
    _transform.removeListener(_trackActiveHeading);
    widget.outline?.detach(_scrollToOffset);
    widget.fitController?.detach(_fit);
    _scrollAnimation.dispose();
    _autoSaveInkTimer?.cancel();
    if (widget.session.isDirty) {
      final snapshot = widget.session.encode();
      final session = widget.session;
      _storage
          .autoSave(
            name: widget.name,
            bytes: Uint8List.fromList(utf8.encode(snapshot)),
          )
          .then((saved) {
            if (saved) {
              session.markSaved(snapshot);
            }
          });
    }
    widget.session.pen.removeListener(_onPenChanged);
    EditorSettings.instance.removeListener(_onEditorSettingsChanged);
    if (_ownsTransform) {
      _transform.dispose();
    }
    super.dispose();
  }

  RenderBox? _blockBox(int offset) {
    final box = _blockKeys[offset]?.currentContext?.findRenderObject();
    return box is RenderBox && box.attached ? box : null;
  }

  /// Top of the heading's block in page coordinates, before any zoom.
  double? _headingTop(int offset) {
    final page = _pageKey.currentContext?.findRenderObject();
    final box = _blockBox(offset);
    if (page is! RenderBox || box == null) return null;
    return box.localToGlobal(Offset.zero, ancestor: page).dy;
  }

  void _trackActiveHeading() {
    final outline = widget.outline;
    if (_jumping || outline == null) return;
    if (_headingsSource != widget.markdown) {
      _headings = parseMarkdownHeadings(widget.markdown);
      _headingsSource = widget.markdown;
    }
    final value = _transform.value;
    final scale = value.getMaxScaleOnAxis();
    final ty = value.getTranslation().y;
    int? active = _headings.isEmpty ? null : _headings.first.offset;
    for (final heading in _headings) {
      final top = _headingTop(heading.offset);
      if (top == null) continue;
      // A heading counts as reached once it is near the top of the view.
      if (top * scale + ty > 48) break;
      active = heading.offset;
    }
    outline.activeOffset.value = active;
  }

  Future<void> _scrollToOffset(int offset) async {
    final top = _headingTop(offset);
    final page = _pageKey.currentContext?.size;
    if (top == null || page == null) return;
    final value = _transform.value;
    final scale = value.getMaxScaleOnAxis();
    final from = value.getTranslation().y;
    final to = (16 - top * scale).clamp(_lowestOffset(scale), 0.0);
    _jumping = true;
    widget.outline?.activeOffset.value = offset;
    // A jump started mid-way through another replaces it rather than letting
    // both move the page at once.
    if (_jumpStep case final previous?) {
      _scrollAnimation.removeListener(previous);
    }
    void step() {
      final t = Curves.easeInOutCubic.transform(_scrollAnimation.value);
      final current = _transform.value;
      _transform.value = current.clone()
        ..setTranslationRaw(
          current.getTranslation().x,
          from + (to - from) * t,
          0,
        );
    }

    _jumpStep = step;
    _scrollAnimation.addListener(step);
    try {
      await _scrollAnimation.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Replaced by a newer jump, which now owns the animation.
      return;
    }
    _scrollAnimation.removeListener(step);
    _jumpStep = null;
    _jumping = false;
  }

  /// The furthest the page can scroll up at [scale] before its bottom edge
  /// leaves the bottom of the view.
  double _lowestOffset(double scale) {
    final rendered = _pageKey.currentContext?.size?.height ?? 0;
    final height = math.max(rendered, widget.session.height);
    return (_viewportHeight - height * scale).clamp(
      double.negativeInfinity,
      0.0,
    );
  }

  /// Fits the page to the view width while keeping the part of the page in
  /// the middle of the view where it is, instead of jumping back to the top.
  void _fit() {
    final scale = (_viewportWidth / InkSession.pageWidth).clamp(0.1, 1.0);
    final dx = _viewportWidth > InkSession.pageWidth
        ? (_viewportWidth - InkSession.pageWidth) / 2
        : 0.0;
    final current = _transform.value;
    final centre =
        (_viewportHeight / 2 - current.getTranslation().y) /
        current.getMaxScaleOnAxis();
    final dy = (_viewportHeight / 2 - centre * scale).clamp(
      _lowestOffset(scale),
      0.0,
    );
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(dx, dy, 0);
  }

  /// Keeps the page horizontally centred (or edge-clamped when zoomed in).
  /// Runs on every transform change, so stale fits, stray pans and viewport
  /// resizes can never leave the margins shifted.
  void _clampHorizontal() {
    if (_viewportWidth <= 0) return;
    final value = _transform.value;
    final scale = value.getMaxScaleOnAxis();
    final scaledWidth = InkSession.pageWidth * scale;
    final tx = value.getTranslation().x;
    final target = scaledWidth <= _viewportWidth
        ? (_viewportWidth - scaledWidth) / 2
        : tx.clamp(_viewportWidth - scaledWidth, 0.0);
    if ((target - tx).abs() < 0.01) return;
    _transform.value = value.clone()
      ..setTranslationRaw(target, value.getTranslation().y, 0);
  }

  void _selectTool(InkTool tool) {
    final pen = widget.session.pen;
    setState(() => _tool = tool);
    switch (tool) {
      case InkTool.pen:
        pen
          ..setColor(_penColor)
          ..setStrokeWidth(_penWidth);
      case InkTool.highlighter:
        pen
          ..setColor(InkSession.highlightInk(widget.session.highlightColor))
          ..setStrokeWidth(widget.session.highlightWidth);
      case InkTool.eraser:
        pen
          ..setEraser()
          // Radius of the eraser circle; it rubs out only what it covers.
          ..setStrokeWidth(12);
    }
  }

  void _selectColor(Color color) {
    if (_tool == InkTool.highlighter) {
      widget.session.selectHighlight(color: color);
      widget.session.pen.setColor(InkSession.highlightInk(color));
      return;
    }
    setState(() {
      _penColor = color;
      _tool = InkTool.pen;
    });
    widget.session.pen
      ..setColor(color)
      ..setStrokeWidth(_penWidth);
  }

  void _selectWidth(double width) {
    if (_tool == InkTool.highlighter) {
      widget.session.selectHighlight(width: width);
      widget.session.pen.setStrokeWidth(width);
      return;
    }
    setState(() {
      _penWidth = width;
      _tool = InkTool.pen;
    });
    widget.session.pen
      ..setColor(_penColor)
      ..setStrokeWidth(width);
  }

  Future<void> _clearInk() async {
    if (widget.session.pen.currentSketch.lines.isEmpty) return;
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text(context.l10n.clearInkTitle),
        content: Text(context.l10n.clearInkBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.clearAll),
          ),
        ],
      ),
    );
    if (clear == true) widget.session.pen.clear();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final pen = widget.session.pen;
      final canvas = LayoutBuilder(
        builder: (context, constraints) {
          _viewportHeight = constraints.maxHeight;
          if (widget.outline != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _trackActiveHeading();
            });
          }
          if (_viewportWidth != constraints.maxWidth) {
            _viewportWidth = constraints.maxWidth;
            // Re-centre immediately (also covers rotation / split-view resize).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _clampHorizontal();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fit();
            });
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final size = _pageKey.currentContext?.size;
            if (size != null) widget.session.grow(size.height);
          });
          // The gray backdrop and the page's border and shadow show where
          // ink can go; nothing outside the page is drawable.
          return ColoredBox(
            key: const Key('ink-page-backdrop'),
            color: _backdropColor,
            child: InteractiveViewer(
              transformationController: _transform,
              constrained: false,
              alignment: Alignment.topLeft,
              // InteractiveViewer won't zoom out past the point where the page
              // fills the viewport. On a viewport wider than the page that
              // stops the zoom short of the fitted state, so leave the sides
              // open; _clampHorizontal keeps the page centred or edge-clamped.
              boundaryMargin: const EdgeInsets.symmetric(horizontal: 10000),
              minScale: 0.1,
              maxScale: 4,
              panEnabled: !_touch,
              scaleEnabled: !_touch,
              // InteractiveViewer already scales the complete page. Keep
              // Scribble's scale at 1 so stroke width is not scaled twice.
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x29000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: InkSession.pageWidth,
                  child: Stack(
                    key: _pageKey,
                    children: [
                      MarkdownDocumentSurface(
                        markdown: widget.markdown,
                        height: widget.session.height,
                        selectable: false,
                        blockKeys: widget.outline == null ? null : _blockKeys,
                        textOptions: widget.session.layoutFor(
                          EditorSettings.instance.textOptions,
                        ),
                        imageDirectory: widget.imageDirectory,
                        builders: {'code': MermaidElementBuilder()},
                      ),
                      // Highlighter strokes multiply onto the page, so the text
                      // stays crisp like a real highlighter and pictures are
                      // marked too.
                      Positioned.fill(
                        child: InkLayer(notifier: pen, highlighter: true),
                      ),
                      Positioned.fill(
                        child: InkLayer(notifier: pen, highlighter: false),
                      ),
                      // Receives the pointer input; the layers above and beneath
                      // the text do the drawing.
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: Scribble(notifier: pen, drawPen: false),
                        ),
                      ),
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            key: Key('ink-page-border'),
                            decoration: BoxDecoration(
                              border: Border.fromBorderSide(
                                BorderSide(color: _pageBorderColor, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      if (!widget.showToolbar) {
        return canvas;
      }
      return Column(
        children: [
          InkToolbar(
            selectedTool: _tool,
            penColor: _tool == InkTool.highlighter
                ? widget.session.highlightColor
                : _penColor,
            penWidth: _tool == InkTool.highlighter
                ? widget.session.highlightWidth
                : _penWidth,
            touchEnabled: _touch,
            onToolSelected: _selectTool,
            onColorSelected: _selectColor,
            onWidthSelected: _selectWidth,
            colorPresets: _tool == InkTool.highlighter
                ? widget.session.highlightPresets
                : widget.session.colorPresets,
            widthPresets: _tool == InkTool.highlighter
                ? widget.session.highlightWidthPresets
                : widget.session.widthPresets,
            onColorPresetChanged: _tool == InkTool.highlighter
                ? widget.session.setHighlightPreset
                : widget.session.setColorPreset,
            onWidthPresetChanged: _tool == InkTool.highlighter
                ? widget.session.setHighlightWidthPreset
                : widget.session.setWidthPreset,
            onUndo: pen.canUndo ? pen.undo : null,
            onRedo: pen.canRedo ? pen.redo : null,
            onClear: pen.currentSketch.lines.isEmpty ? null : _clearInk,
            eraseWholeStroke: widget.session.eraseWholeStroke,
            onEraserModeChanged: (whole) =>
                setState(() => widget.session.setEraseWholeStroke(whole)),
            onTouchChanged: () {
              pen.setAllowedPointersMode(
                _touch ? ScribblePointerMode.penOnly : ScribblePointerMode.all,
              );
            },
            onFit: _fit,
          ),
          Expanded(child: canvas),
        ],
      );
    },
  );
}

enum InkTool { pen, highlighter, eraser }

/// Behind the page while drawing, so the white page stands out.
const _backdropColor = Color(0xFFE8EAED);

/// Edge of the drawable page.
const _pageBorderColor = Color(0xFFADB1B8);

class _InkHistoryDock extends StatelessWidget {
  const _InkHistoryDock({required this.onUndo, required this.onRedo});

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('ink-history-dock'),
      color: colors.surfaceContainerHighest,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('ink-undo'),
            tooltip: context.l10n.inkUndo,
            color: colors.onSurfaceVariant,
            disabledColor: colors.onSurfaceVariant.withValues(alpha: 0.38),
            onPressed: onUndo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            key: const Key('ink-redo'),
            tooltip: context.l10n.inkRedo,
            color: colors.onSurfaceVariant,
            disabledColor: colors.onSurfaceVariant.withValues(alpha: 0.38),
            onPressed: onRedo,
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
    );
  }
}

class InkToolbar extends StatelessWidget {
  const InkToolbar({
    super.key,
    required this.selectedTool,
    required this.penColor,
    required this.penWidth,
    required this.touchEnabled,
    required this.onToolSelected,
    required this.onColorSelected,
    required this.onWidthSelected,
    required this.colorPresets,
    required this.widthPresets,
    required this.onColorPresetChanged,
    required this.onWidthPresetChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onTouchChanged,
    required this.onFit,
    required this.eraseWholeStroke,
    required this.onEraserModeChanged,
  });

  final InkTool selectedTool;
  final Color penColor;
  final double penWidth;
  final bool touchEnabled;
  final ValueChanged<InkTool> onToolSelected;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onWidthSelected;
  final List<Color> colorPresets;
  final List<double> widthPresets;
  final void Function(int index, Color color) onColorPresetChanged;
  final void Function(int index, double width) onWidthPresetChanged;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final VoidCallback onTouchChanged;
  final VoidCallback onFit;

  /// Shown in place of colors and widths while the eraser is selected.
  final bool eraseWholeStroke;
  final ValueChanged<bool> onEraserModeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        key: const Key('ink-toolbar'),
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: workspaceToolbarHeight,
          width: double.infinity,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: _InkHistoryDock(onUndo: onUndo, onRedo: onRedo),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _InkToolbarGroup(
                              key: const Key('ink-tools-group'),
                              label: context.l10n.inkGroupDraw,
                              color: colors.primaryContainer.withValues(
                                alpha: 0.45,
                              ),
                              children: [
                                _toolButton(
                                  key: const Key('ink-pen'),
                                  tooltip: context.l10n.inkPen,
                                  icon: const Icon(Icons.edit_outlined),
                                  selectedIcon: const Icon(Icons.edit),
                                  selected: selectedTool == InkTool.pen,
                                  onPressed: () => onToolSelected(InkTool.pen),
                                ),
                                _toolButton(
                                  key: const Key('ink-highlighter'),
                                  tooltip: context.l10n.inkHighlighter,
                                  icon: const _HighlighterIcon(),
                                  selectedIcon: const _HighlighterIcon(),
                                  selected: selectedTool == InkTool.highlighter,
                                  onPressed: () =>
                                      onToolSelected(InkTool.highlighter),
                                ),
                                _toolButton(
                                  key: const Key('ink-eraser'),
                                  tooltip: context.l10n.inkEraser,
                                  icon: const _EraserIcon(),
                                  selectedIcon: const _EraserIcon(filled: true),
                                  selected: selectedTool == InkTool.eraser,
                                  onPressed: () =>
                                      onToolSelected(InkTool.eraser),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            _InkToolbarGroup(
                              key: const Key('ink-style-group'),
                              label: context.l10n.inkGroupStroke,
                              children: selectedTool == InkTool.eraser
                                  ? _eraserModes(context)
                                  : [
                                      for (
                                        var i = 0;
                                        i < colorPresets.length;
                                        i++
                                      )
                                        _ColorSwatchButton(
                                          key: Key('ink-color-preset-$i'),
                                          color: colorPresets[i],
                                          selected: colorPresets[i] == penColor,
                                          onTap: () =>
                                              colorPresets[i] == penColor
                                              ? _editColor(context, i)
                                              : onColorSelected(
                                                  colorPresets[i],
                                                ),
                                          onLongPress: () =>
                                              _editColor(context, i),
                                        ),
                                      IconButton(
                                        key: const Key('ink-color'),
                                        tooltip: context.l10n.inkChangeColor,
                                        icon: const Icon(
                                          Icons.palette_outlined,
                                        ),
                                        onPressed: () {
                                          final selected = colorPresets.indexOf(
                                            penColor,
                                          );
                                          _editColor(
                                            context,
                                            selected < 0
                                                ? colorPresets.length - 1
                                                : selected,
                                            initial: penColor,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      for (
                                        var i = 0;
                                        i < widthPresets.length;
                                        i++
                                      )
                                        _WidthPresetButton(
                                          key: Key('ink-width-preset-$i'),
                                          width: widthPresets[i],
                                          color: penColor,
                                          selected: widthPresets[i] == penWidth,
                                          onTap: () =>
                                              widthPresets[i] == penWidth
                                              ? _editWidth(context, i)
                                              : onWidthSelected(
                                                  widthPresets[i],
                                                ),
                                          onLongPress: () =>
                                              _editWidth(context, i),
                                        ),
                                    ],
                            ),
                            const SizedBox(width: 8),
                            _InkToolbarGroup(
                              key: const Key('ink-page-group'),
                              label: context.l10n.inkGroupPage,
                              children: [
                                _toolButton(
                                  key: const Key('ink-touch'),
                                  tooltip: touchEnabled
                                      ? context.l10n.inkFingerOn
                                      : context.l10n.inkPencilOnly,
                                  icon: const Icon(Icons.touch_app_outlined),
                                  selectedIcon: const Icon(Icons.touch_app),
                                  selected: touchEnabled,
                                  onPressed: onTouchChanged,
                                ),
                                IconButton(
                                  key: const Key('ink-fit'),
                                  tooltip: context.l10n.inkFitWidth,
                                  onPressed: onFit,
                                  icon: const Icon(Icons.fit_screen),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            _InkToolbarGroup(
                              key: const Key('ink-management-group'),
                              label: context.l10n.inkGroupManage,
                              color: colors.secondaryContainer.withValues(
                                alpha: 0.55,
                              ),
                              children: [
                                PopupMenuButton<bool>(
                                  key: const Key('ink-management-menu'),
                                  tooltip: context.l10n.inkMore,
                                  onSelected: (_) => onClear?.call(),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      key: const Key('ink-clear'),
                                      value: true,
                                      enabled: onClear != null,
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.delete_outline,
                                          color: onClear == null
                                              ? null
                                              : colors.error,
                                        ),
                                        title: Text(
                                          context.l10n.inkClearAll,
                                          style: TextStyle(
                                            color: onClear == null
                                                ? null
                                                : colors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_horiz),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  List<Widget> _eraserModes(BuildContext context) => [
    _EraserModeButton(
      key: const Key('ink-eraser-partial'),
      icon: Icons.auto_fix_normal,
      label: context.l10n.inkErasePartial,
      selected: !eraseWholeStroke,
      onTap: () => onEraserModeChanged(false),
    ),
    _EraserModeButton(
      key: const Key('ink-eraser-whole'),
      icon: Icons.gesture,
      label: context.l10n.inkEraseWhole,
      selected: eraseWholeStroke,
      onTap: () => onEraserModeChanged(true),
    ),
  ];

  Widget _toolButton({
    required Key key,
    required String tooltip,
    required Widget icon,
    required Widget selectedIcon,
    required bool selected,
    required VoidCallback onPressed,
  }) => IconButton(
    key: key,
    tooltip: tooltip,
    isSelected: selected,
    onPressed: onPressed,
    icon: icon,
    selectedIcon: selectedIcon,
  );

  Future<void> _editColor(
    BuildContext context,
    int index, {
    Color? initial,
  }) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) =>
          _CustomColorDialog(initial: initial ?? colorPresets[index]),
    );
    if (picked == null) return;
    onColorPresetChanged(index, picked);
    onColorSelected(picked);
  }

  Future<void> _editWidth(BuildContext context, int index) async {
    final picked = await showDialog<double>(
      context: context,
      builder: (_) =>
          _CustomWidthDialog(initial: widthPresets[index], color: penColor),
    );
    if (picked == null) return;
    onWidthPresetChanged(index, picked);
    onWidthSelected(picked);
  }
}

class _EraserModeButton extends StatelessWidget {
  const _EraserModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: foreground),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InkToolbarGroup extends StatelessWidget {
  const _InkToolbarGroup({
    super.key,
    required this.label,
    required this.children,
    this.color,
  });

  final String label;
  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _HighlighterIcon extends StatelessWidget {
  const _HighlighterIcon();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _HighlighterIconPainter(
      color:
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _HighlighterIconPainter extends CustomPainter {
  const _HighlighterIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final marker = Path()
      ..moveTo(6, 2)
      ..lineTo(18, 2)
      ..lineTo(18, 13)
      ..lineTo(15, 17)
      ..lineTo(15, 21)
      ..lineTo(9, 21)
      ..lineTo(9, 17)
      ..lineTo(6, 13)
      ..close();
    canvas.drawPath(marker, stroke);
    canvas.drawRect(const Rect.fromLTRB(6, 2, 18, 13), fill);
    canvas.drawRect(const Rect.fromLTRB(9, 18, 15, 21), fill);
    canvas.drawLine(const Offset(8, 23), const Offset(16, 23), stroke);
  }

  @override
  bool shouldRepaint(covariant _HighlighterIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _EraserIcon extends StatelessWidget {
  const _EraserIcon({this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(24),
    painter: _EraserIconPainter(
      color:
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurfaceVariant,
      filled: filled,
    ),
  );
}

class _EraserIconPainter extends CustomPainter {
  const _EraserIconPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final eraser = Path()
      ..moveTo(7, 3)
      ..lineTo(21, 17)
      ..lineTo(15, 23)
      ..lineTo(1, 9)
      ..close();
    if (filled) {
      canvas.drawPath(
        eraser,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      final selectedDetail = Paint()
        ..color = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        const Offset(11, 13),
        const Offset(16, 8),
        selectedDetail,
      );
    } else {
      canvas.drawPath(eraser, outline);
      canvas.drawLine(const Offset(9, 15), const Offset(15, 9), outline);
    }
    canvas.drawLine(const Offset(11, 23), const Offset(22, 23), outline);
  }

  @override
  bool shouldRepaint(covariant _EraserIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({required this.initial});

  final Color initial;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  /// Ready-made colors: tap one and you're done. Grays and browns, then the
  /// main hues in regular, dark and light shades.
  static const _palette = <Color>[
    Color(0xFF000000),
    Color(0xFF424242),
    Color(0xFF757575),
    Color(0xFFBDBDBD),
    Color(0xFFFFFFFF),
    Color(0xFF5D4037),
    Color(0xFF8D6E63),
    Color(0xFFD7CCC8),
    Color(0xFFF44336),
    Color(0xFFFF9800),
    Color(0xFFFFEB3B),
    Color(0xFF4CAF50),
    Color(0xFF009688),
    Color(0xFF2196F3),
    Color(0xFF3F51B5),
    Color(0xFF9C27B0),
    Color(0xFFB71C1C),
    Color(0xFFE65100),
    Color(0xFFF9A825),
    Color(0xFF1B5E20),
    Color(0xFF004D40),
    Color(0xFF0D47A1),
    Color(0xFF1A237E),
    Color(0xFF4A148C),
    Color(0xFFEF9A9A),
    Color(0xFFFFCC80),
    Color(0xFFFFF59D),
    Color(0xFFA5D6A7),
    Color(0xFF80CBC4),
    Color(0xFF90CAF9),
    Color(0xFF9FA8DA),
    Color(0xFFCE93D8),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(context.l10n.inkCustomColor),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: const Key('ink-color-preview'),
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _palette.length; i++)
                    _paletteSwatch(context, i, color),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.inkFineTune,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              _slider(
                context.l10n.inkHue,
                _hsv.hue,
                360,
                (v) => _hsv = _hsv.withHue(v),
                key: const Key('ink-color-hue'),
                track: [
                  for (var h = 0; h <= 360; h += 60)
                    HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
                ],
              ),
              _slider(
                context.l10n.inkSaturation,
                _hsv.saturation,
                1,
                (v) => _hsv = _hsv.withSaturation(v),
                key: const Key('ink-color-saturation'),
                track: [
                  _hsv.withSaturation(0).toColor(),
                  _hsv.withSaturation(1).toColor(),
                ],
              ),
              _slider(
                context.l10n.inkBrightness,
                _hsv.value,
                1,
                (v) => _hsv = _hsv.withValue(v),
                key: const Key('ink-color-value'),
                track: [const Color(0xFF000000), _hsv.withValue(1).toColor()],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('ink-color-apply'),
          onPressed: () => Navigator.pop(context, color),
          child: Text(context.l10n.ok),
        ),
      ],
    );
  }

  Widget _paletteSwatch(BuildContext context, int index, Color current) {
    final swatch = _palette[index];
    final selected = swatch.toARGB32() == current.toARGB32();
    final onSwatch = swatch.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
    return InkResponse(
      key: Key('ink-color-palette-$index'),
      radius: 20,
      onTap: () => setState(() => _hsv = HSVColor.fromColor(swatch)),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: swatch,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected ? Icon(Icons.check, size: 18, color: onSwatch) : null,
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double max,
    void Function(double) apply, {
    required Key key,
    required List<Color> track,
  }) => Row(
    children: [
      SizedBox(width: 72, child: Text(label)),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12,
            trackShape: _GradientTrackShape(track),
            thumbColor: Colors.white,
            overlayColor: Colors.black12,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 11,
              elevation: 3,
            ),
          ),
          child: Slider(
            key: key,
            value: value.clamp(0, max),
            max: max,
            onChanged: (v) => setState(() => apply(v)),
          ),
        ),
      ),
    ],
  );
}

/// A slider track that shows what each position looks like, so dragging
/// the thumb isn't guesswork.
class _GradientTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _GradientTrackShape(this.colors);

  final List<Color> colors;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    context.canvas
      ..drawRRect(
        rrect,
        Paint()..shader = LinearGradient(colors: colors).createShader(rect),
      )
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0x1F000000),
      );
  }
}

class _CustomWidthDialog extends StatefulWidget {
  const _CustomWidthDialog({required this.initial, required this.color});

  final double initial;
  final Color color;

  @override
  State<_CustomWidthDialog> createState() => _CustomWidthDialogState();
}

class _CustomWidthDialogState extends State<_CustomWidthDialog> {
  late double _width = widget.initial.clamp(1, 40);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.inkCustomWidth),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: Center(
                child: Container(
                  key: const Key('ink-width-preview'),
                  height: _width,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(_width / 2),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    key: const Key('ink-width-slider'),
                    value: _width,
                    min: 1,
                    max: 40,
                    onChanged: (v) => setState(() => _width = v),
                  ),
                ),
                SizedBox(width: 40, child: Text(_width.toStringAsFixed(0))),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('ink-width-apply'),
          onPressed: () => Navigator.pop(context, _width.roundToDouble()),
          child: Text(context.l10n.ok),
        ),
      ],
    );
  }
}

/// A stroke-width preset in the toolbar, drawn as a dot of that thickness.
/// Tap selects it; tap again or long-press edits the preset slot.
class _WidthPresetButton extends StatelessWidget {
  const _WidthPresetButton({
    super.key,
    required this.width,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final double width;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.inkWidthTip(width.toStringAsFixed(0)),
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? scheme.secondaryContainer.withValues(alpha: 0.8)
                  : null,
              border: Border.all(
                width: selected ? 2 : 1,
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: Container(
              width: width.clamp(2.0, 22.0),
              height: width.clamp(2.0, 22.0),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pen-colour swatch in the toolbar. Tap selects it; long-press edits the
/// preset slot.
class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.inkColorTip,
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                width: selected ? 3 : 1,
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Draws either the highlighter strokes or all other strokes of [notifier].
class InkLayer extends StatelessWidget {
  const InkLayer({
    super.key,
    required this.notifier,
    required this.highlighter,
  });

  final ScribbleNotifier notifier;
  final bool highlighter;

  @override
  Widget build(BuildContext context) {
    final sketch = ValueListenableBuilder<ScribbleState>(
      valueListenable: notifier,
      builder: (context, state, _) => ScribbleSketch(
        sketch: Sketch(
          lines: [
            // `lines` includes the stroke still being drawn, so ink follows
            // the pen; the highlighter's width is constant while drawing too.
            for (final line in state.lines)
              if (((line.color >> 24) & 0xFF != 0xFF) == highlighter)
                highlighter ? _constantWidth(line) : line,
          ],
        ),
      ),
    );
    return IgnorePointer(
      child: highlighter ? MultiplyBlend(child: sketch) : sketch,
    );
  }
}

/// Paints [child] with [BlendMode.multiply] onto what is already drawn
/// beneath it: dark text shows through unchanged while white paper and
/// pictures take on the colour, as with a real highlighter. The child must
/// paint into this layer (no repaint boundary of its own).
class MultiplyBlend extends SingleChildRenderObjectWidget {
  const MultiplyBlend({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMultiplyBlend();
}

class _RenderMultiplyBlend extends RenderProxyBox {
  @override
  bool get alwaysNeedsCompositing => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = BlendMode.multiply,
    );
    context.paintChild(child, offset);
    context.canvas.restore();
  }
}

SketchLine _constantWidth(SketchLine line) => line.copyWith(
  points: [
    for (var i = 0; i < line.points.length; i++)
      Point(
        line.points[i].x,
        line.points[i].y,
        pressure: i == 0 ? 0.5 : 0.5001,
      ),
  ],
);
