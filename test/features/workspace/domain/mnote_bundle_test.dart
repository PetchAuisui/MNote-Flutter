import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/domain/mnote_bundle.dart';

void main() {
  test('round-trips markdown and ink', () {
    final ink = jsonEncode({
      'format': 'mnote-ink',
      'version': 1,
      'width': 800.0,
      'height': 1400.0,
      'sketch': {'lines': []},
    });
    final bundle = MnoteBundle(name: 'a.md', markdown: '# สวัสดี', ink: ink);

    final decoded = MnoteBundle.decode(bundle.encode());

    expect(decoded.name, 'a.md');
    expect(decoded.markdown, '# สวัสดี');
    expect(jsonDecode(decoded.ink!), jsonDecode(ink));
  });

  test('a note without ink decodes with null ink', () {
    final decoded = MnoteBundle.decode(
      const MnoteBundle(name: 'a.md', markdown: 'hi').encode(),
    );

    expect(decoded.ink, isNull);
  });

  test('rejects files that are not a supported bundle', () {
    Uint8List bytes(Object value) =>
        Uint8List.fromList(utf8.encode(jsonEncode(value)));

    expect(
      () => MnoteBundle.decode(Uint8List.fromList([0xff, 0xfe])),
      throwsFormatException,
    );
    expect(() => MnoteBundle.decode(bytes([1])), throwsFormatException);
    expect(
      () => MnoteBundle.decode(
        bytes({
          'format': 'mnote-bundle',
          'version': 2,
          'name': 'a',
          'markdown': '',
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => MnoteBundle.decode(
        bytes({
          'format': 'mnote-bundle',
          'version': 1,
          'name': 'a',
          'markdown': '',
          'ink': 'nope',
        }),
      ),
      throwsFormatException,
    );
  });

  test('uniqueName keeps a free name and numbers a taken one', () {
    expect(MnoteBundle.uniqueName('a.md', {'b.md'}), 'a.md');
    expect(MnoteBundle.uniqueName('a.md', {'A.md'}), 'a (2).md');
    expect(MnoteBundle.uniqueName('a.md', {'a.md', 'a (2).md'}), 'a (3).md');
  });
}
