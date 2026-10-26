import 'package:mnote/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';

/// Asks the user to confirm deleting their account. Pops with the password
/// typed (empty for Google accounts), or null when cancelled.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.user});

  final AuthUser user;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool get _needsPassword => !widget.user.usesGoogle;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.deleteAccount),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.deleteAccountBody(widget.user.email)),
          const SizedBox(height: 12),
          Text(
            _needsPassword
                ? context.l10n.deleteEnterPassword
                : context.l10n.deleteGoogleReauth,
            style: const TextStyle(fontSize: 13),
          ),
          if (_needsPassword) ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('delete-account-password'),
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.password,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          key: const Key('delete-account-confirm'),
          onPressed: _needsPassword && _passwordController.text.isEmpty
              ? null
              : () => Navigator.pop(context, _passwordController.text),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(context.l10n.deleteForever),
        ),
      ],
    );
  }
}
