import 'package:mnote/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:mnote/core/theme/brand_palette.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';
import 'package:mnote/features/auth/domain/auth_validators.dart';
import 'package:mnote/features/auth/presentation/widgets/delete_account_dialog.dart';

String accountInitial(AuthUser user) {
  final source = (user.displayName?.trim().isNotEmpty ?? false)
      ? user.displayName!.trim()
      : user.email.trim();
  // Skip Thai leading vowels (เ แ โ ใ ไ) so "เพชร" shows "พ", and drop
  // combining marks so "สิ" shows "ส".
  for (final cluster in source.characters) {
    final first = cluster.runes.first;
    if (first >= 0x0E40 && first <= 0x0E44) continue;
    final isThai = first >= 0x0E00 && first <= 0x0E7F;
    return (isThai ? String.fromCharCode(first) : cluster).toUpperCase();
  }
  return '?';
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.user, this.radius = 16});

  final AuthUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final palette = BrandPalette.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.primary,
      // The initial underneath stays visible if the photo fails to load.
      foregroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Text(
        accountInitial(user),
        style: TextStyle(
          color: palette.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: radius * 1.0,
        ),
      ),
    );
  }
}

class AccountDialog extends StatefulWidget {
  const AccountDialog({
    super.key,
    required this.user,
    required this.authRepository,
    this.onDeleteAccount,
  });

  final AuthUser user;
  final AuthRepository authRepository;

  /// Deletes the account; receives the password for email accounts.
  final Future<void> Function(String password)? onDeleteAccount;

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  late AuthUser _user = widget.user;
  bool _editing = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  late final _nameController = TextEditingController(text: _user.displayName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? get _memberSince {
    final d = _user.createdAt;
    if (d == null) return null;
    return context.l10n.shortDate(d);
  }

  String get _providerLabel {
    if (_user.usesGoogle) return context.l10n.providerGoogle;
    if (_user.usesPassword) return context.l10n.providerEmail;
    return context.l10n.providerMnote;
  }

  void _setMessage(String text, {bool error = false}) => setState(() {
    _message = text;
    _messageIsError = error;
  });

  Future<void> _saveName() async {
    final error = AuthValidators.displayName(
      context.l10n,
      _nameController.text,
    );
    if (error != null) return _setMessage(error, error: true);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final updated = await widget.authRepository.updateDisplayName(
        _nameController.text,
      );
      if (!mounted) return;
      setState(() {
        _user = updated;
        _editing = false;
        _busy = false;
      });
      _setMessage(context.l10n.nameSaved);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _setMessage(AuthValidators.messageFor(context.l10n, e), error: true);
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.authRepository.sendPasswordReset(_user.email);
      if (!mounted) return;
      setState(() => _busy = false);
      _setMessage(context.l10n.resetLinkSentTo(_user.email));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _setMessage(AuthValidators.messageFor(context.l10n, e), error: true);
    }
  }

  Future<void> _confirmDelete() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => DeleteAccountDialog(user: _user),
    );
    if (password == null || !mounted) return;
    Navigator.of(context).pop();
    await widget.onDeleteAccount!(password);
  }

  @override
  Widget build(BuildContext context) {
    final name = _user.displayName?.trim();
    final since = _memberSince;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AccountAvatar(user: _user, radius: 40),
              const SizedBox(height: 16),
              if (_editing)
                TextField(
                  key: const Key('account-name-field'),
                  controller: _nameController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveName(),
                  decoration: InputDecoration(
                    labelText: context.l10n.displayNameLabel,
                    border: OutlineInputBorder(),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        (name != null && name.isNotEmpty)
                            ? name
                            : context.l10n.noName,
                        key: const Key('account-name'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('account-edit-name'),
                      tooltip: context.l10n.editName,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => setState(() {
                        _nameController.text = _user.displayName ?? '';
                        _editing = true;
                        _message = null;
                      }),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                _user.email,
                key: const Key('account-email'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5A6C80)),
              ),
              const SizedBox(height: 14),
              Chip(
                avatar: _user.usesGoogle
                    ? Image.asset(
                        'assets/images/google_logo.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.account_circle, size: 18),
                      )
                    : const Icon(Icons.mail_outline, size: 18),
                label: Text(_providerLabel),
                visualDensity: VisualDensity.compact,
              ),
              if (since != null) ...[
                const SizedBox(height: 6),
                Text(
                  context.l10n.memberSince(since),
                  key: const Key('account-since'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A6C80),
                  ),
                ),
              ],
              if (_user.usesPassword && !_editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('account-reset-password'),
                  onPressed: _busy ? null : _resetPassword,
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: Text(context.l10n.changePasswordByEmail),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  key: const Key('account-message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _messageIsError
                        ? const Color(0xFFD9534F)
                        : const Color(0xFF3C9A5F),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: _editing
          ? [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _editing = false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                key: const Key('account-save-name'),
                onPressed: _busy ? null : _saveName,
                child: Text(context.l10n.save),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.close),
              ),
              if (widget.onDeleteAccount != null)
                TextButton.icon(
                  key: const Key('account-delete'),
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                  label: Text(context.l10n.deleteAccount),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD9534F),
                  ),
                ),
            ],
    );
  }
}
