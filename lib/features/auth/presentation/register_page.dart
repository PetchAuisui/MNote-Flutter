import 'package:mnote/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:mnote/core/theme/brand_palette.dart';
import 'package:mnote/features/auth/domain/auth_exception.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_validators.dart';
import 'package:mnote/features/auth/presentation/login_page.dart';
import 'package:mnote/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:mnote/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:mnote/features/auth/presentation/widgets/google_sign_in_button.dart';

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
        _error = AuthValidators.messageFor(context.l10n, e);
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.authRepository.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => widget.nextPage),
        (_) => false,
      );
    } catch (error) {
      debugPrint('Google sign-in failed: $error');
      if (!mounted) return;
      final e = error is AuthException
          ? error
          : const AuthException(AuthErrorCode.unknown);
      setState(() {
        _isLoading = false;
        // Cancelling the Google flow is not an error worth showing.
        _error = e.code == AuthErrorCode.cancelled
            ? null
            : AuthValidators.messageFor(context.l10n, e);
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
                      context.l10n.register,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AuthTextField(
                      controller: _name,
                      label: context.l10n.displayNameLabel,
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (v) =>
                          AuthValidators.displayName(context.l10n, v),
                    ),
                    const SizedBox(height: 16),
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
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) =>
                          AuthValidators.password(context.l10n, v),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _confirm,
                      label: context.l10n.confirmPassword,
                      icon: Icons.lock_outline,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) => AuthValidators.confirmPassword(
                        context.l10n,
                        v,
                        _password.text,
                      ),
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
                      label: context.l10n.register,
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFB8CCDD))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            context.l10n.orDivider,
                            style: TextStyle(color: Color(0xFF5A6C80)),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFB8CCDD))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GoogleSignInButton(
                      label: context.l10n.registerWithGoogle,
                      onPressed: _signInWithGoogle,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading ? null : _openLogin,
                      child: Text(context.l10n.haveAccountLogin),
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
