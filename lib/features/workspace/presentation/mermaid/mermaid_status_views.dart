import 'package:flutter/material.dart';

/// มุมมองแสดงสถานะไดอะแกรมว่างเปล่า
class MermaidDiagramEmptyView extends StatelessWidget {
  const MermaidDiagramEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mermaid-diagram-empty'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'ไดอะแกรมว่าง',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

/// มุมมองแสดงผลสำรอง (Fallback) เมื่อแพลตฟอร์มไม่รองรับ WebView
class MermaidDiagramFallbackView extends StatelessWidget {
  final String source;

  const MermaidDiagramFallbackView({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('mermaid-diagram-fallback'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            source,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Text(
            'แพลตฟอร์มนี้ยังไม่รองรับการแสดงไดอะแกรม',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// มุมมองแสดงข้อผิดพลาดเมื่อเรนเดอร์ไดอะแกรมไม่สำเร็จ
class MermaidDiagramErrorView extends StatelessWidget {
  final String message;
  final String source;

  const MermaidDiagramErrorView({
    super.key,
    required this.message,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('mermaid-diagram-error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'แสดงไดอะแกรมไม่ได้',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const Divider(height: 16),
          SelectableText(
            source,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
