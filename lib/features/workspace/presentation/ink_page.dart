import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:scribble/scribble.dart';

import 'ink_session.dart';

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
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'ปากกา',
                          onPressed: () => pen.setColor(Colors.black),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: 'ปากกาสีแดง',
                          onPressed: () => pen.setColor(Colors.red.shade800),
                          icon: const Icon(Icons.circle, color: Colors.red),
                        ),
                        IconButton(
                          tooltip: 'ยางลบทั้งเส้น',
                          onPressed: pen.setEraser,
                          icon: const Icon(Icons.auto_fix_normal),
                        ),
                        IconButton(
                          tooltip: 'ย้อนกลับหมึก',
                          onPressed: pen.canUndo ? pen.undo : null,
                          icon: const Icon(Icons.undo),
                        ),
                        IconButton(
                          tooltip: 'ทำซ้ำหมึก',
                          onPressed: pen.canRedo ? pen.redo : null,
                          icon: const Icon(Icons.redo),
                        ),
                        IconButton(
                          tooltip: _touch
                              ? 'ใช้นิ้วหรือเมาส์เขียนอยู่'
                              : 'ใช้ปากกาเท่านั้น · นิ้วเลื่อนหน้า',
                          isSelected: _touch,
                          onPressed: () {
                            setState(() => _touch = !_touch);
                            pen.setAllowedPointersMode(
                              _touch
                                  ? ScribblePointerMode.all
                                  : ScribblePointerMode.penOnly,
                            );
                          },
                          icon: const Icon(Icons.touch_app),
                        ),
                        IconButton(
                          tooltip: 'พอดีความกว้าง',
                          onPressed: _fit,
                          icon: const Icon(Icons.fit_screen),
                        ),
                        IconButton(
                          tooltip: 'เพิ่มพื้นที่ด้านล่าง',
                          onPressed: () =>
                              widget.session.grow(widget.session.height + 1000),
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: 'เปิดไฟล์หมึก',
                          onPressed: _busy ? null : () => _fileAction(false),
                          icon: const Icon(Icons.folder_open),
                        ),
                        IconButton(
                          tooltip: 'บันทึกไฟล์หมึกแยกจาก Markdown',
                          onPressed: _busy ? null : () => _fileAction(true),
                          icon: Icon(
                            widget.session.isDirty
                                ? Icons.save_as
                                : Icons.save_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                  child: SizedBox(
                    width: InkSession.pageWidth,
                    child: Stack(
                      key: _pageKey,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: widget.session.height,
                          ),
                          child: ColoredBox(
                            color: Colors.white,
                            child: SizedBox(
                              width: InkSession.pageWidth,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Theme(
                                  data: ThemeData(
                                    brightness: Brightness.light,
                                    useMaterial3: true,
                                  ),
                                  child: MarkdownBody(
                                    data: widget.markdown,
                                    imageDirectory: widget.imageDirectory,
                                    selectable: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
