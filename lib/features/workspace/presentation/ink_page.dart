import 'package:flutter/material.dart';
import 'package:mnote/features/workspace/presentation/workspace_toolbar_metrics.dart';
import 'package:scribble/scribble.dart';

import 'ink_session.dart';
import 'markdown_document_canvas.dart';
import 'mermaid/mermaid_element_builder.dart';

class InkPage extends StatefulWidget {
  const InkPage({
    super.key,
    required this.session,
    required this.markdown,
    this.imageDirectory,
    this.transformationController,
    this.showToolbar = true,
    this.onViewportWidthChanged,
  });
  final InkSession session;
  final String markdown;
  final String? imageDirectory;
  final TransformationController? transformationController;
  final bool showToolbar;
  final ValueChanged<double>? onViewportWidthChanged;

  @override
  State<InkPage> createState() => _InkPageState();
}

class _InkPageState extends State<InkPage> {
  late TransformationController _transform;
  bool _ownsTransform = false;
  final _pageKey = GlobalKey();
  InkTool _tool = InkTool.pen;
  Color _penColor = const Color(0xFF202124);
  double _penWidth = 3;
  bool get _touch =>
      widget.session.pen.value.allowedPointersMode == ScribblePointerMode.all;
  double _viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    _attachTransform();
  }

  void _attachTransform() {
    final external = widget.transformationController;
    _ownsTransform = external == null;
    _transform = external ?? TransformationController();
    _transform.addListener(_clampHorizontal);
  }

  @override
  void didUpdateWidget(InkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformationController != widget.transformationController) {
      _transform.removeListener(_clampHorizontal);
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
    if (_ownsTransform) {
      _transform.dispose();
    }
    super.dispose();
  }

  void _fit() {
    final scale = (_viewportWidth / InkSession.pageWidth).clamp(0.1, 1.0);
    final dx = _viewportWidth > InkSession.pageWidth
        ? (_viewportWidth - InkSession.pageWidth) / 2
        : 0.0;
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(dx, 0, 0);
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
          ..setStrokeWidth(28);
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
        title: const Text('ล้างหมึกทั้งหมด?'),
        content: const Text('สามารถกดย้อนกลับได้หลังจากล้าง'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ล้างทั้งหมด'),
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
          if (_viewportWidth != constraints.maxWidth) {
            _viewportWidth = constraints.maxWidth;
            widget.onViewportWidthChanged?.call(constraints.maxWidth);
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
          return InteractiveViewer(
            transformationController: _transform,
            constrained: false,
            alignment: Alignment.topLeft,
            minScale: 0.1,
            maxScale: 4,
            panEnabled: !_touch,
            scaleEnabled: !_touch,
            // InteractiveViewer already scales the complete page. Keep
            // Scribble's scale at 1 so stroke width is not scaled twice.
            child: SizedBox(
              width: InkSession.pageWidth,
              child: Stack(
                key: _pageKey,
                children: [
                  MarkdownDocumentSurface(
                    markdown: widget.markdown,
                    height: widget.session.height,
                    selectable: false,
                    imageDirectory: widget.imageDirectory,
                    builders: {'code': MermaidElementBuilder()},
                    // Highlighter strokes sit beneath the text, so the text
                    // stays crisp on top of them like a real highlighter.
                    underlay: _InkLayer(notifier: pen, highlighter: true),
                  ),
                  Positioned.fill(
                    child: _InkLayer(notifier: pen, highlighter: false),
                  ),
                  // Receives the pointer input; the layers above and beneath
                  // the text do the drawing.
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: Scribble(notifier: pen, drawPen: false),
                    ),
                  ),
                ],
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
            tooltip: 'ย้อนกลับหมึก',
            color: colors.onSurfaceVariant,
            disabledColor: colors.onSurfaceVariant.withValues(alpha: 0.38),
            onPressed: onUndo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            key: const Key('ink-redo'),
            tooltip: 'ทำซ้ำหมึก',
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
                              label: 'เครื่องมือวาด',
                              color: colors.primaryContainer.withValues(
                                alpha: 0.45,
                              ),
                              children: [
                                _toolButton(
                                  key: const Key('ink-pen'),
                                  tooltip: 'ปากกา',
                                  icon: const Icon(Icons.edit_outlined),
                                  selectedIcon: const Icon(Icons.edit),
                                  selected: selectedTool == InkTool.pen,
                                  onPressed: () => onToolSelected(InkTool.pen),
                                ),
                                _toolButton(
                                  key: const Key('ink-highlighter'),
                                  tooltip: 'ปากกาไฮไลต์',
                                  icon: const _HighlighterIcon(),
                                  selectedIcon: const _HighlighterIcon(),
                                  selected: selectedTool == InkTool.highlighter,
                                  onPressed: () =>
                                      onToolSelected(InkTool.highlighter),
                                ),
                                _toolButton(
                                  key: const Key('ink-eraser'),
                                  tooltip: 'ยางลบทั้งเส้น',
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
                              label: 'รูปแบบเส้น',
                              children: [
                                for (var i = 0; i < colorPresets.length; i++)
                                  _ColorSwatchButton(
                                    key: Key('ink-color-preset-$i'),
                                    color: colorPresets[i],
                                    selected: colorPresets[i] == penColor,
                                    onTap: () => colorPresets[i] == penColor
                                        ? _editColor(context, i)
                                        : onColorSelected(colorPresets[i]),
                                    onLongPress: () => _editColor(context, i),
                                  ),
                                IconButton(
                                  key: const Key('ink-color'),
                                  tooltip: 'เปลี่ยนสีที่เลือกอยู่',
                                  icon: const Icon(Icons.palette_outlined),
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
                                for (var i = 0; i < widthPresets.length; i++)
                                  _WidthPresetButton(
                                    key: Key('ink-width-preset-$i'),
                                    width: widthPresets[i],
                                    color: penColor,
                                    selected: widthPresets[i] == penWidth,
                                    onTap: () => widthPresets[i] == penWidth
                                        ? _editWidth(context, i)
                                        : onWidthSelected(widthPresets[i]),
                                    onLongPress: () => _editWidth(context, i),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            _InkToolbarGroup(
                              key: const Key('ink-page-group'),
                              label: 'การควบคุมหน้า',
                              children: [
                                _toolButton(
                                  key: const Key('ink-touch'),
                                  tooltip: touchEnabled
                                      ? 'ใช้นิ้วเขียนอยู่'
                                      : 'Apple Pencil เขียน · นิ้วเลื่อนหน้า',
                                  icon: const Icon(Icons.touch_app_outlined),
                                  selectedIcon: const Icon(Icons.touch_app),
                                  selected: touchEnabled,
                                  onPressed: onTouchChanged,
                                ),
                                IconButton(
                                  key: const Key('ink-fit'),
                                  tooltip: 'พอดีความกว้าง',
                                  onPressed: onFit,
                                  icon: const Icon(Icons.fit_screen),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            _InkToolbarGroup(
                              key: const Key('ink-management-group'),
                              label: 'จัดการหมึก',
                              color: colors.secondaryContainer.withValues(
                                alpha: 0.55,
                              ),
                              children: [
                                PopupMenuButton<bool>(
                                  key: const Key('ink-management-menu'),
                                  tooltip: 'เพิ่มเติม',
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
                                          'ล้างหมึกทั้งหมด',
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

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      title: const Text('กำหนดสีเอง'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const Key('ink-color-preview'),
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _slider(
              'สี',
              _hsv.hue,
              360,
              (v) => _hsv = _hsv.withHue(v),
              key: const Key('ink-color-hue'),
              activeColor: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
            ),
            _slider(
              'ความเข้ม',
              _hsv.saturation,
              1,
              (v) => _hsv = _hsv.withSaturation(v),
              key: const Key('ink-color-saturation'),
            ),
            _slider(
              'ความสว่าง',
              _hsv.value,
              1,
              (v) => _hsv = _hsv.withValue(v),
              key: const Key('ink-color-value'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          key: const Key('ink-color-apply'),
          onPressed: () => Navigator.pop(context, color),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double max,
    void Function(double) apply, {
    required Key key,
    Color? activeColor,
  }) => Row(
    children: [
      SizedBox(width: 72, child: Text(label)),
      Expanded(
        child: Slider(
          key: key,
          value: value.clamp(0, max),
          max: max,
          activeColor: activeColor,
          onChanged: (v) => setState(() => apply(v)),
        ),
      ),
    ],
  );
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
      title: const Text('กำหนดขนาดเส้น'),
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
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          key: const Key('ink-width-apply'),
          onPressed: () => Navigator.pop(context, _width.roundToDouble()),
          child: const Text('ตกลง'),
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
      message:
          'ความหนา ${width.toStringAsFixed(0)} · แตะซ้ำหรือกดค้างเพื่อแก้ไข',
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
      message: 'แตะเพื่อเลือก · แตะซ้ำหรือกดค้างเพื่อเปลี่ยนสีนี้',
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
class _InkLayer extends StatelessWidget {
  const _InkLayer({required this.notifier, required this.highlighter});

  final ScribbleNotifier notifier;
  final bool highlighter;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ValueListenableBuilder<ScribbleState>(
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
    ),
  );
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
