import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_html.dart';

void main() {
  const fakeScript = '/* fake mermaid */';

  group('buildMermaidHtml', () {
    test('มี securityLevel: strict', () {
      final html = buildMermaidHtml(mermaidScript: fakeScript, isDark: false);
      expect(html, contains("securityLevel: 'strict'"));
    });

    test('มี startOnLoad: false', () {
      final html = buildMermaidHtml(mermaidScript: fakeScript, isDark: false);
      expect(html, contains('startOnLoad: false'));
    });

    test('มี CSP default-src none', () {
      final html = buildMermaidHtml(mermaidScript: fakeScript, isDark: false);
      expect(html, contains("default-src 'none'"));
    });

    test('ปรับ theme ตาม isDark ถูกต้อง', () {
      final darkHtml = buildMermaidHtml(
        mermaidScript: fakeScript,
        isDark: true,
      );
      expect(darkHtml, contains("theme: 'dark'"));

      final lightHtml = buildMermaidHtml(
        mermaidScript: fakeScript,
        isDark: false,
      );
      expect(lightHtml, contains("theme: 'default'"));
    });

    test('มีสตริงปลอมของ mermaid อยู่ใน HTML', () {
      final html = buildMermaidHtml(mermaidScript: fakeScript, isDark: false);
      expect(html, contains(fakeScript));
    });

    test('มี mermaidChannelName อยู่ใน HTML', () {
      final html = buildMermaidHtml(mermaidScript: fakeScript, isDark: false);
      expect(html, contains(mermaidChannelName));
    });

    test('ไม่มี http:// และ ไม่มี https://', () {
      final html = buildMermaidHtml(mermaidScript: fakeScript, isDark: false);
      expect(html, isNot(contains('http://')));
      expect(html, isNot(contains('https://')));
    });
  });

  group('security', () {
    test('throw ArgumentError เมื่อ mermaidScript มี </script>', () {
      expect(
        () => buildMermaidHtml(
          mermaidScript: 'console.log("</script>");',
          isDark: false,
        ),
        throwsArgumentError,
      );
    });

    test('throw ArgumentError เมื่อมี </SCRIPT> ตัวพิมพ์ใหญ่', () {
      expect(
        () => buildMermaidHtml(
          mermaidScript: 'console.log("</SCRIPT>");',
          isDark: false,
        ),
        throwsArgumentError,
      );
    });

    test('ไฟล์ mermaid จริงใน assets ต้องผ่านด่านโดยไม่ throw', () {
      final realScript = File(
        'assets/mermaid/mermaid.min.js',
      ).readAsStringSync();
      expect(
        () => buildMermaidHtml(mermaidScript: realScript, isDark: false),
        returnsNormally,
      );
    });
  });

  group('buildMermaidRenderCall', () {
    test('ผลลัพธ์ขึ้นต้นด้วย window.renderDiagram( และลงท้ายด้วย );', () {
      final call = buildMermaidRenderCall('graph TD;');
      expect(call.startsWith('window.renderDiagram('), isTrue);
      expect(call.endsWith(');'), isTrue);
    });

    test(
      'test ไป-กลับ ด้วยข้อความอันตราย เมื่อ jsonDecode ต้องได้ข้อความเดิมทุกตัวอักษร',
      () {
        const payload =
            'graph TD\n  A["</script><script>alert(1)</script>"] --> B \'quote\' "dq" \\\\back';
        final call = buildMermaidRenderCall(payload);

        const prefix = 'window.renderDiagram(';
        final jsonContent = call.substring(prefix.length, call.length - 2);
        expect(jsonDecode(jsonContent), equals(payload));
      },
    );

    test('ผลลัพธ์ไม่มีการขึ้นบรรทัดใหม่จริง (\\n) อยู่ข้างใน', () {
      final call = buildMermaidRenderCall('graph TD\n  A-->B\r\n  C-->D');
      expect(call.contains('\n'), isFalse);
      expect(call.contains('\r'), isFalse);
    });

    test('จัดการอักขระพิเศษ \\u2028 และ \\u2029 ได้ถูกต้อง', () {
      const special = 'line1 \u2028 line2 \u2029 end';
      final call = buildMermaidRenderCall(special);

      expect(call.contains('\u2028'), isFalse);
      expect(call.contains('\u2029'), isFalse);

      const prefix = 'window.renderDiagram(';
      final jsonContent = call.substring(prefix.length, call.length - 2);
      expect(jsonDecode(jsonContent), equals(special));
    });
  });
}
