import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/ai_assistant_flow.dart' as ai_assistant;
import 'flows/login_flow.dart' as login;
import 'flows/note_lifecycle_flow.dart' as note_lifecycle;

/// One entry point for every end-to-end flow.
///
/// A device (including the headless `flutter-tester` used in CI) starts the
/// app once per test file, so all flows run from this single file.
///
/// Headless, as in CI: `flutter test integration_test -d flutter-tester`
/// On an iPad or Simulator: `flutter test integration_test -d DEVICE_ID`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Notes: create, save, restart', note_lifecycle.main);
  group('Login: cold start to library', login.main);
  group('AI assistant: ask about a note', ai_assistant.main);
}
