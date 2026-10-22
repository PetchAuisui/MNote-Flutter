import 'package:flutter/material.dart';
import 'package:mnote/features/sync/domain/syncable_document_repository.dart';
import 'package:mnote/models/note_item.dart';

/// Small cloud icon showing whether a document is saved to the account.
/// Renders nothing when the repository does not sync.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({
    super.key,
    required this.repository,
    required this.doc,
  });

  final Object repository;
  final DocumentItem doc;

  @override
  Widget build(BuildContext context) {
    final repo = repository;
    if (repo is! SyncableDocumentRepository ||
        doc.id == 'welcome_initial_doc') {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<Set<String>>(
      valueListenable: repo.syncedNames,
      builder: (context, synced, _) {
        final isSynced = synced.contains(doc.name);
        final scheme = Theme.of(context).colorScheme;
        return Tooltip(
          message: isSynced ? 'Sync แล้ว' : 'รอ sync',
          child: Icon(
            isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_outlined,
            key: ValueKey(
              isSynced ? 'synced-${doc.name}' : 'pending-${doc.name}',
            ),
            size: 16,
            color: isSynced ? scheme.primary : scheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
