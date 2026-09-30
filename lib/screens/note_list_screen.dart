import 'package:flutter/material.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import '../models/note_item.dart';

enum ViewFilter { all, starred, foldersOnly, filesOnly, markdownOnly, txtOnly }

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key, required this.repository});

  final DocumentRepository repository;

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  bool _isGridView = true;
  ViewFilter _filter = ViewFilter.all;
  String? _currentFolderId; // null = root directory
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Folders State
  final List<FolderItem> _folders = [
    FolderItem(
      id: 'f1',
      name: 'ใบประกอบวิชาชีพครู',
      updatedAt: DateTime(2026, 9, 20, 13, 34),
      isStarred: false,
    ),
    FolderItem(
      id: 'f2',
      name: 'ปี 1',
      updatedAt: DateTime(2026, 7, 1, 8, 27),
      isStarred: true,
    ),
    FolderItem(
      id: 'f3',
      name: 'ปี 2',
      updatedAt: DateTime(2026, 7, 3, 14, 2),
      isStarred: false,
    ),
    FolderItem(
      id: 'f4',
      name: 'ปี 3',
      updatedAt: DateTime(2026, 6, 29, 8, 39),
      isStarred: true,
    ),
    FolderItem(
      id: 'f5',
      name: 'ฝึกงาน',
      updatedAt: DateTime(2026, 6, 6, 20, 17),
      isStarred: false,
    ),
    FolderItem(
      id: 'f6',
      name: 'มัธยม',
      updatedAt: DateTime(2026, 7, 1, 9, 5),
      isStarred: false,
    ),
    FolderItem(
      id: 'f7',
      name: 'สสวท',
      updatedAt: DateTime(2026, 5, 22, 18, 25),
      isStarred: true,
    ),
    FolderItem(
      id: 'f8',
      name: 'Final Project',
      updatedAt: DateTime(2026, 3, 18, 15, 11),
      isStarred: false,
    ),
  ];

  // Documents State (supports .md and .txt)
  final List<DocumentItem> _documents = [
    DocumentItem(
      id: 'd1',
      name: '2569-01-CT05-report02.md',
      content: '# รายงานผลการดำเนินงาน\n\n- ตรวจสอบระบบเอกสาร\n- ออกแบบหน้าจอรวมไฟล์\n- ทดสอบการทำงานร่วมกับปากกา\n\nสถานะ: ดำเนินการเสร็จสมบูรณ์',
      updatedAt: DateTime(2026, 8, 14, 11, 43),
      isStarred: false,
    ),
    DocumentItem(
      id: 'd2',
      name: '2569-01-CT05-report03.txt',
      content: 'ตารางบันทึกประจำวัน:\n- 09:00 ประชุมวางแผนงาน\n- 11:30 ตรวจสอบโค้ดระบบดึงไฟล์และโฟลเดอร์\n- 14:00 ปรับแต่งการแสดงผล Responsive สำหรับ Desktop/Tablet/Phone\n- 16:30 สรุปผลการทดสอบ',
      updatedAt: DateTime(2026, 9, 23, 14, 41),
      isStarred: true,
    ),
    DocumentItem(
      id: 'd3',
      name: 'แบบร่างความคิด.md',
      content: '## ไอเดียการทำงาน\n\nใช้ Flutter Workspace Engine ร่วมกับการวาดเขียนด้วยปากกา\n1. รองรับลายมือและการวาดรูป\n2. เขียน Markdown ควบคู่กันได้\n3. จัดหมวดหมู่ไฟล์เป็นระเบียบ',
      updatedAt: DateTime(2026, 9, 28, 10, 15),
      folderId: 'f2',
      isStarred: false,
    ),
    DocumentItem(
      id: 'd4',
      name: 'บันทึกสั้น_To_Do.txt',
      content: '- ส่งแบบคำขอใบประกอบวิชาชีพ\n- แนบเอกสารหลักสูตร\n- ติดต่อฝ่ายทะเบียน',
      updatedAt: DateTime(2026, 9, 15, 16, 20),
      folderId: 'f1',
      isStarred: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
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
    final defaultName = isMarkdown ? 'เอกสาร_$count.md' : 'ข้อความ_$count.txt';

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
              final raw = textController.text.trim();
              if (raw.isEmpty) return;
              final fileName = raw.endsWith('.$ext') ? raw : '$raw.$ext';
              Navigator.of(ctx).pop(fileName);
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

  void _deleteFolder(FolderItem folder) {
    setState(() {
      _folders.removeWhere((f) => f.id == folder.id);
      // ย้ายเอกสารในโฟลเดอร์ออกมาหน้าหลัก
      for (int i = 0; i < _documents.length; i++) {
        if (_documents[i].folderId == folder.id) {
          _documents[i] = _documents[i].copyWith(folderId: null);
        }
      }
    });
  }

  void _deleteDocument(DocumentItem doc) {
    setState(() {
      _documents.removeWhere((d) => d.id == doc.id);
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

  // คำนวณจำนวนคอลัมน์แบบ Responsive (Desktop, Tablet, Phone)
  int _calculateColumnCount(double width) {
    if (width < 600) return 2; // Phone
    if (width < 900) return 3; // Small Tablet
    if (width < 1200) return 4; // iPad / Tablet Horizontal
    return 6; // Desktop
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRoot = _currentFolderId == null;

    // กรองโฟลเดอร์ (แสดงเฉพาะหน้าแรก root)
    final visibleFolders = _folders.where((f) {
      if (!isRoot) return false;
      if (_filter == ViewFilter.filesOnly ||
          _filter == ViewFilter.markdownOnly ||
          _filter == ViewFilter.txtOnly) {
        return false;
      }
      if (_filter == ViewFilter.starred && !f.isStarred) return false;
      if (_searchQuery.isNotEmpty) {
        return f.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    // กรองเอกสาร
    final visibleDocuments = _documents.where((d) {
      // ตรวจสอบว่าอยู่ในโฟลเดอร์ปัจจุบันหรือไม่
      if (d.folderId != _currentFolderId) return false;

      if (_filter == ViewFilter.foldersOnly) return false;
      if (_filter == ViewFilter.starred && !d.isStarred) return false;
      if (_filter == ViewFilter.markdownOnly && !d.isMarkdown) return false;
      if (_filter == ViewFilter.txtOnly && !d.isTxt) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return d.name.toLowerCase().contains(q) ||
            d.content.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: isRoot
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                  setState(() {
                    _currentFolderId = null;
                  });
                },
              ),
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
            : Row(
                children: [
                  Text(
                    isRoot ? 'เอกสาร' : _currentFolder?.name ?? 'โฟลเดอร์',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: 'ดึงข้อมูลไฟล์ล่าสุด (Refresh)',
            onPressed: _loadDeviceDocuments,
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
                child: Row(
                  children: [
                    // ตัวเลือกตัวกรอง (☰ ทั้งหมด)
                    PopupMenuButton<ViewFilter>(
                      initialValue: _filter,
                      onSelected: (val) {
                        setState(() {
                          _filter = val;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_rounded, size: 18),
                            if (constraints.maxWidth > 340) ...[
                              const SizedBox(width: 4),
                              Text(
                                _getFilterLabel(_filter),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const Icon(Icons.arrow_drop_down_rounded, size: 18),
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
                      ],
                    ),

                    const Spacer(),

                    // ปุ่ม "+ ใหม่" สไตล์ Pill Button สีเด่น
                    _buildNewButton(context),

                    const SizedBox(width: 8),

                    // ปุ่มสลับมุมมอง Grid / List
                    IconButton(
                      icon: Icon(
                        _isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                      ),
                      tooltip: _isGridView ? 'มุมมองรายการ' : 'มุมมองตาราง',
                      onPressed: () {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Main Content Grid / List
              Expanded(
                child: visibleFolders.isEmpty && visibleDocuments.isEmpty
                    ? _buildEmptyState(context)
                    : _isGridView
                        ? _buildGridView(visibleFolders, visibleDocuments, columns)
                        : _buildListView(visibleFolders, visibleDocuments),
              ),
            ],
          );
        },
      ),
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
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.82,
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

  // การ์ดโฟลเดอร์ใน Grid View
  Widget _buildFolderGridCard(FolderItem folder) {
    final theme = Theme.of(context);
    final count = _documents.where((d) => d.folderId == folder.id).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1.15,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _currentFolderId = folder.id;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              size: 64,
                              color: theme.colorScheme.primary.withValues(alpha: 0.85),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count ไฟล์',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton(
                          iconSize: 20,
                          icon: Icon(
                            folder.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: folder.isStarred ? Colors.amber : Colors.grey,
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
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentFolderId = folder.id;
                  });
                },
                child: Text(
                  folder.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            PopupMenuButton<String>(
              iconSize: 16,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              onSelected: (val) {
                if (val == 'delete') _deleteFolder(folder);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('ลบโฟลเดอร์', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        Text(
          _formatDate(folder.updatedAt),
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // การ์ดเอกสารใน Grid View (รูปทรงกระดาษ/สมุดโน้ต Preview)
  Widget _buildDocumentGridCard(DocumentItem doc) {
    final theme = Theme.of(context);
    final isTxt = doc.isTxt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 0.82,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openDocument(doc),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
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
                                fontSize: 9,
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
                                fontSize: 10,
                                height: 1.3,
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
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
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
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            PopupMenuButton<String>(
              iconSize: 16,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              onSelected: (val) {
                if (val == 'open') _openDocument(doc);
                if (val == 'delete') _deleteDocument(doc);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'open',
                  child: Text('เปิดเอกสาร'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('ลบไฟล์', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        Text(
          _formatDate(doc.updatedAt),
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // List View ทางเลือก
  Widget _buildListView(List<FolderItem> folders, List<DocumentItem> documents) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (folders.isNotEmpty) ...[
          for (final folder in folders)
            ListTile(
              leading: const Icon(Icons.folder_rounded, color: Colors.amber, size: 36),
              title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_formatDate(folder.updatedAt)),
              trailing: IconButton(
                icon: Icon(
                  folder.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: folder.isStarred ? Colors.amber : Colors.grey,
                ),
                onPressed: () => _toggleFolderStar(folder),
              ),
              onTap: () {
                setState(() {
                  _currentFolderId = folder.id;
                });
              },
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
              trailing: IconButton(
                icon: Icon(
                  doc.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: doc.isStarred ? Colors.amber : Colors.grey,
                ),
                onPressed: () => _toggleDocumentStar(doc),
              ),
              onTap: () => _openDocument(doc),
            ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

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
    }
  }
}