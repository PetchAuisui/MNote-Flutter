import 'package:flutter/material.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';
import 'package:mnote/features/workspace/presentation/workspace_toolbar_metrics.dart';

class MarkdownFormattingToolbar extends StatelessWidget {
  const MarkdownFormattingToolbar({
    super.key,
    required this.onUndo,
    required this.onRedo,
    required this.onHeading,
    required this.onBold,
    required this.onItalic,
    required this.onList,
    required this.onOrderedList,
    required this.onIndentList,
    required this.onOutdentList,
    required this.onQuote,
    required this.onLineBreak,
    required this.onHorizontalRule,
    required this.onInlineCode,
    required this.onCodeBlock,
    required this.onLink,
    required this.onImage,
    this.onDiagramTemplate,
    this.onImportDiagram,
  });

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final ValueChanged<int> onHeading;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onList;
  final VoidCallback onOrderedList;
  final VoidCallback onIndentList;
  final VoidCallback onOutdentList;
  final VoidCallback onQuote;
  final VoidCallback onLineBreak;
  final VoidCallback onHorizontalRule;
  final VoidCallback onInlineCode;
  final VoidCallback onCodeBlock;
  final VoidCallback onLink;
  final VoidCallback onImage;
  final ValueChanged<MermaidTemplate>? onDiagramTemplate;
  final VoidCallback? onImportDiagram;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onDiagramTemplate = this.onDiagramTemplate;
    final onImportDiagram = this.onImportDiagram;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        key: const Key('markdown-toolbar-surface'),
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showLabels = constraints.maxWidth >= 1400;
            return Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                height: workspaceToolbarControlSize,
                width: double.infinity,
                child: Row(
                  key: const Key('markdown-formatting-toolbar'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _fitTools(context, constraints.maxWidth - 16, [
                    _ToolbarActionButton(
                      buttonKey: const Key('toolbar-undo'),
                      icon: Icons.undo_rounded,
                      label: 'เลิกทำ',
                      showLabel: false,
                      onPressed: onUndo,
                    ),
                    _ToolbarActionButton(
                      buttonKey: const Key('toolbar-redo'),
                      icon: Icons.redo_rounded,
                      label: 'ทำซ้ำ',
                      showLabel: false,
                      onPressed: onRedo,
                    ),
                    const _ToolbarDivider(),
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
                    _ToolbarMenuButton<_ListStyle>(
                      buttonKey: const Key('toolbar-list'),
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'รายการ',
                      showLabel: showLabels,
                      onSelected: (style) {
                        switch (style) {
                          case _ListStyle.bulleted:
                            onList();
                          case _ListStyle.ordered:
                            onOrderedList();
                        }
                      },
                      items: const [
                        PopupMenuItem(
                          value: _ListStyle.bulleted,
                          child: ListTile(
                            leading: Icon(Icons.format_list_bulleted_rounded),
                            title: Text('รายการหัวข้อ'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _ListStyle.ordered,
                          child: ListTile(
                            leading: Icon(Icons.format_list_numbered_rounded),
                            title: Text('รายการตัวเลข'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    _ToolbarActionButton(
                      buttonKey: const Key('toolbar-indent-list'),
                      icon: Icons.format_indent_increase_rounded,
                      label: 'ทำเป็นรายการย่อย',
                      tooltip: 'ทำเป็นรายการย่อย',
                      showLabel: false,
                      onPressed: onIndentList,
                    ),
                    _ToolbarActionButton(
                      buttonKey: const Key('toolbar-outdent-list'),
                      icon: Icons.format_indent_decrease_rounded,
                      label: 'กลับสู่รายการหลัก',
                      tooltip: 'กลับสู่รายการหลัก',
                      showLabel: false,
                      onPressed: onOutdentList,
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
                      label: 'ขึ้นบรรทัด',
                      tooltip: 'ขึ้นบรรทัดใหม่ด้วย <br>',
                      showLabel: showLabels,
                      onPressed: onLineBreak,
                    ),
                    _ToolbarActionButton(
                      buttonKey: const Key('toolbar-horizontal-rule'),
                      icon: Icons.horizontal_rule_rounded,
                      label: 'เส้นคั่น',
                      tooltip: 'แทรกเส้นคั่นแนวนอนด้วย ---',
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
                    if (onDiagramTemplate != null || onImportDiagram != null)
                      _ToolbarMenuButton<_DiagramMenuAction>(
                        buttonKey: const Key('toolbar-diagram'),
                        icon: Icons.account_tree_outlined,
                        label: 'ไดอะแกรม',
                        showLabel: showLabels,
                        onSelected: (action) {
                          switch (action) {
                            case _InsertDiagramTemplate(:final template):
                              onDiagramTemplate?.call(template);
                            case _ImportDiagramFile():
                              onImportDiagram?.call();
                          }
                        },
                        items: [
                          if (onDiagramTemplate != null)
                            for (final template in mermaidTemplates)
                              PopupMenuItem(
                                key: Key('toolbar-diagram-${template.id}'),
                                value: _InsertDiagramTemplate(template),
                                child: ListTile(
                                  leading: Icon(
                                    _diagramTemplateIcon(template.id),
                                  ),
                                  title: Text(template.label),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                          if (onDiagramTemplate != null &&
                              onImportDiagram != null)
                            const PopupMenuDivider(),
                          if (onImportDiagram != null)
                            const PopupMenuItem(
                              key: Key('toolbar-diagram-import'),
                              value: _ImportDiagramFile(),
                              child: ListTile(
                                leading: Icon(Icons.file_open_outlined),
                                title: Text('นำเข้าจากไฟล์ .mmd…'),
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
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _fitTools(
    BuildContext context,
    double width,
    List<Widget> tools,
  ) {
    double toolWidth(Widget tool) {
      if (tool is _ToolbarDivider) return 13;
      final showLabel = tool is _ToolbarActionButton
          ? tool.showLabel
          : (tool as _ToolbarMenuButton).showLabel;
      final label = tool is _ToolbarActionButton
          ? tool.label
          : (tool as _ToolbarMenuButton).label;
      if (!showLabel) {
        return tool is _ToolbarActionButton ? 52 : 67;
      }
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final result = text.width + 72;
      text.dispose();
      return result;
    }

    final widths = tools.map(toolWidth).toList();
    if (widths.fold<double>(0, (sum, value) => sum + value) <= width) {
      return tools;
    }
    var used = 0.0;
    var count = 0;
    while (count < tools.length && used + widths[count] <= width - 48) {
      used += widths[count++];
    }
    while (count > 0 && tools[count - 1] is _ToolbarDivider) {
      count--;
    }
    final entries = <PopupMenuEntry<VoidCallback>>[];
    for (final tool in tools.skip(count)) {
      if (tool is _ToolbarActionButton) {
        entries.add(
          PopupMenuItem<VoidCallback>(
            key: tool.buttonKey,
            value: tool.onPressed,
            enabled: tool.onPressed != null,
            child: ListTile(
              leading: Icon(tool.icon),
              title: Text(tool.label),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      } else if (tool is _ToolbarMenuButton) {
        entries.addAll(tool.overflowItems());
      }
    }
    return [
      ...tools.take(count),
      PopupMenuButton<VoidCallback>(
        key: const Key('toolbar-more'),
        tooltip: 'เครื่องมือเพิ่มเติม',
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (action) => action(),
        itemBuilder: (_) => entries,
      ),
    ];
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
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: showLabel
          ? TextButton.icon(
              key: buttonKey,
              onPressed: onPressed,
              icon: Icon(icon, size: workspaceToolbarIconSize),
              label: Text(label),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                minimumSize: workspaceToolbarControlConstraints,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            )
          : IconButton(
              key: buttonKey,
              onPressed: onPressed,
              tooltip: tooltip ?? label,
              constraints: const BoxConstraints.tightFor(
                width: workspaceToolbarControlSize,
                height: workspaceToolbarControlSize,
              ),
              icon: Icon(icon, size: workspaceToolbarIconSize),
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

  List<PopupMenuEntry<VoidCallback>> overflowItems() => [
    for (final item in items)
      if (item is PopupMenuItem<T>)
        PopupMenuItem<VoidCallback>(
          value: () => onSelected(item.value as T),
          child: item.child,
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: PopupMenuButton<T>(
        key: buttonKey,
        tooltip: label,
        onSelected: onSelected,
        itemBuilder: (_) => items,
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surfaceContainer,
        child: Container(
          height: workspaceToolbarControlSize,
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 14 : 12),
          decoration: ShapeDecoration(
            color: Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: workspaceToolbarIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
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
      child: SizedBox(
        height: 32,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

enum _CodeStyle { inline, block }

enum _ListStyle { bulleted, ordered }

sealed class _DiagramMenuAction {
  const _DiagramMenuAction();
}

final class _InsertDiagramTemplate extends _DiagramMenuAction {
  const _InsertDiagramTemplate(this.template);
  final MermaidTemplate template;
}

final class _ImportDiagramFile extends _DiagramMenuAction {
  const _ImportDiagramFile();
}

IconData _diagramTemplateIcon(String id) => switch (id) {
  'sequence' => Icons.swap_horiz_rounded,
  'class' => Icons.schema_outlined,
  _ => Icons.account_tree_outlined,
};
