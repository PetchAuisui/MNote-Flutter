import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:mnote/core/theme/app_theme.dart';

abstract final class DocumentPageMetrics {
  static const width = 1000.0;
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
  });

  final String markdown;
  final double height;
  final bool selectable;
  final String? imageDirectory;
  final void Function(String, String?, String?)? onTapLink;
  final Map<String, MarkdownElementBuilder>? builders;

  @override
  Widget build(BuildContext context) {
    final appColors = AppTheme.colorScheme(Brightness.light);
    final documentTheme = ThemeData.from(
      colorScheme: appColors,
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: appColors.onSurface,
        displayColor: appColors.onSurface,
      ),
      useMaterial3: true,
    ).copyWith(scaffoldBackgroundColor: Colors.white);
    final colors = documentTheme.colorScheme;
    final markdownStyle = MarkdownStyleSheet.fromTheme(documentTheme).copyWith(
      blockquoteDecoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: colors.primary, width: 4)),
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant, width: 1)),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: ColoredBox(
        key: const Key('markdown-document-page'),
        color: Colors.white,
        child: SizedBox(
          width: DocumentPageMetrics.width,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Theme(
              data: documentTheme,
              child: MarkdownBody(
                key: selectable ? const Key('markdown-preview') : null,
                data: markdown,
                fitContent: false,
                styleSheet: markdownStyle,
                imageDirectory: imageDirectory,
                selectable: selectable,
                onTapLink: onTapLink,
                builders: builders ?? const {},
              ),
            ),
          ),
        ),
      ),
    );
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
    final scale = (_viewportWidth / DocumentPageMetrics.width).clamp(0.1, 4.0);
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1);
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
