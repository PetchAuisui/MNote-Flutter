import 'package:flutter/material.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';
import 'package:mnote/features/auth/presentation/login_page.dart';
import 'package:mnote/features/auth/presentation/register_page.dart';
import 'package:mnote/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:mnote/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:mnote/features/workspace/data/device_document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/features/workspace/presentation/markdown_workspace_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.repository,
    this.animateEntrance = true,
    this.nextPage,
    this.authRepository,
  });

  final DocumentRepository? repository;
  final bool animateEntrance;
  final Widget? nextPage;

  /// Email login/register buttons are shown only when this is provided.
  final AuthRepository? authRepository;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;

  late final AnimationController _entranceController;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    if (widget.animateEntrance) {
      _titleFade = CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOut),
      );
      _titleSlide = Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
        ),
      );

      _subtitleFade = CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOut),
      );
      _subtitleSlide = Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.40, 0.85, curve: Curves.easeOutCubic),
        ),
      );

      _buttonFade = CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      );
      _buttonSlide = Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
        ),
      );

      _entranceController.forward();
    } else {
      _titleFade = const AlwaysStoppedAnimation(1.0);
      _titleSlide = const AlwaysStoppedAnimation(Offset.zero);
      _subtitleFade = const AlwaysStoppedAnimation(1.0);
      _subtitleSlide = const AlwaysStoppedAnimation(Offset.zero);
      _buttonFade = const AlwaysStoppedAnimation(1.0);
      _buttonSlide = const AlwaysStoppedAnimation(Offset.zero);
      _entranceController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // แสดงแจ้งเตือนล็อกอินสำเร็จตามที่ระบุใน requirements
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'ล็อกอินสำเร็จ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4A89DC),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }

    // ดีเลย์เล็กน้อยเพื่อให้ผู้ใช้เห็นข้อความแจ้งเตือน ก่อนนำทางเข้าสู่หน้า workspace
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final repo = widget.repository ??
        const LocalDocumentRepository(DeviceDocumentStorage());

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextPage ?? MarkdownWorkspacePage(repository: repo),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showGoogleComingSoon() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('การเข้าสู่ระบบด้วย Google เร็วๆ นี้'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openEmailFlow(bool register) {
    final auth = widget.authRepository!;
    final next = widget.nextPage ??
        MarkdownWorkspacePage(
          repository: widget.repository ??
              const LocalDocumentRepository(DeviceDocumentStorage()),
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => register
            ? RegisterPage(authRepository: auth, nextPage: next)
            : LoginPage(authRepository: auth, nextPage: next),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF3FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Mnote Logo with Hero shared element animation
                  Hero(
                    tag: 'app-logo',
                    child: Image.asset(
                      'assets/images/logo_transparent.png',
                      width: 230,
                      height: 230,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/logo.png',
                          width: 230,
                          height: 230,
                          fit: BoxFit.contain,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title with fade & slide entrance
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: const Text(
                        'Welcome to Mnote',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2B3A),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Subtitle with fade & slide entrance
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: SlideTransition(
                      position: _subtitleSlide,
                      child: Text(
                        widget.authRepository == null
                            ? 'Log in or create a new account\nusing your Google account.'
                            : 'Log in or create an account\nto start using Mnote.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.45,
                          color: Color(0xFF5A6C80),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 38),
                  if (widget.authRepository == null)
                    // Offline/dev fallback only; main() never reaches this
                    // when Firebase is unavailable.
                    FadeTransition(
                      opacity: _buttonFade,
                      child: SlideTransition(
                        position: _buttonSlide,
                        child: GoogleSignInButton(
                          onPressed: _handleGoogleSignIn,
                          isLoading: _isLoading,
                        ),
                      ),
                    )
                  else
                    FadeTransition(
                      opacity: _buttonFade,
                      child: SlideTransition(
                        position: _buttonSlide,
                        child: Column(
                          children: [
                            GoogleSignInButton(
                              onPressed: _showGoogleComingSoon,
                            ),
                            const SizedBox(height: 16),
                            AuthPrimaryButton(
                              label: 'เข้าสู่ระบบ',
                              onPressed: () => _openEmailFlow(false),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => _openEmailFlow(true),
                              child: const Text('สมัครสมาชิกใหม่'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
