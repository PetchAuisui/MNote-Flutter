import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
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
    required this.name,
    this.imageDirectory,
    this.fileStorage = const DeviceInkFileStorage(),
    this.transformationController,
    this.showToolbar = true,
    this.onViewportWidthChanged,
  });
  final InkSession session;
  final String markdown;
  final String name;
  final String? imageDirectory;
  final InkFileStorage fileStorage;
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
  bool _busy = false;
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
  }

  @override
  void didUpdateWidget(InkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformationController != widget.transformationController) {
      if (_ownsTransform) _transform.dispose();
      _attachTransform();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
  }

  @override
  void dispose() {
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

  /// Keeps the page horizontally centred (or edge-clamped when zoomed in) so
  /// stray pan gestures can't shift the margins sideways.
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
          ..setColor(const Color(0x66FFD54F))
          ..setStrokeWidth(18);
      case InkTool.eraser:
        pen
          ..setEraser()
          ..setStrokeWidth(28);
    }
  }

  void _selectColor(Color color) {
    setState(() {
      _penColor = color;
      _tool = InkTool.pen;
    });
    widget.session.pen
      ..setColor(color)
      ..setStrokeWidth(_penWidth);
  }

  void _selectWidth(double width) {
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

  Future<void> _fileAction(bool save) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (save) {
        final snapshot = widget.session.encode();
        final saved = await widget.fileStorage.save(
          name: '${widget.name}.ink.json',
          bytes: Uint8List.fromList(utf8.encode(snapshot)),
        );
        if (saved && mounted) widget.session.markSaved(snapshot);
      } else {
        if (widget.session.isDirty) {
          final discard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('แทนที่หมึกที่ยังไม่บันทึก?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('เปิดหมึก'),
                ),
              ],
            ),
          );
          if (discard != true || !mounted) return;
        }
        final bytes = await widget.fileStorage.open();
        if (bytes == null) return;
        if (!mounted) return;
        widget.session.load(utf8.decode(bytes));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'เปิดหรือบันทึกหมึกไม่สำเร็จ กรุณาตรวจสอบไฟล์แล้วลองใหม่',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            onInteractionUpdate: (_) => _clampHorizontal(),
            onInteractionEnd: (_) => _clampHorizontal(),
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
                  ),
                  Positioned.fill(
                    child: Scribble(notifier: pen, drawPen: false),
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
            penColor: _penColor,
            penWidth: _penWidth,
            touchEnabled: _touch,
            busy: _busy,
            onToolSelected: _selectTool,
            onColorSelected: _selectColor,
            onWidthSelected: _selectWidth,
            onUndo: pen.canUndo ? pen.undo : null,
            onRedo: pen.canRedo ? pen.redo : null,
            onClear: pen.currentSketch.lines.isEmpty ? null : _clearInk,
            onTouchChanged: () {
              pen.setAllowedPointersMode(
                _touch ? ScribblePointerMode.penOnly : ScribblePointerMode.all,
              );
            },
            onFit: _fit,
            onGrow: () => widget.session.grow(widget.session.height + 1000),
            onOpen: () => _fileAction(false),
            onSave: () => _fileAction(true),
            isDirty: widget.session.isDirty,
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: canvas),
        ],
      );
    },
  );
}

enum InkTool { pen, highlighter, eraser }

