import 'package:mnote/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid.dart';
import 'package:mnote/features/workspace/presentation/workspace_toolbar_metrics.dart';

class MarkdownFormattingToolbar extends StatefulWidget {
  const MarkdownFormattingToolbar({
    super.key,
    required this.onUndo,
    required this.onRedo,
    required this.onHeading,
    required this.onBold,
    required this.onItalic,
    required this.onStrikethrough,
    required this.onList,
    required this.onOrderedList,
    required this.onTaskList,
    required this.onIndentList,
    required this.onOutdentList,
    required this.onQuote,
    required this.onLineBreak,
    required this.onHorizontalRule,
    required this.onInlineCode,
    required this.onCodeBlock,
    required this.onLink,
    required this.onImage,
    required this.onTable,
    this.onDiagramTemplate,
    this.onImportDiagram,
  });

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final ValueChanged<int> onHeading;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onStrikethrough;
  final VoidCallback onList;
  final VoidCallback onOrderedList;
  final VoidCallback onTaskList;

  /// Null (and the button disabled) when the selection has no list item.
  final VoidCallback? onIndentList;

  /// Null (and the button disabled) when no selected list item is nested.
  final VoidCallback? onOutdentList;
  final VoidCallback onQuote;
  final VoidCallback onLineBreak;
  final VoidCallback onHorizontalRule;
  final VoidCallback onInlineCode;
  final VoidCallback onCodeBlock;
  final VoidCallback onLink;
  final VoidCallback onImage;
  final VoidCallback onTable;
  final ValueChanged<MermaidTemplate>? onDiagramTemplate;
  final VoidCallback? onImportDiagram;

  @override
  State<MarkdownFormattingToolbar> createState() =>
      _MarkdownFormattingToolbarState();
}

class _MarkdownFormattingToolbarState extends State<MarkdownFormattingToolbar> {
  int _headingLevel = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onDiagramTemplate = widget.onDiagramTemplate;
    final onImportDiagram = widget.onImportDiagram;

