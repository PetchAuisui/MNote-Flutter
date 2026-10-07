import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mermaid_diagram_view.dart';
import 'mermaid_templates.dart';

/// แสดงหน้าต่างดูตัวอย่างไฟล์ Mermaid ที่นำเข้า พร้อมตัวเลือกดูโค้ดและปุ่มคัดลอก
/// ปรับรูปแบบเป็นแบบเต็มจอบนอุปกรณ์จอแคบ (< 600) ตามหลัก MD3 Adaptive
Future<void> showMermaidImportDialog(
  BuildContext context, {
  required String fileName,
  required String source,
}) {
  final isCompact = MediaQuery.sizeOf(context).width < 600;

  if (isCompact) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        key: const Key('mermaid-import-dialog'),
        child: Scaffold(
          appBar: AppBar(
            leading: const CloseButton(key: Key('mermaid-import-cancel')),
            title: Text(fileName),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  key: const Key('mermaid-import-copy'),
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('คัดลอกโค้ด'),
                  onPressed: () => _copy(context, source),
                ),
              ),
            ],
          ),
          body: _ImportDialogContent(source: source),
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return Dialog(
        key: const Key('mermaid-import-dialog'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  fileName,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Flexible(child: _ImportDialogContent(source: source)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('mermaid-import-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const Key('mermaid-import-copy'),
                      icon: const Icon(Icons.content_copy_rounded),
                      label: const Text('คัดลอกโค้ด'),
                      onPressed: () => _copy(context, source),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ImportDialogContent extends StatelessWidget {
  const _ImportDialogContent({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MermaidDiagramView(source: source),
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            key: const Key('mermaid-import-code-toggle'),
            title: const Text('ดูโค้ด'),
            tilePadding: EdgeInsets.zero,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SelectableText(
                    source,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _copy(BuildContext context, String source) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  await Clipboard.setData(ClipboardData(text: buildMermaidFencedBlock(source)));
  navigator.pop();
  messenger.showSnackBar(
    const SnackBar(content: Text('คัดลอกแล้ว วางในโน้ตได้เลย')),
  );
}
