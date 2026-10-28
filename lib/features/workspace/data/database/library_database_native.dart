import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mnote/features/workspace/data/database/library_database.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the library database in the app documents folder.
LibraryDatabase openLibraryDatabase() {
  return LibraryDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(
        File('${dir.path}/mnote_library.sqlite'),
      );
    }),
  );
}