enum _InkManagementAction { open, save, clear }

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
    required this.busy,
    required this.onToolSelected,
    required this.onColorSelected,
    required this.onWidthSelected,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onTouchChanged,
    required this.onFit,
    required this.onGrow,
    required this.onOpen,
    required this.onSave,
    required this.isDirty,
  });

  final InkTool selectedTool;
  final Color penColor;
  final double penWidth;
  final bool touchEnabled;
  final bool busy;
  final ValueChanged<InkTool> onToolSelected;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onWidthSelected;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final VoidCallback onTouchChanged;
  final VoidCallback onFit;
  final VoidCallback onGrow;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final bool isDirty;

  static const _colors = [
    Color(0xFF202124),
    Color(0xFF275DAD),
    Color(0xFFB3261E),
    Color(0xFF237A3B),
    Color(0xFF7B4BA0),
  ];

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
                                PopupMenuButton<Object>(
                                  key: const Key('ink-color'),
                                  tooltip: 'เลือกสีปากกา',
                                  initialValue: penColor,
                                  onSelected: (value) async {
                                    if (value is Color) {
                                      onColorSelected(value);
                                      return;
                                    }
                                    final picked = await showDialog<Color>(
                                      context: context,
                                      builder: (_) =>
                                          _CustomColorDialog(initial: penColor),
                                    );
                                    if (picked != null) onColorSelected(picked);
                                  },
                                  itemBuilder: (context) => [
                                    for (final color in _colors)
                                      PopupMenuItem(
                                        value: color,
                                        child: Row(
                                          children: [
                                            Icon(Icons.circle, color: color),
                                            const SizedBox(width: 12),
                                            Text(_colorName(color)),
                                            if (color == penColor) ...[
                                              const Spacer(),
                                              const Icon(Icons.check),
                                            ],
                                          ],
                                        ),
                                      ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem<Object>(
                                      key: Key('ink-color-custom'),
                                      value: _customOption,
                                      child: Row(
                                        children: [
                                          Icon(Icons.palette_outlined),
                                          SizedBox(width: 12),
                                          Text('กำหนดสีเอง…'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  icon: Icon(
                                    Icons.circle,
                                    color: penColor,
                                    size: 22,
                                  ),
                                ),
                                PopupMenuButton<double>(
                                  key: const Key('ink-width'),
                                  tooltip: 'เลือกความหนาปากกา',
                                  initialValue: penWidth,
                                  onSelected: onWidthSelected,
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 3,
                                      child: Text('เส้นบาง'),
                                    ),
                                    PopupMenuItem(
                                      value: 6,
                                      child: Text('เส้นกลาง'),
                                    ),
                                    PopupMenuItem(
                                      value: 12,
                                      child: Text('เส้นหนา'),
                                    ),
                                  ],
                                  icon: const Icon(Icons.line_weight),
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
                                IconButton(
                                  key: const Key('ink-grow'),
                                  tooltip: 'เพิ่มพื้นที่ด้านล่าง',
                                  onPressed: onGrow,
                                  icon: const Icon(Icons.vertical_align_bottom),
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
                                PopupMenuButton<_InkManagementAction>(
                                  key: const Key('ink-management-menu'),
                                  tooltip: 'จัดการหมึก',
                                  enabled: !busy,
                                  onSelected: (action) {
                                    switch (action) {
                                      case _InkManagementAction.open:
                                        onOpen();
                                      case _InkManagementAction.save:
                                        onSave();
                                      case _InkManagementAction.clear:
                                        onClear?.call();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      key: Key('ink-open'),
                                      value: _InkManagementAction.open,
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.folder_open_outlined,
                                        ),
                                        title: Text('เปิดไฟล์หมึก'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      key: const Key('ink-save'),
                                      value: _InkManagementAction.save,
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          isDirty
                                              ? Icons.save_as
                                              : Icons.save_outlined,
                                        ),
                                        title: const Text('บันทึกไฟล์หมึก'),
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      key: const Key('ink-clear'),
                                      value: _InkManagementAction.clear,
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
                                  icon: Badge(
                                    isLabelVisible: isDirty,
                                    child: const Icon(Icons.layers_outlined),
                                  ),
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

  static const _customOption = 'custom';

  static String _colorName(Color color) => switch (color.toARGB32()) {
    0xFF202124 => 'ดำ',
    0xFF275DAD => 'น้ำเงิน',
    0xFFB3261E => 'แดง',
    0xFF237A3B => 'เขียว',
    _ => 'ม่วง',
  };
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
