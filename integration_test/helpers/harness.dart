import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/workspace/data/database/library_database.dart';
import 'package:mnote/features/workspace/data/document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';
import 'package:mnote/features/workspace/presentation/workspace_controller.dart';
import 'package:mnote/models/note_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's real storage stack (files on disk + the SQLite library index),
/// pointed at a throw-away folder instead of the app's documents directory.
///
/// Only the folder differs from `DeviceDocumentStorage`, so these tests run
/// the same repository, database and file code the shipped app does, and
/// also run headless in CI where `path_provider` has no platform plugin.
class TempDirStorage implements DocumentStorage {
  TempDirStorage(this.directory) : _db = _open(directory);

  final Directory directory;
  LibraryDatabase _db;

  static LibraryDatabase _open(Directory dir) =>
      LibraryDatabase(NativeDatabase(File('${dir.path}/library.sqlite')));

  /// Closes the database and opens it again from disk, as an app restart
  /// would: anything not really written to the file is lost.
  Future<void> reopen() async {
    await _db.close();
    _db = _open(directory);
  }

  Future<void> close() => _db.close();

  @override
  Future<SelectedDocumentFile?> pickDocument() async => null;

  @override
  Future<Uri?> saveAs({required String name, required Uint8List bytes}) =>
      createDocument(name: name, bytes: bytes);

  @override
  Future<Uri?> createDocument({
    required String name,
    required Uint8List bytes,
  }) async {
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.uri;
  }

  @override
  Future<void> write(Uri uri, Uint8List bytes) =>
      File.fromUri(uri).writeAsBytes(bytes, flush: true);

  @override
  Future<Uint8List?> read(Uri uri) async {
    final file = File.fromUri(uri);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<List<SelectedDocumentFile>> listDocuments() async {
    final result = <SelectedDocumentFile>[];
    for (final file in directory.listSync().whereType<File>()) {
      if (!file.path.endsWith('.md')) continue;
      result.add(
        SelectedDocumentFile(
          name: file.uri.pathSegments.last,
          uri: file.uri,
          bytes: await file.readAsBytes(),
        ),
      );
    }
    return result;
  }

  @override
  Future<void> delete(Uri uri) async {
    final file = File.fromUri(uri);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<Uri> relocate(Uri uri) async => uri;

  @override
  Future<String?> readMetadata() async {
    if (!await _db.isInitialized()) return null;
    return jsonEncode((await _db.loadLibrary()).toJson());
  }

  @override
  Future<void> writeMetadata(String content) => _db.replaceLibrary(
    LibraryMetadata.fromJson(jsonDecode(content) as Map<String, dynamic>),
  );

  /// What the library index on disk holds right now.
  Future<LibraryMetadata> library() => _db.loadLibrary();
}

/// A fresh, empty storage folder, removed when the test ends.
Future<TempDirStorage> createStorage(WidgetTester tester) async {
  final dir = await Directory.systemTemp.createTemp('mnote_it_');
  final storage = TempDirStorage(dir);
  addTearDown(() async {
    await storage.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  return storage;
}

/// Common setup every flow needs: a tablet-sized window, Thai UI (the
/// default for this app), the Markdown editor, and clean preferences.
void prepareDevice(WidgetTester tester, {Size size = const Size(1194, 834)}) {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = const [Locale('th')];
  MarkdownWorkspacePage.defaultMode = WorkspaceMode.split;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

/// Launches the whole app on [storage], already past login.
Future<void> launchApp(WidgetTester tester, TempDirStorage storage) async {
  await tester.pumpWidget(
    MnoteApp(
      // A new key makes Flutter build a new app instead of reusing state,
      // which is what a cold start looks like.
      key: UniqueKey(),
      documentRepository: LocalDocumentRepository(storage),
    ),
  );
  await settle(tester);
}

/// Waits for animations and the real disk/database work to finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await Future<void>.delayed(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}
