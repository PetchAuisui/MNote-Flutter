import 'package:flutter/material.dart';
import 'package:mnote/features/auth/domain/auth_user.dart';

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
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF4A89DC),
      child: Text(
        accountInitial(user),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radius * 1.0,
        ),
      ),
    );
  }
}

/// App-bar icon showing the user's initial; opens an account dialog.
class AccountAvatarButton extends StatelessWidget {
  const AccountAvatarButton({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final AuthUser user;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'บัญชีของฉัน',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => AccountDialog(user: user, onSignOut: onSignOut),
      ),
      icon: AccountAvatar(user: user),
    );
  }
}

class AccountDialog extends StatelessWidget {
  const AccountDialog({super.key, required this.user, required this.onSignOut});

  final AuthUser user;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName?.trim();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AccountAvatar(user: user, radius: 36),
            const SizedBox(height: 16),
            if (name != null && name.isNotEmpty)
              Text(
                name,
                key: const Key('account-name'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              user.email,
              key: const Key('account-email'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5A6C80)),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ปิด'),
        ),
        TextButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            await onSignOut();
          },
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('ออกจากระบบ'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFD9534F)),
        ),
      ],
    );
  }
}
