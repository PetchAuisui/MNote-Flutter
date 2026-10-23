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
      title: const Text('ลบบัญชี'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'บัญชี ${widget.user.email} และไฟล์ทั้งหมดบน cloud จะถูกลบถาวร '
            'ไฟล์ในเครื่องนี้จะถูกลบด้วย และกู้คืนไม่ได้',
          ),
          const SizedBox(height: 12),
          Text(
            _needsPassword
                ? 'กรอกรหัสผ่านเพื่อยืนยัน'
                : 'ระบบจะให้ยืนยันตัวตนด้วย Google อีกครั้ง',
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
              decoration: const InputDecoration(
                labelText: 'รหัสผ่าน',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          key: const Key('delete-account-confirm'),
          onPressed: _needsPassword && _passwordController.text.isEmpty
              ? null
              : () => Navigator.pop(context, _passwordController.text),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('ลบบัญชีถาวร'),
        ),
      ],
    );
  }
}
