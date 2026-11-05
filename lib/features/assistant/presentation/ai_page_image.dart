import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../workspace/presentation/document_page_render.dart';

/// พิกเซลสูงสุดของรูปที่ส่งให้ AI รูปเล็กกว่าการส่งออกมาก ส่งเร็วและไม่เกินขนาดคำขอ
const _maxPixels = 4e6;

/// ความสูงสูงสุดของรูปเดียว (ข้อจำกัด texture ของ GPU)
const _maxHeight = 4096.0;

/// วาดหน้าโน้ตพร้อมลายมือเป็น PNG ให้ AI อ่าน ใช้ตัววาดเดียวกับการส่งออก
/// โน้ตยาวมากจะถูกย่อ ลายมือท้ายโน้ตอาจเล็กจนอ่านยาก
Future<Uint8List> renderNotePageForAi(
  BuildContext context, {
  required String markdown,
  required String ink,
  String? imageDirectory,
}) async {
  final page = await DocumentPageRender.render(
    context,
    markdown: markdown,
    ink: ink,
    imageDirectory: imageDirectory,
  );
  try {
    final size = page.size;
    final ratio = math.min(
      1.5,
      math.min(
        _maxHeight / size.height,
        math.sqrt(_maxPixels / (size.width * size.height)),
      ),
    );
    final image = await page.capture(Offset.zero & size, ratio);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return png!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    page.dispose();
  }
}
