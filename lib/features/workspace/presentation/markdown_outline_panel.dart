import 'package:flutter/material.dart';
import 'package:mnote/l10n/l10n.dart';

import 'markdown_live_editor.dart';
import 'markdown_outline.dart';

/// The note's table of contents, shown as a side sheet or inside a bottom
/// sheet: tapping a heading scrolls the document to it.
class MarkdownOutlinePanel extends StatefulWidget {
  const MarkdownOutlinePanel({
    super.key,
    this.asSheet = false,
    required this.textController,
    required this.outline,
    required this.onSelected,
    required this.onClose,
  });

  /// Inside a bottom sheet, which supplies its own surface and handle.
  final bool asSheet;
  final TextEditingController textController;
  final MarkdownOutlineController outline;
  final ValueChanged<MarkdownHeading> onSelected;
  final VoidCallback onClose;

  @override
  State<MarkdownOutlinePanel> createState() => _MarkdownOutlinePanelState();
}

class _MarkdownOutlinePanelState extends State<MarkdownOutlinePanel> {
  String? _source;
  List<MarkdownHeading> _headings = const [];

  List<MarkdownHeading> _headingsOf(String source) {
    if (_source != source) {
      _headings = parseMarkdownHeadings(source);
      _source = source;
    }
    return _headings;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.outlineTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (!widget.asSheet)
                IconButton(
                  key: const Key('outline-close'),
                  onPressed: widget.onClose,
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        Flexible(
          child: ListenableBuilder(
            listenable: widget.textController,
            builder: (context, _) {
              final headings = _headingsOf(widget.textController.text);
              if (headings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text(
                    context.l10n.outlineEmpty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return _HeadingList(
                headings: headings,
                outline: widget.outline,
                onSelected: widget.onSelected,
              );
            },
          ),
        ),
      ],
    );
    if (widget.asSheet) return content;
    // A standard Material 3 side sheet: it sits beside the document on a
    // container surface and is separated from it by a divider.
    return Material(
      key: const Key('outline-panel'),
      color: theme.colorScheme.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            end: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(top: false, right: false, child: content),
      ),
    );
  }
}

class _HeadingList extends StatelessWidget {
  const _HeadingList({
    required this.headings,
    required this.outline,
    required this.onSelected,
  });

  final List<MarkdownHeading> headings;
  final MarkdownOutlineController outline;
  final ValueChanged<MarkdownHeading> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Indent relative to the shallowest heading so a document that only uses
    // `##` does not start with an empty margin.
    final shallowest = headings
        .map((heading) => heading.level)
        .reduce((a, b) => a < b ? a : b);
    return ValueListenableBuilder<int?>(
      valueListenable: outline.activeOffset,
      builder: (context, active, _) => ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: headings.length,
        itemBuilder: (context, index) {
          final heading = headings[index];
          final selected = heading.offset == active;
          final title = heading.title.isEmpty
              ? context.l10n.outlineUntitled
              : heading.title;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Material(
              color: selected
                  ? theme.colorScheme.secondaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                key: ValueKey('outline-item-${heading.offset}'),
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelected(heading),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    12 + (heading.level - shallowest) * 14.0,
                    8,
                    12,
                    8,
                  ),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: heading.level == shallowest
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
