import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';

import 'ink_session.dart';
import 'markdown_document_canvas.dart';

class InkPage extends StatefulWidget {
  const InkPage({
    super.key,
    required this.session,
    required this.markdown,
    required this.name,
    this.imageDirectory,
  });
  final InkSession session;
  final String markdown;
  final String name;
  final String? imageDirectory;

  @override
  State<InkPage> createState() => _InkPageState();
}

class _InkPageState extends State<InkPage> {
  final _transform = TransformationController();
  final _pageKey = GlobalKey();
  _InkTool _tool = _InkTool.pen;
  Color _penColor = const Color(0xFF202124);
  double _penWidth = 3;
  bool _touch = false;
  bool _busy = false;
  double _viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    _touch =
        widget.session.pen.value.allowedPointersMode == ScribblePointerMode.all;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit() {
    final scale = (_viewportWidth / InkSession.pageWidth).clamp(0.1, 4.0);
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1);
    widget.session.pen.setScaleFactor(scale);
  }

  void _selectTool(_InkTool tool) {
    final pen = widget.session.pen;
    setState(() => _tool = tool);
    switch (tool) {
      case _InkTool.pen:
        pen
          ..setColor(_penColor)
          ..setStrokeWidth(_penWidth);
      case _InkTool.highlighter:
        pen
          ..setColor(const Color(0x66FFD54F))
          ..setStrokeWidth(18);
      case _InkTool.eraser:
        pen
          ..setEraser()
          ..setStrokeWidth(28);
    }
  }

  void _selectColor(Color color) {
    setState(() {
      _penColor = color;
      _tool = _InkTool.pen;
    });
    widget.session.pen
      ..setColor(color)
      ..setStrokeWidth(_penWidth);
  }

  void _selectWidth(double width) {
    setState(() {
      _penWidth = width;
      _tool = _InkTool.pen;
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
        final uri = await FilePicker.saveFile(
          dialogTitle: 'บันทึกหมึกแยกจาก Markdown',
          fileName: '${widget.name}.ink.json',
          bytes: Uint8List.fromList(utf8.encode(snapshot)),
          mimeType: 'application/json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (uri != null && mounted) widget.session.markSaved(snapshot);
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
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
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
      return Column(
        children: [
          _InkToolbar(
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
              setState(() => _touch = !_touch);
              pen.setAllowedPointersMode(
                _touch ? ScribblePointerMode.all : ScribblePointerMode.penOnly,
              );
            },
            onFit: _fit,
            onGrow: () => widget.session.grow(widget.session.height + 1000),
            onOpen: () => _fileAction(false),
            onSave: () => _fileAction(true),
            isDirty: widget.session.isDirty,
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_viewportWidth != constraints.maxWidth) {
                  _viewportWidth = constraints.maxWidth;
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
                  onInteractionUpdate: (_) =>
                      pen.setScaleFactor(_transform.value.getMaxScaleOnAxis()),
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
                        ),
                        Positioned.fill(
                          child: Scribble(notifier: pen, drawPen: false),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

enum _InkTool { pen, highlighter, eraser }

class _InkToolbar extends StatelessWidget {
  const _InkToolbar({
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

  final _InkTool selectedTool;
  final Color penColor;
  final double penWidth;
  final bool touchEnabled;
  final bool busy;
  final ValueChanged<_InkTool> onToolSelected;
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
    return Material(
      key: const Key('ink-toolbar'),
      color: colors.surfaceContainerLow,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _toolButton(
                    key: const Key('ink-pen'),
                    tooltip: 'ปากกา',
                    icon: const Icon(Icons.edit_outlined),
                    selectedIcon: const Icon(Icons.edit),
                    selected: selectedTool == _InkTool.pen,
                    onPressed: () => onToolSelected(_InkTool.pen),
                  ),
                  _toolButton(
                    key: const Key('ink-highlighter'),
                    tooltip: 'ปากกาไฮไลต์',
                    icon: const Icon(Icons.border_color_outlined),
                    selectedIcon: const Icon(Icons.border_color),
                    selected: selectedTool == _InkTool.highlighter,
                    onPressed: () => onToolSelected(_InkTool.highlighter),
                  ),
                  _toolButton(
                    key: const Key('ink-eraser'),
                    tooltip: 'ยางลบทั้งเส้น',
                    icon: const _EraserIcon(),
                    selectedIcon: const _EraserIcon(filled: true),
                    selected: selectedTool == _InkTool.eraser,
                    onPressed: () => onToolSelected(_InkTool.eraser),
                  ),
                  const _InkToolbarDivider(),
                  PopupMenuButton<Color>(
                    key: const Key('ink-color'),
                    tooltip: 'เลือกสีปากกา',
                    initialValue: penColor,
                    onSelected: onColorSelected,
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
                    ],
                    icon: Icon(Icons.circle, color: penColor, size: 22),
                  ),
                  PopupMenuButton<double>(
                    key: const Key('ink-width'),
                    tooltip: 'เลือกความหนาปากกา',
                    initialValue: penWidth,
                    onSelected: onWidthSelected,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 3, child: Text('เส้นบาง')),
                      PopupMenuItem(value: 6, child: Text('เส้นกลาง')),
                      PopupMenuItem(value: 12, child: Text('เส้นหนา')),
                    ],
                    icon: const Icon(Icons.line_weight),
                  ),
                  const _InkToolbarDivider(),
                  IconButton(
                    key: const Key('ink-undo'),
                    tooltip: 'ย้อนกลับหมึก',
                    onPressed: onUndo,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    key: const Key('ink-redo'),
                    tooltip: 'ทำซ้ำหมึก',
                    onPressed: onRedo,
                    icon: const Icon(Icons.redo),
                  ),
                  IconButton(
                    key: const Key('ink-clear'),
                    tooltip: 'ล้างหมึกทั้งหมด',
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  const _InkToolbarDivider(),
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
                  const _InkToolbarDivider(),
                  IconButton(
                    key: const Key('ink-open'),
                    tooltip: 'เปิดไฟล์หมึก',
                    onPressed: busy ? null : onOpen,
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                  IconButton(
                    key: const Key('ink-save'),
                    tooltip: 'บันทึกไฟล์หมึก',
                    onPressed: busy ? null : onSave,
                    icon: Icon(isDirty ? Icons.save_as : Icons.save_outlined),
                  ),
                ],
              ),
            ),
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

  static String _colorName(Color color) => switch (color.toARGB32()) {
    0xFF202124 => 'ดำ',
    0xFF275DAD => 'น้ำเงิน',
    0xFFB3261E => 'แดง',
    0xFF237A3B => 'เขียว',
    _ => 'ม่วง',
  };
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

class _InkToolbarDivider extends StatelessWidget {
  const _InkToolbarDivider();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: VerticalDivider(color: Theme.of(context).colorScheme.outlineVariant),
  );
}
