import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../workspace/presentation/mermaid/mermaid.dart';

/// ตัววาดบล็อกโค้ดในคำตอบของ AI
///
/// บล็อก mermaid แสดงเป็นภาพพร้อมปุ่มสลับดูโค้ดและปุ่มคัดลอก
/// ใช้เฉพาะในแชท หน้าโน้ตยังใช้ [MermaidElementBuilder] เดิม
/// บล็อกภาษาอื่นและโค้ดในบรรทัดคืน null ให้แพ็กเกจวาดตามปกติ
class AssistantCodeBlockBuilder extends MarkdownElementBuilder {
  AssistantCodeBlockBuilder({this.isStreaming = false});

  final bool isStreaming;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (!isMermaidCodeClass(element.attributes['class'])) return null;
    return AssistantMermaidCard(
      source: normalizeMermaidSource(element.textContent),
      isStreaming: isStreaming,
    );
  }
}

class AssistantMermaidCard extends StatefulWidget {
  const AssistantMermaidCard({
    super.key,
    required this.source,
    this.isStreaming = false,
  });

  final String source;
  final bool isStreaming;

  @override
  State<AssistantMermaidCard> createState() => _AssistantMermaidCardState();
}

class _AssistantMermaidCardState extends State<AssistantMermaidCard> {
  bool _showCode = false;
  bool _copied = false;
  Timer? _copiedTimer;

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: buildMermaidFencedBlock(widget.source)),
    );
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // ระหว่างที่ AI ยังพิมพ์ไม่จบ ให้แสดงเป็นโค้ดก่อนเพื่อไม่ให้ตัววาดผังพัง
    final effectiveShowCode = widget.isStreaming || _showCode;

    return Container(
      key: const Key('assistant-mermaid-card'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(
              children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.image_outlined, size: 18),
                      label: Text(
                        'ภาพ',
                        key: Key('assistant-mermaid-show-diagram'),
                      ),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.code_rounded, size: 18),
                      label: Text(
                        'โค้ด',
                        key: Key('assistant-mermaid-show-code'),
                      ),
                    ),
                  ],
                  selected: {effectiveShowCode},
                  onSelectionChanged: widget.isStreaming
                      ? null
                      : (selection) =>
                            setState(() => _showCode = selection.first),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('assistant-mermaid-copy'),
                  tooltip: _copied ? 'คัดลอกแล้ว' : 'คัดลอกโค้ด',
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.content_copy_rounded,
                    size: 20,
                  ),
                  onPressed: _copy,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (effectiveShowCode)
            Container(
              key: const Key('assistant-mermaid-code'),
              color: colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                widget.source,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            )
          else
            MermaidDiagramView(source: widget.source),
        ],
      ),
    );
  }
}
