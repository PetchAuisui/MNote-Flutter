# Firebase setup (Auth + Firestore)

โค้ดเรียก `Firebase.initializeApp()` ตอนเริ่มแอป จึงต้องเพิ่มไฟล์ config ของ Firebase project เอง (ไม่ commit ลง repository):

1. สร้าง Firebase project แล้วเปิด **Authentication → Sign-in method → Email/Password**
2. สร้าง **Cloud Firestore** database
3. ตั้งค่าแต่ละ platform:
   - Android: วาง `google-services.json` ที่ `android/app/` และเพิ่ม plugin `com.google.gms.google-services`
   - iOS/macOS: วาง `GoogleService-Info.plist` ใน `ios/Runner/` / `macos/Runner/` ผ่าน Xcode
   - หรือรัน `flutterfire configure` เพื่อให้ตั้งค่าให้อัตโนมัติ
4. ต้อง login ก่อนใช้งานเสมอ ถ้า Firebase ยังไม่ถูกตั้งค่า แอปจะแสดงหน้าแจ้งให้ตั้งค่าและเข้าใช้งานไม่ได้

## Firestore

เก็บโปรไฟล์ผู้ใช้ที่ `users/{uid}`: `displayName`, `email`, `createdAt`

Security rules ที่แนะนำ:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```
