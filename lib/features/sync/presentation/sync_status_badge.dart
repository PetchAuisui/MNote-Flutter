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
    return ListenableBuilder(
      listenable: Listenable.merge([repo.syncedNames, repo.settings]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        if (!repo.settings.allows(doc)) {
          return Tooltip(
            message: _offReason(repo, doc),
            child: Icon(
              Icons.cloud_off_outlined,
              key: ValueKey('off-${doc.name}'),
              size: 16,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          );
        }
        final isSynced = repo.syncedNames.value.contains(doc.name);
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

  static String _offReason(SyncableDocumentRepository repo, DocumentItem doc) {
    if (!repo.settings.enabled) return 'ปิดการซิงก์อยู่';
    if (doc.syncMode == SyncMode.never) return 'ไฟล์นี้ตั้งเป็นไม่ซิงก์';
    return 'ไฟล์ใหญ่เกิน 900 KB จึงไม่ซิงก์';
  }
}
