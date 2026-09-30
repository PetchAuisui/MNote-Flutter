import 'package:flutter/material.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import '../models/note_item.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key, required this.repository});

  final DocumentRepository repository;

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final List<NoteItem> _notes = [
    NoteItem(
      id: '1',
      title: 'Sprint Planning & Notes',
      previewText: '# Agenda\n- Discuss architecture\n- Wireframe sketches',
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      type: NoteType.mixed,
    ),
    NoteItem(
      id: '2',
      title: 'System Architecture',
      previewText: 'Drawing canvas: Flutter + Workspace engine',
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      type: NoteType.drawing,
    ),
  ];

  void _openWorkspace() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarkdownWorkspacePage(repository: widget.repository),
      ),
    );
  }

  IconData _getNoteIcon(NoteType type) {
    switch (type) {
      case NoteType.markdown:
        return Icons.text_snippet_outlined;
      case NoteType.drawing:
        return Icons.draw_outlined;
      case NoteType.mixed:
        return Icons.auto_stories_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mnote'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: _notes.isEmpty
          ? const Center(
              child: Text(
                'ยังไม่มีโน้ต\nกดปุ่ม + ด้านล่างเพื่อเริ่มสร้าง',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        _getNoteIcon(note.type),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          note.previewText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'แก้ไขล่าสุด: ${note.updatedAt.hour}:${note.updatedAt.minute.toString().padLeft(2, '0')} น.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    onTap: _openWorkspace,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWorkspace,
        icon: const Icon(Icons.add),
        label: const Text('โน้ตใหม่'),
      ),
    );
  }
}