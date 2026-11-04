import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mnote/features/workspace/data/device_image_picker.dart';
import 'package:mnote/l10n/l10n.dart';

import 'ink_picture.dart';
import 'ink_session.dart';
import 'markdown_rendered_block.dart';

/// Draws the page's free pictures. It sits beneath the ink, so strokes and
/// highlights go over the pictures.
class InkPicturesLayer extends StatelessWidget {
  const InkPicturesLayer({
    super.key,
    required this.pictures,
    this.imageDirectory,
  });

  final List<InkPicture> pictures;
  final String? imageDirectory;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        for (final picture in pictures)
          Positioned.fromRect(
            key: ValueKey('ink-picture-${picture.id}'),
            rect: picture.rect,
            child: MarkdownImage(
              uri: Uri.parse(picture.src),
              directory: imageDirectory,
              width: picture.rect.width,
              height: picture.rect.height,
            ),
          ),
      ],
    ),
  );
}

/// Lets the person pick, move, resize and delete the page's pictures. Shown
/// above the ink while the picture tool is selected; the page still scrolls
/// and zooms when a drag starts away from a picture.
class InkPictureEditor extends StatefulWidget {
  const InkPictureEditor({
    super.key,
    required this.session,
    required this.pageKey,
    required this.scale,
  });

  final InkSession session;

  /// The page the pictures are placed on, to turn pointer positions into page
  /// coordinates whatever the zoom.
  final GlobalKey pageKey;

  /// The page's current zoom, so handles stay finger-sized on screen.
  final double scale;

  @override
  State<InkPictureEditor> createState() => _InkPictureEditorState();
}

class _InkPictureEditorState extends State<InkPictureEditor> {
  Offset? _dragStart;
  Rect? _startRect;

  InkSession get _session => widget.session;

  Offset? _pagePosition(Offset global) {
    final box = widget.pageKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : null;
  }

  void _start(InkPicture picture, DragStartDetails details) {
    _session.selectPicture(picture.id);
    _dragStart = _pagePosition(details.globalPosition);
    _startRect = picture.rect;
  }

  void _startGesture(InkPicture picture, ScaleStartDetails details) {
    _session.selectPicture(picture.id);
    _dragStart = _pagePosition(details.focalPoint);
    _startRect = picture.rect;
  }

  /// One finger moves the picture; a pinch also resizes it, keeping its
  /// shape, so pinching on a picture never zooms the page by surprise.
  void _transformPicture(InkPicture picture, ScaleUpdateDetails details) {
    final start = _dragStart, rect = _startRect;
    final now = _pagePosition(details.focalPoint);
    if (start == null || rect == null || now == null) return;
    final scale = details.pointerCount > 1 ? details.scale : 1.0;
    _session.placePicture(
      picture.id,
      Rect.fromCenter(
        center: rect.center + (now - start),
        width: rect.width * scale,
        height: rect.height * scale,
      ),
    );
  }

  void _resize(InkPicture picture, DragUpdateDetails details) {
    final start = _dragStart, rect = _startRect;
    final now = _pagePosition(details.globalPosition);
    if (start == null || rect == null || now == null) return;
    // Keep the picture's shape; the wider way of dragging wins.
    final aspect = rect.width / rect.height;
    final delta = now - start;
    final grow = delta.dx.abs() > (delta.dy * aspect).abs()
        ? delta.dx
        : delta.dy * aspect;
    // The page keeps the picture within bounds, shape intact.
    final width = math.max(1.0, rect.width + grow);
    _session.placePicture(
      picture.id,
      Rect.fromLTWH(rect.left, rect.top, width, width / aspect),
    );
  }

  void _end() {
    _dragStart = null;
    _startRect = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scale = widget.scale <= 0 ? 1.0 : widget.scale;
    final handle = 32 / scale;
    final border = 2 / scale;
    final pictures = _session.pictures;
    final selected = pictures
        .where((p) => p.id == _session.selectedPicture)
        .firstOrNull;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // A tap on the page away from every picture lets go of the selection.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _session.selectPicture(null),
          ),
        ),
        for (final picture in pictures)
          Positioned.fromRect(
            rect: picture.rect,
            child: GestureDetector(
              key: Key('ink-picture-drag-${picture.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _session.selectPicture(picture.id),
              // Measure from where the finger landed, so the picture doesn't
              // lag behind it by the drag slop.
              dragStartBehavior: DragStartBehavior.down,
              onScaleStart: (d) => _startGesture(picture, d),
              onScaleUpdate: (d) => _transformPicture(picture, d),
              onScaleEnd: (_) => _end(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: picture == selected
                        ? colors.primary
                        : colors.primary.withValues(alpha: 0.35),
                    width: border,
                  ),
                ),
              ),
            ),
          ),
        if (selected != null) ...[
          Positioned(
            left: selected.rect.right - handle / 2,
            top: selected.rect.bottom - handle / 2,
            width: handle,
            height: handle,
            child: GestureDetector(
              key: const Key('ink-picture-resize'),
              behavior: HitTestBehavior.opaque,
              // Measure from where the finger landed, so the picture doesn't
              // lag behind it by the drag slop.
              dragStartBehavior: DragStartBehavior.down,
              onPanStart: (d) => _start(selected, d),
              onPanUpdate: (d) => _resize(selected, d),
              onPanEnd: (_) => _end(),
              onPanCancel: _end,
              child: _Handle(
                color: colors.primary,
                border: border,
                child: Icon(
                  Icons.open_in_full,
                  size: handle * 0.55,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ),
          Positioned(
            left: selected.rect.right - handle / 2,
            top: selected.rect.top - handle / 2,
            width: handle,
            height: handle,
            child: Tooltip(
              message: context.l10n.inkDeletePicture,
              child: GestureDetector(
                key: const Key('ink-picture-delete'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _session.removePicture(selected.id),
                child: _Handle(
                  color: colors.error,
                  border: border,
                  child: Icon(
                    Icons.close,
                    size: handle * 0.6,
                    color: colors.onError,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.color,
    required this.border,
    required this.child,
  });

  final Color color;
  final double border;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: border),
    ),
    child: Center(child: child),
  );
}

/// Lets the person choose a picture, copies it into the note's `images/`
/// folder and places it on the ink page at [center]. Returns whether a
/// picture was added; shows a message when it could not be saved.
Future<bool> insertInkPicture({
  required BuildContext context,
  required InkSession session,
  required DeviceImagePicker picker,
  required String? imageDirectory,
  required Offset center,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = context.l10n.imageSaveFailed;
  final MarkdownImageReference? image;
  try {
    image = await picker.pick(
      documentDirectory: imageDirectory == null
          ? null
          : Uri.parse(imageDirectory),
    );
  } on FileSystemException {
    messenger?.showSnackBar(SnackBar(content: Text(failed)));
    return false;
  }
  if (image == null) return false;
  final size = await _pictureSize(image.uri, imageDirectory);
  session.addPicture(
    image.uri.toString(),
    size: size ?? const Size(400, 300),
    center: center,
  );
  return true;
}

Future<Size?> _pictureSize(Uri uri, String? directory) async {
  try {
    final file = await locateDocumentImage(uri, directory);
    if (file == null) return null;
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = Size(
      descriptor.width.toDouble(),
      descriptor.height.toDouble(),
    );
    descriptor.dispose();
    buffer.dispose();
    return size.isEmpty ? null : size;
  } on Object {
    return null;
  }
}
