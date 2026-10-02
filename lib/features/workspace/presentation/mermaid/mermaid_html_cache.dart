import 'package:flutter/services.dart';
import 'mermaid_html.dart';

/// ที่อยู่ของไฟล์สคริปต์ Mermaid ภายใน assets
const String mermaidAssetPath = 'assets/mermaid/mermaid.min.js';

/// จัดการแคชของโค้ดสคริปต์และ HTML สำเร็จรูปสำหรับ Mermaid เพื่อหลีกเลี่ยงการสร้างซ้ำ
class MermaidHtmlCache {
  final AssetBundle _bundle;

  Future<String>? _scriptFuture;
  final Map<bool, Future<String>> _htmlFutures = {};

  MermaidHtmlCache({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// ดึงโค้ด HTML ตามธีม [isDark] โดยนำผลลัพธ์ที่แคชไว้กลับมาใช้ซ้ำ
  ///
  /// Future อาจโยนข้อผิดพลาดได้หากโหลดไฟล์ asset ไม่สำเร็จ หรือสคริปต์ไม่ผ่านเกณฑ์ความปลอดภัย
  Future<String> htmlFor({required bool isDark}) {
    final cached = _htmlFutures[isDark];
    if (cached != null) {
      return cached;
    }

    final future = _buildHtml(isDark);
    _htmlFutures[isDark] = future;

    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_htmlFutures[isDark], future)) {
          _htmlFutures.remove(isDark);
        }
      },
    );

    return future;
  }

  Future<String> _loadScript() {
    final cached = _scriptFuture;
    if (cached != null) {
      return cached;
    }

    final future = _bundle.loadString(mermaidAssetPath);
    _scriptFuture = future;

    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_scriptFuture, future)) {
          _scriptFuture = null;
        }
      },
    );

    return future;
  }

  Future<String> _buildHtml(bool isDark) async {
    final script = await _loadScript();
    return buildMermaidHtml(mermaidScript: script, isDark: isDark);
  }
}

/// แคชกลางสำหรับให้วิดเจ็ต Mermaid ทุกตัวภายในแอปเรียกใช้งานร่วมกัน
final MermaidHtmlCache defaultMermaidHtmlCache = MermaidHtmlCache();
