import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/firebase_options.dart';
import 'package:mnote/features/auth/data/firebase_auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MnoteApp.loadThemeMode();

  GoogleFonts.config.allowRuntimeFetching = false;

  final AuthRepository authRepository;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _activateAppCheck();
    authRepository = FirebaseAuthRepository();
  } catch (e) {
    // Login is mandatory, so without Firebase the app cannot be used.
    debugPrint('Firebase initialization failed: $e');
    runApp(const FirebaseSetupErrorApp());
    return;
  }

  runApp(MnoteApp(authRepository: authRepository));
}

/// Debug builds use the Debug provider (token is printed in the native log and
/// must be registered in the Firebase Console). Release builds use Play
/// Integrity on Android and App Attest (DeviceCheck fallback) on Apple.
Future<void> _activateAppCheck() async {
  // No web provider (reCAPTCHA) is configured for this app.
  if (kIsWeb) return;
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (e) {
    // Enforcement is off, so a failure here must not block the app.
    debugPrint('Firebase App Check activation failed: $e');
  }
}

class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'ไม่สามารถเชื่อมต่อ Firebase ได้\n'
              'กรุณาตั้งค่า Firebase ตาม docs/firebase-setup.md',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
