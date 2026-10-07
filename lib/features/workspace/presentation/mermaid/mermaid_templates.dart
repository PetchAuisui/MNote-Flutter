/// โครงไดอะแกรมสำเร็จรูปสำหรับปุ่มบน toolbar
/// [source] คือโค้ด mermaid ที่ยังไม่มีรั้วครอบ
final class MermaidTemplate {
  const MermaidTemplate({
    required this.id,
    required this.label,
    required this.source,
  });

  final String id;
  final String label;
  final String source;
}

/// รายการ template ที่แสดงในเมนู
/// ใช้รูปแบบเขียนดั้งเดิมเพื่อให้วาดได้กับ mermaid ทุกเวอร์ชัน
/// และใช้ชื่อตัวระบุภาษาอังกฤษเพราะไดอะแกรมบางชนิดไม่รองรับภาษาไทยในชื่อ
const List<MermaidTemplate> mermaidTemplates = [
  MermaidTemplate(
    id: 'flowchart',
    label: 'ผังงาน (Flowchart)',
    source: '''flowchart TD
  start([เริ่มต้น]) --> step[ขั้นตอน]
  step --> check{เงื่อนไข?}
  check -->|ใช่| finish([จบ])
  check -->|ไม่ใช่| step''',
  ),
  MermaidTemplate(
    id: 'sequence',
    label: 'ลำดับการทำงาน (Sequence)',
    source: '''sequenceDiagram
  participant U as ผู้ใช้
  participant S as ระบบ
  U->>S: ส่งคำขอ
  S-->>U: ตอบกลับ''',
  ),
  MermaidTemplate(
    id: 'class',
    label: 'คลาส (Class)',
    source: '''classDiagram
  class Folder {
    +String name
  }
  class Note {
    +String title
    +save()
  }
  Folder "1" --> "*" Note : มี''',
  ),
];

/// ครอบโค้ดด้วยรั้ว mermaid โดยใช้รั้วยาวกว่า backtick ที่ยาวที่สุดในโค้ด
/// เพื่อไม่ให้บล็อกปิดก่อนเวลา
String buildMermaidFencedBlock(String source) {
  final matches = RegExp(r'`+').allMatches(source);
  var maxTicks = 0;
  for (final match in matches) {
    if (match.group(0)!.length > maxTicks) {
      maxTicks = match.group(0)!.length;
    }
  }

  final fenceLength = maxTicks >= 3 ? maxTicks + 1 : 3;
  final fence = '`' * fenceLength;
  return '${fence}mermaid\n$source\n$fence';
}
