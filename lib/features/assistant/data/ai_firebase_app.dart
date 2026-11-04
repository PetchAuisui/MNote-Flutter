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

  /// ค่าจาก GoogleService-Info.plist ของแอป iOS ใน mnote-ai
  @visibleForTesting
  static const FirebaseOptions iosOptions = FirebaseOptions(
    apiKey: 'AIzaSyDS81C2EQAlGtihOTtxo7WjWiRfhtRa05Q',
    appId: '1:5815891505:ios:dd5ee702caab9c0082c710',
    messagingSenderId: '5815891505',
    projectId: 'mnote-ai',
    iosBundleId: 'com.petchauisui.mnote',
  );

  /// options ของแพลตฟอร์มที่รองรับ เว็บและแพลตฟอร์มอื่นได้ null
  @visibleForTesting
  static FirebaseOptions? optionsFor(
    TargetPlatform platform, {
    bool isWeb = false,
  }) {
    if (isWeb) return null;
    return switch (platform) {
      TargetPlatform.android => androidOptions,
      TargetPlatform.iOS => iosOptions,
      _ => null,
    };
  }

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
    final options = optionsFor(defaultTargetPlatform, isWeb: kIsWeb);
    if (options == null) {
      throw FirebaseException(
        plugin: 'firebase_core',
        code: 'ai-not-configured',
        message: 'AI project is not configured for this platform',
      );
    }
    // หลัง hot restart ฝั่ง native ยังมี app ชื่อนี้อยู่ สร้างซ้ำจะ error
    final app =
        Firebase.apps.where((a) => a.name == appName).firstOrNull ??
        await Firebase.initializeApp(name: appName, options: options);
    // provider ชุดเดียวกับ main.dart: debug ตอนพัฒนา, Play Integrity / App Attest ตอน release
    // ถ้าล้มเหลวให้โยนต่อ instance() จะล้าง _pending แล้วลองใหม่ตอนส่งครั้งหน้า
    // และผู้ใช้เห็น "ยืนยันความปลอดภัยของแอปไม่สำเร็จ" แทนการพังเงียบ
    await FirebaseAppCheck.instanceFor(app: app).activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    return app;
  }
}
