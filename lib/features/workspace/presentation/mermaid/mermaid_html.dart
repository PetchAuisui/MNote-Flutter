import 'dart:convert';

/// ชื่อ Channel สำหรับการสื่อสารระหว่าง JavaScript ใน WebView กับฝั่ง Dart
const String mermaidChannelName = 'MermaidBridge';

/// สร้างโค้ด HTML สำหรับแสดงผลไดอะแกรม Mermaid ภายใน WebView อย่างปลอดภัย
///
/// Throws [ArgumentError] ถ้า [mermaidScript] มี `</script`
String buildMermaidHtml({required String mermaidScript, required bool isDark}) {
  // ด่านป้องกัน: ตรวจจับแท็กปิดสคริปต์เพื่อป้องกันโครงสร้าง HTML แตก
  if (mermaidScript.toLowerCase().contains('</script')) {
    throw ArgumentError('mermaidScript must not contain "</script" tag.');
  }

  final theme = isDark ? 'dark' : 'default';

  return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:">
  <style>
    body {
      margin: 0;
      background-color: transparent;
    }
    svg {
      max-width: 100%;
    }
  </style>
</head>
<body>
  <div id="diagram"></div>
  <script>$mermaidScript</script>
  <script>
    if (typeof mermaid !== 'undefined') {
      mermaid.initialize({
        startOnLoad: false,
        securityLevel: 'strict',
        theme: '$theme'
      });
    }

    window.renderDiagram = async function (source) {
      if (typeof mermaid === 'undefined') {
        $mermaidChannelName.postMessage(JSON.stringify({
          type: "error",
          message: "Mermaid library is not loaded"
        }));
        return;
      }

      try {
        const { svg } = await mermaid.render('mnote-diagram', source);
        const container = document.getElementById('diagram');
        container.innerHTML = svg;
        const height = Math.ceil(container.getBoundingClientRect().height);
        $mermaidChannelName.postMessage(JSON.stringify({
          type: "rendered",
          height: height
        }));
      } catch (e) {
        $mermaidChannelName.postMessage(JSON.stringify({
          type: "error",
          message: (e && e.message) ? String(e.message) : String(e)
        }));
      }
    };
  </script>
</body>
</html>''';
}

/// สร้างคำสั่ง JavaScript สำหรับเรียก window.renderDiagram พร้อมใส่โค้ดไดอะแกรมที่ encode ปลอดภัยแล้ว
String buildMermaidRenderCall(String source) {
  var encoded = jsonEncode(source);

  // WebView รุ่นเก่าถือว่า \u2028 และ \u2029 เป็นการขึ้นบรรทัดใหม่กลางสตริง จึงต้อง escape เพิ่ม
  encoded = encoded
      .replaceAll('\u2028', r'\u2028')
      .replaceAll('\u2029', r'\u2029');

  return 'window.renderDiagram($encoded);';
}

/// คลาสแม่ของข้อความที่ได้รับจาก JavaScript ผ่าน MermaidBridge
sealed class MermaidBridgeMessage {
  const MermaidBridgeMessage();
}

/// ข้อความแจ้งว่าเรนเดอร์สำเร็จ พร้อมความสูงของไดอะแกรม
final class MermaidRendered extends MermaidBridgeMessage {
  final double height;
  const MermaidRendered(this.height);
}

/// ข้อความแจ้งว่าการเรนเดอร์ล้มเหลว พร้อมรายละเอียดข้อผิดพลาด
final class MermaidRenderFailed extends MermaidBridgeMessage {
  final String message;
  const MermaidRenderFailed(this.message);
}

/// แปลงข้อความ JSON ดิบจาก JavaScript Bridge ให้เป็น [MermaidBridgeMessage]
///
/// คืนค่า `null` หากรูปแบบข้อความไม่ถูกต้อง หรือไม่มีข้อมูลที่ต้องการประมวลผล
MermaidBridgeMessage? parseMermaidBridgeMessage(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final type = decoded['type'];
    if (type == 'rendered') {
      final height = decoded['height'];
      if (height is num && height >= 0) {
        return MermaidRendered(height.toDouble());
      }
      return null;
    }

    if (type == 'error') {
      final message = decoded['message'];
      if (message is String && message.isNotEmpty) {
        return MermaidRenderFailed(message);
      }
      return const MermaidRenderFailed('Unknown render error');
    }

    return null;
  } catch (_) {
    return null;
  }
}
