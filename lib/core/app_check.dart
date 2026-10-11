import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void>? _activation;

/// เปิด App Check ให้ทุกบริการ Firebase ในแอป
///
/// เรียกซ้ำได้ เปิดจริงครั้งเดียว ถ้าล้มเหลวจะลองใหม่ในการเรียกครั้งถัดไป
/// debug build ใช้ debug provider (ต้องลงทะเบียน debug token ใน Console)
/// release build ใช้ Play Integrity
Future<void> ensureAppCheckActivated() {
  return _activation ??= FirebaseAppCheck.instance
      .activate(
        providerAndroid: kReleaseMode
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(),
      )
      .catchError((Object error) {
        _activation = null;
        throw error;
      });
}
