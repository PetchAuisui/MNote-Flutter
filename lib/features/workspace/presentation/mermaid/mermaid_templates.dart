import 'package:mnote/l10n/app_localizations.dart';
import 'package:mnote/l10n/app_localizations_th.dart';

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
/// ข้อความในแผนภาพเปลี่ยนตามภาษาที่ใช้
List<MermaidTemplate> mermaidTemplatesFor(AppLocalizations l) => [
  MermaidTemplate(
    id: 'flowchart',
    label: l.tplFlowLabel,
    source:
        '''flowchart TD
  start([${l.tplFlowStart}]) --> step[${l.tplFlowStep}]
  step --> check{${l.tplFlowCond}}
  check -->|${l.tplYes}| finish([${l.tplEnd}])
  check -->|${l.tplNo}| step''',
  ),
  MermaidTemplate(
    id: 'sequence',
    label: l.tplSeqLabel,
    source:
        '''sequenceDiagram
  participant U as ${l.tplUser}
  participant S as ${l.tplSystem}
  U->>S: ${l.tplRequest}
  S-->>U: ${l.tplReply}''',
  ),
  MermaidTemplate(
    id: 'class',
    label: l.tplClassLabel,
    source: '''classDiagram
  class Folder {
    +String name
  }
  class Note {
    +String title
    +save()
  }
  Folder "1" --> "*" Note : ${l.tplHas}''',
  ),
];

/// รายการ template ภาษาไทย (ค่าเริ่มต้น)
final List<MermaidTemplate> mermaidTemplates = mermaidTemplatesFor(
  AppLocalizationsTh(),
);

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
