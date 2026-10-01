import 'package:flutter/material.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import '../models/note_item.dart';

enum ViewFilter { all, starred, foldersOnly, filesOnly, markdownOnly, txtOnly, trash }
enum SortMode { newest, oldest, nameAsc, nameDesc }

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({
    super.key,
    required this.repository,
    this.initialFolders = const [],
    this.initialDocuments = const [],
  });

  final DocumentRepository repository;
  final List<FolderItem> initialFolders;
  final List<DocumentItem> initialDocuments;

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  bool _isGridView = true;
  ViewFilter _filter = ViewFilter.all;
  SortMode _sortMode = SortMode.newest;
  String? _currentFolderId; // null = root directory
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Folders and Documents State (เริ่มเป็นลิสต์ว่าง โหลดไฟล์จริงจากเครื่องหรือจากการสร้างใหม่)
  late final List<FolderItem> _folders;
  late final List<DocumentItem> _documents;

  @override
  void initState() {
    super.initState();
    _folders = List.from(widget.initialFolders);
    _documents = List.from(widget.initialDocuments);
    _loadDeviceDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ดึงไฟล์จากที่เก็บข้อมูลในเครื่องผ่าน repository
  Future<void> _loadDeviceDocuments() async {
    try {
      final docs = await widget.repository.listDocuments();
      if (docs.isNotEmpty) {
        setState(() {
          for (final doc in docs) {
            final exists = _documents.any((d) => d.uri == doc.uri && d.name == doc.name);
            if (!exists) {
              _documents.add(
                DocumentItem(
                  id: 'dev_${DateTime.now().millisecondsSinceEpoch}_${doc.name}',
                  name: doc.name,
                  content: doc.content,
                  updatedAt: DateTime.now(),
                  uri: doc.uri,
                ),
              );
            }
          }
        });
      }
    } catch (_) {
      // หากยังไม่มีไฟล์ในเครื่องหรือระบบไฟล์ยังไม่พร้อม ให้ใช้ไฟล์เริ่มต้น
    }
  }

  // ดึงไฟล์ภายนอกจากเครื่อง (Import / Open from Device)
  Future<void> _importDocumentFromDevice() async {
    try {
      final doc = await widget.repository.open();
      if (doc == null) return;

      final existingIndex = _documents.indexWhere((d) => d.name == doc.name);
      if (existingIndex != -1) {
        setState(() {
          _documents[existingIndex] = _documents[existingIndex].copyWith(
            content: doc.content,
            updatedAt: DateTime.now(),
            uri: doc.uri,
          );
        });
      } else {
        final newDoc = DocumentItem(
          id: 'imp_${DateTime.now().millisecondsSinceEpoch}',
          name: doc.name,
          content: doc.content,
          updatedAt: DateTime.now(),
          folderId: _currentFolderId,
          uri: doc.uri,
        );
        setState(() {
          _documents.insert(0, newDoc);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ดึงไฟล์ "${doc.name}" เข้ามาแล้ว'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการดึงไฟล์: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // สร้างไฟล์ใหม่ (สร้างไฟล์เฉยๆ หรือเปิด Workspace)
  Future<void> _createNewFile({required bool isMarkdown}) async {
    final ext = isMarkdown ? 'md' : 'txt';
    final count = _documents.where((d) => d.extension == ext).length + 1;
    final defaultName = isMarkdown ? 'เอกสาร_$count' : 'ข้อความ_$count';

    final textController = TextEditingController(text: defaultName);

    final fileName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMarkdown ? 'สร้างไฟล์ Markdown ใหม่' : 'สร้างไฟล์ข้อความ (.txt) ใหม่'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'ชื่อไฟล์',
            suffixText: '.$ext',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              var raw = textController.text.trim();
              if (raw.isEmpty) return;
              while (raw.toLowerCase().endsWith('.$ext')) {
                raw = raw.substring(0, raw.length - (ext.length + 1)).trim();
              }
              if (raw.isEmpty) return;
              Navigator.of(ctx).pop('$raw.$ext');
            },
            child: const Text('สร้างไฟล์'),
          ),
        ],
      ),
    );

    if (fileName == null || fileName.isEmpty || !mounted) return;

    final newDoc = DocumentItem(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      name: fileName,
      content: isMarkdown
          ? '# $fileName\n\nเริ่มพิมพ์ข้อความหรือจดโน้ตของคุณที่นี่...'
          : 'บันทึกข้อความ $fileName\n\n',
      updatedAt: DateTime.now(),
      folderId: _currentFolderId,
    );

    setState(() {
      _documents.insert(0, newDoc);
    });

    _openDocument(newDoc);
  }

  // สร้างโฟลเดอร์ใหม่
  Future<void> _createNewFolder() async {
    final textController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('สร้างโฟลเดอร์ใหม่'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่อโฟลเดอร์',
            hintText: 'เช่น วิชาสัมมนา, บันทึกย่อ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop(name);
              }
            },
            child: const Text('สร้าง'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    setState(() {
      _folders.insert(
        0,
        FolderItem(
          id: 'f_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          updatedAt: DateTime.now(),
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('สร้างโฟลเดอร์ "$name" เรียบร้อยแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // เปิดเอกสารใน Workspace Page
  Future<void> _openDocument(DocumentItem item) async {
    if (item.isTrash) {
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.restore_from_trash_rounded, color: Colors.blue),
          title: const Text('เอกสารอยู่ในถังขยะ'),
          content: Text('คุณต้องการกู้คืน "${item.name}" เพื่อเปิดดูหรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('กู้คืนและเปิด'),
            ),
          ],
        ),
      );

      if (shouldRestore == true) {
        _restoreDocument(item);
      } else {
        return;
      }
    }

    if (!mounted) return;

    final doc = MarkdownDocument(
      name: item.name,
      content: item.content,
      savedName: item.name,
      savedContent: item.content,
      uri: item.uri,
    );

    final updatedDoc = await Navigator.of(context).push<MarkdownDocument>(
      MaterialPageRoute(
        builder: (_) => MarkdownWorkspacePage(
          repository: widget.repository,
          initialDocument: doc,
        ),
      ),
    );

    if (updatedDoc != null) {
      setState(() {
        final idx = _documents.indexWhere((d) => d.id == item.id);
        if (idx != -1) {
          _documents[idx] = _documents[idx].copyWith(
            name: updatedDoc.name,
            content: updatedDoc.content,
            updatedAt: DateTime.now(),
            uri: updatedDoc.uri ?? _documents[idx].uri,
          );
        }
      });
    }

    // รีเฟรชรายการหลังปิด editor
    _loadDeviceDocuments();
  }

  void _toggleFolderStar(FolderItem folder) {
    setState(() {
      final index = _folders.indexWhere((f) => f.id == folder.id);
      if (index != -1) {
        _folders[index] = folder.copyWith(isStarred: !folder.isStarred);
      }
    });
  }

  void _toggleDocumentStar(DocumentItem doc) {
    setState(() {
      final index = _documents.indexWhere((d) => d.id == doc.id);
      if (index != -1) {
        _documents[index] = doc.copyWith(isStarred: !doc.isStarred);
      }
    });
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: MnoteApp.themeModeNotifier,
          builder: (context, currentMode, _) {
            final theme = Theme.of(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.settings_rounded, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('การตั้งค่า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'โหมดการแสดงผล (Theme)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 18),
                              label: Text('สว่าง'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded, color: Colors.indigoAccent, size: 18),
                              label: Text('มืด'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_rounded, color: Colors.teal, size: 18),
                              label: Text('ตามระบบ'),
                            ),
                          ],
                          selected: {currentMode},
                          onSelectionChanged: (newSelection) {
                            MnoteApp.themeModeNotifier.value = newSelection.first;
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'MNote v1.0.0 • Local-First Markdown Workspace',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('เสร็จสิ้น'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _moveToTrashFolder(FolderItem folder) {
    setState(() {
      final idx = _folders.indexWhere((f) => f.id == folder.id);
      if (idx != -1) {
        _folders[idx] = folder.copyWith(isTrash: true);
      }
      for (int i = 0; i < _documents.length; i++) {
        if (_documents[i].folderId == folder.id) {
          _documents[i] = _documents[i].copyWith(isTrash: true);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ย้ายโฟลเดอร์ "${folder.name}" ไปยังถังขยะแล้ว'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'เลิกทำ',
          onPressed: () => _restoreFolder(folder),
        ),
      ),
    );
  }

  void _restoreFolder(FolderItem folder) {
    setState(() {
      final idx = _folders.indexWhere((f) => f.id == folder.id);
      if (idx != -1) {
        _folders[idx] = folder.copyWith(isTrash: false);
      }
      for (int i = 0; i < _documents.length; i++) {
        if (_documents[i].folderId == folder.id) {
          _documents[i] = _documents[i].copyWith(isTrash: false);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('กู้คืนโฟลเดอร์ "${folder.name}" เรียบร้อยแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _permanentlyDeleteFolder(FolderItem folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
        title: const Text('ลบโฟลเดอร์ถาวร?'),
        content: Text(
          'คุณต้องการลบโฟลเดอร์ "${folder.name}" และเอกสารภายในทั้งหมดอย่างถาวรหรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบถาวร'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _folders.removeWhere((f) => f.id == folder.id);
      _documents.removeWhere((d) => d.folderId == folder.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ลบโฟลเดอร์ "${folder.name}" ถาวรแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _moveToTrashDocument(DocumentItem doc) {
    setState(() {
      final idx = _documents.indexWhere((d) => d.id == doc.id);
      if (idx != -1) {
        _documents[idx] = doc.copyWith(isTrash: true);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ย้ายไฟล์ "${doc.name}" ไปยังถังขยะแล้ว'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'เลิกทำ',
          onPressed: () => _restoreDocument(doc),
        ),
      ),
    );
  }

  void _restoreDocument(DocumentItem doc) {
    setState(() {
      final idx = _documents.indexWhere((d) => d.id == doc.id);
      if (idx != -1) {
        _documents[idx] = doc.copyWith(isTrash: false);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('กู้คืนไฟล์ "${doc.name}" เรียบร้อยแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _permanentlyDeleteDocument(DocumentItem doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
        title: const Text('ลบไฟล์ถาวร?'),
        content: Text('คุณต้องการลบ "${doc.name}" อย่างถาวรหรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบถาวร'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _documents.removeWhere((d) => d.id == doc.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ลบไฟล์ "${doc.name}" ถาวรแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _emptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
        title: const Text('ล้างถังขยะ?'),
        content: const Text('รายการทั้งหมดในถังขยะจะถูกลบอย่างถาวรและไม่สามารถกู้คืนได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ล้างถังขยะ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      final trashedFolderIds = _folders.where((f) => f.isTrash).map((f) => f.id).toSet();
      _folders.removeWhere((f) => f.isTrash);
      _documents.removeWhere(
        (d) => d.isTrash || (d.folderId != null && trashedFolderIds.contains(d.folderId)),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ล้างถังขยะเรียบร้อยแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleFolderTap(FolderItem folder) async {
    if (folder.isTrash) {
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.restore_from_trash_rounded, color: Colors.blue),
          title: const Text('โฟลเดอร์อยู่ในถังขยะ'),
          content: Text('คุณต้องการกู้คืนโฟลเดอร์ "${folder.name}" หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('กู้คืน'),
            ),
          ],
        ),
      );

      if (shouldRestore == true) {
        _restoreFolder(folder);
      }
      return;
    }

    setState(() {
      _currentFolderId = folder.id;
    });
  }

  String _formatDate(DateTime dt) {
    final mNames = [
      '',
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    final yearThai = dt.year + (dt.year < 2500 ? 543 : 0);
    final min = dt.minute.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    return '${dt.day} ${mNames[dt.month]} $yearThai $hour:$min';
  }

  FolderItem? get _currentFolder {
    if (_currentFolderId == null) return null;
    try {
      return _folders.firstWhere((f) => f.id == _currentFolderId);
    } catch (_) {
      return null;
    }
  }

  // คำนวณจำนวนคอลัมน์แบบ Responsive (Desktop, Tablet, Phone) ให้ระยะห่างกระชับสมส่วน
  int _calculateColumnCount(double width) {
    if (width < 480) return 2; // Phone
    if (width < 740) return 3; // Small Tablet
    if (width < 1020) return 4; // Tablet / Small Desktop
    if (width < 1300) return 5; // Desktop
    return 6; // Large Desktop
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRoot = _currentFolderId == null;
    final isTrashView = _filter == ViewFilter.trash;

    // กรองโฟลเดอร์
    final visibleFolders = _folders.where((f) {
      if (isTrashView) {
        if (!f.isTrash) return false;
      } else {
        if (f.isTrash) return false;
        if (!isRoot) return false;
        if (_filter == ViewFilter.filesOnly ||
            _filter == ViewFilter.markdownOnly ||
            _filter == ViewFilter.txtOnly) {
          return false;
        }
        if (_filter == ViewFilter.starred && !f.isStarred) return false;
      }
      if (_searchQuery.isNotEmpty) {
        return f.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    // กรองเอกสาร
    final visibleDocuments = _documents.where((d) {
      if (isTrashView) {
        if (!d.isTrash) return false;
      } else {
        if (d.isTrash) return false;
        if (d.folderId != _currentFolderId) return false;
        if (_filter == ViewFilter.foldersOnly) return false;
        if (_filter == ViewFilter.starred && !d.isStarred) return false;
        if (_filter == ViewFilter.markdownOnly && !d.isMarkdown) return false;
        if (_filter == ViewFilter.txtOnly && !d.isTxt) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return d.name.toLowerCase().contains(q) ||
            d.content.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    void sortFolders(List<FolderItem> list) {
      switch (_sortMode) {
        case SortMode.newest:
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        case SortMode.oldest:
          list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        case SortMode.nameAsc:
          list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        case SortMode.nameDesc:
          list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      }
    }

    void sortDocs(List<DocumentItem> list) {
      switch (_sortMode) {
        case SortMode.newest:
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        case SortMode.oldest:
          list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        case SortMode.nameAsc:
          list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        case SortMode.nameDesc:
          list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      }
    }

    sortFolders(visibleFolders);
    sortDocs(visibleDocuments);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: (!isRoot || isTrashView)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                  setState(() {
                    _currentFolderId = null;
                    if (isTrashView) {
                      _filter = ViewFilter.all;
                    }
                  });
                },
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหาไฟล์หรือโฟลเดอร์...',
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              )
            : Text(
                isTrashView
                    ? 'ถังขยะ'
                    : (isRoot ? 'เอกสาร' : _currentFolder?.name ?? 'โฟลเดอร์'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'ปิดการค้นหา' : 'ค้นหา',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'การตั้งค่า (Settings)',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _calculateColumnCount(constraints.maxWidth);

          return Column(
            children: [
              // Toolbar: Filter & Actions Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: constraints.maxWidth < 420
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterMenu(theme),
                            const SizedBox(width: 8),
                            _buildSortMenu(),
                            const SizedBox(width: 4),
                            if (isTrashView)
                              _buildEmptyTrashButton(context)
                            else
                              _buildNewButton(context),
                            const SizedBox(width: 4),
                            _buildViewModeButton(),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          _buildFilterMenu(theme),
                          const Spacer(),
                          _buildSortMenu(),
                          const SizedBox(width: 4),
                          if (isTrashView)
                            _buildEmptyTrashButton(context)
                          else
                            _buildNewButton(context),
                          const SizedBox(width: 8),
                          _buildViewModeButton(),
                        ],
                      ),
              ),

              const Divider(height: 1),

              // Main Content Grid / List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadDeviceDocuments,
                  child: visibleFolders.isEmpty && visibleDocuments.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: _buildEmptyState(context),
                            ),
                          ),
                        )
                      : (_isGridView
                          ? _buildGridView(visibleFolders, visibleDocuments, columns)
                          : _buildListView(visibleFolders, visibleDocuments)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ปุ่มล้างถังขยะ
  Widget _buildEmptyTrashButton(BuildContext context) {
    final hasTrash = _folders.any((f) => f.isTrash) || _documents.any((d) => d.isTrash);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
      onPressed: hasTrash ? _emptyTrash : null,
      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
      label: const Text(
        'ล้างถังขยะ',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  // เมนูตัวกรอง
  Widget _buildFilterMenu(ThemeData theme) {
    final trashCount = _folders.where((f) => f.isTrash).length +
        _documents.where((d) => d.isTrash).length;
    final isTrash = _filter == ViewFilter.trash;

    return PopupMenuButton<ViewFilter>(
      initialValue: _filter,
      onSelected: (val) {
        setState(() {
          _filter = val;
          if (val == ViewFilter.trash) {
            _currentFolderId = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isTrash
              ? Colors.red.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTrash ? Icons.delete_outline_rounded : Icons.menu_rounded,
              size: 18,
              color: isTrash ? Colors.red : null,
            ),
            const SizedBox(width: 6),
            Text(
              _getFilterLabel(_filter),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isTrash ? Colors.red : null,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: isTrash ? Colors.red : null,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: ViewFilter.all,
          child: Text('ทั้งหมด'),
        ),
        const PopupMenuItem(
          value: ViewFilter.starred,
          child: Text('⭐ ติดดาว (รายการโปรด)'),
        ),
        const PopupMenuItem(
          value: ViewFilter.foldersOnly,
          child: Text('📁 เฉพาะโฟลเดอร์'),
        ),
        const PopupMenuItem(
          value: ViewFilter.filesOnly,
          child: Text('📄 ไฟล์ทั้งหมด (.md, .txt)'),
        ),
        const PopupMenuItem(
          value: ViewFilter.markdownOnly,
          child: Text('📝 เฉพาะ Markdown (.md)'),
        ),
        const PopupMenuItem(
          value: ViewFilter.txtOnly,
          child: Text('📋 เฉพาะ Text (.txt)'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: ViewFilter.trash,
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              const Text('ถังขยะ', style: TextStyle(color: Colors.red)),
              if (trashCount > 0) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$trashCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ปุ่มจัดเรียง (Sort)
  Widget _buildSortMenu() {
    return PopupMenuButton<SortMode>(
      initialValue: _sortMode,
      tooltip: 'จัดเรียงตาม',
      icon: const Icon(Icons.sort_rounded, size: 20),
      onSelected: (mode) {
        setState(() {
          _sortMode = mode;
        });
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: SortMode.newest,
          child: Row(
            children: [
              Icon(Icons.access_time_rounded, size: 18),
              SizedBox(width: 8),
              Text('ล่าสุด (วันที่แก้ไข)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: SortMode.oldest,
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 18),
              SizedBox(width: 8),
              Text('เก่าสุด (วันที่แก้ไข)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: SortMode.nameAsc,
          child: Row(
            children: [
              Icon(Icons.arrow_downward_rounded, size: 18),
              SizedBox(width: 8),
              Text('ชื่อ (ก - ฮ / A - Z)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: SortMode.nameDesc,
          child: Row(
            children: [
              Icon(Icons.arrow_upward_rounded, size: 18),
              SizedBox(width: 8),
              Text('ชื่อ (ฮ - ก / Z - A)'),
            ],
          ),
        ),
      ],
    );
  }

  // ปุ่มสลับมุมมอง Grid / List
  Widget _buildViewModeButton() {
    return IconButton(
      icon: Icon(
        _isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
      ),
      tooltip: _isGridView ? 'มุมมองรายการ' : 'มุมมองตาราง',
      onPressed: () {
        setState(() {
          _isGridView = !_isGridView;
        });
      },
    );
  }

  // ปุ่มสร้างใหม่ (+ ใหม่)
  Widget _buildNewButton(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      tooltip: 'สร้างใหม่หรือดึงไฟล์',
      onSelected: (action) {
        if (action == 'new_md') {
          _createNewFile(isMarkdown: true);
        } else if (action == 'new_txt') {
          _createNewFile(isMarkdown: false);
        } else if (action == 'new_folder') {
          _createNewFolder();
        } else if (action == 'import') {
          _importDocumentFromDevice();
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'new_md',
          child: Row(
            children: [
              Icon(Icons.description_outlined, color: Colors.blue),
              SizedBox(width: 10),
              Text('เอกสาร Markdown ใหม่ (.md)'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'new_txt',
          child: Row(
            children: [
              Icon(Icons.text_snippet_outlined, color: Colors.teal),
              SizedBox(width: 10),
              Text('ไฟล์ข้อความใหม่ (.txt)'),
            ],
          ),
        ),
        if (_currentFolderId == null)
          const PopupMenuItem(
            value: 'new_folder',
            child: Row(
              children: [
                Icon(Icons.create_new_folder_outlined, color: Colors.amber),
                SizedBox(width: 10),
                Text('โฟลเดอร์ใหม่'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.file_open_outlined, color: Colors.orange),
              SizedBox(width: 10),
              Text('ดึงไฟล์จากเครื่อง (Import)'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_rounded,
              color: theme.colorScheme.onPrimary,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              'ใหม่',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Grid View ที่ปรับคอลัมน์อัตโนมัติ (Responsive)
  Widget _buildGridView(
    List<FolderItem> folders,
    List<DocumentItem> documents,
    int columns,
  ) {
    final totalItems = folders.length + documents.length;

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.86,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          return _buildFolderGridCard(folder);
        } else {
          final doc = documents[index - folders.length];
          return _buildDocumentGridCard(doc);
        }
      },
    );
  }

  // การ์ดโฟลเดอร์ใน Grid View (ขนาดเท่ากับเอกสาร MD/TXT สมมาตร มีกรอบ สัดส่วน และเงาสวยงาม)
  Widget _buildFolderGridCard(FolderItem folder) {
    final theme = Theme.of(context);
    final count = _documents.where((d) => d.folderId == folder.id && !d.isTrash).length;
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _handleFolderTap(folder),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // ป้ายระบุประเภทและจำนวนไฟล์ในโฟลเดอร์
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$count ไฟล์',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ),
                      // ไอคอนโฟลเดอร์ตรงกลาง ขนาดสมดุลพอดีกับตัวการ์ด
                      Center(
                        child: Icon(
                          Icons.folder_rounded,
                          size: 52,
                          color: primary,
                        ),
                      ),
                      // ปุ่มติดดาว (⭐ รายการโปรด)
                      if (!folder.isTrash)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: IconButton(
                            iconSize: 20,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              folder.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: folder.isStarred
                                  ? Colors.amberAccent
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            onPressed: () => _toggleFolderStar(folder),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleFolderTap(folder),
                      child: Text(
                        folder.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    onSelected: (val) {
                      if (val == 'open') _handleFolderTap(folder);
                      if (val == 'trash') _moveToTrashFolder(folder);
                      if (val == 'restore') _restoreFolder(folder);
                      if (val == 'delete_perm') _permanentlyDeleteFolder(folder);
                    },
                    itemBuilder: (ctx) => folder.isTrash
                        ? const [
                            PopupMenuItem(
                              value: 'restore',
                              child: Row(
                                children: [
                                  Icon(Icons.restore_from_trash_rounded, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('กู้คืน'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete_perm',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ลบถาวร', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ]
                        : const [
                            PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('เปิดโฟลเดอร์'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'trash',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ย้ายไปถังขยะ', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'โฟลเดอร์ • ${_formatDate(folder.updatedAt)}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // การ์ดเอกสารใน Grid View (รูปทรงกระดาษ/สมุดโน้ต Preview มีสัดส่วนสมดุลกับโฟลเดอร์)
  Widget _buildDocumentGridCard(DocumentItem doc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTxt = doc.isTxt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openDocument(doc),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // พรีวิวเนื้อหาของเอกสาร
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isTxt ? Colors.teal : Colors.blue).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isTxt ? 'TXT' : 'MD',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isTxt ? Colors.teal : Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              doc.content,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                              ),
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: IconButton(
                          iconSize: 20,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            doc.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: doc.isStarred ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () => _toggleDocumentStar(doc),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openDocument(doc),
                      child: Text(
                        doc.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    onSelected: (val) {
                      if (val == 'open') _openDocument(doc);
                      if (val == 'trash') _moveToTrashDocument(doc);
                      if (val == 'restore') _restoreDocument(doc);
                      if (val == 'delete_perm') _permanentlyDeleteDocument(doc);
                    },
                    itemBuilder: (ctx) => doc.isTrash
                        ? const [
                            PopupMenuItem(
                              value: 'restore',
                              child: Row(
                                children: [
                                  Icon(Icons.restore_from_trash_rounded, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('กู้คืน'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete_perm',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ลบถาวร', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ]
                        : const [
                            PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('เปิดเอกสาร'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'trash',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ย้ายไปถังขยะ', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${isTxt ? "ข้อความ TXT" : "Markdown"} • ${_formatDate(doc.updatedAt)}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // List View ทางเลือก
  Widget _buildListView(List<FolderItem> folders, List<DocumentItem> documents) {
    final theme = Theme.of(context);
    final isTrashView = _filter == ViewFilter.trash;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (folders.isNotEmpty) ...[
          for (final folder in folders)
            ListTile(
              leading: Icon(Icons.folder_rounded, color: theme.colorScheme.primary, size: 36),
              title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${_documents.where((d) => d.folderId == folder.id && !d.isTrash).length} ไฟล์ • ${_formatDate(folder.updatedAt)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isTrashView)
                    IconButton(
                      icon: Icon(
                        folder.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: folder.isStarred ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () => _toggleFolderStar(folder),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (val) {
                      if (val == 'open') _handleFolderTap(folder);
                      if (val == 'trash') _moveToTrashFolder(folder);
                      if (val == 'restore') _restoreFolder(folder);
                      if (val == 'delete_perm') _permanentlyDeleteFolder(folder);
                    },
                    itemBuilder: (ctx) => folder.isTrash
                        ? const [
                            PopupMenuItem(
                              value: 'restore',
                              child: Row(
                                children: [
                                  Icon(Icons.restore_from_trash_rounded, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('กู้คืน'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete_perm',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ลบถาวร', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ]
                        : const [
                            PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('เปิดโฟลเดอร์'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'trash',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ย้ายไปถังขยะ', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                  ),
                ],
              ),
              onTap: () => _handleFolderTap(folder),
            ),
        ],
        if (documents.isNotEmpty) ...[
          for (final doc in documents)
            ListTile(
              leading: Icon(
                doc.isTxt ? Icons.text_snippet_rounded : Icons.description_rounded,
                color: doc.isTxt ? Colors.teal : Colors.blue,
                size: 32,
              ),
              title: Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${doc.isTxt ? "ข้อความ TXT" : "Markdown"} • ${_formatDate(doc.updatedAt)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isTrashView)
                    IconButton(
                      icon: Icon(
                        doc.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: doc.isStarred ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () => _toggleDocumentStar(doc),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (val) {
                      if (val == 'open') _openDocument(doc);
                      if (val == 'trash') _moveToTrashDocument(doc);
                      if (val == 'restore') _restoreDocument(doc);
                      if (val == 'delete_perm') _permanentlyDeleteDocument(doc);
                    },
                    itemBuilder: (ctx) => doc.isTrash
                        ? const [
                            PopupMenuItem(
                              value: 'restore',
                              child: Row(
                                children: [
                                  Icon(Icons.restore_from_trash_rounded, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('กู้คืน'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete_perm',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ลบถาวร', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ]
                        : const [
                            PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('เปิดเอกสาร'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'trash',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('ย้ายไปถังขยะ', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                  ),
                ],
              ),
              onTap: () => _openDocument(doc),
            ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isTrashView = _filter == ViewFilter.trash;

    if (isTrashView) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'ถังขยะว่างเปล่า',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'ไม่มีไฟล์หรือโฟลเดอร์ในถังขยะ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'ยังไม่มีไฟล์หรือโฟลเดอร์',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'กดปุ่ม "+ ใหม่" ด้านบน เพื่อสร้างไฟล์ Markdown, ไฟล์ TXT หรือโฟลเดอร์',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterLabel(ViewFilter filter) {
    switch (filter) {
      case ViewFilter.all:
        return 'ทั้งหมด';
      case ViewFilter.starred:
        return 'ติดดาว ⭐';
      case ViewFilter.foldersOnly:
        return 'โฟลเดอร์';
      case ViewFilter.filesOnly:
        return 'ไฟล์ทั้งหมด';
      case ViewFilter.markdownOnly:
        return 'Markdown (.md)';
      case ViewFilter.txtOnly:
        return 'Text (.txt)';
      case ViewFilter.trash:
        return 'ถังขยะ 🗑️';
    }
  }
}