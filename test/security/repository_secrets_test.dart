@Tags(['security'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Security: nothing secret is committed to the repository.
///
/// Firebase client config (the `AIza…` web API keys) is public by design and
/// is only allowed in the files FlutterFire generates, plus the AI app config
/// and the doc that explains why it is safe. Anything that can act as a
/// server (private keys, service accounts) or sign a release must never be in
/// git.
void main() {
  late List<String> tracked;

  setUpAll(() async {
    final result = await Process.run('git', ['ls-files', '-z']);
    expect(result.exitCode, 0, reason: 'git ls-files failed');
    tracked = (result.stdout as String)
        .split('\x00')
        .where((p) => p.isNotEmpty && File(p).existsSync())
        .toList();
    expect(tracked, isNotEmpty);
  });

  Iterable<(String, String)> textFiles() sync* {
    const binary = {
      '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.ttf', '.otf', //
      '.jar', '.pdf', '.zip', '.mnote',
    };
    for (final path in tracked) {
      final dot = path.lastIndexOf('.');
      if (dot != -1 && binary.contains(path.substring(dot).toLowerCase())) {
        continue;
      }
      final String text;
      try {
        text = File(path).readAsStringSync();
      } on FileSystemException {
        continue; // Not UTF-8: not a text file.
      }
      yield (path, text);
    }
  }

  test('no private keys are committed', () {
    final privateKey = RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----');
    final offenders = [
      for (final (path, text) in textFiles())
        if (privateKey.hasMatch(text)) path,
    ];
    expect(offenders, isEmpty);
  });

  test('no service-account credentials are committed', () {
    final serviceAccount = RegExp(r'"type"\s*:\s*"service_account"');
    final offenders = [
      for (final (path, text) in textFiles())
        if (serviceAccount.hasMatch(text)) path,
    ];
    expect(offenders, isEmpty);
  });

  test('Google API keys appear only in Firebase client config', () {
    const allowed = {
      'lib/firebase_options.dart',
      'android/app/google-services.json',
      'ios/Runner/GoogleService-Info.plist',
      'lib/features/assistant/data/ai_firebase_app.dart',
      'docs/ai-assistant.md',
    };
    final apiKey = RegExp(r'AIza[0-9A-Za-z_\-]{35}');
    final offenders = [
      for (final (path, text) in textFiles())
        if (apiKey.hasMatch(text) && !allowed.contains(path)) path,
    ];
    expect(offenders, isEmpty);
  });

  test('no other kinds of API tokens are committed', () {
    final tokens = {
      'GitHub token': RegExp(r'gh[pousr]_[0-9A-Za-z]{36}'),
      'OpenAI key': RegExp(r'sk-[0-9A-Za-z]{32,}'),
      'Anthropic key': RegExp(r'sk-ant-[0-9A-Za-z_\-]{20,}'),
      'AWS access key': RegExp(r'AKIA[0-9A-Z]{16}'),
      'Slack token': RegExp(r'xox[baprs]-[0-9A-Za-z\-]{10,}'),
    };
    final offenders = [
      for (final (path, text) in textFiles())
        for (final MapEntry(:key, :value) in tokens.entries)
          if (value.hasMatch(text)) '$path ($key)',
    ];
    expect(offenders, isEmpty);
  });

  test('signing keys and env files are not committed', () {
    final forbidden = RegExp(
      r'(^|/)(\.env(\..+)?|key\.properties|.+\.(jks|keystore|p12|p8|mobileprovision))$',
    );
    expect(tracked.where(forbidden.hasMatch), isEmpty);
  });
}
