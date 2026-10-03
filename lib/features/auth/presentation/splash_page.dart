import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mnote/features/auth/presentation/auth_page.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.repository,
    this.duration = const Duration(milliseconds: 1800),
    this.nextPage,
  });

  final DocumentRepository? repository;
  final Duration duration;
  final Widget? nextPage;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _navigationTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();

    _navigationTimer = Timer(widget.duration, _navigateToAuth);
  }

  void _navigateToAuth() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _navigationTimer?.cancel();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 850),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AuthPage(
              repository: widget.repository,
              nextPage: widget.nextPage,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB9D7F2),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToAuth,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Hero(
                tag: 'app-logo',
                child: Image.asset(
                  'assets/images/logo_transparent.png',
                  width: 270,
                  height: 270,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/images/logo.png',
                      width: 270,
                      height: 270,
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
