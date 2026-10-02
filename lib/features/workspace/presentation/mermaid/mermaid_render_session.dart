import 'mermaid_height_cache.dart';
import 'mermaid_html.dart';

/// ผลลัพธ์จากการประมวลผลข้อความเรนเดอร์ของคำสั่งปัจจุบัน
sealed class MermaidRenderOutcome {
  const MermaidRenderOutcome();
}

/// แจ้งว่าการเรนเดอร์สำเร็จพร้อมความสูงที่จำกัดขอบเขตแล้ว
final class MermaidRenderSucceeded extends MermaidRenderOutcome {
  const MermaidRenderSucceeded({required this.height});

  final double height;
}

/// แจ้งว่าการเรนเดอร์ล้มเหลวพร้อมข้อความแจ้งเตือนข้อผิดพลาด
final class MermaidRenderErrored extends MermaidRenderOutcome {
  const MermaidRenderErrored({required this.message});

  final String message;
}

/// จัดการลำดับคำสั่งเรนเดอร์และประเมินความถูกต้องของผลลัพธ์จาก WebView
///
/// ทำหน้าที่ตัดสินว่าผลจาก WebView เป็นของคำสั่งวาดล่าสุดหรือไม่ ผลของคำสั่งเก่าจะถูกทิ้ง
/// และบันทึกความสูงลง cache ด้วย source ของคำสั่งที่ตรงกับ token
class MermaidRenderSession {
  MermaidRenderSession({required this.heightCache});

  final MermaidHeightCache heightCache;

  int _latestToken = 0;
  String _currentSource = '';
  bool _currentIsDark = false;

  /// เริ่มต้นรอบคำสั่งใหม่ เพิ่มค่า token จำ source และธีมปัจจุบัน แล้วคืนค่า token ล่าสุด
  int begin({required String source, required bool isDark}) {
    _latestToken++;
    _currentSource = source;
    _currentIsDark = isDark;
    return _latestToken;
  }

  /// ตรวจสอบว่า [token] ตรงกับรอบคำสั่งล่าสุดหรือไม่
  bool isCurrent(int token) => token == _latestToken;

  /// ประมวลผลข้อความ [bridgeMessage] ที่ได้รับจาก WebView
  ///
  /// คืนค่า `null` หาก token ไม่ตรงกับคำสั่งล่าสุด หรือคืน [MermaidRenderOutcome] ที่พร้อมนำไปใช้งาน
  MermaidRenderOutcome? handle(MermaidBridgeMessage bridgeMessage) {
    if (bridgeMessage.token != _latestToken) return null;

    switch (bridgeMessage) {
      case MermaidRendered(:final height):
        final clampedHeight = clampMermaidHeight(height);
        heightCache.store(
          source: _currentSource,
          isDark: _currentIsDark,
          height: clampedHeight,
        );
        return MermaidRenderSucceeded(height: clampedHeight);
      case MermaidRenderFailed(:final message):
        return MermaidRenderErrored(message: message);
    }
  }
}
