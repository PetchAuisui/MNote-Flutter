import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/ink_page.dart';
import 'package:mnote/features/workspace/presentation/ink_pen.dart';
import 'package:mnote/features/workspace/presentation/stylus_actions.dart';
import 'package:scribble/scribble.dart';

SketchLine _line() => SketchLine(
  color: 0xFF000000,
  width: 2,
  points: [for (var x = 0; x <= 100; x += 2) Point(x.toDouble(), 50)],
);

InkPenNotifier _pen() =>
    InkPenNotifier(sketch: Sketch(lines: [_line()]))
      ..setColor(const Color(0xFF275DAD));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void swipe(
    InkPenNotifier pen, {
    required PointerDeviceKind kind,
    int buttons = kPrimaryButton,
  }) {
    pen.onPointerDown(
      PointerDownEvent(
        pointer: 1,
        kind: kind,
        buttons: buttons,
        position: const Offset(50, 20),
      ),
    );
    pen.onPointerUpdate(
      PointerMoveEvent(
        pointer: 1,
        kind: kind,
        buttons: buttons,
        position: const Offset(50, 80),
      ),
    );
    pen.onPointerUp(
      PointerUpEvent(pointer: 1, kind: kind, position: const Offset(50, 80)),
    );
  }

  test('the eraser end of a stylus erases, then the pen comes back', () {
    final pen = _pen();
    addTearDown(pen.dispose);
    swipe(pen, kind: PointerDeviceKind.invertedStylus);
    expect(pen.currentSketch.lines, hasLength(2));
    expect(pen.value, isA<Drawing>());
    expect((pen.value as Drawing).selectedColor, 0xFF275DAD);
    expect((pen.value as Drawing).activeLine, isNull);

    pen.undo();
    expect(pen.currentSketch.lines, hasLength(1));
    expect(pen.value, isA<Drawing>());
  });

  test('a stylus that leaves without lifting hands the pen back', () {
    final pen = _pen();
    addTearDown(pen.dispose);
    const kind = PointerDeviceKind.invertedStylus;
    pen.onPointerDown(
      const PointerDownEvent(pointer: 1, kind: kind, position: Offset(50, 20)),
    );
    pen.onPointerUpdate(
      const PointerMoveEvent(pointer: 1, kind: kind, position: Offset(50, 80)),
    );
    pen.onPointerExit(
      const PointerExitEvent(pointer: 1, kind: kind, position: Offset(50, 80)),
    );
    expect(pen.currentSketch.lines, hasLength(2));
    expect(pen.value, isA<Drawing>());
    expect(pen.value.activePointerIds, isEmpty);
    expect((pen.value as Drawing).selectedColor, 0xFF275DAD);
  });

  test('holding the stylus side button erases', () {
    final pen = _pen();
    addTearDown(pen.dispose);
    swipe(
      pen,
      kind: PointerDeviceKind.stylus,
      buttons: kPrimaryButton | kPrimaryStylusButton,
    );
    expect(pen.currentSketch.lines, hasLength(2));
    expect(pen.value, isA<Drawing>());
  });

  test('a plain stylus stroke still draws', () {
    final pen = _pen();
    addTearDown(pen.dispose);
    swipe(pen, kind: PointerDeviceKind.stylus);
    expect(pen.currentSketch.lines, hasLength(2));
    expect(pen.currentSketch.lines.last.color, 0xFF275DAD);
  });

  test('stylus gestures pick the tool the person asked for', () {
    expect(
      toolAfterStylusAction(
        StylusAction.switchEraser,
        current: InkTool.highlighter,
        previous: InkTool.pen,
      ),
      InkTool.eraser,
    );
    expect(
      toolAfterStylusAction(
        StylusAction.switchEraser,
        current: InkTool.eraser,
        previous: InkTool.highlighter,
      ),
      InkTool.highlighter,
    );
    expect(
      toolAfterStylusAction(
        StylusAction.switchEraser,
        current: InkTool.eraser,
        previous: InkTool.eraser,
      ),
      InkTool.pen,
    );
    expect(
      toolAfterStylusAction(
        StylusAction.switchPrevious,
        current: InkTool.pen,
        previous: InkTool.highlighter,
      ),
      InkTool.highlighter,
    );
    expect(
      toolAfterStylusAction(
        StylusAction.ignore,
        current: InkTool.pen,
        previous: InkTool.eraser,
      ),
      isNull,
    );
  });

  test('Apple Pencil taps arrive from the platform channel', () async {
    final received = <StylusAction>[];
    final sub = StylusActions.instance.actions.listen(received.add);
    addTearDown(sub.cancel);
    const codec = StandardMethodCodec();
    for (final call in const [
      MethodCall('tap', 'switchEraser'),
      MethodCall('squeeze', 'switchPrevious'),
      MethodCall('tap', 'showColorPalette'),
    ]) {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'mnote/stylus',
            codec.encodeMethodCall(call),
            (_) {},
          );
    }
    await Future<void>.delayed(Duration.zero);
    expect(received, [
      StylusAction.switchEraser,
      StylusAction.switchPrevious,
      StylusAction.ignore,
    ]);
  });
}
