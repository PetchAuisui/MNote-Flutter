import 'package:mnote/l10n/l10n.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mnote/core/theme/brand_palette.dart';
import 'package:mnote/features/workspace/data/device_document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/screens/note_list_screen.dart';

/// หน้าแนะนำการใช้งาน Mnote (3 หน้า)
/// แสดงผลแบบ Presentation Carousel มีเอฟเฟกต์เบลอที่การ์ดด้านข้าง
/// และมีปุ่ม "ข้าม" กับ "เข้าสู่ Mnote" เพื่อนำทางไปยัง NoteListScreen
class AppGuidePage extends StatefulWidget {
  const AppGuidePage({super.key, this.repository, this.nextPage});

  final DocumentRepository? repository;
  final Widget? nextPage;

  @override
  State<AppGuidePage> createState() => _AppGuidePageState();
}

class _AppGuidePageState extends State<AppGuidePage> {
  late final PageController _pageController;
  int _currentPage = 0;
  double _pageOffset = 0.0;

  List<_GuideItem> get _guides => [
    _GuideItem(
      step: '01',
      title: context.l10n.guide1Title,
      description: context.l10n.guide1Body,
      featureLabel: 'Markdown Editor',
      icon: Icons.edit_note_rounded,
      badgeColor: Color(0xFF4A89DC),
      accentTone: 1,
    ),
    _GuideItem(
      step: '02',
      title: context.l10n.guide2Title,
      description: context.l10n.guide2Body,
      featureLabel: 'Ink & Stylus Drawing',
      icon: Icons.draw_rounded,
      badgeColor: Color(0xFF5C9BD1),
      accentTone: 2,
    ),
    _GuideItem(
      step: '03',
      title: context.l10n.guide3Title,
      description: context.l10n.guide3Body,
      featureLabel: 'Mermaid & Live Preview',
      icon: Icons.account_tree_rounded,
      badgeColor: Color(0xFF388E3C),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.76);
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        setState(() {
          _pageOffset = _pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToNext() {
    final repo =
        widget.repository ??
        const LocalDocumentRepository(DeviceDocumentStorage());
    final destination = widget.nextPage ?? NoteListScreen(repository: repo);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _onNextPressed() {
    if (_currentPage < _guides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _navigateToNext();
    }
  }

  void _onPrevPressed() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLastPage = _currentPage == _guides.length - 1;
    final palette = BrandPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header Area: Title & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center Title
                  Center(
                    child: Text(
                      context.l10n.guideTitle,
                      key: Key('app-guide-title'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: palette.headline,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  // Top Right Skip Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('app-guide-skip-button'),
                        onTap: _navigateToNext,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.mid,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: palette.mid.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            context.l10n.guideSkip,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Middle Carousel Area with Background Strip
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Horizontal decorative strip matching mockup
                  Container(
                    width: double.infinity,
                    height: size.height * 0.44,
                    color: palette.soft.withValues(alpha: 0.7),
                  ),

                  // Presentation PageView
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _guides.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _guides[index];
                      // Calculate distance from center to control scale, blur and opacity
                      final diff = (_pageOffset - index).abs();
                      final isCurrent = (_currentPage == index);

                      // Interpolated visual values
                      final scale = (1.0 - (diff * 0.12)).clamp(0.86, 1.0);
                      final opacity = (1.0 - (diff * 0.4)).clamp(0.5, 1.0);
                      final blurSigma = (diff * 5.5).clamp(0.0, 6.0);

                      Widget cardContent = _buildCard(
                        item,
                        isCurrent: isCurrent,
                      );

                      // Apply blur to side cards as requested: "ส่วนข้างที่สีมนๆ ทำเบลอข้อมูล"
                      if (blurSigma > 0.1) {
                        cardContent = ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: blurSigma,
                            sigmaY: blurSigma,
                          ),
                          child: cardContent,
                        );
                      }

                      return Center(
                        child: Transform.scale(
                          scale: scale,
                          child: Opacity(opacity: opacity, child: cardContent),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Navigation Controls: [◀] [Dots / "เข้าสู่ Mnote"] [▶]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous Arrow
                      IconButton(
                        key: const Key('app-guide-prev-button'),
                        onPressed: _currentPage > 0 ? _onPrevPressed : null,
                        icon: Icon(
                          Icons.arrow_left_rounded,
                          size: 42,
                          color: _currentPage > 0
                              ? palette.mid
                              : Colors.black26,
                        ),
                        splashRadius: 26,
                        tooltip: context.l10n.guidePrev,
                      ),

                      const SizedBox(width: 12),

                      // Indicators or "เข้าสู่ Mnote" button
                      if (!isLastPage) ...[
                        // Page Indicator Dots
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_guides.length, (i) {
                            final isActive = i == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? palette.mid
                                    : palette.softBorder,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        // Next Arrow
                        IconButton(
                          key: const Key('app-guide-next-button'),
                          onPressed: _onNextPressed,
                          icon: Icon(
                            Icons.arrow_right_rounded,
                            size: 42,
                            color: palette.mid,
                          ),
                          splashRadius: 26,
                          tooltip: context.l10n.guideNext,
                        ),
                      ] else ...[
                        // Last Page: "เข้าสู่ Mnote" Prominent Button
                        ElevatedButton.icon(
                          key: const Key('app-guide-enter-button'),
                          onPressed: _navigateToNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.primary,
                            foregroundColor: palette.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: palette.primary.withValues(alpha: 0.4),
                          ),
                          icon: Text(
                            context.l10n.guideStart,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          label: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_GuideItem item, {required bool isCurrent}) {
    final palette = BrandPalette.of(context);
    final badge = switch (item.accentTone) {
      1 => palette.primary,
      2 => palette.mid,
      _ => item.badgeColor,
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 380),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isCurrent ? 0.10 : 0.05),
            blurRadius: isCurrent ? 18 : 10,
            offset: Offset(0, isCurrent ? 8 : 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Side: Content & Description
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Step Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badge.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.l10n.guideStep(item.step),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: badge,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.headline,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                // Description
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Right Side: Graphic/Preview Box matching mockup
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.softBorder, width: 1),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(item.icon, size: 34, color: badge),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        item.featureLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF63778F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideItem {
  final String step;
  final String title;
  final String description;
  final String featureLabel;
  final IconData icon;
  final Color badgeColor;

  /// 0 = fixed [badgeColor]; 1 = follows the accent primary; 2 = accent mid-tone.
  final int accentTone;

  const _GuideItem({
    required this.step,
    required this.title,
    required this.description,
    required this.featureLabel,
    required this.icon,
    required this.badgeColor,
    this.accentTone = 0,
  });
}
