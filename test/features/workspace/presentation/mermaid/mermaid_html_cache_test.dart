import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_html_cache.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  int calls = 0;
  bool failNext = false;
  bool failSyncNext = false;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    calls++;
    if (failSyncNext) {
      failSyncNext = false;
      throw Exception('sync boom');
    }
    if (failNext) {
      failNext = false;
      return Future.error(Exception('boom'));
    }
    return Future.value('/* fake mermaid */');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MermaidHtmlCache', () {
    test(
      'ยามเฝ้า pubspec: เรียกด้วย rootBundle จริงต้องได้ HTML สมบูรณ์',
      () async {
        final cache = MermaidHtmlCache();
        final html = await cache.htmlFor(isDark: false);

        expect(html, contains("securityLevel: 'strict'"));
        expect(html.length, greaterThan(1000000));
      },
    );

    test('เรียก htmlFor ซ้ำในธีมเดิม ต้องโหลดสคริปต์เพียงครั้งเดียว', () async {
      final fakeBundle = _FakeAssetBundle();
      final cache = MermaidHtmlCache(bundle: fakeBundle);

      await cache.htmlFor(isDark: false);
      await cache.htmlFor(isDark: false);

      expect(fakeBundle.calls, equals(1));
    });

    test(
      'เรียกทั้งธีมมืดและสว่าง ใช้สคริปต์ร่วมกันและได้ HTML ตรงธีม',
      () async {
        final fakeBundle = _FakeAssetBundle();
        final cache = MermaidHtmlCache(bundle: fakeBundle);

        final light = await cache.htmlFor(isDark: false);
        final dark = await cache.htmlFor(isDark: true);

        expect(fakeBundle.calls, equals(1));
        expect(light, contains("theme: 'default'"));
        expect(dark, contains("theme: 'dark'"));
      },
    );

    test(
      'หากโหลดล้มเหลวครั้งแรก (async error) ต้องสามารถลองใหม่สำเร็จในครั้งที่สอง',
      () async {
        final fakeBundle = _FakeAssetBundle()..failNext = true;
        final cache = MermaidHtmlCache(bundle: fakeBundle);

        await expectLater(cache.htmlFor(isDark: false), throwsException);

        final result = await cache.htmlFor(isDark: false);
        expect(result, contains("theme: 'default'"));
        expect(fakeBundle.calls, equals(2));
      },
    );

    test(
      'หากโหลดล้มเหลวทันที (sync error) ต้องสามารถลองใหม่สำเร็จในครั้งที่สอง',
      () async {
        final fakeBundle = _FakeAssetBundle()..failSyncNext = true;
        final cache = MermaidHtmlCache(bundle: fakeBundle);

        await expectLater(cache.htmlFor(isDark: false), throwsException);

        final result = await cache.htmlFor(isDark: false);
        expect(result, contains("theme: 'default'"));
        expect(fakeBundle.calls, equals(2));
      },
    );
  });
}
