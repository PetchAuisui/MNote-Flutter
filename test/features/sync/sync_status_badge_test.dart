import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/sync/domain/syncable_document_repository.dart';
import 'package:mnote/features/sync/presentation/sync_status_badge.dart';
import 'package:mnote/models/note_item.dart';

import '../../helpers/fakes.dart';

class _SyncableFake extends FakeDocumentRepository
    implements SyncableDocumentRepository {
  final synced = ValueNotifier<Set<String>>({});
  @override
  ValueListenable<Set<String>> get syncedNames => synced;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<void> startSync() async {}
  @override
  Future<void> stopSync({bool clearLocal = false}) async {}
}

void main() {
  final doc = DocumentItem(
    id: 'd1',
    name: 'a.md',
    content: '',
    updatedAt: DateTime(2026),
  );

  Widget host(Object repo) => MaterialApp(
    home: Scaffold(
      body: SyncStatusBadge(repository: repo, doc: doc),
    ),
  );

  testWidgets('shows pending then synced state', (tester) async {
    final repo = _SyncableFake();
    await tester.pumpWidget(host(repo));
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);

    repo.synced.value = {'a.md'};
    await tester.pump();
    expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
  });

  testWidgets('hidden when repository does not sync', (tester) async {
    await tester.pumpWidget(host(FakeDocumentRepository()));
    expect(find.byType(Icon), findsNothing);
  });
}
