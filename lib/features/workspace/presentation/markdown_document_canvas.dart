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
  });

  /// Painted on the white page but beneath the text (e.g. highlighter ink).
  final Widget? underlay;
  final String markdown;
  final double height;
  final bool selectable;
  final String? imageDirectory;
  final void Function(String, String?, String?)? onTapLink;
  final Map<String, MarkdownElementBuilder>? builders;

  @override
  Widget build(BuildContext context) {
    final documentTheme = MarkdownDocumentStyle.theme(context);
    final ranges = markdownBlockRanges(markdown);
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
