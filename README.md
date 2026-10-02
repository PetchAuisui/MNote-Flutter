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

- Flutter และ Material Design 3
- ใช้สีส้มเป็น seed color และรองรับ Light/Dark mode
- Top App Bar สำหรับชื่อไฟล์และคำสั่งเอกสาร
- แยก Text mode กับ Draw mode เพื่อลดการแก้ไขหรือวาดโดยไม่ตั้งใจ
- Document surface แยกจากพื้นหลังอย่างชัดเจน
- แสดงสถานะเอกสาร เช่น ยังไม่บันทึก, กำลังบันทึก และบันทึกแล้ว
- รองรับ touch target, tooltip, screen reader และหน้าจอหลายขนาด

## ขอบเขตการพัฒนา

### Milestone 1 — Project foundation

- Flutter project สำหรับ Android, iOS, macOS และ Web
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

## เริ่มต้นใช้งาน

ต้องมี Flutter SDK ที่รองรับ Dart `^3.12.2`, Android ตามค่า `flutter.minSdkVersion`, iOS 15 ขึ้นไป และ macOS 12 ขึ้นไป

สำหรับ Xcode 27 โปรเจกต์กำหนด Debug simulator เป็น `arm64` เพื่อหลีกเลี่ยงข้อจำกัด `lipo -verify_arch` ของ Flutter 3.44; การ build สำหรับอุปกรณ์จริงและ Release ไม่ได้รับผลกระทบ

```bash
flutter pub get
flutter run
```

เลือก platform โดยตรงได้ด้วย:

```bash
flutter run -d chrome
flutter run -d macos
flutter run -d 99DA51DC-293F-438F-819B-B5015B07905D # iPad Simulator
```

ตรวจคุณภาพก่อน commit:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
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
- annotation layer, autosave, recent documents, local database, cloud sync และ AI ยังไม่ได้รวมใน milestone นี้
- ไดอะแกรม Mermaid เพิ่มขนาดแอปประมาณ 3.5 MB, รองรับ Android และ iOS และบน Web/Windows/Linux จะแสดงเป็นโค้ดแทนภาพ (ดู [docs/mermaid-preview.md](docs/mermaid-preview.md))

## เอกสารอ้างอิงของโครงการ

README นี้สรุปจาก product brief `Mnote.pdf` ที่แนบมากับงาน ซึ่งอธิบาย pain points, feature roadmap, Material Design 3, usability testing, testing strategy และขอบเขตเทคโนโลยี เอกสารดังกล่าวไม่ได้ถูกคัดลอกเข้า repository; การพัฒนาจริงแบ่งเป็น milestone ตาม README นี้
