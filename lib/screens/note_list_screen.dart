import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/export_sheet.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/screens/widgets/note_list_settings_dialog.dart';
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
  final SortMode _sortMode = SortMode.newest;
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

  Future<void> _persistLibrary() async {
    try {
      await widget.repository.saveMetadata(
        LibraryMetadata(
          folders: _folders,
          documents: _documents,
        ),
      );
    } catch (_) {}
  }

  // ดึงไฟล์จากที่เก็บข้อมูลในเครื่องและโหลด persistent metadata index
  Future<void> _loadDeviceDocuments() async {
    try {
      final savedMetadata = await widget.repository.loadMetadata();
      if (savedMetadata != null) {
        setState(() {
          for (final folder in savedMetadata.folders) {
            if (!_folders.any((f) => f.id == folder.id)) {
              _folders.add(folder);
            }
          }
          for (final doc in savedMetadata.documents) {
            final exists = _documents.any(
              (d) => d.id == doc.id || (doc.uri != null && d.uri == doc.uri),
            );
            if (!exists) {
              _documents.add(doc);
            }
          }
        });
      }

      final docs = await widget.repository.listDocuments();
      if (docs.isNotEmpty) {
        setState(() {
          for (final doc in docs) {
            final existingIndex = _documents.indexWhere(
              (d) => doc.uri != null && d.uri == doc.uri,
            );
            if (existingIndex != -1) {
              if (_documents[existingIndex].content != doc.content ||
                  _documents[existingIndex].name != doc.name) {
                _documents[existingIndex] = _documents[existingIndex].copyWith(
                  content: doc.content,
                  name: doc.name,
                );
              }
            } else {
              _documents.add(
                DocumentItem(
                  id: 'dev_${doc.uri.toString().hashCode.abs()}_${doc.name}',
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

      // หากเป็นการเปิดแอปครั้งแรก (ยังไม่มี metadata และไม่มีไฟล์ใดๆ)
      // ให้โหลด welcome.md เป็นไฟล์เริ่มต้นในคลังเอกสาร
      if (savedMetadata == null && docs.isEmpty && _documents.isEmpty) {
        try {
          final welcomeContent = await rootBundle.loadString('assets/examples/welcome.md');
          if (mounted && _documents.isEmpty) {
            setState(() {
              _documents.add(
                DocumentItem(
                  id: 'welcome_initial_doc',
                  name: 'Welcome.md',
                  content: welcomeContent,
                  updatedAt: DateTime.now(),
                ),
              );
            });
          }
        } catch (_) {}
      }

      await _persistLibrary();
    } catch (_) {
      // หากยังไม่มีไฟล์ในเครื่องหรือระบบไฟล์ยังไม่พร้อม ให้ใช้ไฟล์เริ่มต้น
    }
  }

  // ดึงไฟล์ภายนอกจากเครื่อง (Import / Open from Device) โดยระบุ identity จาก URI
  Future<void> _importDocumentFromDevice() async {
    try {
      final doc = await widget.repository.open();
      if (doc == null) return;

      final existingIndex = _documents.indexWhere(
        (d) => doc.uri != null && d.uri == doc.uri,
      );
      if (existingIndex != -1) {
        setState(() {
          _documents[existingIndex] = _documents[existingIndex].copyWith(
            name: doc.name,
            content: doc.content,
            updatedAt: DateTime.now(),
            uri: doc.uri,
          );
        });
      } else {
        final newDoc = DocumentItem(
          id: 'imp_${doc.uri?.toString().hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch}',
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

      await _persistLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('ดึงไฟล์ "${doc.name}" เข้ามาแล้ว'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาดในการดึงไฟล์: $e'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
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

    await _persistLibrary();

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

    await _persistLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('สร้างโฟลเดอร์ "$name" เรียบร้อยแล้ว'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    }
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

    String currentContent = item.content;
    if (item.uri != null) {
      final fresh = await widget.repository.readDocument(item.uri!);
      if (fresh != null) {
        currentContent = fresh;
      }
    }

    if (!mounted) return;

    final doc = MarkdownDocument(
      name: item.name,
      content: currentContent,
      savedName: item.name,
      savedContent: currentContent,
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
        final isDifferentUri = item.uri != null &&
            updatedDoc.uri != null &&
            updatedDoc.uri != item.uri;
        if (isDifferentUri) {
          final newDoc = DocumentItem(
            id: 'doc_${updatedDoc.uri.toString().hashCode.abs()}',
            name: updatedDoc.name,
            content: updatedDoc.content,
            updatedAt: DateTime.now(),
            folderId: item.folderId,
            uri: updatedDoc.uri,
          );
          _documents.insert(0, newDoc);
        } else if (idx != -1) {
          _documents[idx] = _documents[idx].copyWith(
            name: updatedDoc.name,
            content: updatedDoc.content,
            updatedAt: DateTime.now(),
            uri: updatedDoc.uri ?? _documents[idx].uri,
          );
        }
      });
      await _persistLibrary();
    }

    // รีเฟรชรายการหลังปิด editor
    await _loadDeviceDocuments();
  }

  void _toggleFolderStar(FolderItem folder) {
    setState(() {
      final index = _folders.indexWhere((f) => f.id == folder.id);
      if (index != -1) {
        _folders[index] = folder.copyWith(isStarred: !folder.isStarred);
      }
    });
    _persistLibrary();
  }

  void _toggleDocumentStar(DocumentItem doc) {
    setState(() {
      final index = _documents.indexWhere((d) => d.id == doc.id);
      if (index != -1) {
        _documents[index] = doc.copyWith(isStarred: !doc.isStarred);
      }
    });
    _persistLibrary();
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => const NoteListSettingsDialog(),
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

    _persistLibrary();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('ย้ายโฟลเดอร์ "${folder.name}" ไปยังถังขยะแล้ว'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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

    _persistLibrary();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('กู้คืนโฟลเดอร์ "${folder.name}" เรียบร้อยแล้ว'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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

    final childDocs = _documents.where((d) => d.folderId == folder.id).toList();
    for (final doc in childDocs) {
      if (doc.uri != null) {
        try {
          await widget.repository.delete(doc.uri!);
        } catch (_) {}
      }
    }

    setState(() {
      _folders.removeWhere((f) => f.id == folder.id);
      _documents.removeWhere((d) => d.folderId == folder.id);
    });

    await _persistLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('ลบโฟลเดอร์ "${folder.name}" ถาวรแล้ว'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _renameDocument(DocumentItem doc) async {
    final controller = TextEditingController(text: doc.displayName);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เปลี่ยนชื่อเอกสาร'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('rename-document-input'),
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'ชื่อเอกสาร',
              hintText: 'กรอกชื่อเอกสารใหม่',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'กรุณาระบุชื่อเอกสาร';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            key: const Key('rename-document-submit'),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == doc.displayName || !mounted) {
      return;
    }

    final ext = doc.name.contains('.')
        ? '.${doc.name.split('.').last}'
        : (doc.isTxt ? '.txt' : '.md');
    final newFileName = newName.endsWith(ext) ? newName : '$newName$ext';

    Uri? newUri = doc.uri;
    if (doc.uri != null && doc.uri!.scheme == 'file') {
      try {
        final oldFile = File.fromUri(doc.uri!);
        if (await oldFile.exists()) {
          final newPath = '${oldFile.parent.path}/$newFileName';
          final newFile = await oldFile.rename(newPath);
          newUri = newFile.uri;
        }
      } catch (_) {}
    }

    setState(() {
      final idx = _documents.indexWhere((d) => d.id == doc.id);
      if (idx != -1) {
        _documents[idx] = doc.copyWith(
          name: newFileName,
          uri: newUri,
          updatedAt: DateTime.now(),
        );
      }
    });

    await _persistLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('เปลี่ยนชื่อเอกสารเป็น "$newName" แล้ว'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _renameFolder(FolderItem folder) async {
    final controller = TextEditingController(text: folder.name);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เปลี่ยนชื่อโฟลเดอร์'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('rename-folder-input'),
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'ชื่อโฟลเดอร์',
              hintText: 'กรอกชื่อโฟลเดอร์ใหม่',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'กรุณาระบุชื่อโฟลเดอร์';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            key: const Key('rename-folder-submit'),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == folder.name || !mounted) {
      return;
    }

    setState(() {
      final idx = _folders.indexWhere((f) => f.id == folder.id);
      if (idx != -1) {
        _folders[idx] = folder.copyWith(
          name: newName,
          updatedAt: DateTime.now(),
        );
      }
    });

    await _persistLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('เปลี่ยนชื่อโฟลเดอร์เป็น "$newName" แล้ว'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _exportDocument(DocumentItem doc) async {
    var content = doc.content;
    final uri = doc.uri;
    if (content.isEmpty && uri != null) {
      try {
        final fresh = await widget.repository.readDocument(uri);
        if (fresh != null) content = fresh;
      } catch (_) {}
    }

    final mdDoc = uri != null
        ? MarkdownDocument.opened(
            name: doc.name,
            content: content,
            uri: uri,
          )
        : MarkdownDocument(
            name: doc.name,
            content: content,
            savedName: doc.name,
            savedContent: content,
          );

    if (!mounted) return;

    await showExportBottomSheet(
      context,
      document: mdDoc,
    );
  }

  void _moveToTrashDocument(DocumentItem doc) {
    setState(() {
      final idx = _documents.indexWhere((d) => d.id == doc.id);
      if (idx != -1) {
        _documents[idx] = doc.copyWith(isTrash: true);
      }
    });

    _persistLibrary();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('ย้ายไฟล์ "${doc.name}" ไปยังถังขยะแล้ว'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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

    _persistLibrary();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('กู้คืนไฟล์ "${doc.name}" เรียบร้อยแล้ว'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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

    if (doc.uri != null) {
      try {
        await widget.repository.delete(doc.uri!);
      } catch (_) {}
    }

    setState(() {
      _documents.removeWhere((d) => d.id == doc.id);
    });

    await _persistLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('ลบไฟล์ "${doc.name}" ถาวรแล้ว'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    }
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

    final trashedFolderIds = _folders.where((f) => f.isTrash).map((f) => f.id).toSet();
    final trashedDocs = _documents.where(
      (d) => d.isTrash || (d.folderId != null && trashedFolderIds.contains(d.folderId)),
    ).toList();

    for (final doc in trashedDocs) {
      if (doc.uri != null) {
        try {
          await widget.repository.delete(doc.uri!);
        } catch (_) {}
      }
    }

    setState(() {
      _folders.removeWhere((f) => f.isTrash);
      _documents.removeWhere(
        (d) => d.isTrash || (d.folderId != null && trashedFolderIds.contains(d.folderId)),
      );
    });

    await _persistLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('ล้างถังขยะเรียบร้อยแล้ว'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
    }
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

  String _formatDate(DateTime dt, {bool includeTime = true}) {
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
    final yearShort = (yearThai % 100).toString().padLeft(2, '0');
    final dateStr = '${dt.day} ${mNames[dt.month]} $yearShort';
    if (!includeTime) return dateStr;
    final min = dt.minute.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    return '$dateStr $hour:$min';
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
    if (width < 380) return 2; // Phone
    if (width < 600) return 3; // Large Phone / Small Tablet
    if (width < 880) return 4; // Tablet (iPad)
    if (width < 1180) return 5; // Laptop / Desktop
    if (width < 1480) return 6; // Large Desktop
    return 7;
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
      list.sort((a, b) {
        switch (_sortMode) {
          case SortMode.newest:
            return b.updatedAt.compareTo(a.updatedAt);
          case SortMode.oldest:
            return a.updatedAt.compareTo(b.updatedAt);
          case SortMode.nameAsc:
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case SortMode.nameDesc:
            return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        }
      });
    }

    void sortDocs(List<DocumentItem> list) {
      list.sort((a, b) {
        switch (_sortMode) {
          case SortMode.newest:
            return b.updatedAt.compareTo(a.updatedAt);
          case SortMode.oldest:
            return a.updatedAt.compareTo(b.updatedAt);
          case SortMode.nameAsc:
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case SortMode.nameDesc:
            return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        }
      });
    }

    final starredFolders = visibleFolders.where((f) => f.isStarred).toList();
    final starredDocs = visibleDocuments.where((d) => d.isStarred).toList();
    final unstarredFolders = visibleFolders.where((f) => !f.isStarred).toList();
    final unstarredDocs = visibleDocuments.where((d) => !d.isStarred).toList();

    sortFolders(starredFolders);
    sortDocs(starredDocs);
    sortFolders(unstarredFolders);
    sortDocs(unstarredDocs);

    // รวมรายการทั้งหมด: รายการโปรด (ทั้งโฟลเดอร์และไฟล์ที่ติดดาว ⭐) ขึ้นก่อนเสมอ!
    final allItems = <dynamic>[
      ...starredFolders,
      ...starredDocs,
      ...unstarredFolders,
      ...unstarredDocs,
    ];

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
                child: Row(
                  children: [
                    _buildFilterMenu(theme),
                    const Spacer(),
                    if (isTrashView)
                      _buildEmptyTrashButton(context)
                    else
                      _buildNewButton(context),
                    const SizedBox(width: 6),
                    _buildViewModeButton(),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Main Content Grid / List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadDeviceDocuments,
                  child: allItems.isEmpty
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
                          ? _buildGridView(allItems, columns)
                          : _buildListView(allItems)),
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
      offset: const Offset(10, 42),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
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
        // 1. กลุ่มมุมมองหลัก (View)
        _buildFilterMenuItem(
          value: ViewFilter.all,
          icon: Icons.grid_view_rounded,
          title: 'ทั้งหมด',
          theme: theme,
        ),
        _buildFilterMenuItem(
          value: ViewFilter.starred,
          icon: Icons.star_rounded,
          title: 'ติดดาว (รายการโปรด)',
          theme: theme,
          iconColor: Colors.amber,
        ),

        const PopupMenuDivider(),

        // 2. กลุ่มประเภทเนื้อหา (Filter by Type)
        _buildFilterMenuItem(
          value: ViewFilter.foldersOnly,
          icon: Icons.folder_rounded,
          title: 'โฟลเดอร์',
          theme: theme,
          iconColor: Colors.blue,
        ),
        _buildFilterMenuItem(
          value: ViewFilter.filesOnly,
          icon: Icons.insert_drive_file_outlined,
          title: 'เอกสารทั้งหมด',
          theme: theme,
          iconColor: Colors.indigo,
        ),
        _buildFilterMenuItem(
          value: ViewFilter.markdownOnly,
          icon: Icons.description_outlined,
          title: 'Markdown (.md)',
          theme: theme,
          iconColor: Colors.blue,
        ),
        _buildFilterMenuItem(
          value: ViewFilter.txtOnly,
          icon: Icons.text_snippet_outlined,
          title: 'Text (.txt)',
          theme: theme,
          iconColor: Colors.teal,
        ),

        const PopupMenuDivider(),

        // 3. กลุ่มระบบ (System)
        _buildFilterMenuItem(
          value: ViewFilter.trash,
          icon: Icons.delete_outline_rounded,
          title: 'ถังขยะ',
          theme: theme,
          iconColor: Colors.red,
          trailing: trashCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                )
              : null,
        ),
      ],
    );
  }

  // สร้างไอเทมเมนูตัวกรองพร้อมสถานะ Active และ Checkmark
  PopupMenuItem<ViewFilter> _buildFilterMenuItem({
    required ViewFilter value,
    required IconData icon,
    required String title,
    required ThemeData theme,
    Color? iconColor,
    Widget? trailing,
  }) {
    final isSelected = _filter == value;
    final primary = theme.colorScheme.primary;
    final activeColor = value == ViewFilter.trash ? Colors.red : primary;

    return PopupMenuItem<ViewFilter>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? activeColor : (iconColor ?? theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (trailing != null) ...[
            trailing,
            const SizedBox(width: 8),
          ],
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 18,
              color: activeColor,
            ),
        ],
      ),
    );
  }

  // แสดงตัวเลือกของโฟลเดอร์ (เปิด, ติดดาว, ย้ายไปถังขยะ, กู้คืน, ลบถาวร)
  void _showFolderOptions(FolderItem folder) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.folder_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  title: Text(
                    folder.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_formatDate(folder.updatedAt)),
                ),
                const Divider(),
                if (folder.isTrash) ...[
                  ListTile(
                    leading: const Icon(Icons.restore_from_trash_rounded, color: Colors.blue),
                    title: const Text('กู้คืน'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _restoreFolder(folder);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    title: const Text('ลบถาวร', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _permanentlyDeleteFolder(folder);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.folder_open_rounded),
                    title: const Text('เปิดโฟลเดอร์'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _handleFolderTap(folder);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('เปลี่ยนชื่อโฟลเดอร์'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _renameFolder(folder);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      folder.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: folder.isStarred ? Colors.amber : null,
                    ),
                    title: Text(folder.isStarred ? 'ยกเลิกรายการโปรด' : 'เพิ่มในรายการโปรด'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleFolderStar(folder);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: const Text('ย้ายไปถังขยะ', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _moveToTrashFolder(folder);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // แสดงตัวเลือกของเอกสาร (เปิด, เปลี่ยนชื่อ, ส่งออก, ติดดาว, ย้ายไปถังขยะ, กู้คืน, ลบถาวร)
  void _showDocumentOptions(DocumentItem doc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    doc.isTxt ? Icons.text_snippet_rounded : Icons.description_rounded,
                    color: doc.isTxt ? Colors.teal : Colors.blue,
                    size: 28,
                  ),
                  title: Text(
                    doc.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_formatDate(doc.updatedAt)),
                ),
                const Divider(),
                if (doc.isTrash) ...[
                  ListTile(
                    leading: const Icon(Icons.restore_from_trash_rounded, color: Colors.blue),
                    title: const Text('กู้คืน'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _restoreDocument(doc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    title: const Text('ลบถาวร', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _permanentlyDeleteDocument(doc);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded),
                    title: const Text('เปิดเอกสาร'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openDocument(doc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('เปลี่ยนชื่อไฟล์'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _renameDocument(doc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.upload_rounded),
                    title: const Text('ส่งออก'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _exportDocument(doc);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      doc.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: doc.isStarred ? Colors.amber : null,
                    ),
                    title: Text(doc.isStarred ? 'ยกเลิกรายการโปรด' : 'เพิ่มในรายการโปรด'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleDocumentStar(doc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: const Text('ย้ายไปถังขยะ', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _moveToTrashDocument(doc);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
              Icon(Icons.description_outlined, color: Colors.blue, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('เอกสาร Markdown ใหม่ (.md)')),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'new_txt',
          child: Row(
            children: [
              Icon(Icons.text_snippet_outlined, color: Colors.teal, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('ไฟล์ข้อความใหม่ (.txt)')),
            ],
          ),
        ),
        if (_currentFolderId == null)
          const PopupMenuItem(
            value: 'new_folder',
            child: Row(
              children: [
                Icon(Icons.create_new_folder_outlined, color: Colors.amber, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('โฟลเดอร์ใหม่')),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.file_open_outlined, color: Colors.orange, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('ดึงไฟล์จากเครื่อง (Import)')),
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
    List<dynamic> items,
    int columns,
  ) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 24,
        crossAxisSpacing: 18,
        childAspectRatio: 0.74,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is FolderItem) {
          return _buildFolderGridCard(item);
        } else {
          return _buildDocumentGridCard(item as DocumentItem);
        }
      },
    );
  }

  // การ์ดโฟลเดอร์ใน Grid View (จัดกึ่งกลาง สมมาตรตาม Reference ใน Image 1)
  Widget _buildFolderGridCard(FolderItem folder) {
    final theme = Theme.of(context);
    final count = _documents.where((d) => d.folderId == folder.id && !d.isTrash).length;
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _handleFolderTap(folder),
                onLongPress: () => _showFolderOptions(folder),
                onSecondaryTap: () => _showFolderOptions(folder),
                child: SizedBox(
                  width: 160,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.folder_rounded,
                        size: 128,
                        color: primary,
                      ),
                      Positioned(
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '$count ไฟล์',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                              color: isDark ? Colors.white : primary,
                            ),
                          ),
                        ),
                      ),
                      if (!folder.isTrash)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: IconButton(
                            iconSize: 22,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              folder.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: folder.isStarred
                                  ? Colors.amberAccent
                                  : (isDark ? Colors.white70 : Colors.black45),
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _handleFolderTap(folder),
                      onLongPress: () => _showFolderOptions(folder),
                      onSecondaryTap: () => _showFolderOptions(folder),
                      child: Text(
                        folder.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          letterSpacing: -0.1,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(folder.updatedAt, includeTime: false),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 24,
                height: 32,
                child: PopupMenuButton<String>(
                  key: Key('folder-menu-${folder.id}'),
                  tooltip: 'ตัวเลือกโฟลเดอร์',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                  onSelected: (val) {
                    if (val == 'open') _handleFolderTap(folder);
                    if (val == 'rename') _renameFolder(folder);
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
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('เปลี่ยนชื่อโฟลเดอร์'),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  // การ์ดเอกสารใน Grid View (รูปทรงกระดาษ/สมุดโน้ต Preview จัดกึ่งกลาง สมมาตรตาม Reference ใน Image 1)
  Widget _buildDocumentGridCard(DocumentItem doc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTxt = doc.isTxt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openDocument(doc),
                onLongPress: () => _showDocumentOptions(doc),
                onSecondaryTap: () => _showDocumentOptions(doc),
                child: Container(
                  width: 148,
                  height: 175,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surfaceContainerLow : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: (isTxt ? Colors.teal : Colors.blue).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isTxt ? 'TXT' : 'MD',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: isTxt ? Colors.teal : Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _buildCardPreviewContent(doc.content, theme),
                          ),
                        ],
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: IconButton(
                          iconSize: 22,
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 148),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _openDocument(doc),
                      onLongPress: () => _showDocumentOptions(doc),
                      onSecondaryTap: () => _showDocumentOptions(doc),
                      child: Text(
                        doc.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          letterSpacing: -0.1,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(doc.updatedAt, includeTime: false),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 24,
                height: 32,
                child: PopupMenuButton<String>(
                  key: Key('doc-menu-${doc.id}'),
                  tooltip: 'ตัวเลือกเอกสาร',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                  onSelected: (val) {
                    if (val == 'open') _openDocument(doc);
                    if (val == 'rename') _renameDocument(doc);
                    if (val == 'export') _exportDocument(doc);
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
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('เปลี่ยนชื่อไฟล์'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.upload_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('ส่งออก'),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  // พรีวิวเนื้อหาเอกสารในการ์ด (แยก Title บรรทัดแรกให้อ่านง่าย และตัดคำไม่ให้เสียรูปทรง)
  Widget _buildCardPreviewContent(String content, ThemeData theme) {
    final rawLines = content.trim().split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (rawLines.isEmpty) {
      return Text(
        'เอกสารว่าง',
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }

    // แยก Title บรรทัดแรก (ตัดเครื่องหมาย # ออก)
    final firstLine = rawLines.first.replaceAll(RegExp(r'^#{1,6}\s*'), '');
    final remaining = rawLines.skip(1).map((l) => l.replaceAll(RegExp(r'^#{1,6}\s*'), '')).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstLine,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            height: 1.35,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              remaining,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                letterSpacing: 0.05,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  // List View ทางเลือก
  Widget _buildListView(List<dynamic> items) {
    final theme = Theme.of(context);
    final isTrashView = _filter == ViewFilter.trash;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final item in items)
          if (item is FolderItem)
            ListTile(
              leading: Icon(Icons.folder_rounded, color: theme.colorScheme.primary, size: 36),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2)),
              subtitle: Text(
                '${_documents.where((d) => d.folderId == item.id && !d.isTrash).length} ไฟล์ • ${_formatDate(item.updatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isTrashView)
                    IconButton(
                      icon: Icon(
                        item.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: item.isStarred ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () => _toggleFolderStar(item),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (val) {
                      if (val == 'open') _handleFolderTap(item);
                      if (val == 'rename') _renameFolder(item);
                      if (val == 'trash') _moveToTrashFolder(item);
                      if (val == 'restore') _restoreFolder(item);
                      if (val == 'delete_perm') _permanentlyDeleteFolder(item);
                    },
                    itemBuilder: (ctx) => item.isTrash
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
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('เปลี่ยนชื่อโฟลเดอร์'),
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
              onTap: () => _handleFolderTap(item),
            )
          else
            ListTile(
              leading: Icon(
                (item as DocumentItem).isTxt ? Icons.text_snippet_rounded : Icons.description_rounded,
                color: item.isTxt ? Colors.teal : Colors.blue,
                size: 32,
              ),
              title: Text(item.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2)),
              subtitle: Text(
                '${item.isTxt ? "ข้อความ TXT" : "Markdown"} • ${_formatDate(item.updatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isTrashView)
                    IconButton(
                      icon: Icon(
                        item.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: item.isStarred ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () => _toggleDocumentStar(item),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (val) {
                      if (val == 'open') _openDocument(item);
                      if (val == 'rename') _renameDocument(item);
                      if (val == 'export') _exportDocument(item);
                      if (val == 'trash') _moveToTrashDocument(item);
                      if (val == 'restore') _restoreDocument(item);
                      if (val == 'delete_perm') _permanentlyDeleteDocument(item);
                    },
                    itemBuilder: (ctx) => item.isTrash
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
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('เปลี่ยนชื่อไฟล์'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'export',
                              child: Row(
                                children: [
                                  Icon(Icons.upload_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('ส่งออก'),
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
              onTap: () => _openDocument(item),
            ),
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
        return 'ติดดาว';
      case ViewFilter.foldersOnly:
        return 'โฟลเดอร์';
      case ViewFilter.filesOnly:
        return 'เอกสารทั้งหมด';
      case ViewFilter.markdownOnly:
        return 'Markdown';
      case ViewFilter.txtOnly:
        return 'Text (.txt)';
      case ViewFilter.trash:
        return 'ถังขยะ';
    }
  }
}