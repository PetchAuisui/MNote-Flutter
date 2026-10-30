import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase project ที่สองที่ใช้กับ AI อย่างเดียว (แผน Spark ไม่ผูกบัตร)
///
/// project หลัก (mnote-8db27) ผูกบัตรแล้ว Gemini จึงไม่มีโควตาฟรี
/// Firestore, Auth, Storage ยังอยู่ project หลักตามเดิม
/// ค่าด้านล่างเป็นตัวระบุ project ไม่ใช่ความลับ (ชนิดเดียวกับ firebase_options.dart)
/// ตัวที่กันการใช้งานจากนอกแอปคือ App Check
class AiFirebaseApp {
  AiFirebaseApp._();

  static const appName = 'ai';

  @visibleForTesting
  static const FirebaseOptions androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyBwcc_f5rA-YUbQ0NcNrkSru04cjpdiJO0',
    appId: '1:5815891505:android:fdd824afb277359482c710',
    messagingSenderId: '5815891505',
    projectId: 'mnote-ai',
  );

  static Future<FirebaseApp>? _pending;

  /// เริ่ม app ตอนส่งข้อความครั้งแรก ไม่ทำให้แอปเปิดช้าลง
  /// ถ้าล้มเหลว ครั้งถัดไปจะลองใหม่
  static Future<FirebaseApp> instance() async {
    final pending = _pending ??= _initialize();
    try {
      return await pending;
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }

  static Future<FirebaseApp> _initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw FirebaseException(
        plugin: 'firebase_core',
        code: 'ai-not-configured',
        message: 'AI project is configured for Android only',
      );
    }
    // หลัง hot restart ฝั่ง native ยังมี app ชื่อนี้อยู่ สร้างซ้ำจะ error
    final app = Firebase.apps.where((a) => a.name == appName).firstOrNull ??
        await Firebase.initializeApp(name: appName, options: androidOptions);
    try {
      // provider ชุดเดียวกับ main.dart: debug ตอนพัฒนา, Play Integrity ตอน release
      await FirebaseAppCheck.instanceFor(app: app).activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
    } catch (e) {
      debugPrint('AI App Check activation failed: $e');
    }
    return app;
  }
}