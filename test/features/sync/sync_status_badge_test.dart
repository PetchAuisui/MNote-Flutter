import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/sync/presentation/sync_status_badge.dart';
import 'package:mnote/models/note_item.dart';

import '../../helpers/fake_syncable_repository.dart';
import '../../helpers/fakes.dart';

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
    final repo = FakeSyncableRepository();
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

  testWidgets('shows an off icon when sync is disabled or excluded', (
    tester,
  ) async {
    final repo = FakeSyncableRepository();
    await tester.pumpWidget(host(repo));
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);

    repo.settings.enabled = false;
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

    repo.settings.enabled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncStatusBadge(
            repository: repo,
            doc: doc.copyWith(syncMode: SyncMode.never),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });
}
