import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mnote/l10n/l10n.dart';

final _separatorPattern = RegExp(
  r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$',
);

/// One cell as written in the source: its text with `\|` unescaped, and where
/// the escaped text sits in the table source.
class _SourceCell {
  const _SourceCell(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

final _escapedPipePattern = RegExp(r'(\\*)\|');

/// Cell text to source: a pipe becomes `\|`, and backslashes right before it
/// are doubled so they cannot pair up with the escape and split the cell.
String _escapeCell(String cell) => cell
    .replaceAll('\n', ' ')
    .replaceAllMapped(
      _escapedPipePattern,
      (match) => '${'\\' * (match[1]!.length * 2 + 1)}|',
    );

/// The inverse of [_escapeCell] for one cell's source.
String _unescapeCell(String source) =>
    source.replaceAllMapped(_escapedPipePattern, (match) {
      final slashes = match[1]!.length;
      return slashes.isOdd ? '${'\\' * (slashes ~/ 2)}|' : match[0]!;
    });

/// Whether the pipe at [index] is escaped by an odd run of backslashes.
bool _isEscaped(String line, int index, int from) {
  var slashes = 0;
  while (index - slashes - 1 >= from && line[index - slashes - 1] == '\\') {
    slashes++;
  }
  return slashes.isOdd;
}

/// Splits a table line on unescaped pipes. [offset] is where the line starts.
List<_SourceCell> _splitRow(String line, int offset) {
  var from = 0;
  var to = line.length;
  while (from < to && line[from].trim().isEmpty) {
    from++;
  }
  while (to > from && line[to - 1].trim().isEmpty) {
    to--;
  }
  if (from < to && line[from] == '|') from++;
  if (to > from && line[to - 1] == '|' && !_isEscaped(line, to - 1, from)) {
    to--;
  }
  final cells = <_SourceCell>[];
  var cellStart = from;
  void addCell(int end) {
    var start = cellStart;
    while (start < end && line[start].trim().isEmpty) {
      start++;
    }
    while (end > start && line[end - 1].trim().isEmpty) {
      end--;
    }
    cells.add(
      _SourceCell(
        _unescapeCell(line.substring(start, end)),
        offset + start,
        offset + end,
      ),
    );
  }

  for (var i = from; i < to; i++) {
    if (line[i] == '\\' && i + 1 < to) {
      i++;
    } else if (line[i] == '|') {
      addCell(i);
      cellStart = i + 1;
    }
  }
  addCell(to);
  return cells;
}

/// A GitHub-flavoured Markdown table that can be edited cell by cell.
class MarkdownTable {
  MarkdownTable(this.rows, this.alignments);

  /// Row 0 is the header. Every row has [columns] cells.
  final List<List<String>> rows;

  /// The separator marker of each column: `---`, `:---`, `---:` or `:---:`.
  final List<String> alignments;

  int get columns => alignments.length;

  /// Where each cell's text sits in the source it was parsed from.
  List<List<TextRange>> _ranges = const [];

  /// Parses [source] when it is exactly one table, otherwise returns null.
  static MarkdownTable? parse(String source) {
    final lines = source.split('\n');
    if (lines.length < 2 ||
        !lines[0].contains('|') ||
        // GFM needs a pipe in the separator; a bare `---` underlines a
        // setext heading.
        !lines[1].contains('|') ||
        !_separatorPattern.hasMatch(lines[1]) ||
        lines.skip(2).any((line) => !line.contains('|'))) {
      return null;
    }
    final parsed = <List<_SourceCell>>[];
    var offset = 0;
    for (final line in lines) {
      parsed.add(_splitRow(line, offset));
      offset += line.length + 1;
    }
    final separator = parsed.removeAt(1);
    // As in GFM: a header that does not match the separator is not a table
    // (it may be a setext heading), and cells past the header are hidden, so
    // rewriting the table would reveal them. Leave both to the Markdown editor.
    final columns = separator.length;
    if (parsed.first.length != columns ||
        parsed.any((row) => row.length > columns)) {
      return null;
    }
    final alignments = [
      for (final marker in separator)
        '${marker.text.startsWith(':') ? ':' : ''}---'
            '${marker.text.endsWith(':') ? ':' : ''}',
    ];
    final table = MarkdownTable([
      for (final row in parsed)
        [for (var x = 0; x < columns; x++) x < row.length ? row[x].text : ''],
    ], alignments);
    table._ranges = [
      for (final row in parsed)
        [
          for (var x = 0; x < columns; x++)
            x < row.length
                ? TextRange(start: row[x].start, end: row[x].end)
                : TextRange.empty,
        ],
    ];
    return table;
  }

  /// Writes the table back as Markdown, recording where each cell landed.
  String format() {
    final buffer = StringBuffer();
    final ranges = <List<TextRange>>[];
    void writeRow(List<String> cells, {bool record = true}) {
      final row = <TextRange>[];
      buffer.write('|');
      for (final cell in cells) {
        buffer.write(' ');
        final start = buffer.length;
        buffer.write(_escapeCell(cell));
        row.add(TextRange(start: start, end: buffer.length));
        buffer.write(' |');
      }
      if (record) ranges.add(row);
    }

    for (var y = 0; y < rows.length; y++) {
      if (y > 0) buffer.write('\n');
      writeRow(rows[y]);
      if (y == 0) {
        buffer.write('\n');
        writeRow(alignments, record: false);
      }
    }
    _ranges = ranges;
    return buffer.toString();
  }

  /// Whether cell ([row], [column]) is written in the source; a short row
  /// leaves its last cells out.
  bool hasSource(int row, int column) => _ranges[row][column].isValid;

  /// The source offset of [index] within cell ([row], [column]).
  int sourceOffset(int row, int column, int index) {
    final range = _ranges[row][column];
    final text = rows[row][column];
    final before = text.substring(0, index.clamp(0, text.length));
    return range.start + _escapeCell(before).length;
  }

  /// The cell holding source [offset] and the index inside its text.
  (int, int, int)? cellAt(int offset) {
    for (var y = 0; y < _ranges.length; y++) {
      for (var x = 0; x < _ranges[y].length; x++) {
        final range = _ranges[y][x];
        if (!range.isValid || offset < range.start || offset > range.end) {
          continue;
        }
        final text = rows[y][x];
        var index = 0;
        while (index < text.length &&
            range.start + _escapeCell(text.substring(0, index + 1)).length <=
                offset) {
          index++;
        }
        return (y, x, index);
      }
    }
    return null;
  }
}

/// Finds the table cell under [globalPosition] in a rendered table block, so
/// the editor can open on the cell that was tapped.
(int, int)? renderedTableCellAt(BuildContext block, Offset globalPosition) {
  RenderTable? table;
  void visit(RenderObject object) {
    if (table != null) return;
    if (object is RenderTable) {
      table = object;
      return;
    }
    object.visitChildren(visit);
  }

  final root = block.findRenderObject();
  if (root == null) return null;
  visit(root);
  final found = table;
  if (found == null || !found.attached) return null;
  final local = found.globalToLocal(globalPosition);
  int? row;
  for (var y = 0; y < found.rows; y++) {
    if (found.getRowBox(y).contains(local) ||
        (y == found.rows - 1 && local.dy >= found.getRowBox(y).top)) {
      row = y;
      break;
    }
  }
  if (row == null) return null;
  final cells = found.row(row).toList();
  for (var x = 0; x < cells.length; x++) {
    final left = found.globalToLocal(cells[x].localToGlobal(Offset.zero)).dx;
    if (local.dx < left + cells[x].size.width || x == cells.length - 1) {
      return (row, x);
    }
  }
  return null;
}

/// Edits a Markdown table one cell at a time, writing every change back to
/// [controller] as Markdown so history, saving and the toolbar keep working.
class MarkdownTableEditor extends StatefulWidget {
  const MarkdownTableEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.onEditAsMarkdown,
    this.initialCell,
  });

