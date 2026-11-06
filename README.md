# Mnote

Mnote คือ Mobile App สำหรับอ่านและแก้ไขเอกสาร Markdown พร้อมแนวทางต่อยอดเป็นพื้นที่จดบันทึกแบบหลายชั้น (layer) ผู้ใช้จะสามารถเขียน ไฮไลต์ และแทรกรูปโดยไม่ทำลายไฟล์ Markdown ต้นฉบับ

> สถานะปัจจุบัน: Markdown workspace ใช้งานได้บน feature branch `feature/markdown-editor`; annotation layer, cloud และ AI อยู่ใน roadmap ระยะถัดไป

## ความสามารถที่ใช้งานได้แล้ว

- เปิดไฟล์ `.md`, `.markdown` และ `.txt` ด้วย file picker ของระบบ
- แก้ไขข้อความและติดตามสถานะที่ยังไม่ได้บันทึก
- สลับระหว่างโหมดแก้ไขกับ preview แบบ GitHub Flavored Markdown
- แสดงบล็อกโค้ด `mermaid` ใน preview เป็นไดอะแกรมแบบออฟไลน์ (รายละเอียดใน [docs/mermaid-preview.md](docs/mermaid-preview.md))
- บันทึกไฟล์เดิมเมื่อระบบให้ file URI และใช้ Save As เป็น fallback
- แทรก bold, italic, heading, list, quote, code, link และ image reference จาก toolbar
- แสดงรูปจาก URL, absolute file URI และ relative path ของเอกสาร
- ป้องกันการเปิด/สร้างเอกสารใหม่ทับงานที่ยังไม่ได้บันทึก
- รองรับ Light/Dark mode ตามระบบ

## เป้าหมายของโครงการ

- เปิดไฟล์ `.md`, `.markdown` และ `.txt` จากอุปกรณ์
- อ่านและแก้ไข Markdown ภายในแอป
- แสดงผล heading, list, quote, code block, link และ image
- แทรกรูปเป็น Markdown image reference และบันทึกกลับไปยังเอกสาร
- แยก annotation layer สำหรับปากกา ไฮไลต์ และรูปประกอบออกจาก Markdown ต้นฉบับ
- ทำงานแบบ local-first และต่อยอดการ sync ข้ามอุปกรณ์
- เพิ่ม AI assistant สำหรับสรุป ถาม-ตอบ และวิเคราะห์รูปภาพในระยะถัดไป

## แนวทาง UI/UX

