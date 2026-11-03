import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/ink_page.dart';

void main() {
  testWidgets('highlighter ink tints pictures but leaves black text black', (
    tester,
  ) async {
    const picture = Color(0xFF6496FF);
    const highlight = Color(0x80FFD54F);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: 30,
              height: 10,
              child: Stack(
                children: [
                  // White paper, a picture and a line of black text.
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 10,
                        child: ColoredBox(color: Colors.white),
                      ),
                      SizedBox(width: 10, child: ColoredBox(color: picture)),
                      SizedBox(
                        width: 10,
                        child: ColoredBox(color: Colors.black),
                      ),
                    ],
                  ),
                  const Positioned.fill(
                    child: MultiplyBlend(child: ColoredBox(color: highlight)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final pixels = (await tester.runAsync(() async {
      final image = await render.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    }))!;
    Color at(int x) {
      final i = (5 * 30 + x) * 4;
      return Color.fromARGB(
        255,
        pixels.getUint8(i),
        pixels.getUint8(i + 1),
        pixels.getUint8(i + 2),
      );
    }

    // Paper turns light yellow.
    final paper = at(5);
    expect((paper.r * 255).round(), 255);
    expect((paper.b * 255).round(), lessThan(200));
    // The picture is marked too, not hidden over the ink.
    expect(at(15), isNot(picture));
    expect((at(15).b * 255).round(), lessThan(200));
    // Text stays fully black.
    expect(at(25), const Color(0xFF000000));
  });
}
