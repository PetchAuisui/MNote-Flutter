import 'package:mnote/l10n/l10n.dart';
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
            message: _offReason(context, repo, doc),
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
          message: isSynced
              ? context.l10n.badgeSynced
              : context.l10n.badgePending,
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

  static String _offReason(
    BuildContext context,
    SyncableDocumentRepository repo,
    DocumentItem doc,
  ) {
    if (!repo.settings.enabled) return context.l10n.badgeOffSyncOff;
    if (doc.syncMode == SyncMode.never) return context.l10n.badgeOffNever;
    return context.l10n.badgeOffTooBig;
  }
}
