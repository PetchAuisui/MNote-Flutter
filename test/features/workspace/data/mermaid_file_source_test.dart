import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/data/mermaid_file_source.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';

void main() {
  group('readLimitedBytes', () {
    test('ไฟล์เล็กกว่าเพดาน ได้ครบทุก byte', () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
        [4, 5],
      ]);

      final bytes = await readLimitedBytes(stream, 100);

      expect(bytes, equals(Uint8List.fromList([1, 2, 3, 4, 5])));
    });

    test('ไฟล์ใหญ่กว่าเพดาน ได้แค่ limit byte', () async {
      final stream = Stream.fromIterable(
        List.generate(100, (_) => List.filled(4096, 7)),
      );

      final bytes = await readLimitedBytes(stream, 1001);

      expect(bytes.length, 1001);
    });

    test('ชิ้นข้อมูลยาวเท่าเพดานพอดี ได้ครบและหยุด', () async {
      final stream = Stream.fromIterable([
        List.filled(10, 1),
        List.filled(10, 2),
      ]);

      final bytes = await readLimitedBytes(stream, 10);

      expect(bytes, equals(Uint8List.fromList(List.filled(10, 1))));
    });

    test('(Security) หยุดอ่านทันทีที่ครบ ไม่อ่านไฟล์ที่เหลือ', () async {
      var produced = 0;
      Stream<List<int>> hugeFile() async* {
        for (var i = 0; i < 100000; i++) {
          produced++;
          yield List.filled(1024, 0);
        }
      }

      final bytes = await readLimitedBytes(hugeFile(), 2049);

      expect(bytes.length, 2049);
      expect(produced, lessThan(10));
    });

    test(
      '(Security) ไฟล์ใหญ่ที่อ่านแบบจำกัด ถูกปฏิเสธด้วยข้อความเรื่องขนาด',
      () async {
        final stream = Stream.fromIterable(
          List.generate(1000, (_) => List.filled(1024, 65)),
        );

        final bytes = await readLimitedBytes(stream, mermaidImportMaxBytes + 1);
        final result = parseMermaidImport(name: 'huge.mmd', bytes: bytes);

        expect(bytes.length, mermaidImportMaxBytes + 1);
        expect(result, isA<MermaidImportFailure>());
      },
    );
  });
}
