import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'markdown_document_style.dart';
import 'markdown_rendered_block.dart';

abstract final class DocumentPageMetrics {
  static const width = MarkdownDocumentStyle.maxWidth + 48;
  static const initialHeight = 2400.0;
}

class MarkdownDocumentSurface extends StatelessWidget {
  const MarkdownDocumentSurface({
    super.key,
    required this.markdown,
    required this.height,
    required this.selectable,
    this.imageDirectory,
    this.onTapLink,
    this.builders,
    this.underlay,
    this.blockKeys,
    this.textOptions = const DocumentTextOptions(),
  });

  /// When given, each block is keyed by its source offset so a caller can find
  /// where a block was laid out (the outline uses this to jump to headings).
  final Map<int, GlobalKey>? blockKeys;

  /// Painted on the white page but beneath the text (e.g. highlighter ink).
  final Widget? underlay;
  final String markdown;
  final double height;
  final bool selectable;
  final String? imageDirectory;
  final void Function(String, String?, String?)? onTapLink;
  final Map<String, MarkdownElementBuilder>? builders;
  final DocumentTextOptions textOptions;

  Widget _keyed(int start, Widget block) {
    final keys = blockKeys;
    if (keys == null) return block;
    return KeyedSubtree(
      key: keys.putIfAbsent(start, GlobalKey.new),
      child: block,
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentTheme = MarkdownDocumentStyle.theme(context);
    final ranges = markdownBlockRanges(markdown);
    if (blockKeys case final keys?) {
      final starts = {for (final range in ranges) range.start};
      keys.removeWhere((start, _) => !starts.contains(start));
    }
    final blockContext = MarkdownBlockContext(markdown, ranges);
    final surface = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: ColoredBox(
        key: const Key('markdown-document-page'),
        color: Colors.white,
        child: SizedBox(
          width: DocumentPageMetrics.width,
          child: Stack(
            children: [
              if (underlay != null) Positioned.fill(child: underlay!),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Theme(
                  data: documentTheme,
                  child: Column(
                    key: selectable ? const Key('markdown-preview') : null,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final range in ranges)
                        _keyed(
                          range.start,
                          MarkdownRenderedBlock(
                            markdown: range.textInside(markdown),
                            references: blockContext.references,
                            orderedNumber:
                                blockContext.orderedNumbers[range.start],
                            theme: documentTheme,
                            imageDirectory: imageDirectory,
                            selectable: selectable,
                            onTapLink: onTapLink,
                            builders: builders ?? const {},
                            textOptions: textOptions,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return selectable ? surface : IgnorePointer(child: surface);
  }
}

class MarkdownPreviewCanvas extends StatefulWidget {
  const MarkdownPreviewCanvas({
    super.key,
    required this.markdown,
    required this.height,
    this.imageDirectory,
    this.onTapLink,
    this.builders,
  });

  final String markdown;
  final double height;
  final String? imageDirectory;
  final void Function(String, String?, String?)? onTapLink;
  final Map<String, MarkdownElementBuilder>? builders;

  @override
  State<MarkdownPreviewCanvas> createState() => _MarkdownPreviewCanvasState();
}

class _MarkdownPreviewCanvasState extends State<MarkdownPreviewCanvas> {
  final _transform = TransformationController();
  double _viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_clampHorizontal);
  }

  /// Keeps the page horizontally centred (or edge-clamped when zoomed in).
  void _clampHorizontal() {
    if (_viewportWidth <= 0) return;
    final value = _transform.value;
    final scaledWidth = DocumentPageMetrics.width * value.getMaxScaleOnAxis();
    final tx = value.getTranslation().x;
    final target = scaledWidth <= _viewportWidth
        ? (_viewportWidth - scaledWidth) / 2
        : tx.clamp(_viewportWidth - scaledWidth, 0.0);
    if ((target - tx).abs() < 0.01) return;
    _transform.value = value.clone()
      ..setTranslationRaw(target, value.getTranslation().y, 0);
  }

  void _fit() {
    final scale = (_viewportWidth / DocumentPageMetrics.width).clamp(0.1, 1.0);
    final dx = _viewportWidth > DocumentPageMetrics.width
        ? (_viewportWidth - DocumentPageMetrics.width) / 2
        : 0.0;
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(dx, 0, 0);
  }

  @override
  void dispose() {
    _transform.removeListener(_clampHorizontal);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_viewportWidth != constraints.maxWidth) {
          _viewportWidth = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit();
          });
        }
        return InteractiveViewer(
          transformationController: _transform,
          constrained: false,
          alignment: Alignment.topLeft,
          // Open the sides so the page can be zoomed out to the fitted state
          // on a viewport wider than the page; _clampHorizontal keeps it
          // centred or edge-clamped.
          boundaryMargin: const EdgeInsets.symmetric(horizontal: 10000),
          minScale: 0.1,
          maxScale: 4,
          child: SizedBox(
            width: DocumentPageMetrics.width,
            child: MarkdownDocumentSurface(
              markdown: widget.markdown,
              height: widget.height,
              selectable: true,
              imageDirectory: widget.imageDirectory,
              onTapLink: widget.onTapLink,
              builders: widget.builders,
            ),
          ),
        );
      },
    );
  }
}
