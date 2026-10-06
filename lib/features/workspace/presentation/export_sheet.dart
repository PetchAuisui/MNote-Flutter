import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ExportFormat {
  pdf,
  markdown,
  plainText,
  image,
}

String stripMarkdown(String markdown) {
  var text = markdown;
  // Remove fenced code blocks
  text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
  // Remove inline code: `code` -> code
  text = text.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '');
  // Remove images: ![alt](url) -> alt
  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
    (m) => m[1] ?? '',
  );
  // Remove links: [text](url) -> text
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (m) => m[1] ?? '',
  );
  // Remove headers: # Title -> Title
  text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
  // Remove bold: **text** or __text__ -> text
  text = text.replaceAllMapped(
    RegExp(r'\*\*([^*]+)\*\*|__([^_]+)__'),
    (m) => m[1] ?? m[2] ?? '',
  );
  // Remove italics: *text* or _text_ -> text
  text = text.replaceAllMapped(
    RegExp(r'\*([^*]+)\*|_([^_]+)_'),
    (m) => m[1] ?? m[2] ?? '',
  );
  // Remove strikethrough: ~~text~~ -> text
  text = text.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m[1] ?? '');
  // Remove blockquotes: > Quote -> Quote
  text = text.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
  // Remove unordered list bullets: - item -> item
  text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
  // Remove horizontal rules
  text = text.replaceAll(RegExp(r'^\s*([-*_]){3,}\s*$', multiLine: true), '');
  return text.trim();
}

typedef ExportSaver = Future<Uri?> Function({
  required String fileName,
  required Uint8List bytes,
  required String extension,
});

Future<Uri?> defaultExportSaver({
  required String fileName,
  required Uint8List bytes,
  required String extension,
}) async {
  return FilePicker.saveFile(
    dialogTitle: 'บันทึกไฟล์ส่งออก',
    fileName: fileName,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: [extension],
  );
}

Future<Uint8List?> captureSurfaceImage(GlobalKey surfaceKey) async {
  try {
    final boundary = surfaceKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) return null;
    final image = await boundary.toImage(pixelRatio: 2.0).timeout(
      const Duration(milliseconds: 300),
      onTimeout: () => throw TimeoutException('toImage timed out'),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

Future<Uint8List> generatePdf({
  required String title,
  required String markdown,
  Uint8List? surfaceImageBytes,
}) async {
  final pdf = pw.Document();
  if (surfaceImageBytes != null && surfaceImageBytes.isNotEmpty) {
    final image = pw.MemoryImage(surfaceImageBytes);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        },
      ),
    );
  } else {
    final plainText = stripMarkdown(markdown);
    final safeTitle = title.replaceAll(RegExp(r'[^\x00-\x7F]'), '').trim();
    final displayTitle = safeTitle.isEmpty ? 'Mnote Document' : safeTitle;
    final safeText = plainText.replaceAll(RegExp(r'[^\x00-\x7F]'), ' ');
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                displayTitle,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                safeText,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
              ),
            ],
          );
        },
      ),
    );
  }
  return pdf.save();
}

Future<void> showExportBottomSheet(
  BuildContext context, {
  required MarkdownDocument document,
  required GlobalKey surfaceKey,
  ExportSaver exportSaver = defaultExportSaver,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => ExportBottomSheet(
      document: document,
      surfaceKey: surfaceKey,
      exportSaver: exportSaver,
    ),
  );
}

class ExportBottomSheet extends StatelessWidget {
  const ExportBottomSheet({
    super.key,
    required this.document,
    required this.surfaceKey,
    required this.exportSaver,
  });

  final MarkdownDocument document;
  final GlobalKey surfaceKey;
  final ExportSaver exportSaver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseName = document.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ส่งออกเอกสาร',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          document.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('export-sheet-close'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            _ExportOptionTile(
              key: const Key('export-option-pdf'),
              icon: Icons.picture_as_pdf_rounded,
              iconColor: const Color(0xFFE53935),
              iconBgColor: const Color(0xFFFFEBEE),
              title: 'เอกสาร PDF (.pdf)',
              subtitle: 'รวมเนื้อหาและลายเส้นหมึก (สไตล์ Goodnotes)',
              onTap: () => _handleExport(context, ExportFormat.pdf, baseName),
            ),
            _ExportOptionTile(
              key: const Key('export-option-markdown'),
              icon: Icons.description_rounded,
              iconColor: const Color(0xFF1E88E5),
              iconBgColor: const Color(0xFFE3F2FD),
              title: 'Markdown (.md)',
              subtitle: 'ไฟล์ข้อความ Markdown ต้นฉบับ',
              onTap: () =>
                  _handleExport(context, ExportFormat.markdown, baseName),
            ),
            _ExportOptionTile(
              key: const Key('export-option-plaintext'),
              icon: Icons.text_snippet_rounded,
              iconColor: const Color(0xFFFB8C00),
              iconBgColor: const Color(0xFFFFF3E0),
              title: 'ข้อความล้วน (.txt)',
              subtitle: 'เฉพาะเนื้อหา ตัดสัญลักษณ์ Markdown ออก',
              onTap: () =>
                  _handleExport(context, ExportFormat.plainText, baseName),
            ),
            _ExportOptionTile(
              key: const Key('export-option-image'),
              icon: Icons.image_rounded,
              iconColor: const Color(0xFF43A047),
              iconBgColor: const Color(0xFFE8F5E9),
              title: 'รูปภาพ (.png)',
              subtitle: 'ภาพสแนปช็อตหน้าเอกสารและหมึกความละเอียดสูง',
              onTap: () => _handleExport(context, ExportFormat.image, baseName),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    ExportFormat format,
    String baseName,
  ) async {
    Navigator.pop(context);
    final messenger = ScaffoldMessenger.of(context);

    Uint8List bytes;
    String ext;
    String fileName;

    try {
      switch (format) {
        case ExportFormat.markdown:
          bytes = Uint8List.fromList(utf8.encode(document.content));
          ext = 'md';
          fileName = '$baseName.md';
          break;

        case ExportFormat.plainText:
          final text = stripMarkdown(document.content);
          bytes = Uint8List.fromList(utf8.encode(text));
          ext = 'txt';
          fileName = '$baseName.txt';
          break;

        case ExportFormat.image:
          final imageBytes = await captureSurfaceImage(surfaceKey);
          if (imageBytes == null || imageBytes.isEmpty) {
            messenger.showSnackBar(
              const SnackBar(content: Text('ไม่สามารถจับภาพเอกสารได้')),
            );
            return;
          }
          bytes = imageBytes;
          ext = 'png';
          fileName = '$baseName.png';
          break;

        case ExportFormat.pdf:
          final surfaceBytes = await captureSurfaceImage(surfaceKey);
          bytes = await generatePdf(
            title: baseName,
            markdown: document.content,
            surfaceImageBytes: surfaceBytes,
          );
          ext = 'pdf';
          fileName = '$baseName.pdf';
          break;
      }

      final result = await exportSaver(
        fileName: fileName,
        bytes: bytes,
        extension: ext,
      );

      if (result != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('ส่งออกไฟล์ $fileName สำเร็จ')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการส่งออกไฟล์ กรุณาลองใหม่')),
      );
    }
  }
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.outline,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
