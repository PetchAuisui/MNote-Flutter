import 'package:flutter/material.dart';

class MarkdownFormattingToolbar extends StatelessWidget {
  const MarkdownFormattingToolbar({
    super.key,
    required this.onHeading,
    required this.onBold,
    required this.onItalic,
    required this.onList,
    required this.onQuote,
    required this.onLineBreak,
    required this.onHorizontalRule,
    required this.onInlineCode,
    required this.onCodeBlock,
    required this.onLink,
    required this.onImage,
  });

  final ValueChanged<int> onHeading;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onList;
  final VoidCallback onQuote;
  final VoidCallback onLineBreak;
  final VoidCallback onHorizontalRule;
  final VoidCallback onInlineCode;
  final VoidCallback onCodeBlock;
  final VoidCallback onLink;
  final VoidCallback onImage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showLabels = constraints.maxWidth >= 900;
            return SizedBox(
              height: 58,
              child: ListView(
                key: const Key('markdown-formatting-toolbar'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                children: [
                  _ToolbarMenuButton<int>(
                    buttonKey: const Key('toolbar-heading'),
                    icon: Icons.title_rounded,
                    label: 'หัวข้อ',
                    showLabel: showLabels,
                    onSelected: onHeading,
                    items: const [
                      PopupMenuItem(value: 1, child: Text('หัวข้อ 1')),
                      PopupMenuItem(value: 2, child: Text('หัวข้อ 2')),
                      PopupMenuItem(value: 3, child: Text('หัวข้อ 3')),
                      PopupMenuItem(value: 4, child: Text('หัวข้อ 4')),
                    ],
                  ),
                  _ToolbarActionButton(
                    buttonKey: const Key('toolbar-bold'),
                    icon: Icons.format_bold_rounded,
                    label: 'ตัวหนา',
                    showLabel: showLabels,
                    onPressed: onBold,
                  ),
                  _ToolbarActionButton(
                    buttonKey: const Key('toolbar-italic'),
                    icon: Icons.format_italic_rounded,
                    label: 'ตัวเอียง',
                    showLabel: showLabels,
                    onPressed: onItalic,
                  ),
                  const _ToolbarDivider(),
                  _ToolbarActionButton(
                    buttonKey: const Key('toolbar-list'),
                    icon: Icons.format_list_bulleted_rounded,
                    label: 'รายการ',
                    showLabel: showLabels,
                    onPressed: onList,
                  ),
                  _ToolbarActionButton(
                    buttonKey: const Key('toolbar-quote'),
                    icon: Icons.format_quote_rounded,
                    label: 'อ้างอิง',
                    showLabel: showLabels,
                    onPressed: onQuote,
                  ),
                  _ToolbarActionButton(
                    buttonKey: const Key('toolbar-line-break'),
                    icon: Icons.keyboard_return_rounded,
                    label: 'BR',
                    tooltip: 'ขึ้นบรรทัดใหม่ (BR)',
                    showLabel: showLabels,
                    onPressed: onLineBreak,
                  ),
                  _ToolbarActionButton(
                    buttonKey: const Key('toolbar-horizontal-rule'),
                    icon: Icons.horizontal_rule_rounded,
                    label: 'HR',
                    tooltip: 'เส้นคั่นแนวนอน (HR)',
                    showLabel: showLabels,
                    onPressed: onHorizontalRule,
                  ),
                  _ToolbarMenuButton<_CodeStyle>(
                    buttonKey: const Key('toolbar-code'),
                    icon: Icons.code_rounded,
                    label: 'โค้ด',
                    showLabel: showLabels,
                    onSelected: (style) {
                      switch (style) {
                        case _CodeStyle.inline:
                          onInlineCode();
                        case _CodeStyle.block:
                          onCodeBlock();
                      }
                    },
                    items: const [
                      PopupMenuItem(
                        value: _CodeStyle.inline,
                        child: ListTile(
                          leading: Icon(Icons.code_rounded),
                          title: Text('โค้ดในบรรทัด'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _CodeStyle.block,
                        child: ListTile(
                          leading: Icon(Icons.data_object_rounded),
                          title: Text('บล็อกโค้ด'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const _ToolbarDivider(),
                  _ToolbarActionButton(
                    buttonKey: const Key('toolbar-link'),
                    icon: Icons.link_rounded,
                    label: 'ลิงก์',
                    showLabel: showLabels,
                    onPressed: onLink,
                  ),
                  _ToolbarActionButton(
                    buttonKey: const Key('toolbar-image'),
                    icon: Icons.image_outlined,
                    label: 'รูปภาพ',
                    showLabel: showLabels,
                    onPressed: onImage,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ToolbarActionButton extends StatelessWidget {
  const _ToolbarActionButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    this.tooltip,
    required this.showLabel,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final String? tooltip;
  final bool showLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: showLabel
          ? FilledButton.tonalIcon(
              key: buttonKey,
              onPressed: onPressed,
              icon: Icon(icon, size: 19),
              label: Text(label),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            )
          : IconButton.filledTonal(
              key: buttonKey,
              onPressed: onPressed,
              tooltip: tooltip ?? label,
              icon: Icon(icon, size: 21),
            ),
    );
  }
}

class _ToolbarMenuButton<T> extends StatelessWidget {
  const _ToolbarMenuButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.showLabel,
    required this.onSelected,
    required this.items,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final bool showLabel;
  final ValueChanged<T> onSelected;
  final List<PopupMenuEntry<T>> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: PopupMenuButton<T>(
        key: buttonKey,
        tooltip: label,
        onSelected: onSelected,
        itemBuilder: (_) => items,
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.secondaryContainer,
        child: Ink(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 14 : 12),
          decoration: ShapeDecoration(
            color: colorScheme.secondaryContainer,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: colorScheme.onSecondaryContainer),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: colorScheme.onSecondaryContainer),
                ),
              ],
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

enum _CodeStyle { inline, block }
