const double mermaidMinHeight = 48.0;
const double mermaidMaxHeight = 2000.0;

/// จำกัดความสูงของไดอะแกรมให้อยู่ในช่วงที่เหมาะสม
double clampMermaidHeight(double height) {
  return height.clamp(mermaidMinHeight, mermaidMaxHeight);
}

/// แคชความสูงของไดอะแกรมเพื่อป้องกันหน้าจอกระตุกขณะเลื่อน (Scroll)
class MermaidHeightCache {
  final int limit;
  final Map<String, double> _cache = {};

  MermaidHeightCache({this.limit = 100});

  String _buildKey({required bool isDark, required String source}) {
    return '${isDark ? 'dark' : 'light'}:$source';
  }

  /// ค้นหาความสูงที่บันทึกไว้ คืนค่า null หากยังไม่เคยมี
  double? lookup({required bool isDark, required String source}) {
    final key = _buildKey(isDark: isDark, source: source);
    return _cache[key];
  }

  /// บันทึกความสูงของไดอะแกรมลงแคช
  void store({
    required bool isDark,
    required String source,
    required double height,
  }) {
    final key = _buildKey(isDark: isDark, source: source);
    if (!_cache.containsKey(key) && _cache.length >= limit) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = height;
  }
}

final MermaidHeightCache defaultMermaidHeightCache = MermaidHeightCache();
