import 'package:mnote/l10n/language_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'mermaid_block.dart';

/// ขนาดไฟล์สูงสุดที่อนุญาตให้นำเข้า (100 KB)
const int mermaidImportMaxBytes = 100 * 1024;

/// ผลลัพธ์ของการตรวจสอบและแปลงไฟล์ Mermaid ที่นำเข้า
sealed class MermaidImportResult {
  const MermaidImportResult();
}

/// กรณีนำเข้าไฟล์สำเร็จ
final class MermaidImportSuccess extends MermaidImportResult {
  const MermaidImportSuccess({required this.name, required this.source});

  final String name;
  final String source;
}

/// กรณีนำเข้าไฟล์ไม่สำเร็จพร้อมข้อความแจ้งเตือนภาษาไทย
final class MermaidImportFailure extends MermaidImportResult {
  const MermaidImportFailure(this.message);

  final String message;
}

/// ตรวจสอบและแปลงไฟล์ Mermaid ตามลำดับความปลอดภัย
MermaidImportResult parseMermaidImport({
  required String name,
  required Uint8List bytes,
}) {
  final lowerName = name.toLowerCase();
  if (!lowerName.endsWith('.mmd') && !lowerName.endsWith('.mermaid')) {
    return MermaidImportFailure(LanguagePreferences.current().mmdOnlyMmd);
  }

  if (bytes.length > mermaidImportMaxBytes) {
    return MermaidImportFailure(
      LanguagePreferences.current().mmdTooBig(mermaidImportMaxBytes ~/ 1024),
    );
  }

  String content;
  try {
    content = utf8.decode(bytes);
  } on FormatException {
    return MermaidImportFailure(LanguagePreferences.current().mmdNotUtf8);
  }

  if (content.startsWith('\uFEFF')) {
    content = content.substring(1);
  }

  final fenceRegex = RegExp(
    r'^\s*(`{3,})\s*mermaid[^\n]*\n([\s\S]*?)\n\s*\1\s*$',
  );
  final match = fenceRegex.firstMatch(content);
  if (match != null) {
    content = match.group(2) ?? '';
  }

  final cleanedSource = normalizeMermaidSource(content);
  if (cleanedSource.isEmpty) {
    return MermaidImportFailure(LanguagePreferences.current().mmdEmpty);
  }

  return MermaidImportSuccess(name: name, source: cleanedSource);
}
