import 'package:flutter_test/flutter_test.dart';
import 'package:mnote/features/assistant/data/ai_firebase_app.dart';

void main() {
  // 1. ใส่ค่า config ครบ ไม่มีค่าว่างหรือข้อความตัวอย่างค้าง
  test('android options are filled in', () {
    const o = AiFirebaseApp.androidOptions;
    for (final v in [o.apiKey, o.appId, o.messagingSenderId, o.projectId]) {
      expect(v, isNotEmpty);
      expect(v, isNot(contains('ใส่')));
    }
  });

  // 2. Security: ต้องไม่ใช่ project หลักที่ผูกบัตร
  test('AI does not use the billed main project', () {
    expect(AiFirebaseApp.androidOptions.projectId, isNot('mnote-8db27'));
  });

  // 3. ชื่อ app ต้องไม่ใช่ app หลัก ไม่งั้นจะชนกับ app ของ main.dart
  test('uses a named secondary app', () {
    expect(AiFirebaseApp.appName, isNot('[DEFAULT]'));
  });
}
