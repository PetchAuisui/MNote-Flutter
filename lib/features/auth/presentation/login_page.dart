import 'package:mnote/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:mnote/core/theme/brand_palette.dart';
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
        _error = AuthValidators.messageFor(context.l10n, e);
      });
    }
  }

  Future<void> _resetPassword() async {
    final emailError = AuthValidators.email(context.l10n, _email.text);
    if (emailError != null) {
      setState(() => _error = context.l10n.enterEmailFirst);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await widget.authRepository.sendPasswordReset(_email.text);
      messenger.showSnackBar(SnackBar(content: Text(l.resetLinkSent)));
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _error = AuthValidators.messageFor(l, e));
      }
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
      backgroundColor: BrandPalette.of(context).background,
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
                    Text(
                      context.l10n.login,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AuthTextField(
                      controller: _email,
                      label: context.l10n.email,
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) => AuthValidators.email(context.l10n, v),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _password,
                      label: context.l10n.password,
                      icon: Icons.lock_outline,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: (v) =>
                          (v ?? '').isEmpty ? context.l10n.enterPassword : null,
                      onSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: Text(context.l10n.forgotPassword),
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
                      label: context.l10n.login,
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _openRegister,
                      child: Text(context.l10n.noAccountRegister),
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
