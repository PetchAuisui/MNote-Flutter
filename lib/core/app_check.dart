import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void>? _activation;

/// เปิด App Check ให้ทุกบริการ Firebase ในแอป
///
/// เรียกซ้ำได้ เปิดจริงครั้งเดียว ถ้าล้มเหลวจะลองใหม่ในการเรียกครั้งถัดไป
/// debug build ใช้ debug provider (ต้องลงทะเบียน debug token ใน Console)
/// profile/release ใช้ Play Integrity (Android) และ App Attest (iOS/macOS)
Future<void> ensureAppCheckActivated() => _activation ??= _activate();

Future<void> _activate() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (_) {
    _activation = null;
    rethrow;
  }
}
