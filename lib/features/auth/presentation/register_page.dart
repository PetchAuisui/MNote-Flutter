import 'package:flutter/material.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_validators.dart';
import 'package:mnote/features/auth/presentation/login_page.dart';
import 'package:mnote/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:mnote/features/auth/presentation/widgets/auth_text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.authRepository,
    required this.nextPage,
  });

  final AuthRepository authRepository;
  final Widget nextPage;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.authRepository.registerWithEmail(
        displayName: _name.text,
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

  void _openLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(
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
                      'สมัครสมาชิก',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2B3A),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AuthTextField(
                      controller: _name,
                      label: 'ชื่อที่แสดง',
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: AuthValidators.displayName,
                    ),
                    const SizedBox(height: 16),
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
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: AuthValidators.password,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _confirm,
                      label: 'ยืนยันรหัสผ่าน',
                      icon: Icons.lock_outline,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          AuthValidators.confirmPassword(v, _password.text),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
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
                      label: 'สมัครสมาชิก',
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _openLogin,
                      child: const Text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'),
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
