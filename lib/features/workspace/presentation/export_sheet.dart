import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

enum ExportFormat { pdf, markdown, plainText, image }

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

typedef ExportSaver =
    Future<Uri?> Function({
      required String fileName,
      required Uint8List bytes,
      required String extension,
    });

typedef ExportSharer =
    Future<void> Function({
      required String fileName,
      required Uint8List bytes,
      required String mimeType,
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

Future<void> defaultExportSharer({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$fileName');
  await tempFile.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(tempFile.path, mimeType: mimeType)],
      text: 'แชร์เอกสาร $fileName',
    ),
  );
}

Future<Uint8List?> captureSurfaceImage(GlobalKey surfaceKey) async {
  try {
    final boundary =
        surfaceKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) return null;
    final image = await boundary
        .toImage(pixelRatio: 2.0)
        .timeout(
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
  bool includeInk = true,
  bool isContinuous = false,
}) async {
  final pdf = pw.Document();
  if (includeInk && surfaceImageBytes != null && surfaceImageBytes.isNotEmpty) {
    final image = pw.MemoryImage(surfaceImageBytes);
    final imgW = (image.width ?? 1).toDouble();
    final imgH = (image.height ?? 1).toDouble();
    final pageFormat = isContinuous
        ? PdfPageFormat(
            PdfPageFormat.a4.width,
            (PdfPageFormat.a4.width * (imgH / imgW)).clamp(100.0, 6000.0),
          )
        : PdfPageFormat.a4;
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
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
  GlobalKey? surfaceKey,
  ExportSaver exportSaver = defaultExportSaver,
  ExportSharer exportSharer = defaultExportSharer,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => ExportBottomSheet(
      document: document,
      surfaceKey: surfaceKey,
      exportSaver: exportSaver,
      exportSharer: exportSharer,
    ),
  );
}

class ExportBottomSheet extends StatefulWidget {
  const ExportBottomSheet({
    super.key,
    required this.document,
    this.surfaceKey,
    required this.exportSaver,
    this.exportSharer = defaultExportSharer,
  });

  final MarkdownDocument document;
  final GlobalKey? surfaceKey;
  final ExportSaver exportSaver;
  final ExportSharer exportSharer;

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  ExportFormat? _selectedFormat;
  bool _includeInk = true;
  bool _isContinuous = false;
  bool _isProcessing = false;

