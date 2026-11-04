@Tags(['security'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Security: platform and backend config does not open holes.
///
/// The Firebase rules themselves are exercised against the emulator in
/// `test_security_rules/`; this file guards the config around them so a
/// careless edit fails CI instead of shipping.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Android', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');

    test('does not allow plain-HTTP traffic', () {
      expect(manifest, isNot(contains('usesCleartextTraffic="true"')));
    });

    test('is not marked debuggable in the shipped manifest', () {
      expect(manifest, isNot(contains('android:debuggable="true"')));
    });

    test('only the launcher activity is exported', () {
      final exported = RegExp(
        r'android:exported="true"',
      ).allMatches(manifest).length;
      expect(exported, 1);
    });
  });

  group('Apple', () {
    for (final plist in ['ios/Runner/Info.plist', 'macos/Runner/Info.plist']) {
      test('$plist keeps App Transport Security on', () {
        final text = read(plist);
        final arbitrary = RegExp(
          r'<key>NSAllowsArbitraryLoads</key>\s*<true\s*/>',
        );
        expect(arbitrary.hasMatch(text), isFalse);
      });
    }
  });

  group('Firebase rules', () {
    for (final path in ['firestore.rules', 'storage.rules']) {
      final rules = read(path);
      final allows = RegExp(
        r'allow\s+[^:]+:\s*if\s+([^;]+);',
      ).allMatches(rules).map((m) => m[1]!).toList();

      test('$path has rules', () => expect(allows, isNotEmpty));

      test('$path never grants access unconditionally', () {
        expect(rules, isNot(matches(RegExp(r'if\s+true\b'))));
        expect(rules, isNot(matches(RegExp(r'allow\s+[^:;]+;'))));
      });

      test('$path ties every grant to the signed-in owner', () {
        for (final condition in allows) {
          expect(condition, contains('request.auth != null'));
          expect(condition, contains('request.auth.uid == uid'));
        }
      });
    }

    test('Storage size limit matches what the app uploads', () {
      // ImageSyncLimits.maxFileBytes is 1536 KiB; the rule must agree, or
      // uploads the app thinks are fine get rejected (or the reverse).
      expect(
        read('storage.rules'),
        contains('request.resource.size <= 1536 * 1024'),
      );
      expect(
        read('lib/features/sync/domain/image_sync_guard.dart'),
        contains('this.maxFileBytes = 1536 * 1024'),
      );
    });
  });

  group('App Check', () {
    final main = read('lib/main.dart');

    test('debug providers are only used in debug builds', () {
      expect(
        main,
        contains(
          'kDebugMode\n          ? const AndroidDebugProvider()\n          : const AndroidPlayIntegrityProvider()',
        ),
      );
      expect(
        main,
        contains(
          'kDebugMode\n          ? const AppleDebugProvider()\n          : const AppleAppAttestWithDeviceCheckFallbackProvider()',
        ),
      );
    });

    test('no App Check debug token is hard-coded', () {
      expect(main, isNot(contains('debugToken')));
    });
  });
}
