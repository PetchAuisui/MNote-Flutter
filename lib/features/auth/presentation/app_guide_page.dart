import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mnote/features/workspace/data/device_document_storage.dart';
import 'package:mnote/features/workspace/data/local_document_repository.dart';
import 'package:mnote/features/workspace/domain/document_repository.dart';
import 'package:mnote/screens/note_list_screen.dart';

/// หน้าแนะนำการใช้งาน Mnote (3 หน้า)
/// แสดงผลแบบ Presentation Carousel มีเอฟเฟกต์เบลอที่การ์ดด้านข้าง
/// และมีปุ่ม "ข้าม" กับ "เข้าสู่ Mnote" เพื่อนำทางไปยัง NoteListScreen
class AppGuidePage extends StatefulWidget {
  const AppGuidePage({
    super.key,
    this.repository,
    this.nextPage,
  });

  final DocumentRepository? repository;
  final Widget? nextPage;

  @override
  State<AppGuidePage> createState() => _AppGuidePageState();
}

class _AppGuidePageState extends State<AppGuidePage> {
  late final PageController _pageController;
  int _currentPage = 0;
  double _pageOffset = 0.0;

  final List<_GuideItem> _guides = const [
    _GuideItem(
      step: '01',
      title: 'เขียนและจัดรูปแบบ Markdown',
      description:
          'เขียนโน้ตได้อย่างรวดเร็วด้วยไวยากรณ์ Markdown รองรับหัวข้อ Heading, To-do list, ตัวหนา, ตัวเอียง พร้อมแถบเครื่องมือด่วนที่ช่วยจัดรูปแบบได้ทันที',
      featureLabel: 'Markdown Editor',
      icon: Icons.edit_note_rounded,
      badgeColor: Color(0xFF4A89DC),
    ),
    _GuideItem(
      step: '02',
      title: 'วาดเขียน & จดโน้ตด้วยปากกา',
      description:
          'ขีดเขียน ไฮไลต์ข้อความ และวาดภาพประกอบลงบนเอกสารได้อย่างอิสระ ด้วยระบบหมึกดิจิทัล (Ink & Stylus) ที่ตอบสนองแม่นยำ พร้อมยางลบและตัวเลือกสีครบครัน',
      featureLabel: 'Ink & Stylus Drawing',
      icon: Icons.draw_rounded,
      badgeColor: Color(0xFF5C9BD1),
    ),
    _GuideItem(
      step: '03',
      title: 'สร้างไดอะแกรม Mermaid ทันใจ',
      description:
          'แปลงข้อความโค้ด Mermaid เป็นแผนผัง Flowchart และไดอะแกรมสวยงาม พร้อมระบบพรีวิวเอกสารแบบเรียลไทม์ควบคู่กับการเขียน',
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
    final repo = widget.repository ??
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

    return Scaffold(
      backgroundColor: const Color(0xFFEBF3FA),
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
                  const Center(
                    child: Text(
                      'คู่มือการใช้ Mnote',
                      key: Key('app-guide-title'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A5F),
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
                            color: const Color(0xFF5B8CB9),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5B8CB9).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text(
                            'ข้าม',
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
                    color: const Color(0xFFDCE8F5).withValues(alpha: 0.7),
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

                      Widget cardContent = _buildCard(item, isCurrent: isCurrent);

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
                          child: Opacity(
                            opacity: opacity,
                            child: cardContent,
                          ),
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
                              ? const Color(0xFF5B8CB9)
                              : Colors.black26,
                        ),
                        splashRadius: 26,
                        tooltip: 'หน้าก่อนหน้า',
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
                                    ? const Color(0xFF5B8CB9)
                                    : const Color(0xFFB0C7DE),
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
                          icon: const Icon(
                            Icons.arrow_right_rounded,
                            size: 42,
                            color: Color(0xFF5B8CB9),
                          ),
                          splashRadius: 26,
                          tooltip: 'หน้าถัดไป',
                        ),
                      ] else ...[
                        // Last Page: "เข้าสู่ Mnote" Prominent Button
                        ElevatedButton.icon(
                          key: const Key('app-guide-enter-button'),
                          onPressed: _navigateToNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A89DC),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF4A89DC).withValues(alpha: 0.4),
                          ),
                          icon: const Text(
                            'เข้าสู่ Mnote',
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      constraints: const BoxConstraints(
        maxWidth: 680,
        maxHeight: 380,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    color: item.badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ขั้นตอน ${item.step} / 03',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.badgeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                // Description
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF5A6E85),
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
                color: const Color(0xFFE2E7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.04),
                  width: 1,
                ),
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
                      child: Icon(
                        item.icon,
                        size: 34,
                        color: item.badgeColor,
                      ),
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

  const _GuideItem({
    required this.step,
    required this.title,
    required this.description,
    required this.featureLabel,
    required this.icon,
    required this.badgeColor,
  });
}