  String _getFormatTitle(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return 'PDF (.pdf)';
      case ExportFormat.markdown:
        return 'Markdown (.md)';
      case ExportFormat.plainText:
        return 'ข้อความล้วน (.txt)';
      case ExportFormat.image:
        return 'รูปภาพ (.png)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            // Drag handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header with Back button (if drilled-down) and File Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  if (_selectedFormat != null)
                    IconButton(
                      key: const Key('export-back-button'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'ย้อนกลับ',
                      onPressed: () => setState(() => _selectedFormat = null),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFormat == null
                              ? 'ส่งออกเอกสาร'
                              : 'ส่งออกเป็น ${_getFormatTitle(_selectedFormat!)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Badge / Chip แสดงชื่อไฟล์อย่างโดดเด่น
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.document.name.endsWith('.txt')
                                    ? Icons.text_snippet_outlined
                                    : Icons.description_outlined,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                ),
                                child: Text(
                                  widget.document.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
            if (_selectedFormat == null)
              _buildFormatListView()
            else
              _buildOptionsView(context),
          ],
        ),
      ),
    );
  }

  // หน้าเลือกประเภทไฟล์หลัก (4 ตัวเลือก)
  Widget _buildFormatListView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ExportOptionTile(
          key: const Key('export-option-pdf'),
          icon: Icons.picture_as_pdf_rounded,
          iconColor: const Color(0xFFE53935),
          iconBgColor: const Color(0xFFFFEBEE),
          title: 'เอกสาร PDF (.pdf)',
          subtitle: 'รวมเนื้อหา ข้อความ และลายเส้นหมึกวาด',
          onTap: () => setState(() => _selectedFormat = ExportFormat.pdf),
        ),
        _ExportOptionTile(
          key: const Key('export-option-markdown'),
          icon: Icons.description_rounded,
          iconColor: const Color(0xFF1E88E5),
          iconBgColor: const Color(0xFFE3F2FD),
          title: 'Markdown (.md)',
          subtitle: 'ไฟล์ข้อความ Markdown ต้นฉบับ',
          onTap: () => setState(() => _selectedFormat = ExportFormat.markdown),
        ),
        _ExportOptionTile(
          key: const Key('export-option-plaintext'),
          icon: Icons.text_snippet_rounded,
          iconColor: const Color(0xFFFB8C00),
          iconBgColor: const Color(0xFFFFF3E0),
          title: 'ข้อความล้วน (.txt)',
          subtitle: 'เฉพาะเนื้อหา ตัดสัญลักษณ์ Markdown ออก',
          onTap: () => setState(() => _selectedFormat = ExportFormat.plainText),
        ),
        _ExportOptionTile(
          key: const Key('export-option-image'),
          icon: Icons.image_rounded,
          iconColor: const Color(0xFF43A047),
          iconBgColor: const Color(0xFFE8F5E9),
          title: 'รูปภาพ (.png)',
          subtitle: 'ภาพสแนปช็อตหน้าเอกสารและหมึกความละเอียดสูง',
          onTap: () => setState(() => _selectedFormat = ExportFormat.image),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // หน้า Drill-down กำหนด Options สำหรับประเภทไฟล์ที่เลือก
  Widget _buildOptionsView(BuildContext context) {
    switch (_selectedFormat!) {
      case ExportFormat.pdf:
        return _buildPdfOptionsView(context);
      case ExportFormat.image:
        return _buildImageOptionsView(context);
      case ExportFormat.markdown:
        return _buildTextOptionsView(context, isMarkdown: true);
      case ExportFormat.plainText:
        return _buildTextOptionsView(context, isMarkdown: false);
    }
  }

  Widget _buildPdfOptionsView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: isDark
                ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('export-pdf-ink-switch'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: const Text(
                    'รวมรอยหมึกปากกา (Layer หมึกวาด)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(
                    _includeInk
                        ? 'เรนเดอร์ลายเส้นหมึกและไฮไลท์ลงบนเอกสาร PDF'
                        : 'ส่งออกเฉพาะข้อความล้วน (ไม่รวมลายเส้นวาด)',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  secondary: Icon(
                    Icons.draw_rounded,
                    color: _includeInk
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                  value: _includeInk,
                  onChanged: (val) => setState(() => _includeInk = val),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  title: const Text(
                    'ขนาดหน้าเอกสาร',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(
                    _isContinuous
                        ? 'แบบต่อเนื่อง (Continuous / หน้าเดียวยาว)'
                        : 'ขนาดมาตรฐาน A4',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  leading: Icon(
                    _isContinuous
                        ? Icons.view_day_rounded
                        : Icons.description_outlined,
                    color: colorScheme.primary,
                  ),
                  trailing: SegmentedButton<bool>(
                    key: const Key('export-pdf-page-format'),
                    segments: const [
                      ButtonSegment(value: false, label: Text('A4')),
                      ButtonSegment(value: true, label: Text('ต่อเนื่อง')),
                    ],
                    selected: {_isContinuous},
                    onSelectionChanged: (set) {
                      setState(() => _isContinuous = set.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButtons(
            saveLabel: 'บันทึกไฟล์ PDF',
            shareLabel: 'แชร์ไฟล์ PDF',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildImageOptionsView(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: isDark
                ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: SwitchListTile(
              key: const Key('export-image-ink-switch'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: const Text(
                'รวมรอยหมึกปากกา',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
              ),
              subtitle: Text(
                _includeInk
                    ? 'สแนปช็อตรวมลายเส้นหมึกวาดทั้งหมด'
                    : 'เฉพาะข้อความเอกสาร',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              secondary: Icon(
                Icons.image_rounded,
                color: _includeInk ? Colors.green : colorScheme.outline,
              ),
              value: _includeInk,
              onChanged: (val) => setState(() => _includeInk = val),
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButtons(
            saveLabel: 'บันทึกรูปภาพ (.png)',
            shareLabel: 'แชร์รูปภาพ',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTextOptionsView(
    BuildContext context, {
    required bool isMarkdown,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: isDark
                ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isMarkdown
                          ? const Color(0xFFE3F2FD)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isMarkdown
                          ? Icons.description_rounded
                          : Icons.text_snippet_rounded,
                      color: isMarkdown
                          ? const Color(0xFF1E88E5)
                          : const Color(0xFFFB8C00),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMarkdown ? 'Markdown (.md)' : 'ข้อความล้วน (.txt)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMarkdown
                              ? 'ส่งออกโค้ด Markdown ต้นฉบับทั้งหมด'
                              : 'ตัดเครื่องหมาย Markdown ออก เหลือเฉพาะข้อความธรรมดา',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButtons(saveLabel: 'บันทึกไฟล์', shareLabel: 'แชร์ไฟล์'),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required String saveLabel,
    required String shareLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('export-share-button'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(shareLabel),
            onPressed: _isProcessing
                ? null
                : () => _executeExport(isShare: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            key: const Key('export-save-button'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            label: Text(saveLabel),
            onPressed: _isProcessing
                ? null
                : () => _executeExport(isShare: false),
          ),
        ),
      ],
    );
  }

  Future<void> _executeExport({required bool isShare}) async {
    if (_isProcessing || _selectedFormat == null) return;
    setState(() => _isProcessing = true);

    final format = _selectedFormat!;
    final baseName = widget.document.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    Uint8List bytes;
    String ext;
    String mimeType;
    String fileName;

    try {
      switch (format) {
        case ExportFormat.markdown:
          bytes = Uint8List.fromList(utf8.encode(widget.document.content));
          ext = 'md';
          mimeType = 'text/markdown';
          fileName = '$baseName.md';
          break;

        case ExportFormat.plainText:
          final text = stripMarkdown(widget.document.content);
          bytes = Uint8List.fromList(utf8.encode(text));
          ext = 'txt';
          mimeType = 'text/plain';
          fileName = '$baseName.txt';
          break;

        case ExportFormat.image:
          final imageBytes = widget.surfaceKey != null
              ? await captureSurfaceImage(widget.surfaceKey!)
              : null;
          if (imageBytes == null || imageBytes.isEmpty) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'กรุณาเปิดหน้าเอกสารเพื่อจับภาพส่งออกเป็นรูปภาพความละเอียดสูง',
                ),
              ),
            );
            setState(() => _isProcessing = false);
            return;
          }
          bytes = imageBytes;
          ext = 'png';
          mimeType = 'image/png';
          fileName = '$baseName.png';
          break;

        case ExportFormat.pdf:
          final surfaceBytes = widget.surfaceKey != null && _includeInk
              ? await captureSurfaceImage(widget.surfaceKey!)
              : null;
          bytes = await generatePdf(
            title: baseName,
            markdown: widget.document.content,
            surfaceImageBytes: surfaceBytes,
            includeInk: _includeInk,
            isContinuous: _isContinuous,
          );
          ext = 'pdf';
          mimeType = 'application/pdf';
          fileName = '$baseName.pdf';
          break;
      }

      navigator.pop();

      if (isShare) {
        await widget.exportSharer(
          fileName: fileName,
          bytes: bytes,
          mimeType: mimeType,
        );
      } else {
        final result = await widget.exportSaver(
          fileName: fileName,
          bytes: bytes,
          extension: ext,
        );
        if (result != null) {
          messenger.showSnackBar(
            SnackBar(content: Text('ส่งออกไฟล์ $fileName สำเร็จ')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่งออกไฟล์ กรุณาลองใหม่'),
        ),
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
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Material(
        color: isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.3,
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
