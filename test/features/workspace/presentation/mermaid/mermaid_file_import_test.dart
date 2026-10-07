import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';

void main() {
  Uint8List toBytes(String text) => Uint8List.fromList(utf8.encode(text));

  group('parseMermaidImport Unit Tests', () {
    test(
      'ไฟล์ diagram.mmd เนื้อหาปกติ ได้ Success และตัดช่องว่างส่วนเกินออก',
      () {
        final bytes = toBytes('graph TD\n  A-->B\n');
        final result = parseMermaidImport(name: 'diagram.mmd', bytes: bytes);

        expect(result, isA<MermaidImportSuccess>());
        final success = result as MermaidImportSuccess;
        expect(success.name, equals('diagram.mmd'));
        expect(success.source, equals('graph TD\n  A-->B'));
      },
    );

    test('รองรับนามสกุล .MMD ตัวพิมพ์ใหญ่ และ .mermaid ทั้งคู่', () {
      final bytes = toBytes('graph TD\n  A-->B');

      final resultUpper = parseMermaidImport(
        name: 'flowchart.MMD',
        bytes: bytes,
      );
      expect(resultUpper, isA<MermaidImportSuccess>());

      final resultMermaid = parseMermaidImport(
        name: 'flowchart.mermaid',
        bytes: bytes,
      );
      expect(resultMermaid, isA<MermaidImportSuccess>());
    });

    test('นามสกุล .txt หรือนามสกุลอื่น ได้ Failure ข้อความเรื่องนามสกุล', () {
      final bytes = toBytes('graph TD\n  A-->B');
      final result = parseMermaidImport(name: 'notes.txt', bytes: bytes);

      expect(result, isA<MermaidImportFailure>());
      final failure = result as MermaidImportFailure;
      expect(failure.message, equals('รองรับเฉพาะไฟล์ .mmd หรือ .mermaid'));
    });

    test(
      '(Security) bytes ขนาดเกิน mermaidImportMaxBytes ได้ Failure ข้อความเรื่องขนาด',
      () {
        final largeBytes = Uint8List(mermaidImportMaxBytes + 1);
        final result = parseMermaidImport(name: 'large.mmd', bytes: largeBytes);

        expect(result, isA<MermaidImportFailure>());
        final failure = result as MermaidImportFailure;
        expect(failure.message, equals('ไฟล์ใหญ่เกินไป (สูงสุด 100 KB)'));
      },
    );

    test(
      '(Security) bytes ที่ไม่ใช่ UTF-8 ได้ Failure และไม่ throw FormatException',
      () {
        final invalidBytes = Uint8List.fromList([0xFF, 0xFE, 0xFD]);
        final result = parseMermaidImport(
          name: 'corrupted.mmd',
          bytes: invalidBytes,
        );

        expect(result, isA<MermaidImportFailure>());
        final failure = result as MermaidImportFailure;
        expect(
          failure.message,
          equals('อ่านไฟล์ไม่ได้ ไฟล์ต้องเป็นข้อความแบบ UTF-8'),
        );
      },
    );

    test(
      'เนื้อหาขึ้นต้นด้วย BOM (\\uFEFF) จะถูกตัดออกและได้ source ที่สะอาด',
      () {
        final bytes = toBytes('\uFEFFgraph TD\n  A-->B');
        final result = parseMermaidImport(name: 'bom.mmd', bytes: bytes);

        expect(result, isA<MermaidImportSuccess>());
        final success = result as MermaidImportSuccess;
        expect(success.source.startsWith('\uFEFF'), isFalse);
        expect(success.source, equals('graph TD\n  A-->B'));
      },
    );

    test(
      'เนื้อหาที่ครอบรั้ว ```mermaid อยู่แล้ว จะถูกแกะรั้วออกเหลือเฉพาะโค้ดข้างใน',
      () {
        final bytes = toBytes('```mermaid\ngraph TD\n  A-->B\n```');
        final result = parseMermaidImport(name: 'fenced.mmd', bytes: bytes);

        expect(result, isA<MermaidImportSuccess>());
        final success = result as MermaidImportSuccess;
        expect(success.source, equals('graph TD\n  A-->B'));
      },
    );

    test(
      'เนื้อหาที่มีแต่ช่องว่างหรือบรรทัดว่าง ได้ Failure ข้อความเรื่องไฟล์ว่าง',
      () {
        final bytes = toBytes('   \n\n\t  \n');
        final result = parseMermaidImport(name: 'empty.mmd', bytes: bytes);

        expect(result, isA<MermaidImportFailure>());
        final failure = result as MermaidImportFailure;
        expect(failure.message, equals('ไฟล์ว่าง ไม่มีโค้ดไดอะแกรม'));
      },
    );

    test(
      'รองรับรูปแบบ syntax จาก mermaid.ai ที่มีโครงสร้าง @{ shape: ... }',
      () {
        const aiSource = '''flowchart TD
  n1["เริ่มต้น"] --> n2["ประมวลผล"]
  n2 --> n3@{ shape: diam, label: "เงื่อนไข" }''';

        final bytes = toBytes(aiSource);
        final result = parseMermaidImport(name: 'ai_export.mmd', bytes: bytes);

        expect(result, isA<MermaidImportSuccess>());
        final success = result as MermaidImportSuccess;
        expect(success.source, equals(aiSource));
      },
    );
  });
}
