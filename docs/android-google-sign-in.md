# Google Sign-In บน Android

แอปใช้ `google_sign_in` (Credential Manager) ซึ่งต้องมี **Android OAuth client (type 1)** ที่ผูกกับ package `com.petchauisui.mnote` และ SHA-1 ของ keystore ที่ใช้ build

อาการเมื่อขาด: กด "Continue with Google" แล้วไม่ล็อกอิน หรือขึ้นข้อความ "เข้าสู่ระบบด้วย Google ไม่ได้ในขณะนี้" (รายละเอียดจริงดูได้ใน log: `Google sign-in failed: ...`)

## วิธีแก้

1. หา SHA-1 ของ debug keystore:

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

2. Firebase Console → Project settings → Your apps → แอป Android → **Add fingerprint** แล้ววาง SHA-1 (ทำซ้ำกับ SHA-1 ของ release keystore และ Play App Signing ด้วย)
3. ดาวน์โหลด `google-services.json` ใหม่มาทับ `android/app/google-services.json` — ต้องมี `oauth_client` ที่ `client_type: 1` อย่างน้อยหนึ่งรายการ
4. `flutter clean && flutter run`