    // Taps on the toolbar belong to the text being edited, so they must not
    // count as a tap outside it and close the block the user is typing in.
    return TextFieldTapRegion(
      child: Padding(
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
                        label: context.l10n.undo,
                        showLabel: false,
                        onPressed: widget.onUndo,
                      ),
                      _ToolbarActionButton(
                        buttonKey: Key('toolbar-redo'),
                        icon: Icons.redo_rounded,
                        label: context.l10n.redo,
                        showLabel: false,
                        onPressed: widget.onRedo,
                      ),
                      _ToolbarDivider(),
                      _ToolbarMenuButton<int>(
                        buttonKey: Key('toolbar-heading'),
                        icon: Icons.title_rounded,
                        showIcon: false,
                        label: context.l10n.phHeadingN(_headingLevel),
                        showLabel: true,
                        onSelected: (level) {
                          setState(() => _headingLevel = level);
                          widget.onHeading(level);
                        },
                        items: [
                          PopupMenuItem(
                            value: 1,
                            child: Text(context.l10n.phHeadingN(1)),
                          ),
                          PopupMenuItem(
                            value: 2,
                            child: Text(context.l10n.phHeadingN(2)),
                          ),
                          PopupMenuItem(
                            value: 3,
                            child: Text(context.l10n.phHeadingN(3)),
                          ),
                          PopupMenuItem(
                            value: 4,
                            child: Text(context.l10n.phHeadingN(4)),
                          ),
                        ],
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-bold'),
                        icon: Icons.format_bold_rounded,
                        label: context.l10n.tbBold,
                        showLabel: showLabels,
                        onPressed: widget.onBold,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-italic'),
                        icon: Icons.format_italic_rounded,
                        label: context.l10n.tbItalic,
                        showLabel: showLabels,
                        onPressed: widget.onItalic,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-strikethrough'),
                        icon: Icons.format_strikethrough_rounded,
                        label: context.l10n.tbStrike,
                        showLabel: showLabels,
                        onPressed: widget.onStrikethrough,
                      ),
                      const _ToolbarDivider(),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-list'),
                        icon: Icons.format_list_bulleted_rounded,
                        label: context.l10n.tbBullets,
                        showLabel: showLabels,
                        onPressed: widget.onList,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-ordered-list'),
                        icon: Icons.format_list_numbered_rounded,
                        label: context.l10n.tbNumbered,
                        showLabel: showLabels,
                        onPressed: widget.onOrderedList,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-task-list'),
                        icon: Icons.checklist_rounded,
                        label: context.l10n.tbTasks,
                        showLabel: showLabels,
                        onPressed: widget.onTaskList,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-indent-list'),
                        icon: Icons.format_indent_increase_rounded,
                        label: context.l10n.tbIndent,
                        tooltip: context.l10n.tbIndent,
                        showLabel: false,
                        onPressed: widget.onIndentList,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-outdent-list'),
                        icon: Icons.format_indent_decrease_rounded,
                        label: context.l10n.tbOutdent,
                        tooltip: context.l10n.tbOutdent,
                        showLabel: false,
                        onPressed: widget.onOutdentList,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-quote'),
                        icon: Icons.format_quote_rounded,
                        label: context.l10n.tbQuote,
                        showLabel: showLabels,
                        onPressed: widget.onQuote,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-line-break'),
                        icon: Icons.keyboard_return_rounded,
                        label: context.l10n.tbLineBreak,
                        tooltip: context.l10n.tbLineBreakTip,
                        showLabel: showLabels,
                        onPressed: widget.onLineBreak,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-horizontal-rule'),
                        icon: Icons.horizontal_rule_rounded,
                        label: context.l10n.tbRule,
                        tooltip: context.l10n.tbRuleTip,
                        showLabel: showLabels,
                        onPressed: widget.onHorizontalRule,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-table'),
                        icon: Icons.table_chart_outlined,
                        label: context.l10n.tbTable,
                        showLabel: showLabels,
                        onPressed: widget.onTable,
                      ),
                      _ToolbarMenuButton<_CodeStyle>(
                        buttonKey: Key('toolbar-code'),
                        icon: Icons.code_rounded,
                        label: context.l10n.tbCode,
                        showLabel: showLabels,
                        onSelected: (style) {
                          switch (style) {
                            case _CodeStyle.inline:
                              widget.onInlineCode();
                            case _CodeStyle.block:
                              widget.onCodeBlock();
                          }
                        },
                        items: [
                          PopupMenuItem(
                            value: _CodeStyle.inline,
                            child: Row(
                              children: [
                                Icon(Icons.code_rounded, size: 20),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(context.l10n.tbInlineCode),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _CodeStyle.block,
                            child: Row(
                              children: [
                                Icon(Icons.data_object_rounded, size: 20),
                                SizedBox(width: 12),
                                Expanded(child: Text(context.l10n.tbCodeBlock)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (onDiagramTemplate != null || onImportDiagram != null)
                        _ToolbarMenuButton<_DiagramMenuAction>(
                          buttonKey: const Key('toolbar-diagram'),
                          icon: Icons.account_tree_outlined,
                          label: context.l10n.tbDiagram,
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
                              for (final template in mermaidTemplatesFor(
                                context.l10n,
                              ))
                                PopupMenuItem(
                                  key: Key('toolbar-diagram-${template.id}'),
                                  value: _InsertDiagramTemplate(template),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _diagramTemplateIcon(template.id),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(template.label)),
                                    ],
                                  ),
                                ),
                            if (onDiagramTemplate != null &&
                                onImportDiagram != null)
                              const PopupMenuDivider(),
                            if (onImportDiagram != null)
                              PopupMenuItem(
                                key: Key('toolbar-diagram-import'),
                                value: _ImportDiagramFile(),
                                child: Row(
                                  children: [
                                    Icon(Icons.file_open_outlined, size: 20),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(context.l10n.tbImportMmd),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      const _ToolbarDivider(),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-link'),
                        icon: Icons.link_rounded,
                        label: context.l10n.tbLink,
                        showLabel: showLabels,
                        onPressed: widget.onLink,
                      ),
                      _ToolbarActionButton(
                        buttonKey: const Key('toolbar-image'),
                        icon: Icons.image_outlined,
                        label: context.l10n.tbImage,
                        showLabel: showLabels,
                        onPressed: widget.onImage,
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
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
        return tool is _ToolbarActionButton ? 52 : 70;
      }
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      // Label-only heading controls have no icon or icon-to-label gap.
      final result =
          text.width + (tool is _ToolbarMenuButton && !tool.showIcon ? 42 : 72);
      text.dispose();
      return result;
    }

    final widths = tools.map(toolWidth).toList();
    Widget sizedTool(int index) =>
        SizedBox(width: widths[index], child: tools[index]);
    if (widths.fold<double>(0, (sum, value) => sum + value) <= width) {
      return [
        for (var index = 0; index < tools.length; index++) sizedTool(index),
      ];
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
            child: Row(
              children: [
                Icon(tool.icon, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(tool.label)),
              ],
            ),
          ),
        );
      } else if (tool is _ToolbarMenuButton) {
        entries.addAll(tool.overflowItems());
      }
    }
    return [
      for (var index = 0; index < count; index++) sizedTool(index),
      SizedBox(
        width: 48,
        child: PopupMenuButton<VoidCallback>(
          key: const Key('toolbar-more'),
          tooltip: context.l10n.tbMore,
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (action) => action(),
          itemBuilder: (_) => entries,
        ),
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
    this.showIcon = true,
    required this.label,
    required this.showLabel,
    required this.onSelected,
    required this.items,
  });

  final Key buttonKey;
  final IconData icon;
  final bool showIcon;
  final String label;
  final bool showLabel;
  final ValueChanged<T> onSelected;
  final List<PopupMenuEntry<T>> items;

  List<PopupMenuEntry<VoidCallback>> overflowItems() => [
    for (final item in items)
      if (item is PopupMenuItem<T>)
        PopupMenuItem<VoidCallback>(
          key: item.key,
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
        tooltip: showLabel ? '' : label,
        onSelected: onSelected,
        itemBuilder: (_) => items,
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surfaceContainer,
        child: Container(
          height: workspaceToolbarControlSize,
          padding: EdgeInsets.symmetric(
            horizontal: !showIcon
                ? 10
                : showLabel
                ? 14
                : 12,
          ),
          decoration: ShapeDecoration(
            color: Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon)
                Icon(
                  icon,
                  size: workspaceToolbarIconSize,
                  color: colorScheme.onSurfaceVariant,
                ),
              if (showLabel) ...[
                if (showIcon) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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
