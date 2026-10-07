import 'package:flutter/material.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_validators.dart';
import 'package:mnote/features/auth/presentation/register_page.dart';
import 'package:mnote/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:mnote/features/auth/presentation/widgets/auth_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authRepository,
    required this.nextPage,
  });

  final AuthRepository authRepository;
  final Widget nextPage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.authRepository.signInWithEmail(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => widget.nextPage),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AuthValidators.messageFor(e);
      });
    }
  }

  Future<void> _resetPassword() async {
    final emailError = AuthValidators.email(_email.text);
    if (emailError != null) {
      setState(() => _error = 'กรอกอีเมลก่อนเพื่อรีเซ็ตรหัสผ่าน');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.authRepository.sendPasswordReset(_email.text);
      messenger.showSnackBar(
        const SnackBar(content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลแล้ว')),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = AuthValidators.messageFor(e));
    }
  }

  void _openRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RegisterPage(
          authRepository: widget.authRepository,
          nextPage: widget.nextPage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF3FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'เข้าสู่ระบบ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2B3A),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AuthTextField(
                      controller: _email,
                      label: 'อีเมล',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: AuthValidators.email,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _password,
                      label: 'รหัสผ่าน',
                      icon: Icons.lock_outline,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'กรุณากรอกรหัสผ่าน' : null,
                      onSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: const Text('ลืมรหัสผ่าน?'),
                      ),
                    ),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        key: const Key('auth-error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFD9534F)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    AuthPrimaryButton(
                      label: 'เข้าสู่ระบบ',
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _openRegister,
                      child: const Text('ยังไม่มีบัญชี? สมัครสมาชิก'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
