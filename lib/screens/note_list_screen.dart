import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_validators.dart';
import 'package:mnote/features/auth/presentation/auth_page.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mnote/features/sync/domain/syncable_document_repository.dart';
import 'package:mnote/features/workspace/presentation/editor_settings.dart';
import 'package:mnote/features/sync/presentation/sync_status_badge.dart';
import 'package:mnote/features/workspace/data/ink_file_storage.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/domain/markdown_document.dart';
import 'package:mnote/features/workspace/presentation/export_sheet.dart';
import 'package:mnote/features/workspace/presentation/ink_storage_scope.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/l10n/l10n.dart';
import 'package:mnote/screens/widgets/folder_color_dialog.dart';
import 'package:mnote/screens/widgets/note_list_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_item.dart';

enum ViewFilter {
  all,
  starred,
  foldersOnly,
  filesOnly,
  markdownOnly,
  txtOnly,
  trash,
}

enum SortMode { newest, oldest, nameAsc, nameDesc }

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({
    super.key,
    required this.repository,
    this.authRepository,
    this.initialFolders = const [],
    this.initialDocuments = const [],
  });

  final DocumentRepository repository;

  /// When provided, an account icon is shown in the app bar.
  final AuthRepository? authRepository;
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
    _startCloudSync();
  }

  StreamSubscription<void>? _syncSubscription;

  // Remote edits are merged into local storage by the repository; reload the
  // in-memory library whenever that happens.
  void _startCloudSync() {
    final repository = widget.repository;
    if (repository is! SyncableDocumentRepository) return;
    _syncSubscription = repository.changes.listen((_) => _reloadLibrary());
    unawaited(repository.startSync());
  }

  Future<void> _reloadLibrary() async {
    try {
      final metadata = await widget.repository.loadMetadata();
      if (!mounted || metadata == null) return;
      setState(() {
        _folders
          ..clear()
          ..addAll(metadata.folders);
        _documents
          ..clear()
          ..addAll(metadata.documents);
        final folderId = _currentFolderId;
        if (folderId != null && !_folders.any((f) => f.id == folderId)) {
          _currentFolderId = null;
        }
      });
      await _ensureWelcome();
    } catch (_) {}
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _persistLibrary() async {
    try {
      await widget.repository.saveMetadata(
        LibraryMetadata(folders: _folders, documents: _documents),
      );
    } catch (_) {}
  }

  static const _welcomeRemovedKey = 'mnote_welcome_removed';

  bool _isWelcome(DocumentItem d) =>
      d.id == 'welcome_initial_doc' || d.name == 'Welcome.md';

  /// Adds the bundled Welcome note unless one exists or the user deleted it.
  /// Synced libraries and signed-in accounts still get it on a fresh start.
  Future<void> _ensureWelcome() async {
    try {
      if (_documents.any(_isWelcome)) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_welcomeRemovedKey) ?? false) return;
      final content = await rootBundle.loadString('assets/examples/welcome.md');
      if (!mounted || _documents.any(_isWelcome)) return;
      setState(() {
        _documents.add(
          DocumentItem(
            id: 'welcome_initial_doc',
            name: 'Welcome.md',
            content: content,
            updatedAt: DateTime.now(),
          ),
        );
      });
      await _persistLibrary();
    } catch (_) {}
  }

  Future<void> _setWelcomeRemoved(bool removed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeRemovedKey, removed);
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

      // ทุกบัญชี/เครื่องควรมี Welcome.md เริ่มต้น (เว้นแต่ผู้ใช้ลบทิ้งเอง)
      await _ensureWelcome();

      // Upgrade only the untouched bundled document; preserve user edits/files.
      if (_documents.any(
        (doc) =>
            doc.id == 'welcome_initial_doc' &&
            doc.name == 'Welcome.md' &&
            doc.uri == null &&
            !doc.isTrash,
      )) {
        final previous = await rootBundle.loadString(
          'assets/examples/welcome_v1.md',
        );
        final current = await rootBundle.loadString(
          'assets/examples/welcome.md',
        );
        if (!mounted) return;
        setState(() {
          for (var index = 0; index < _documents.length; index++) {
            final doc = _documents[index];
            if (doc.id == 'welcome_initial_doc' &&
                doc.name == 'Welcome.md' &&
                doc.uri == null &&
                !doc.isTrash &&
                doc.content == previous) {
              _documents[index] = doc.copyWith(content: current);
            }
          }
        });
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
              content: Text(context.l10n.noteImported(doc.displayName)),
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
              content: Text(context.l10n.noteImportFailed('$e')),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      }
    }
  }

  // สร้างไฟล์ใหม่ (สร้างไฟล์เฉยๆ หรือเปิด Workspace)
  // New notes are always Markdown; .txt files can still be imported.
  Future<void> _createNewFile() async {
    const ext = 'md';
    final count = _documents.where((d) => d.extension == ext).length + 1;
    final defaultName = context.l10n.defaultDocName(count);

    final textController = TextEditingController(text: defaultName);

    final fileName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.newMarkdownTitle),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.fileNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel),
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
            child: Text(context.l10n.createFile),
          ),
        ],
      ),
    );

    if (fileName == null || fileName.isEmpty || !mounted) return;

    final newDoc = DocumentItem(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      name: fileName,
      // A new note opens blank, ready to type into.
      content: '',
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
        title: Text(context.l10n.newFolderTitle),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.folderNameLabel,
            hintText: context.l10n.folderNameHint,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(ctx).pop(name);
              }
            },
            child: Text(context.l10n.create),
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
            content: Text(context.l10n.folderCreated(name)),
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
          icon: Icon(
            Icons.restore_from_trash_rounded,
            color: Theme.of(ctx).colorScheme.primary,
          ),
          title: Text(context.l10n.trashedDocTitle),
          content: Text(context.l10n.trashedDocBody(item.displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.l10n.restoreAndOpen),
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
        final isDifferentUri =
            item.uri != null &&
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

  Future<void> _changeFolderColor(FolderItem folder) async {
    final choice = await showFolderColorDialog(context, folder);
    if (choice == null || !mounted) return;
    if (choice.color == folder.colorValue) return;
    setState(() {
      final index = _folders.indexWhere((f) => f.id == folder.id);
      if (index != -1) _folders[index] = folder.withColor(choice.color);
    });
    await _persistLibrary();
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

  Future<void> _signOut() async {
    final auth = widget.authRepository!;
    final repository = widget.repository;
    if (repository is SyncableDocumentRepository) {
      final unsynced = await repository.unsyncedCount();
      if (unsynced > 0) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.unsyncedTitle),
            content: Text(context.l10n.unsyncedBody(unsynced)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.l10n.signOutAndDelete),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
      await _syncSubscription?.cancel();
      _syncSubscription = null;
      await repository.stopSync(clearLocal: true);
      // The next account starts with its own Welcome note.
      await _setWelcomeRemoved(false);
    }
    await auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AuthPage(
          repository: widget.repository,
          authRepository: auth,
          nextPage: NoteListScreen(
            repository: widget.repository,
            authRepository: auth,
          ),
        ),
      ),
      (_) => false,
    );
  }

  void _openSettings() {
    final sync = _syncRepository?.settings;
    showDialog(
      context: context,
      builder: (_) => NoteListSettingsDialog(
        syncSettings: sync,
        syncRepository: _syncRepository,
        authRepository: widget.authRepository,
        onSignOut: widget.authRepository == null ? null : _signOut,
        onDeleteAccount: widget.authRepository == null ? null : _deleteAccount,
      ),
    );
  }

  Future<void> _deleteAccount(String password) async {
    final auth = widget.authRepository!;
    final repository = widget.repository;
    final sync = repository is SyncableDocumentRepository ? repository : null;
    // Stop syncing first so nothing is re-uploaded while the cloud is erased.
    await sync?.stopSync();
    // Erasing the cloud data can take a while; keep the user informed.
    if (mounted) {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PopScope(
            canPop: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    try {
      await auth.deleteAccount(password: password.isEmpty ? null : password);
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      unawaited(sync?.startSync());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthValidators.messageFor(context.l10n, e))),
      );
      return;
    }
    await _syncSubscription?.cancel();
    _syncSubscription = null;
    await sync?.stopSync(clearLocal: true);
    await _setWelcomeRemoved(false);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AuthPage(
          repository: widget.repository,
          authRepository: auth,
          nextPage: NoteListScreen(
            repository: widget.repository,
            authRepository: auth,
          ),
        ),
      ),
      (_) => false,
    );
  }

  SyncableDocumentRepository? get _syncRepository {
    final repository = widget.repository;
    return repository is SyncableDocumentRepository ? repository : null;
  }

  String _syncModeLabel(SyncMode mode) => switch (mode) {
    SyncMode.auto => context.l10n.syncModeAuto,
    SyncMode.never => context.l10n.syncModeNever,
  };

  Future<void> _chooseSyncMode(DocumentItem doc) async {
    if (_syncRepository == null) return;
    final chosen = await showDialog<SyncMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.l10n.syncModeTitle(doc.displayName)),
        children: [
          for (final (mode, detail) in [
            (SyncMode.auto, context.l10n.syncModeAutoDesc),
            (SyncMode.never, context.l10n.syncModeNeverDesc),
          ])
            ListTile(
              key: ValueKey('sync-mode-${mode.name}'),
              leading: Icon(
                mode == doc.syncMode
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(_syncModeLabel(mode)),
              subtitle: Text(detail),
              onTap: () => Navigator.pop(ctx, mode),
            ),
        ],
      ),
    );
    if (chosen == null || chosen == doc.syncMode || !mounted) return;
    setState(() {
      // Edit the current entry: a sync may have refreshed it while the dialog
      // was open, and `doc` would bring the stale copy back.
      final index = _documents.indexWhere((d) => d.id == doc.id);
      if (index != -1) {
        _documents[index] = _documents[index].copyWith(syncMode: chosen);
      }
    });
    await _persistLibrary();
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
          content: Text(context.l10n.folderTrashed(folder.name)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: context.l10n.undo,
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
          content: Text(context.l10n.folderRestored(folder.name)),
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
        title: Text(context.l10n.deleteFolderTitle),
        content: Text(context.l10n.deleteFolderBody(folder.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.deleteForeverBtn),
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
            content: Text(context.l10n.folderDeleted(folder.name)),
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
        title: Text(context.l10n.renameDocTitle),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('rename-document-input'),
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.docNameLabel,
              hintText: context.l10n.docNameHint,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return context.l10n.docNameRequired;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('rename-document-submit'),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );

    if (newName == null ||
        newName.isEmpty ||
        newName == doc.displayName ||
        !mounted) {
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
            content: Text(context.l10n.docRenamed(newName)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _moveDocument(DocumentItem doc) async {
    final availableFolders = _folders
        .where((f) => !f.isTrash && f.id != doc.folderId)
        .toList();

    // หากอยู่หน้าหลักและยังไม่มีโฟลเดอร์ให้ย้ายไป
    if (doc.folderId == null && availableFolders.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.l10n.noFoldersToMove),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      }
      return;
    }

    final selected = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.l10n.moveDocTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 350),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (doc.folderId != null)
                  ListTile(
                    leading: const Icon(
                      Icons.home_outlined,
                      color: Colors.blue,
                    ),
                    title: Text(context.l10n.moveToHome),
                    onTap: () => Navigator.pop(ctx, '__root__'),
                  ),
                ...availableFolders.map(
                  (f) => ListTile(
                    leading: Icon(
                      Icons.folder_outlined,
                      color: folderColor(f, Colors.amber),
                    ),
                    title: Text(f.name),
                    onTap: () => Navigator.pop(ctx, f.id),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );

    if (selected == null || !mounted) return;

    final newFolderId = selected == '__root__' ? null : selected;
    final targetFolder = _folders.where((f) => f.id == newFolderId).firstOrNull;
    final destName = newFolderId == null
        ? context.l10n.homeName
        : (targetFolder?.name ?? context.l10n.folderFallback);

    setState(() {
      final idx = _documents.indexWhere((d) => d.id == doc.id);
      if (idx != -1) {
        _documents[idx] = _documents[idx].moveToFolder(newFolderId);
      }
    });

    await _persistLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.docMoved(doc.displayName, destName)),
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
        title: Text(context.l10n.renameFolder),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('rename-folder-input'),
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.folderNameLabel,
              hintText: context.l10n.folderNameNewHint,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return context.l10n.folderNameRequired;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('rename-folder-submit'),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );

    if (newName == null ||
        newName.isEmpty ||
        newName == folder.name ||
        !mounted) {
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
            content: Text(context.l10n.folderRenamed(newName)),
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
        ? MarkdownDocument.opened(name: doc.name, content: content, uri: uri)
        : MarkdownDocument(
            name: doc.name,
            content: content,
            savedName: doc.name,
            savedContent: content,
          );

    if (!mounted) return;

    final inkStorage =
        InkStorageScope.maybeOf(context) ?? const DeviceInkFileStorage();
    await showExportBottomSheet(
      context,
      document: mdDoc,
      inkLoader: () async {
        final bytes = await inkStorage.autoLoad(name: mdDoc.name);
        return bytes == null ? null : utf8.decode(bytes);
      },
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
          content: Text(context.l10n.docTrashed(doc.displayName)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: context.l10n.undo,
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
          content: Text(context.l10n.docRestored(doc.displayName)),
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
        title: Text(context.l10n.deleteDocTitle),
        content: Text(context.l10n.deleteDocBody(doc.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.deleteForeverBtn),
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

    if (_isWelcome(doc)) await _setWelcomeRemoved(true);

    setState(() {
      _documents.removeWhere((d) => d.id == doc.id);
    });

    await _persistLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.docDeleted(doc.displayName)),
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
        title: Text(context.l10n.emptyTrashTitle),
        content: Text(context.l10n.emptyTrashBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.emptyTrash),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final trashedFolderIds = _folders
        .where((f) => f.isTrash)
        .map((f) => f.id)
        .toSet();
    final trashedDocs = _documents
        .where(
          (d) =>
              d.isTrash ||
              (d.folderId != null && trashedFolderIds.contains(d.folderId)),
        )
        .toList();

    for (final doc in trashedDocs) {
      if (doc.uri != null) {
        try {
          await widget.repository.delete(doc.uri!);
        } catch (_) {}
      }
    }

    if (trashedDocs.any(_isWelcome)) await _setWelcomeRemoved(true);

    setState(() {
      _folders.removeWhere((f) => f.isTrash);
      _documents.removeWhere(
        (d) =>
            d.isTrash ||
            (d.folderId != null && trashedFolderIds.contains(d.folderId)),
      );
    });

    await _persistLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.trashEmptied),
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
          icon: Icon(
            Icons.restore_from_trash_rounded,
            color: Theme.of(ctx).colorScheme.primary,
          ),
          title: Text(context.l10n.trashedFolderTitle),
          content: Text(context.l10n.trashedFolderBody(folder.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.l10n.restore),
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
    final dateStr = context.l10n.cardDate(dt);
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

  // คำนวณจำนวนคอลัมน์ให้แต่ละช่องกว้างพอสำหรับการ์ดเอกสาร (148) เสมอ
  // ไม่เช่นนั้นการ์ดถูกบีบจนเนื้อหาล้น (เช่น 3 คอลัมน์บนมือถือ ~400dp)
  int _calculateColumnCount(double width) {
    const horizontalPadding = 40.0; // padding ซ้ายขวาของ Grid
    const cardWidth = 148.0;
    const spacing = 18.0;
    final fit = ((width - horizontalPadding + spacing) / (cardWidth + spacing))
        .floor();
    return fit.clamp(2, 7);
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
                decoration: InputDecoration(
                  hintText: context.l10n.searchHint,
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRoot && !isTrashView) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      isTrashView
                          ? context.l10n.trash
                          : (isRoot
                                ? 'Mnote'
                                : _currentFolder?.name ??
                                      context.l10n.folderFallback),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
            ),
            tooltip: _isSearching
                ? context.l10n.closeSearch
                : context.l10n.search,
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
            tooltip: context.l10n.settingsTooltip,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: constraints.maxWidth < 420
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterMenu(theme),
                            const SizedBox(width: 8),
                            if (isTrashView)
                              _buildEmptyTrashButton(context)
                            else
                              _buildNewButton(context),
                            const SizedBox(width: 4),
                            _buildSortButton(theme),
                            _buildViewModeButton(),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          _buildFilterMenu(theme),
                          const Spacer(),
                          if (isTrashView)
                            _buildEmptyTrashButton(context)
                          else
                            _buildNewButton(context),
                          const SizedBox(width: 8),
                          _buildSortButton(theme),
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
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
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
    final hasTrash =
        _folders.any((f) => f.isTrash) || _documents.any((d) => d.isTrash);
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
      onPressed: hasTrash ? _emptyTrash : null,
      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
      label: Text(
        context.l10n.emptyTrash,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  // เมนูตัวกรอง
  Widget _buildFilterMenu(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    final trashCount =
        _folders.where((f) => f.isTrash).length +
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
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
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
      itemBuilder: (ctx) => [
        // 1. กลุ่มมุมมองหลัก (View)
        _buildFilterMenuItem(
          value: ViewFilter.all,
          icon: Icons.grid_view_rounded,
          title: context.l10n.filterAll,
          theme: theme,
        ),
        _buildFilterMenuItem(
          value: ViewFilter.starred,
          icon: Icons.star_rounded,
          title: context.l10n.filterStarred,
          theme: theme,
          iconColor: Colors.amber,
        ),

        const PopupMenuDivider(),

        // 2. กลุ่มประเภทเนื้อหา (Filter by Type)
        _buildFilterMenuItem(
          value: ViewFilter.foldersOnly,
          icon: Icons.folder_rounded,
          title: context.l10n.filterFolders,
          theme: theme,
          iconColor: primary,
        ),
        _buildFilterMenuItem(
          value: ViewFilter.filesOnly,
          icon: Icons.insert_drive_file_outlined,
          title: context.l10n.filterAllDocs,
          theme: theme,
          iconColor: Colors.indigo,
        ),
        _buildFilterMenuItem(
          value: ViewFilter.markdownOnly,
          icon: Icons.description_outlined,
          title: 'Markdown (.md)',
          theme: theme,
          iconColor: primary,
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
          title: context.l10n.trash,
          theme: theme,
          iconColor: Colors.red,
          trailing: trashCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
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
            color: isSelected
                ? activeColor
                : (iconColor ?? theme.colorScheme.onSurfaceVariant),
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
          if (trailing != null) ...[trailing, const SizedBox(width: 8)],
          if (isSelected)
            Icon(Icons.check_rounded, size: 18, color: activeColor),
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
        final sheetTheme = Theme.of(ctx);
        final sheetPrimary = sheetTheme.colorScheme.primary;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.folder_rounded,
                    color: folderColor(folder, sheetPrimary),
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
                    leading: Icon(
                      Icons.restore_from_trash_rounded,
                      color: sheetPrimary,
                    ),
                    title: Text(context.l10n.restore),
                    onTap: () {
                      Navigator.pop(ctx);
                      _restoreFolder(folder);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                    ),
                    title: Text(
                      context.l10n.deleteForeverBtn,
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _permanentlyDeleteFolder(folder);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.folder_open_rounded),
                    title: Text(context.l10n.openFolder),
                    onTap: () {
                      Navigator.pop(ctx);
                      _handleFolderTap(folder);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(context.l10n.renameFolder),
                    onTap: () {
                      Navigator.pop(ctx);
                      _renameFolder(folder);
                    },
                  ),
                  ListTile(
                    key: const Key('folder-change-color'),
                    leading: Icon(
                      Icons.palette_outlined,
                      color: folderColor(folder, sheetPrimary),
                    ),
                    title: Text(context.l10n.folderColor),
                    onTap: () {
                      Navigator.pop(ctx);
                      _changeFolderColor(folder);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      folder.isStarred
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: folder.isStarred ? Colors.amber : null,
                    ),
                    title: Text(
                      folder.isStarred
                          ? context.l10n.unfavorite
                          : context.l10n.favorite,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleFolderStar(folder);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: Text(
                      context.l10n.moveToTrash,
                      style: TextStyle(color: Colors.red),
                    ),
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
        final sheetTheme = Theme.of(ctx);
        final sheetPrimary = sheetTheme.colorScheme.primary;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    doc.isTxt
                        ? Icons.text_snippet_rounded
                        : Icons.description_rounded,
                    color: doc.isTxt ? Colors.teal : sheetPrimary,
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
                    leading: Icon(
                      Icons.restore_from_trash_rounded,
                      color: sheetPrimary,
                    ),
                    title: Text(context.l10n.restore),
                    onTap: () {
                      Navigator.pop(ctx);
                      _restoreDocument(doc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                    ),
                    title: Text(
                      context.l10n.deleteForeverBtn,
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _permanentlyDeleteDocument(doc);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.edit_note_rounded),
                    title: Text(context.l10n.openDoc),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openDocument(doc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(context.l10n.renameDoc),
                    onTap: () {
                      Navigator.pop(ctx);
                      _renameDocument(doc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.drive_file_move_outlined),
                    title: Text(context.l10n.moveToFolder),
                    onTap: () {
                      Navigator.pop(ctx);
                      _moveDocument(doc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.upload_rounded),
                    title: Text(context.l10n.export),
                    onTap: () {
                      Navigator.pop(ctx);
                      _exportDocument(doc);
                    },
                  ),
                  if (_syncRepository != null)
                    ListTile(
                      leading: const Icon(Icons.cloud_sync_outlined),
                      title: Text(context.l10n.syncSettingsMenu),
                      subtitle: Text(_syncModeLabel(doc.syncMode)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _chooseSyncMode(doc);
                      },
                    ),
                  ListTile(
                    leading: Icon(
                      doc.isStarred
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: doc.isStarred ? Colors.amber : null,
                    ),
                    title: Text(
                      doc.isStarred
                          ? context.l10n.unfavorite
                          : context.l10n.favorite,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleDocumentStar(doc);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: Text(
                      context.l10n.moveToTrash,
                      style: TextStyle(color: Colors.red),
                    ),
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
      tooltip: _isGridView ? context.l10n.listView : context.l10n.gridView,
      onPressed: () {
        setState(() {
          _isGridView = !_isGridView;
        });
      },
    );
  }

  // ปุ่มเมนูจัดเรียงลำดับ
  Widget _buildSortButton(ThemeData theme) {
    return PopupMenuButton<SortMode>(
      tooltip: context.l10n.sortBy,
      initialValue: _sortMode,
      icon: const Icon(Icons.swap_vert_rounded),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      onSelected: (mode) {
        setState(() {
          _sortMode = mode;
        });
      },
      itemBuilder: (context) => [
        _buildSortMenuItem(
          value: SortMode.newest,
          icon: Icons.schedule_rounded,
          title: context.l10n.sortNewest,
          theme: theme,
        ),
        _buildSortMenuItem(
          value: SortMode.oldest,
          icon: Icons.history_rounded,
          title: context.l10n.sortOldest,
          theme: theme,
        ),
        _buildSortMenuItem(
          value: SortMode.nameAsc,
          icon: Icons.sort_by_alpha_rounded,
          title: context.l10n.sortNameAsc,
          theme: theme,
        ),
        _buildSortMenuItem(
          value: SortMode.nameDesc,
          icon: Icons.sort_by_alpha_rounded,
          title: context.l10n.sortNameDesc,
          theme: theme,
        ),
      ],
    );
  }

  PopupMenuItem<SortMode> _buildSortMenuItem({
    required SortMode value,
    required IconData icon,
    required String title,
    required ThemeData theme,
  }) {
    final isSelected = _sortMode == value;
    final primary = theme.colorScheme.primary;

    return PopupMenuItem<SortMode>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? primary : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primary : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (isSelected) Icon(Icons.check_rounded, size: 18, color: primary),
        ],
      ),
    );
  }

  // ปุ่มสร้างใหม่ (+ ใหม่)
  Widget _buildNewButton(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return PopupMenuButton<String>(
      tooltip: context.l10n.createOrImport,
      onSelected: (action) {
        if (action == 'new_md') {
          _createNewFile();
        } else if (action == 'new_folder') {
          _createNewFolder();
        } else if (action == 'import') {
          _importDocumentFromDevice();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'new_md',
          child: Row(
            children: [
              Icon(Icons.description_outlined, color: primary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(context.l10n.newMarkdownItem)),
            ],
          ),
        ),
        if (_currentFolderId == null)
          PopupMenuItem(
            value: 'new_folder',
            child: Row(
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  color: Colors.amber,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(child: Text(context.l10n.newFolderItem)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.file_open_outlined, color: Colors.orange, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text(context.l10n.importItem)),
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
              context.l10n.newButton,
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
  Widget _buildGridView(List<dynamic> items, int columns) {
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
    final count = _documents
        .where((d) => d.folderId == folder.id && !d.isTrash)
        .length;
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
                        color: folderColor(folder, primary),
                      ),
                      Positioned(
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            context.l10n.fileCount(count),
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
                              folder.isStarred
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
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
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.75,
                        ),
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
                  tooltip: context.l10n.folderOptions,
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.75,
                    ),
                  ),
                  onSelected: (val) {
                    if (val == 'open') _handleFolderTap(folder);
                    if (val == 'rename') _renameFolder(folder);
                    if (val == 'color') _changeFolderColor(folder);
                    if (val == 'trash') _moveToTrashFolder(folder);
                    if (val == 'restore') _restoreFolder(folder);
                    if (val == 'delete_perm') _permanentlyDeleteFolder(folder);
                  },
                  itemBuilder: (ctx) => folder.isTrash
                      ? [
                          PopupMenuItem(
                            value: 'restore',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.restore_from_trash_rounded,
                                  size: 18,
                                  color: primary,
                                ),
                                SizedBox(width: 8),
                                Text(context.l10n.restore),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete_perm',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_forever_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  context.l10n.deleteForeverBtn,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : [
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text(context.l10n.renameFolder),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            key: Key('folder-menu-color'),
                            value: 'color',
                            child: Row(
                              children: [
                                Icon(Icons.palette_outlined, size: 18),
                                SizedBox(width: 8),
                                Text(context.l10n.folderColor),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'trash',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  context.l10n.moveToTrash,
                                  style: TextStyle(color: Colors.red),
                                ),
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
    final primary = theme.colorScheme.primary;

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
                  key: ValueKey('doc-card-${doc.id}'),
                  width: 148,
                  height: 175,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerLow
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.08,
                        ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: (isTxt ? Colors.teal : primary).withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isTxt ? 'TXT' : 'MD',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: isTxt ? Colors.teal : primary,
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
                        bottom: 0,
                        right: 0,
                        child: SyncStatusBadge(
                          repository: widget.repository,
                          doc: doc,
                        ),
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
                            doc.isStarred
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
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
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.75,
                        ),
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
                  tooltip: context.l10n.docOptions,
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.75,
                    ),
                  ),
                  onSelected: (val) {
                    if (val == 'open') _openDocument(doc);
                    if (val == 'rename') _renameDocument(doc);
                    if (val == 'move') _moveDocument(doc);
                    if (val == 'export') _exportDocument(doc);
                    if (val == 'sync') _chooseSyncMode(doc);
                    if (val == 'trash') _moveToTrashDocument(doc);
                    if (val == 'restore') _restoreDocument(doc);
                    if (val == 'delete_perm') _permanentlyDeleteDocument(doc);
                  },
                  itemBuilder: (ctx) => doc.isTrash
                      ? [
                          PopupMenuItem(
                            value: 'restore',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.restore_from_trash_rounded,
                                  size: 18,
                                  color: primary,
                                ),
                                const SizedBox(width: 8),
                                Text(context.l10n.restore),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete_perm',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_forever_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  context.l10n.deleteForeverBtn,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : [
                          PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text(context.l10n.renameDoc),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'move',
                            child: Row(
                              children: [
                                Icon(Icons.drive_file_move_outlined, size: 18),
                                SizedBox(width: 8),
                                Text(context.l10n.moveToFolder),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.upload_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(context.l10n.export),
                              ],
                            ),
                          ),
                          if (_syncRepository != null)
                            PopupMenuItem(
                              value: 'sync',
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_sync_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text(context.l10n.syncSettingsMenu),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'trash',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  context.l10n.moveToTrash,
                                  style: TextStyle(color: Colors.red),
                                ),
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
    // The card is a fixed-size thumbnail, so only the font follows the editor
    // settings, not the size or line height.
    return ListenableBuilder(
      listenable: EditorSettings.instance,
      builder: (context, _) => _cardPreviewBody(
        content,
        theme,
        EditorSettings.instance.textOptions.apply,
      ),
    );
  }

  Widget _cardPreviewBody(
    String content,
    ThemeData theme,
    TextStyle Function(TextStyle) font,
  ) {
    final rawLines = content
        .trim()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (rawLines.isEmpty) {
      return Text(
        context.l10n.emptyDoc,
        style: font(
          TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    // แยก Title บรรทัดแรก (ตัดเครื่องหมาย # ออก)
    final firstLine = rawLines.first.replaceAll(RegExp(r'^#{1,6}\s*'), '');
    final remaining = rawLines
        .skip(1)
        .map((l) => l.replaceAll(RegExp(r'^#{1,6}\s*'), ''))
        .join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstLine,
          style: font(
            TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              height: 1.35,
              color: theme.colorScheme.onSurface,
            ),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              remaining,
              style: font(
                TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  letterSpacing: 0.05,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
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
    final primary = theme.colorScheme.primary;
    final isTrashView = _filter == ViewFilter.trash;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final item in items)
          if (item is FolderItem)
            ListTile(
              leading: Icon(
                Icons.folder_rounded,
                color: folderColor(item, primary),
                size: 36,
              ),
              title: Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
              subtitle: Text(
                '${context.l10n.fileCount(_documents.where((d) => d.folderId == item.id && !d.isTrash).length)}'
                ' • ${_formatDate(item.updatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isTrashView)
                    IconButton(
                      icon: Icon(
                        item.isStarred
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: item.isStarred ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () => _toggleFolderStar(item),
                    ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (val) {
                      if (val == 'open') _handleFolderTap(item);
                      if (val == 'rename') _renameFolder(item);
                      if (val == 'color') _changeFolderColor(item);
                      if (val == 'trash') _moveToTrashFolder(item);
                      if (val == 'restore') _restoreFolder(item);
                      if (val == 'delete_perm') _permanentlyDeleteFolder(item);
                    },
                    itemBuilder: (ctx) => item.isTrash
                        ? [
                            PopupMenuItem(
                              value: 'restore',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.restore_from_trash_rounded,
                                    size: 18,
                                    color: primary,
                                  ),
                                  SizedBox(width: 8),
                                  Text(context.l10n.restore),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete_perm',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_forever_rounded,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    context.l10n.deleteForeverBtn,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : [
                            PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.folder_open_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(context.l10n.openFolder),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text(context.l10n.renameFolder),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              key: Key('folder-menu-color'),
                              value: 'color',
                              child: Row(
                                children: [
                                  Icon(Icons.palette_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text(context.l10n.folderColor),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'trash',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    context.l10n.moveToTrash,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                  ),
                ],
              ),
              onTap: () => _handleFolderTap(item),
              onLongPress: () => _showFolderOptions(item),
            )
          else
            ListTile(
              leading: Icon(
                (item as DocumentItem).isTxt
                    ? Icons.text_snippet_rounded
                    : Icons.description_rounded,
                color: item.isTxt ? Colors.teal : primary,
                size: 32,
              ),
              title: Text(
                item.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
              subtitle: Text(
                '${item.isTxt ? context.l10n.textTypeName : "Markdown"} • ${_formatDate(item.updatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SyncStatusBadge(repository: widget.repository, doc: item),
                  if (!isTrashView)
                    IconButton(
                      icon: Icon(
                        item.isStarred
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: item.isStarred ? Colors.amber : Colors.grey,
                      ),
                      onPressed: () => _toggleDocumentStar(item),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (val) {
                      if (val == 'open') _openDocument(item);
                      if (val == 'rename') _renameDocument(item);
                      if (val == 'move') _moveDocument(item);
                      if (val == 'export') _exportDocument(item);
                      if (val == 'sync') _chooseSyncMode(item);
                      if (val == 'trash') _moveToTrashDocument(item);
                      if (val == 'restore') _restoreDocument(item);
                      if (val == 'delete_perm') {
                        _permanentlyDeleteDocument(item);
                      }
                    },
                    itemBuilder: (ctx) => item.isTrash
                        ? [
                            PopupMenuItem(
                              value: 'restore',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.restore_from_trash_rounded,
                                    size: 18,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(context.l10n.restore),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete_perm',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_forever_rounded,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    context.l10n.deleteForeverBtn,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : [
                            PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(context.l10n.openDoc),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text(context.l10n.renameDoc),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'move',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.drive_file_move_outlined,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(context.l10n.moveToFolder),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'export',
                              child: Row(
                                children: [
                                  Icon(Icons.upload_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(context.l10n.export),
                                ],
                              ),
                            ),
                            if (_syncRepository != null)
                              PopupMenuItem(
                                value: 'sync',
                                child: Row(
                                  children: [
                                    Icon(Icons.cloud_sync_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text(context.l10n.syncSettingsMenu),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'trash',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    context.l10n.moveToTrash,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                  ),
                ],
              ),
              onTap: () => _openDocument(item),
              onLongPress: () => _showDocumentOptions(item),
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
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.trashEmptyTitle,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.trashEmptyBody,
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
            Text(
              context.l10n.emptyLibraryTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.emptyLibraryBody,
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
        return context.l10n.filterAll;
      case ViewFilter.starred:
        return context.l10n.filterStarredShort;
      case ViewFilter.foldersOnly:
        return context.l10n.filterFolders;
      case ViewFilter.filesOnly:
        return context.l10n.filterAllDocs;
      case ViewFilter.markdownOnly:
        return 'Markdown';
      case ViewFilter.txtOnly:
        return 'Text (.txt)';
      case ViewFilter.trash:
        return context.l10n.trash;
    }
  }
}
