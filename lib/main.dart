import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mnote/app/mnote_app.dart';
import 'package:mnote/features/auth/data/firebase_auth_repository.dart';
import 'package:mnote/features/auth/domain/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AuthRepository authRepository;
  try {
    await Firebase.initializeApp();
    authRepository = FirebaseAuthRepository();
  } catch (e) {
    // Login is mandatory, so without Firebase the app cannot be used.
    debugPrint('Firebase initialization failed: $e');
    runApp(const FirebaseSetupErrorApp());
    return;
  }

  runApp(MnoteApp(authRepository: authRepository));
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
