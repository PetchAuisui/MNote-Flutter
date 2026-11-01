import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/assistant/data/ai_firebase_app.dart';

void main() {
  const all = {
    'android': AiFirebaseApp.androidOptions,
    'ios': AiFirebaseApp.iosOptions,
  };

  // 1. ใส่ค่า config ครบ ไม่มีค่าว่างหรือข้อความตัวอย่างค้าง
  for (final MapEntry(key: name, value: o) in all.entries) {
    test('$name options are filled in', () {
      for (final v in [o.apiKey, o.appId, o.messagingSenderId, o.projectId]) {
        expect(v, isNotEmpty);
        expect(v, isNot(contains('ใส่')));
      }
    });
  }

  // 2. Security: ทุกแพลตฟอร์มต้องไม่ใช่ project หลักที่ผูกบัตร
  test('AI does not use the billed main project', () {
    for (final o in all.values) {
      expect(o.projectId, isNot('mnote-8db27'));
    }
  });

  // 3. ชื่อ app ต้องไม่ใช่ app หลัก ไม่งั้นจะชนกับ app ของ main.dart
  test('uses a named secondary app', () {
    expect(AiFirebaseApp.appName, isNot('[DEFAULT]'));
  });

  // 4. เลือก options ตามแพลตฟอร์ม และแพลตฟอร์มที่ไม่ได้ตั้งค่าได้ null
  test('picks options by platform', () {
    expect(
      AiFirebaseApp.optionsFor(TargetPlatform.android),
      AiFirebaseApp.androidOptions,
    );
    expect(
      AiFirebaseApp.optionsFor(TargetPlatform.iOS),
      AiFirebaseApp.iosOptions,
    );
    expect(AiFirebaseApp.optionsFor(TargetPlatform.windows), isNull);
    expect(
      AiFirebaseApp.optionsFor(TargetPlatform.android, isWeb: true),
      isNull,
    );
  });

  // 5. iOS ต้องระบุ bundle ID ให้ตรงกับแอป
  test('ios options carry the app bundle id', () {
    expect(AiFirebaseApp.iosOptions.iosBundleId, 'com.petchauisui.mnote');
  });
}
