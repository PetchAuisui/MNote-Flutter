import 'package:flutter/material.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import '../models/note_item.dart';

enum NoteFilter { all, pinned, markdown, drawing, mixed }

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key, required this.repository});

  final DocumentRepository repository;

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final TextEditingController _searchController = TextEditingController();
  NoteFilter _selectedFilter = NoteFilter.all;
  bool _isGridView = false;
  String _searchQuery = '';

  final List<NoteItem> _notes = [
    NoteItem(
      id: '1',
      title: 'Sprint Planning & Notes',
      previewText: '# Agenda\n- [x] Discuss architecture\n- [x] Wireframe sketches\n- [ ] Integrate workspace engine',
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      type: NoteType.mixed,
      isPinned: true,
    ),
    NoteItem(
      id: '2',
      title: 'System Architecture',
      previewText: 'Drawing canvas: Flutter + Workspace engine + Local Document Storage',
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      type: NoteType.drawing,
      isPinned: true,
    ),
    NoteItem(
      id: '3',
      title: 'สูตรอาหาร & วัตถุดิบ',
      previewText: '## สปาเก็ตตี้คาโบนาร่า\n- เส้นสปาเก็ตตี้ 200g\n- เบคอนกรอบ 100g\n- ไข่แดง 3 ฟอง\n- ชีสพาร์เมซาน',
      updatedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      type: NoteType.markdown,
      isPinned: false,
    ),
    NoteItem(
      id: '4',
      title: 'ไอเดียฟีเจอร์สำหรับ MNote 2.0',
      previewText: '1. รองรับ Cloud Sync ข้ามอุปกรณ์\n2. ส่งออกเอกสารเป็น PDF / HTML\n3. โหมดโฟกัสแบบ Zen Mode\n4. ตารางคันบัน (Kanban Board)',
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      type: NoteType.markdown,
      isPinned: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NoteItem> get _filteredNotes {
    final filtered = _notes.where((note) {
      final matchesSearch = _searchQuery.isEmpty ||
          note.title.toLowerCase().contains(_searchQuery) ||
          note.previewText.toLowerCase().contains(_searchQuery);

      if (!matchesSearch) return false;

      switch (_selectedFilter) {
        case NoteFilter.all:
          return true;
        case NoteFilter.pinned:
          return note.isPinned;
        case NoteFilter.markdown:
          return note.type == NoteType.markdown;
        case NoteFilter.drawing:
          return note.type == NoteType.drawing;
        case NoteFilter.mixed:
          return note.type == NoteType.mixed;
      }
    }).toList();

    // เรียงให้โน้ตที่ปักหมุด (pinned) ขึ้นก่อน แล้วตามด้วยวันที่แก้ไขล่าสุด
    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return filtered;
  }

  void _openWorkspace() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarkdownWorkspacePage(repository: widget.repository),
      ),
    );
  }

  void _togglePin(NoteItem note) {
    setState(() {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note.copyWith(isPinned: !note.isPinned);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          note.isPinned ? 'ยกเลิกการปักหมุดแล้ว' : 'ปักหมุดโน้ตแล้ว',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteNote(NoteItem note) {
    final deletedIndex = _notes.indexWhere((n) => n.id == note.id);
    if (deletedIndex == -1) return;

    setState(() {
      _notes.removeAt(deletedIndex);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ลบ "${note.title}" แล้ว'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'เลิกทำ',
          onPressed: () {
            setState(() {
              _notes.insert(deletedIndex, note);
            });
          },
        ),
      ),
    );
  }

  IconData _getNoteIcon(NoteType type) {
    switch (type) {
      case NoteType.markdown:
        return Icons.text_snippet_rounded;
      case NoteType.drawing:
        return Icons.draw_rounded;
      case NoteType.mixed:
        return Icons.auto_stories_rounded;
    }
  }

  Color _getNoteColor(BuildContext context, NoteType type) {
    final theme = Theme.of(context);
    switch (type) {
      case NoteType.markdown:
        return theme.colorScheme.primary;
      case NoteType.drawing:
        return Colors.deepPurple;
      case NoteType.mixed:
        return Colors.teal;
    }
  }

  String _getNoteTypeName(NoteType type) {
    switch (type) {
      case NoteType.markdown:
        return 'Markdown';
      case NoteType.drawing:
        return 'Drawing';
      case NoteType.mixed:
        return 'Mixed';
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final hourStr = dt.hour.toString().padLeft(2, '0');

    if (difference.inDays == 0 && now.day == dt.day) {
      return 'วันนี้ $hourStr:$minuteStr น.';
    } else if (difference.inDays <= 1 && now.day - dt.day == 1) {
      return 'เมื่อวาน $hourStr:$minuteStr น.';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = _filteredNotes;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.edit_note_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mnote',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  '${_notes.length} รายการ',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isGridView ? 'สลับเป็นมุมมองรายการ' : 'สลับเป็นมุมมองตาราง',
            icon: Icon(
              _isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'ค้นหาชื่อโน้ตหรือเนื้อหา...',
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search_rounded, size: 22),
              ),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
              ],
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('ทั้งหมด', NoteFilter.all),
                const SizedBox(width: 8),
                _buildFilterChip('⭐ ปักหมุด', NoteFilter.pinned),
                const SizedBox(width: 8),
                _buildFilterChip('📝 Markdown', NoteFilter.markdown),
                const SizedBox(width: 8),
                _buildFilterChip('🎨 Drawing', NoteFilter.drawing),
                const SizedBox(width: 8),
                _buildFilterChip('📚 Mixed', NoteFilter.mixed),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Note List / Grid / Empty State
          Expanded(
            child: notes.isEmpty
                ? _buildEmptyState(context)
                : _isGridView
                    ? _buildGridView(notes)
                    : _buildListView(notes),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWorkspace,
        icon: const Icon(Icons.add_rounded),
        label: const Text('โน้ตใหม่'),
      ),
    );
  }

  Widget _buildFilterChip(String label, NoteFilter filter) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == filter;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
      ),
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (_) {
        setState(() {
          _selectedFilter = filter;
        });
      },
    );
  }

  Widget _buildListView(List<NoteItem> notes) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildNoteCard(note, isGrid: false);
      },
    );
  }

  Widget _buildGridView(List<NoteItem> notes) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildNoteCard(note, isGrid: true);
      },
    );
  }

  Widget _buildNoteCard(NoteItem note, {required bool isGrid}) {
    final theme = Theme.of(context);
    final typeColor = _getNoteColor(context, note.type);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
          width: note.isPinned ? 1.5 : 1,
        ),
      ),
      color: note.isPinned
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
          : theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openWorkspace,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: isGrid
              ? _buildGridCardContent(note, typeColor, theme)
              : _buildListCardContent(note, typeColor, theme),
        ),
      ),
    );
  }

  Widget _buildListCardContent(
    NoteItem note,
    Color typeColor,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getNoteIcon(note.type),
                size: 18,
                color: typeColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getNoteTypeName(note.type),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: typeColor,
                ),
              ),
            ),
            const Spacer(),
            if (note.isPinned)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.push_pin_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            _buildCardMenu(note),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          note.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          note.previewText,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDateTime(note.updatedAt),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridCardContent(
    NoteItem note,
    Color typeColor,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getNoteIcon(note.type),
                size: 16,
                color: typeColor,
              ),
            ),
            Row(
              children: [
                if (note.isPinned)
                  Icon(
                    Icons.push_pin_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                _buildCardMenu(note),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          note.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Text(
            note.previewText,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.fade,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formatDateTime(note.updatedAt),
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCardMenu(NoteItem note) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 20,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        if (value == 'pin') {
          _togglePin(note);
        } else if (value == 'delete') {
          _deleteNote(note);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                note.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(note.isPinned ? 'ยกเลิกการปักหมุด' : 'ปักหมุดไว้บนสุด'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('ลบโน้ต', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = _searchQuery.isNotEmpty || _selectedFilter != NoteFilter.all;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.note_alt_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'ไม่พบโน้ตที่ค้นหา' : 'ยังไม่มีโน้ตใดๆ',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'ลองใช้คำค้นหาอื่น หรือเปลี่ยนตัวกรองหมวดหมู่'
                  : 'กดปุ่ม "+ โน้ตใหม่" ด้านล่างเพื่อเริ่มสร้างเอกสารฉบับแรกของคุณ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (isSearching)
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedFilter = NoteFilter.all;
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('ล้างการค้นหา'),
              )
            else
              FilledButton.icon(
                onPressed: _openWorkspace,
                icon: const Icon(Icons.add_rounded),
                label: const Text('สร้างโน้ตใหม่'),
              ),
          ],
        ),
      ),
    );
  }
}