import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_height_cache.dart';

void main() {
  group('clampMermaidHeight', () {
    test('จำกัดค่าต่ำสุดและสูงสุดถูกต้อง', () {
      expect(clampMermaidHeight(10.0), 48.0);
      expect(clampMermaidHeight(5000.0), 2000.0);
      expect(clampMermaidHeight(300.0), 300.0);
    });
  });

  group('MermaidHeightCache', () {
    test('lookup รายการที่ยังไม่เคยเก็บ ต้องได้ null', () {
      final cache = MermaidHeightCache();
      expect(cache.lookup(isDark: false, source: 'graph TD; A-->B;'), isNull);
    });

    test('store แล้ว lookup ต้องได้ค่าเดิม', () {
      final cache = MermaidHeightCache();
      cache.store(isDark: false, source: 'graph TD; A-->B;', height: 250.0);
      expect(cache.lookup(isDark: false, source: 'graph TD; A-->B;'), 250.0);
    });

    test('source เดียวกัน แต่คนละธีม ต้องเก็บแยกกัน', () {
      final cache = MermaidHeightCache();
      const source = 'graph TD; A-->B;';
      cache.store(isDark: false, source: source, height: 200.0);
      cache.store(isDark: true, source: source, height: 220.0);

      expect(cache.lookup(isDark: false, source: source), 200.0);
      expect(cache.lookup(isDark: true, source: source), 220.0);
    });

    test('limit: 3 เมื่อเก็บ 4 รายการ ตัวแรกสุดต้องถูกลบออก', () {
      final cache = MermaidHeightCache(limit: 3);
      cache.store(isDark: false, source: 's1', height: 100.0);
      cache.store(isDark: false, source: 's2', height: 200.0);
      cache.store(isDark: false, source: 's3', height: 300.0);
      cache.store(isDark: false, source: 's4', height: 400.0);

      expect(cache.lookup(isDark: false, source: 's1'), isNull);
      expect(cache.lookup(isDark: false, source: 's2'), 200.0);
      expect(cache.lookup(isDark: false, source: 's3'), 300.0);
      expect(cache.lookup(isDark: false, source: 's4'), 400.0);
    });

    test(
      'limit: 3 เมื่อเก็บครบ 3 แล้ว store ทับ key เดิม ต้องไม่ลบตัวอื่น',
      () {
        final cache = MermaidHeightCache(limit: 3);
        cache.store(isDark: false, source: 's1', height: 100.0);
        cache.store(isDark: false, source: 's2', height: 200.0);
        cache.store(isDark: false, source: 's3', height: 300.0);

        // อัปเดต key เดิม (s2)
        cache.store(isDark: false, source: 's2', height: 250.0);

        expect(cache.lookup(isDark: false, source: 's1'), 100.0);
        expect(cache.lookup(isDark: false, source: 's2'), 250.0);
        expect(cache.lookup(isDark: false, source: 's3'), 300.0);
      },
    );
  });
}
