import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_block.dart';

void main() {
  group('isMermaidCodeClass', () {
    test('คืนค่า true เมื่อเป็น language-mermaid ตัวพิมพ์เล็ก', () {
      expect(isMermaidCodeClass('language-mermaid'), isTrue);
    });

    test('คืนค่า true เมื่อมีตัวพิมพ์ใหญ่ปน (case-insensitive)', () {
      expect(isMermaidCodeClass('language-Mermaid'), isTrue);
      expect(isMermaidCodeClass('LANGUAGE-MERMAID'), isTrue);
    });

    test('คืนค่า false เมื่อค่าเป็น null', () {
      expect(isMermaidCodeClass(null), isFalse);
    });

    test('คืนค่า false เมื่อเป็นภาษาอื่น เช่น language-dart', () {
      expect(isMermaidCodeClass('language-dart'), isFalse);
    });

    test('คืนค่า false เมื่อเป็นชื่อคล้ายกัน เช่น language-mermaidjs', () {
      expect(isMermaidCodeClass('language-mermaidjs'), isFalse);
    });

    test('คืนค่า false เมื่อเป็นสตริงว่าง', () {
      expect(isMermaidCodeClass(''), isFalse);
    });
  });

  group('normalizeMermaidSource', () {
    test('ตัดช่องว่างและ \\n ท้ายข้อความออก โดยคงย่อหน้าข้างในไว้', () {
      const raw = 'graph TD\n  A-->B\n';
      expect(normalizeMermaidSource(raw), equals('graph TD\n  A-->B'));
    });

    test('แปลง \\r\\n (CRLF) ให้เป็น \\n ทั้งหมด', () {
      const raw = 'graph TD\r\n  A-->B\r\n';
      expect(normalizeMermaidSource(raw), equals('graph TD\n  A-->B'));
    });

    test('คงบรรทัดว่างที่อยู่ตรงกลางข้อความไว้ ไม่ลบทิ้ง', () {
      const raw = 'graph TD\n\n  A-->B';
      expect(normalizeMermaidSource(raw), equals('graph TD\n\n  A-->B'));
    });

    test('คืนค่าสตริงว่างเมื่อข้อความมีแต่ช่องว่างและบรรทัดว่าง', () {
      const raw = '\n\n  \n';
      expect(normalizeMermaidSource(raw), equals(''));
    });

    test('ข้อความที่สะอาดอยู่แล้วต้องได้ค่าเดิม', () {
      const clean = 'graph TD\n  A-->B';
      expect(normalizeMermaidSource(clean), equals(clean));
    });
  });
}