ดีไซน์และ prototype ของแอป: [Figma prototype](https://www.figma.com/proto/adh4RXlYPdtv1M5MBFbo5E?node-id=10-3&t=Nw48lqim5Xv3sQH4-6)

- Flutter และ Material Design 3
- ใช้สีส้มเป็น seed color และรองรับ Light/Dark mode
- Top App Bar สำหรับชื่อไฟล์และคำสั่งเอกสาร
- แยก Text mode กับ Draw mode เพื่อลดการแก้ไขหรือวาดโดยไม่ตั้งใจ
- Document surface แยกจากพื้นหลังอย่างชัดเจน
- แสดงสถานะเอกสาร เช่น ยังไม่บันทึก, กำลังบันทึก และบันทึกแล้ว
- รองรับ touch target, tooltip, screen reader และหน้าจอหลายขนาด

## ขอบเขตการพัฒนา

### Milestone 1 — Project foundation

- Flutter project สำหรับ Android, iOS, macOS
- Material 3 theme และโครง feature-first
- เอกสาร architecture, roadmap และ Git workflow

### Milestone 2 — Markdown workspace

- เปิดไฟล์ Markdown/Text
- สลับ Edit/Preview
- แก้ไขและ render Markdown
- บันทึกและ Save As
- แทรกรูปเป็น Markdown image syntax
- unit/widget tests สำหรับ logic และหน้าจอหลัก

สถานะ: พัฒนาแล้วบน `codex/markdown-editor`

### Milestone 3 — Annotation layer

- Pen, highlighter และ eraser
- Undo/Redo/Clear พร้อมคำยืนยัน
- เก็บ stroke ด้วยพิกัดเอกสาร แยกจากเนื้อหา Markdown
- แยก stylus drawing ออกจาก touch scrolling

### Milestone 4 — Persistence, cloud และ AI

- Local database ด้วย Drift หรือ Isar
- Firebase Authentication และ Cloud Firestore
- Gemini API สำหรับ summary, Q&A และ image analysis
- sync status และ conflict handling แบบ local-first

## โครงสร้างโค้ด

```text
lib/
├── app/                    # MaterialApp, navigation และ app-level setup
├── core/                   # theme, shared utilities และ shared widgets
└── features/
    └── workspace/
        ├── domain/         # document model และ repository contract
        ├── data/           # native file/image picker และ local repository
        └── presentation/   # controller และหน้า editor/preview
```

แต่ละ feature จะค่อย ๆ แยกเป็น `domain`, `data` และ `presentation` เมื่อมี business logic มากพอ เพื่อหลีกเลี่ยง abstraction ที่ยังไม่จำเป็นในช่วงต้น

## การนำไปใช้งาน

### 1. เตรียมเครื่อง

| ต้องมี | ใช้ทำอะไร |
|---|---|
| Flutter SDK ช่อง stable ที่มี Dart `^3.12.2` | build และรันแอป (ตรวจด้วย `flutter doctor`) |
| Android Studio + Android SDK, Java 17 | build Android (`minSdk` ตามค่า `flutter.minSdkVersion`) |
| Mac + Xcode และ CocoaPods | build iOS 15+ / macOS 12+ (Windows/Linux build iOS ไม่ได้) |
| Node 22 และ Java 21 (ไม่บังคับ) | รัน security test ของ Firebase rules เท่านั้น |

### 2. Clone และรัน

```bash
git clone https://github.com/PetchAuisui/MNote-Flutter.git
cd MNote-Flutter
flutter pub get
flutter run
```

เลือกอุปกรณ์ด้วย `flutter devices` แล้ว `flutter run -d <device-id>` เช่น `flutter run -d macos` หรือ `flutter run -d chrome`

- ไฟล์ config ของ Firebase (`lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) อยู่ใน repo แล้ว ค่าเหล่านี้ไม่ใช่ความลับ จึง**รันแล้วต่อ Firebase project ของทีม (`mnote-8db27`) ได้ทันที** ไม่ต้องตั้งค่าเพิ่ม
- โค้ดที่ generate แล้ว (drift `*.g.dart`, คำแปลใน `lib/l10n/`) อยู่ใน repo แล้ว ถ้าแก้ schema ฐานข้อมูลให้รัน `dart run build_runner build --delete-conflicting-outputs` ถ้าแก้ไฟล์ `.arb` ให้รัน `flutter gen-l10n`
- Xcode 27: โปรเจกต์กำหนด Debug simulator เป็น `arm64` เพื่อเลี่ยงข้อจำกัด `lipo -verify_arch` ของ Flutter 3.44 ไม่กระทบการ build บนเครื่องจริงและ Release

### 3. เข้าสู่ระบบ

แอปบังคับ login ก่อนใช้งาน (ใช้ Firebase Auth) ถ้า Firebase เริ่มทำงานไม่ได้ แอปจะแสดงหน้าแจ้งให้ตั้งค่าและเข้าใช้งานไม่ได้

- **Email/Password** ใช้ได้ทุกเครื่องทันที
- **Continue with Google บน Android** ต้องเพิ่ม SHA-1 ของคอมที่ build ใน Firebase Console ก่อน ไม่งั้นกดแล้วไม่ login (วิธีทำใน [docs/android-google-sign-in.md](docs/android-google-sign-in.md))

### 4. เปิดใช้ผู้ช่วย AI (ถ้าต้องการ)

AI (Gemini) อยู่ใน Firebase project แยกชื่อ `mnote-ai` และป้องกันด้วย App Check ฟีเจอร์อื่นใช้ได้ตามปกติแม้ AI ยังไม่พร้อม

| วิธีรัน | ต้องทำ |
|---|---|
| `flutter run` (debug) Android/iOS | ส่งข้อความ AI 1 ครั้ง (จะ error) → หา debug token ใน log → ลงทะเบียนใน `mnote-ai` → App Check → Manage debug tokens (ต้องมีสิทธิ์ Editor) |
| APK release บนเครื่อง Android จริง | เพิ่ม SHA-256 ของคอมที่ build ใน Play Integrity ของ `mnote-ai` (`cd android && ./gradlew signingReport`) |
| iOS release / แจกคนอื่น | ยังใช้ไม่ได้ ต้องมีบัญชี Apple Developer แบบเสียเงิน |

ขั้นตอนเต็มอยู่ใน [docs/ai-assistant.md](docs/ai-assistant.md) หัวข้อ 7.3–7.5 **debug token เป็นความลับ** ห้ามใส่ในโค้ด, PR หรือแชทกลุ่ม และโควตาฟรีนับรวมทั้งทีม (500 ครั้งต่อวัน, 15 ครั้งต่อนาที)

### 5. ใช้ Firebase project ของตัวเอง (กรณี fork ไปใช้ต่อ)

ถ้าไม่ได้อยู่ในทีม และต้องการให้ข้อมูลไปอยู่ใน project ของตัวเอง:

1. สร้าง Firebase project แล้วเปิด **Authentication** (Email/Password และ Google), **Cloud Firestore** และ **Storage**
2. เปลี่ยน package/bundle id `com.petchauisui.mnote` เป็นของตัวเอง (`android/app/build.gradle.kts` และ Xcode) ถ้าจะนำไปเผยแพร่
3. ติดตั้ง Firebase CLI และ FlutterFire CLI แล้วรัน `flutterfire configure` เพื่อสร้าง `firebase_options.dart`, `google-services.json` และ `GoogleService-Info.plist` ชุดใหม่ทับของเดิม
4. แก้ `_webClientId` ใน `lib/features/auth/data/firebase_auth_repository.dart` เป็น Web client ID ของ project ใหม่ (ดูได้จาก `google-services.json` ที่ `client_type: 3`)
5. deploy security rules: `firebase deploy --only firestore:rules,storage` (แก้ `projectId` ใน `firebase.json` ก่อน)
6. AI: สร้าง project แยกที่**ไม่ผูกบัตร** เปิด Firebase AI Logic (Gemini Developer API) และ App Check แล้วใส่ค่าของ project นั้นใน `lib/features/assistant/data/ai_firebase_app.dart` (รายละเอียดใน [docs/firebase-setup.md](docs/firebase-setup.md) และ [docs/ai-assistant.md](docs/ai-assistant.md))

### 6. Build สำหรับแจก

```bash
flutter build apk --release        # Android: build/app/outputs/flutter-apk/app-release.apk
flutter build ios --release        # iOS: ต้องมี Mac และบัญชี Apple Developer เพื่อ sign
flutter build macos --release
```

ตอนนี้ release ของ Android เซ็นด้วย debug key ของแต่ละคอม ถ้าจะขึ้น Google Play ต้องสร้าง release keystore ของตัวเอง (ห้าม commit ไฟล์ key และรหัสผ่าน)

### 7. ตรวจคุณภาพก่อน commit

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

## การทดสอบ

CI รันการทดสอบทั้ง 4 ประเภททุกครั้งที่ push หรือเปิด PR และจะไม่ผ่านถ้า line coverage ของ `test/` ต่ำกว่า 70%

| ประเภท | อยู่ที่ | ทดสอบอะไร |
|---|---|---|
| Unit | `test/**` (ส่วนที่ไม่ต้อง render) | logic ทีละส่วน เช่น repository, ฐานข้อมูล drift, sync, validator |
| Widget | `test/**` (`testWidgets`) | หน้าจอและ widget ทีละหน้า |
| Integration | `integration_test/` | flow เต็มของแอปตั้งแต่ต้นจนจบ ใช้ repository จริง ไฟล์จริงบนดิสก์ และ SQLite จริง: สร้างโน้ต → เขียน → ปิดแอปแล้วเปิดใหม่ ข้อมูลยังอยู่ / login → guide → คลังโน้ต / ถาม AI เรื่องโน้ตแล้วได้คำตอบแบบ stream |
| Security | `test_security_rules/`, `test/security/` และ test ที่ขึ้นต้นด้วย `(Security)` | Firestore/Storage rules บน Firebase Emulator (ผู้ใช้อื่นหรือคนที่ไม่ได้ login อ่าน/เขียนข้อมูลไม่ได้ จำกัดชนิดและขนาดไฟล์ภาพ), ไม่มี secret หลุดเข้า repo, config ของ Android/iOS ไม่เปิดช่องโหว่ และฝั่ง AI ไม่ส่งโน้ตออกไปโดยผู้ใช้ไม่รู้ |

```bash
# Unit + Widget + Security ฝั่ง Dart พร้อม coverage
flutter test --coverage

# เฉพาะ security ฝั่ง Dart
flutter test --tags security

# Integration (รันแบบไม่มีหน้าจอ หรือใส่ -d <device> เพื่อรันบน iPad/Simulator)
flutter test integration_test -d flutter-tester

# Security ของ Firebase rules (ต้องมี Node และ Java 21 ขึ้นไป)
cd test_security_rules && npm ci && npm test
```

## Git workflow

`main` เก็บเฉพาะ baseline ที่ผ่านการตรวจสอบแล้ว งานแต่ละชุดพัฒนาใน branch แยก โดยใช้ชื่อที่สื่อความหมาย เช่น `feature/markdown-editor`

แบ่ง commit ตามผลลัพธ์ที่ตรวจสอบได้:

1. `chore: bootstrap Flutter project and documentation`
2. `feat: add Markdown document domain and file access`
3. `feat: build Markdown editor and preview workspace`
4. `test: cover Markdown document workflows`

ห้าม commit API key, Firebase secret หรือข้อมูลส่วนบุคคลลง repository

## Definition of Done

- โค้ดผ่าน formatter และ static analysis
- unit/widget tests ผ่าน
- UI ใช้งานได้บนหน้าจอมือถือและไม่ล้นบนขนาดมาตรฐาน
- error, empty และ unsaved states มี feedback ที่เข้าใจได้
- README และเอกสารที่เกี่ยวข้องตรงกับพฤติกรรมจริงของแอป

## ข้อจำกัดของรุ่นปัจจุบัน

- ปุ่มแทรกรูปเพิ่ม URI ของไฟล์ลงใน Markdown โดยตรง ยังไม่ได้คัดลอกรูปเข้า companion asset folder ดังนั้นลิงก์รูปอาจใช้ข้ามอุปกรณ์ไม่ได้
- Android/iOS อาจส่ง document URI ที่เขียนทับตรง ๆ ไม่ได้ แอปจะเปิด Save As เพื่อให้ผู้ใช้เลือกปลายทางแทน
- autosave, recent documents, local database, cloud sync และ AI ยังไม่ได้รวมใน milestone นี้

## ทดลองเขียนบน Markdown (Scribble)

- เลือกโหมด **จด** เพื่อเขียนบน Markdown ปัจจุบัน โดยโหมดแก้ไขและแสดงผลเดิมยังใช้ได้
- ค่าเริ่มต้นรับปากกาเท่านั้น ใช้นิ้วเลื่อน/ซูมหน้า สำหรับ Simulator หรือเมาส์ ให้เปิดปุ่มรูปนิ้วก่อนเขียน (เมื่อเปิดจะหยุดเลื่อน/ซูม เพื่อไม่ให้ชนกับการวาด)
- มีปากกาดำ/แดง ยางลบทั้งเส้น Undo/Redo หมึก ปุ่มพอดีความกว้าง และเพิ่มพื้นที่ด้านล่าง
- พิกัดหมึกอิงหน้ากว้าง 1,000 logical units ไม่อิงหน้าจอหรือข้อความ พื้นที่จะขยายได้แต่ไม่หดเมื่อลบข้อความ การแก้ Markdown จึงไม่ย้ายหรือลบหมึกเดิม แต่ข้อความใต้หมึกอาจเปลี่ยนตำแหน่งตามเนื้อหาใหม่
- ปุ่มบันทึกหลักบันทึกเฉพาะ Markdown ใช้ปุ่มบันทึกในโหมดจดเพื่อเก็บหมึกเป็น `<ชื่อเอกสาร>.ink.json` และปุ่มเปิดหมึกเพื่อนำกลับมา ไม่เปิดไฟล์หมึกคู่กันอัตโนมัติ
- เมื่อนำไปอีกอุปกรณ์ ต้องนำทั้ง Markdown, ไฟล์หมึก และรูปที่อ้างอิงไปด้วย ไม่มีการ sync อัตโนมัติ หมึกจะแสดงเฉพาะโหมดจดบนกระดาษสีขาว
- ยังไม่มี autosave หมึก ควรบันทึกก่อนปิดแอป การเปิดเอกสารใหม่/สร้างเอกสารใหม่จะเตือนถ้ามีหมึกที่ยังไม่บันทึก

ตรวจสอบด้วย unit/widget tests: บันทึก ยกเลิก และเปิด JSON กลับ, Undo/Redo, ลาก stylus จำลอง, เปลี่ยนขนาดหน้าจอ และลบ Markdown โดยหมึกยังอยู่ตำแหน่งเดิม ต้องทดสอบแรงกด Apple Pencil, palm rejection และการเลือกไฟล์บน iPad จริงเพิ่มเติมก่อนใช้กับข้อมูลสำคัญ
- annotation layer, autosave, recent documents, local database, cloud sync และ AI ยังไม่ได้รวมใน milestone นี้
- ไดอะแกรม Mermaid เพิ่มขนาดแอปประมาณ 3.5 MB, รองรับ Android และ iOS และบน Web/Windows/Linux จะแสดงเป็นโค้ดแทนภาพ (ดู [docs/mermaid-preview.md](docs/mermaid-preview.md))

## เอกสารอ้างอิงของโครงการ

README นี้สรุปจาก product brief `Mnote.pdf` ที่แนบมากับงาน ซึ่งอธิบาย pain points, feature roadmap, Material Design 3, usability testing, testing strategy และขอบเขตเทคโนโลยี เอกสารดังกล่าวไม่ได้ถูกคัดลอกเข้า repository; การพัฒนาจริงแบ่งเป็น milestone ตาม README นี้
