import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_height_cache.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_html.dart';
import 'package:mnote/features/workspace/presentation/mermaid/mermaid_render_session.dart';

void main() {
  group('MermaidRenderSession', () {
    late MermaidHeightCache cache;
    late MermaidRenderSession session;

    setUp(() {
      cache = MermaidHeightCache();
      session = MermaidRenderSession(heightCache: cache);
    });

    test('stale result from A does not overwrite B or corrupt cache', () {
      final tokenA = session.begin(source: 'graph TD; A-->B', isDark: false);
      final tokenB = session.begin(source: 'graph TD; C-->D', isDark: false);

      // A finishes late with height 300
      final outcomeA = session.handle(MermaidRendered(300, token: tokenA));
      expect(outcomeA, isNull);
      expect(cache.lookup(source: 'graph TD; A-->B', isDark: false), isNull);
      expect(cache.lookup(source: 'graph TD; C-->D', isDark: false), isNull);

      // B finishes with height 500
      final outcomeB = session.handle(MermaidRendered(500, token: tokenB));
      expect(outcomeB, isA<MermaidRenderSucceeded>());
      expect((outcomeB as MermaidRenderSucceeded).height, 500);

      expect(cache.lookup(source: 'graph TD; C-->D', isDark: false), 500);
      expect(cache.lookup(source: 'graph TD; A-->B', isDark: false), isNull);
    });

    test('error from A arriving after begin(B) returns null', () {
      final tokenA = session.begin(source: 'graph TD; A', isDark: false);
      session.begin(source: 'graph TD; B', isDark: false);

      final outcome = session.handle(
        MermaidRenderFailed('Syntax error in A', token: tokenA),
      );
      expect(outcome, isNull);
    });

    test(
      'result from A arriving after B succeeded returns null and cache unaffected',
      () {
        final tokenA = session.begin(source: 'graph TD; A', isDark: false);
        final tokenB = session.begin(source: 'graph TD; B', isDark: false);

        session.handle(MermaidRendered(400, token: tokenB));
        expect(cache.lookup(source: 'graph TD; B', isDark: false), 400);

        final outcomeA = session.handle(MermaidRendered(300, token: tokenA));
        expect(outcomeA, isNull);
        expect(cache.lookup(source: 'graph TD; B', isDark: false), 400);
        expect(cache.lookup(source: 'graph TD; A', isDark: false), isNull);
      },
    );

    test('message without token returns null', () {
      session.begin(source: 'graph TD; A', isDark: false);
      final outcome = session.handle(const MermaidRendered(300, token: null));
      expect(outcome, isNull);
    });

    test('isCurrent correctly identifies active token', () {
      final tokenA = session.begin(source: 'graph TD; A', isDark: false);
      expect(session.isCurrent(tokenA), isTrue);

      final tokenB = session.begin(source: 'graph TD; B', isDark: false);
      expect(session.isCurrent(tokenA), isFalse);
      expect(session.isCurrent(tokenB), isTrue);
    });

    test('clamps height to max 2000 in both outcome and cache', () {
      final token = session.begin(source: 'huge graph', isDark: false);
      final outcome = session.handle(MermaidRendered(5000, token: token));

      expect(outcome, isA<MermaidRenderSucceeded>());
      expect((outcome as MermaidRenderSucceeded).height, 2000);
      expect(cache.lookup(source: 'huge graph', isDark: false), 2000);
    });

    test('stores cache with isDark correctly', () {
      final token = session.begin(source: 'graph TD; Dark', isDark: true);
      session.handle(MermaidRendered(350, token: token));

      expect(cache.lookup(source: 'graph TD; Dark', isDark: true), 350);
      expect(cache.lookup(source: 'graph TD; Dark', isDark: false), isNull);
    });
  });
}