  /// The active block's source, which must parse as a [MarkdownTable].
  final TextEditingController controller;

  /// Has focus while any cell does; losing it closes the block.
  final FocusNode focusNode;
  final TextStyle style;
  final VoidCallback onEditAsMarkdown;

  /// The cell (row, column) to focus first.
  final (int, int)? initialCell;

  @override
  State<MarkdownTableEditor> createState() => _MarkdownTableEditorState();
}

class _MarkdownTableEditorState extends State<MarkdownTableEditor> {
  late MarkdownTable _table;
  final _cells = <List<TextEditingController>>[];
  final _cellFocus = <List<FocusNode>>[];
  (int, int) _current = (0, 0);
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    _table = MarkdownTable.parse(widget.controller.text)!;
    _current = _clamp(widget.initialCell ?? (0, 0));
    _rebuildCells();
    widget.controller.addListener(_onSourceChanged);
    _refocus();
  }

  /// Keeps a cell inside the table, which may have shrunk since it was picked
  /// (for example while editing the Markdown).
  (int, int) _clamp((int, int) cell) => (
    cell.$1.clamp(0, _table.rows.length - 1),
    cell.$2.clamp(0, _table.columns - 1),
  );

  /// Focuses the current cell after the next frame builds its field.
  void _refocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCell(_current.$1, _current.$2, selectAll: false);
    });
  }

  @override
  void didUpdateWidget(MarkdownTableEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSourceChanged);
      widget.controller.addListener(_onSourceChanged);
      _onSourceChanged();
    }
  }

  void _disposeCells() {
    final cells = [for (final row in _cells) ...row];
    final focus = [for (final row in _cellFocus) ...row];
    _cells.clear();
    _cellFocus.clear();
    // Old fields may still be in the tree until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final cell in cells) {
        cell.dispose();
      }
      for (final node in focus) {
        node.dispose();
      }
    });
  }

  void _rebuildCells() {
    _disposeCells();
    for (var y = 0; y < _table.rows.length; y++) {
      final row = <TextEditingController>[];
      final focus = <FocusNode>[];
      for (var x = 0; x < _table.columns; x++) {
        final cell = TextEditingController(text: _table.rows[y][x]);
        cell.addListener(() => _onCellChanged(y, x));
        row.add(cell);
        final node = FocusNode();
        node.addListener(() {
          if (node.hasFocus) {
            _current = (y, x);
            _onCellChanged(y, x);
          }
        });
        focus.add(node);
      }
      _cells.add(row);
      _cellFocus.add(focus);
    }
  }

  /// Applies an outside edit (the formatting toolbar) to the cells.
  void _onSourceChanged() {
    if (_writing) return;
    final table = MarkdownTable.parse(widget.controller.text);
    if (table == null) return;
    final sameShape =
        table.rows.length == _table.rows.length &&
        table.columns == _table.columns;
    _table = table;
    if (!sameShape) {
      // The focused field is replaced, so focus its successor or the block
      // would close.
      _current = _clamp(_current);
      _rebuildCells();
      setState(() {});
      _refocus();
      return;
    }
    final selection = widget.controller.selection;
    final base = selection.isValid ? table.cellAt(selection.baseOffset) : null;
    final extent = selection.isValid
        ? table.cellAt(selection.extentOffset)
        : null;
    _writing = true;
    for (var y = 0; y < table.rows.length; y++) {
      for (var x = 0; x < table.columns; x++) {
        final cell = _cells[y][x];
        final text = table.rows[y][x];
        if (cell.text == text && (base?.$1 != y || base?.$2 != x)) continue;
        var cellSelection = TextSelection.collapsed(offset: text.length);
        if (base != null && base.$1 == y && base.$2 == x) {
          cellSelection = TextSelection(
            baseOffset: base.$3,
            extentOffset: extent != null && extent.$1 == y && extent.$2 == x
                ? extent.$3
                : base.$3,
          );
        }
        cell.value = TextEditingValue(text: text, selection: cellSelection);
      }
    }
    _writing = false;
    setState(() {});
  }

  /// Writes cell ([y], [x]) back to the block and points the block's selection
  /// at it, so toolbar actions apply inside the cell being edited.
  void _onCellChanged(int y, int x) {
    if (_writing || y >= _cells.length || x >= _cells[y].length) return;
    if (!_cellFocus[y][x].hasFocus) return;
    final cell = _cells[y][x];
    // Only an actual edit rewrites the table; moving between cells must not
    // reformat Markdown the user wrote by hand.
    // A cell missing from a short row has no place in the source until the
    // table is written out in full.
    var text = widget.controller.text;
    if (cell.text != _table.rows[y][x] || !_table.hasSource(y, x)) {
      _table.rows[y][x] = cell.text;
      text = _table.format();
    }
    final selection = cell.selection.isValid
        ? cell.selection
        : TextSelection.collapsed(offset: cell.text.length);
    _write(
      text,
      TextSelection(
        baseOffset: _table.sourceOffset(y, x, selection.baseOffset),
        extentOffset: _table.sourceOffset(y, x, selection.extentOffset),
      ),
    );
  }

  void _write(String text, TextSelection selection) {
    _writing = true;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: selection,
    );
    _writing = false;
  }

  void _focusCell(int y, int x, {bool selectAll = true}) {
    if (y >= _cellFocus.length || x >= _cellFocus[y].length) return;
    _current = (y, x);
    final cell = _cells[y][x];
    cell.selection = selectAll
        ? TextSelection(baseOffset: 0, extentOffset: cell.text.length)
        : TextSelection.collapsed(offset: cell.text.length);
    _cellFocus[y][x].requestFocus();
  }

  void _reshape(void Function() change, (int, int) focus) {
    change();
    final text = _table.format();
    _rebuildCells();
    _write(text, TextSelection.collapsed(offset: text.length));
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCell(focus.$1, focus.$2);
    });
  }

  void _addRow() {
    final at = _current.$1 + 1;
    _reshape(
      () => _table.rows.insert(
        at,
        List.filled(_table.columns, '', growable: true),
      ),
      (at, _current.$2),
    );
  }

  void _addColumn() {
    final at = _current.$2 + 1;
    _reshape(() {
      _table.alignments.insert(at, '---');
      for (final row in _table.rows) {
        row.insert(at, '');
      }
    }, (_current.$1, at));
  }

  void _deleteRow() {
    final (y, x) = _current;
    if (y == 0 || _table.rows.length <= 2) return;
    _reshape(() => _table.rows.removeAt(y), (
      y.clamp(1, _table.rows.length - 2),
      x,
    ));
  }

  void _deleteColumn() {
    final (y, x) = _current;
    if (_table.columns <= 1) return;
    _reshape(() {
      _table.alignments.removeAt(x);
      for (final row in _table.rows) {
        row.removeAt(x);
      }
    }, (y, x.clamp(0, _table.columns - 2)));
  }

  /// Enter moves down a row, adding one below the last.
  void _onSubmitted(int y, int x) {
    if (y + 1 < _table.rows.length) {
      _focusCell(y + 1, x);
    } else {
      _current = (y, x);
      _addRow();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSourceChanged);
    for (final row in _cells) {
      for (final cell in row) {
        cell.dispose();
      }
    }
    for (final row in _cellFocus) {
      for (final node in row) {
        node.dispose();
      }
    }
    super.dispose();
  }

  TextAlign _align(int x) {
    final marker = _table.alignments[x];
    if (marker.startsWith(':') && marker.endsWith(':')) return TextAlign.center;
    if (marker.endsWith(':')) return TextAlign.right;
    return TextAlign.left;
  }

  Widget _cell(int y, int x) {
    return TextField(
      key: Key('markdown-table-cell-$y-$x'),
      controller: _cells[y][x],
      focusNode: _cellFocus[y][x],
      textAlign: _align(x),
      textInputAction: TextInputAction.next,
      // Without this, the field also moves focus to the next cell itself.
      onEditingComplete: () {},
      onSubmitted: (_) => _onSubmitted(y, x),
      onTapOutside: (_) => widget.focusNode.unfocus(),
      style: y == 0
          ? widget.style.copyWith(fontWeight: FontWeight.w700)
          : widget.style,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  Widget _toolButton(
    Key key,
    IconData icon,
    String tooltip,
    VoidCallback? onPressed,
  ) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final border = scheme.outlineVariant;
    final (row, column) = _current;
    return Focus(
      focusNode: widget.focusNode,
      skipTraversal: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Part of the cells' tap region, so using these keeps the block open.
          TextFieldTapRegion(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _toolButton(
                  const Key('markdown-table-add-row'),
                  Icons.table_rows_outlined,
                  l10n.tableAddRow,
                  _addRow,
                ),
                _toolButton(
                  const Key('markdown-table-add-column'),
                  Icons.view_column_outlined,
                  l10n.tableAddColumn,
                  _addColumn,
                ),
                _toolButton(
                  const Key('markdown-table-delete-row'),
                  Icons.playlist_remove,
                  l10n.tableDeleteRow,
                  row > 0 && _table.rows.length > 2 ? _deleteRow : null,
                ),
                _toolButton(
                  const Key('markdown-table-delete-column'),
                  Icons.remove_circle_outline,
                  l10n.tableDeleteColumn,
                  _table.columns > 1 ? _deleteColumn : null,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('markdown-table-edit-markdown'),
                  onPressed: widget.onEditAsMarkdown,
                  icon: const Icon(Icons.code, size: 18),
                  label: Text(l10n.tableEditMarkdown),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              const minColumnWidth = 140.0;
              final scrolls =
                  _table.columns * minColumnWidth > constraints.maxWidth;
              final table = Table(
                border: TableBorder.all(color: border),
                defaultColumnWidth: scrolls
                    ? const FixedColumnWidth(minColumnWidth)
                    : const FlexColumnWidth(),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  for (var y = 0; y < _table.rows.length; y++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: y == 0
                            ? scheme.surfaceContainerHighest
                            : (y == row
                                  ? scheme.primary.withValues(alpha: 0.04)
                                  : null),
                      ),
                      children: [
                        for (var x = 0; x < _table.columns; x++)
                          ColoredBox(
                            color: y == row && x == column
                                ? scheme.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                            child: _cell(y, x),
                          ),
                      ],
                    ),
                ],
              );
              if (!scrolls) return table;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _table.columns * minColumnWidth,
                  child: table,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
