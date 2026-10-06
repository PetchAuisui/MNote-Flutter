import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'obsidian_markdown_controller.dart';

/// Paints block decorations over their original, hidden source characters.
/// Keeping the source in EditableText preserves selection and clipboard offsets.
class MarkdownEditorDecorations extends StatefulWidget {
  const MarkdownEditorDecorations({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.child,
  });
  final ObsidianMarkdownEditingController controller;
  final ScrollController scrollController;
  final Widget child;
  @override
  State<MarkdownEditorDecorations> createState() =>
      _MarkdownEditorDecorationsState();
}

class _MarkdownEditorDecorationsState extends State<MarkdownEditorDecorations> {
  final _editorKey = GlobalKey();
  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DecorationsPainter(
      widget.controller,
      widget.scrollController,
      _editorKey,
    ),
    child: KeyedSubtree(key: _editorKey, child: widget.child),
  );
}

class _DecorationsPainter extends CustomPainter {
  _DecorationsPainter(this.controller, ScrollController scroll, this.editorKey)
    : super(repaint: Listenable.merge([controller, scroll]));
  final ObsidianMarkdownEditingController controller;
  final GlobalKey editorKey;

  RenderEditable? _editable(RenderObject object) {
    if (object is RenderEditable) return object;
    RenderEditable? result;
    object.visitChildren((child) {
      result ??= _editable(child);
    });
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final root = editorKey.currentContext?.findRenderObject();
    if (root is! RenderBox || !root.hasSize) return;
    final editable = _editable(root);
    if (editable == null || !editable.hasSize) return;
    final origin = root.globalToLocal(editable.localToGlobal(Offset.zero));
    final paint = Paint()
      ..color = const Color(0xFF9AA0A6)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    var offset = 0;
    String? fence;
    for (final line in controller.text.split('\n')) {
      final start = offset;
      offset += line.length + 1;
      final boundary = RegExp(r'^\s*(`{3,}|~{3,})').firstMatch(line);
      if (boundary != null) {
        if (fence == null) {
          fence = boundary.group(1);
        } else if (line.trimLeft().startsWith(fence)) {
          fence = null;
        }
        continue;
      }
      if (fence != null) continue;
      final selection = controller.selection;
      if (controller.editorHasFocus &&
          selection.isValid &&
          selection.start <= start + line.length &&
          selection.end >= start) {
        continue;
      }
      final rule = RegExp(r'^\s*([*\-_])\s*(\1\s*){2,}\s*$').hasMatch(line);
      final bullet = RegExp(r'^(\s*)([-*+])\s+(?!\[[ xX]\])').firstMatch(line);
      if (!rule && bullet == null) continue;
      final markerOffset = start + (bullet?.group(1)?.length ?? 0);
      final caret = editable
          .getLocalRectForCaret(TextPosition(offset: markerOffset))
          .shift(origin);
      if (caret.bottom < 0 || caret.top > size.height) continue;
      if (rule) {
        canvas.drawLine(
          Offset(caret.left, caret.center.dy),
          Offset(size.width - 8, caret.center.dy),
          paint,
        );
      } else {
        paint.color = const Color(0xFF5F6368);
        paint.style = bullet!.group(1)!.isEmpty
            ? PaintingStyle.fill
            : PaintingStyle.stroke;
        paint.strokeWidth = 1.3;
        canvas.drawCircle(
          Offset(caret.left + 4, caret.center.dy),
          bullet.group(1)!.isEmpty ? 4 : 3,
          paint,
        );
        paint.style = PaintingStyle.fill;
        paint.strokeWidth = 1;
        paint.color = const Color(0xFF9AA0A6);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DecorationsPainter oldDelegate) => true;
}
