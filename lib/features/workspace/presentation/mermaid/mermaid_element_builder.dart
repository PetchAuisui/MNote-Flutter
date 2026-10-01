import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'mermaid_block.dart';
import 'mermaid_diagram_view.dart';

/// Builder สำหรับดักจับและแปลงโค้ดบล็อกภาษา Mermaid เป็น [MermaidDiagramView]
///
/// **ข้อสำคัญ:** ต้องลงทะเบียนกับแท็ก 'code' เท่านั้น ห้ามลงกับ 'pre'
/// เพราะถ้าลงทะเบียนกับ 'pre' ตัวแพ็กเกจจะส่งข้อความของ code block ทุกภาษามาให้ builder
/// แทนการสร้าง widget เอง ทำให้ code block ภาษาอื่น (เช่น dart, python) กลายเป็นกล่องว่างเปล่า
class MermaidElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final className = element.attributes['class'];
    if (!isMermaidCodeClass(className)) {
      return null;
    }

    return MermaidDiagramView(
      source: normalizeMermaidSource(element.textContent),
    );
  }
}
