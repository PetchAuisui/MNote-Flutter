import 'package:mnote/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../workspace/presentation/mermaid/mermaid.dart';

/// ตัววาดบล็อกโค้ดในคำตอบของ AI
///
/// - บล็อก mermaid: การ์ดภาพ/โค้ด พร้อมปุ่มคัดลอก
/// - บล็อกโค้ดภาษาอื่น: การ์ดโค้ดพร้อมชื่อภาษาและปุ่มคัดลอก
/// - โค้ดในบรรทัด: คืน null ให้แพ็กเกจวาดตามปกติ
/// ใช้เฉพาะในแชท หน้าโน้ตยังใช้ [MermaidElementBuilder] เดิม
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
    final className = element.attributes['class'];
    if (isMermaidCodeClass(className)) {
      return AssistantMermaidCard(
        source: normalizeMermaidSource(element.textContent),
        isStreaming: isStreaming,
      );
    }

    final code = element.textContent;
    // บล็อกโค้ด (``` ```) ลงท้ายด้วยขึ้นบรรทัดใหม่เสมอ โค้ดในบรรทัดไม่มี
    if (!code.endsWith('\n')) return null;
    return AssistantCodeCard(
      code: code.trimRight(),
      language: _languageOf(className),
    );
  }
}

/// ดึงชื่อภาษาจาก class เช่น `language-dart` → `dart`
String? _languageOf(String? className) {
  const prefix = 'language-';
  if (className == null || !className.startsWith(prefix)) return null;
  final language = className.substring(prefix.length).trim();
  return language.isEmpty ? null : language;
}

/// การ์ดโค้ดทั่วไป: ชื่อภาษา + ปุ่มคัดลอก + โค้ดที่เลื่อนซ้ายขวาได้
class AssistantCodeCard extends StatelessWidget {
  const AssistantCodeCard({super.key, required this.code, this.language});

  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('assistant-code-card'),
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
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Text(
                  language ?? context.l10n.tbCode,
                  key: const Key('assistant-code-language'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                _CopyCodeButton(
                  buttonKey: const Key('assistant-code-copy'),
                  text: code,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                key: const Key('assistant-code-text'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
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
                  style: ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.image_outlined, size: 18),
                      label: Text(
                        context.l10n.aiTabImage,
                        key: Key('assistant-mermaid-show-diagram'),
                      ),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.code_rounded, size: 18),
                      label: Text(
                        context.l10n.tbCode,
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
                _CopyCodeButton(
                  buttonKey: const Key('assistant-mermaid-copy'),
                  // คัดลอกพร้อมรั้ว ```mermaid เพื่อวางในโน้ตแล้ววาดเป็นภาพได้ทันที
                  text: buildMermaidFencedBlock(widget.source),
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

/// ปุ่มคัดลอกที่ใช้ร่วมกันทั้งการ์ดโค้ดและการ์ด Mermaid
/// กดแล้วไอคอนเป็น ✓ 2 วินาที
class _CopyCodeButton extends StatefulWidget {
  const _CopyCodeButton({required this.buttonKey, required this.text});

  final Key buttonKey;
  final String text;

  @override
  State<_CopyCodeButton> createState() => _CopyCodeButtonState();
}

class _CopyCodeButtonState extends State<_CopyCodeButton> {
  bool _copied = false;
  Timer? _copiedTimer;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
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
    return IconButton(
      key: widget.buttonKey,
      tooltip: _copied ? context.l10n.aiCopied : context.l10n.copyCode,
      icon: Icon(
        _copied ? Icons.check_rounded : Icons.content_copy_rounded,
        size: 20,
      ),
      onPressed: _copy,
    );
  }
}
