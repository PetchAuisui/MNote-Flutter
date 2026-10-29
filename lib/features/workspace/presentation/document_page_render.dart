import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'editor_settings.dart';
import 'ink_page.dart';
import 'ink_session.dart';
import 'markdown_document_canvas.dart';
import 'markdown_rendered_block.dart';
import 'markdown_zip_export.dart';
import 'mermaid/mermaid_block.dart';
import 'mermaid/mermaid_height_cache.dart';

/// The whole note page laid out off screen the way the ink page draws it, so
/// it can be exported at full length rather than as a capture of the viewport.
class DocumentPageRender {
  DocumentPageRender._(
    this._entry,
    this._session,
    this._boundary,
    this.size,
    this.breaks,
  );

  final OverlayEntry _entry;
  final InkSession _session;
  final _RenderCaptureBoundary _boundary;

  /// The page in logical pixels; its width is [InkSession.pageWidth].
  final Size size;

  /// Tops of the note's blocks, sorted: a page can break there without
  /// cutting through a line of text.
  final List<double> breaks;

  /// Lays out [markdown] with the [ink] snapshot (an encoded [InkSession])
  /// drawn over it when [includeInk] is set. Call [dispose] when done.
  static Future<DocumentPageRender> render(
    BuildContext context, {
    required String markdown,
    String? ink,
    bool includeInk = true,
    String? imageDirectory,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final session = InkSession();
    if (ink != null) {
      try {
        session.load(ink);
      } on Object {
        // Unreadable ink: export the text on its own.
      }
    }
    await _precacheImages(context, markdown, imageDirectory);

    final showInk = includeInk && session.hasInk;
    final boundaryKey = GlobalKey();
    final blockKeys = <int, GlobalKey>{};
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        // Off screen: laid out and painted, never seen.
        left: -InkSession.pageWidth - 100,
        top: 0,
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: _CaptureBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: InkSession.pageWidth,
                child: Stack(
                  children: [
                    MarkdownDocumentSurface(
                      markdown: markdown,
                      height: showInk ? _inkExtent(session) : 0,
                      selectable: false,
                      blockKeys: blockKeys,
                      textOptions: session.layoutFor(
                        EditorSettings.instance.textOptions,
                      ),
                      imageDirectory: imageDirectory,
                      builders: {'code': _ExportMermaidBuilder()},
                      underlay: showInk
                          ? InkLayer(notifier: session.pen, highlighter: true)
                          : null,
                    ),
                    if (showInk)
                      Positioned.fill(
                        child: InkLayer(
                          notifier: session.pen,
                          highlighter: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await _settle();
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as _RenderCaptureBoundary?;
      if (boundary == null || !boundary.hasSize) {
        throw StateError('The document page was not laid out');
      }
      final breaks = <double>[
        for (final key in blockKeys.values)
          if (key.currentContext?.findRenderObject() case final RenderBox box
              when box.attached && box.hasSize)
            box.localToGlobal(Offset.zero, ancestor: boundary).dy,
      ]..sort();
      return DocumentPageRender._(
        entry,
        session,
        boundary,
        boundary.size,
        breaks,
      );
    } on Object {
      entry
        ..remove()
        ..dispose();
      session.dispose();
      rethrow;
    }
  }

  /// [region] of the page, in logical pixels, as a picture.
  Future<ui.Image> capture(Rect region, double pixelRatio) =>
      _boundary.capture(region, pixelRatio);

  void dispose() {
    _entry
      ..remove()
      ..dispose();
    _session.dispose();
  }

  /// Ink can reach below the text, so the page must be at least this tall.
  static double _inkExtent(InkSession session) {
    var extent = 0.0;
    for (final line in session.pen.currentSketch.lines) {
      for (final point in line.points) {
        extent = math.max(extent, point.y + line.width);
      }
    }
    return extent;
  }

  /// Loads the note's pictures first, so they are on the page when it is
  /// captured instead of the empty space shown while they load.
  static Future<void> _precacheImages(
    BuildContext context,
    String markdown,
    String? imageDirectory,
  ) async {
    final loads = <Future<void>>[];
    for (final uri in markdownImageUris(markdown).toSet()) {
      if (uri.scheme == 'data' || uri.scheme == 'resource') continue;
      final ImageProvider? provider;
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        provider = NetworkImage(uri.toString());
      } else {
        final file = await locateDocumentImage(uri, imageDirectory);
        provider = file == null ? null : FileImage(file);
      }
      if (provider != null && context.mounted) {
        loads.add(
          precacheImage(
            provider,
            context,
            onError: (_, _) {},
          ).timeout(const Duration(seconds: 10), onTimeout: () {}),
        );
      }
    }
    await Future.wait(loads);
  }

  /// Waits until the page has stopped changing: its pictures and fonts have
  /// loaded and no more frames are coming.
  static Future<void> _settle() async {
    final binding = SchedulerBinding.instance;
    binding.scheduleFrame();
    var quiet = 0;
    for (var i = 0; i < 60 && quiet < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (i == 1) {
        await GoogleFonts.pendingFonts().timeout(
          const Duration(seconds: 5),
          onTimeout: () => const [],
        );
        binding.scheduleFrame();
      }
      if (binding.hasScheduledFrame) {
        quiet = 0;
        await binding.endOfFrame;
      } else {
        quiet++;
      }
    }
  }
}

/// A repaint boundary that can picture any part of its child, so a long page
/// is captured in slices no GPU texture limit can refuse.
class _CaptureBoundary extends SingleChildRenderObjectWidget {
  const _CaptureBoundary({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCaptureBoundary();
}

class _RenderCaptureBoundary extends RenderRepaintBoundary {
  Future<ui.Image> capture(Rect region, double pixelRatio) =>
      (layer! as OffsetLayer).toImage(region, pixelRatio: pixelRatio);
}

/// Mermaid diagrams are drawn by a web view, which a picture of the page
/// cannot include. The export keeps the space the diagram takes on screen,
/// so ink drawn below it stays in place, and shows the diagram's source.
class _ExportMermaidBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (!isMermaidCodeClass(element.attributes['class'])) return null;
    final source = normalizeMermaidSource(element.textContent);
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        source,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    final height = defaultMermaidHeightCache.lookup(
      isDark: Theme.of(context).brightness == Brightness.dark,
      source: source,
    );
    if (height == null) return box;
    return SizedBox(
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: box,
        ),
      ),
    );
  }
}

typedef PageSpan = ({double top, double bottom});

/// Splits a page [total] tall into spans no taller than [pageHeight]. Each
/// span ends at the last of [breaks] that fits, so a line of text is not cut
/// in two, unless that would leave the span less than a third full.
List<PageSpan> paginate(double total, double pageHeight, List<double> breaks) {
  final spans = <PageSpan>[];
  var top = 0.0;
  while (total - top > 0.5) {
    var bottom = math.min(top + pageHeight, total);
    if (bottom < total) {
      final fit = breaks.lastWhere(
        (b) => b > top + pageHeight / 3 && b <= bottom,
        orElse: () => bottom,
      );
      bottom = fit;
    }
    spans.add((top: top, bottom: bottom));
    top = bottom;
  }
  return spans;
}

/// The tallest slice captured at once, in device pixels.
const _maxSlicePixels = 4096.0;

/// Resolution of the pictures in an exported PDF: about 240 dpi on A4.
const _pdfPixelRatio = 2.0;

/// White space between the edge of a PDF page and the note on it, in points:
/// half an inch (about 1.27 cm) on every side.
const pdfPageMargin = 36.0;

/// Builds a PDF of [page]. A4 pages break between blocks; [continuous]
/// keeps the note on one long page (split only past PDF's 200-inch limit).
Future<Uint8List> buildDocumentPdf(
  DocumentPageRender page, {
  required bool continuous,
}) async {
  const a4 = PdfPageFormat.a4;
  const margin = pdfPageMargin;
  const maxPdfPageHeight = 14400.0;
  final contentWidth = a4.width - 2 * margin;
  final scale = contentWidth / page.size.width;
  final contentHeight =
      ((continuous ? maxPdfPageHeight : a4.height) - 2 * margin) / scale;
  const sliceHeight = _maxSlicePixels / _pdfPixelRatio;

  final pdf = pw.Document();
  for (final span in paginate(page.size.height, contentHeight, page.breaks)) {
    final slices = <pw.Widget>[];
    for (var top = span.top; top < span.bottom - 0.5; top += sliceHeight) {
      final bottom = math.min(top + sliceHeight, span.bottom);
      final image = await page.capture(
        Rect.fromLTRB(0, top, page.size.width, bottom),
        _pdfPixelRatio,
      );
      final rgba = await image.toByteData();
      slices.add(
        pw.Image(
          pw.RawImage(
            bytes: rgba!.buffer.asUint8List(),
            width: image.width,
            height: image.height,
          ),
          width: contentWidth,
          height: (bottom - top) * scale,
          fit: pw.BoxFit.fill,
        ),
      );
      image.dispose();
    }
    pdf.addPage(
      pw.Page(
        pageFormat: continuous
            ? PdfPageFormat(
                a4.width,
                (span.bottom - span.top) * scale + 2 * margin,
              )
            : a4,
        margin: const pw.EdgeInsets.all(margin),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: slices,
        ),
      ),
    );
  }
  return pdf.save();
}
