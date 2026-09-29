# Mnote

Mnote คือ Mobile App สำหรับอ่านและแก้ไขเอกสาร Markdown พร้อมแนวทางต่อยอดเป็นพื้นที่จดบันทึกแบบหลายชั้น (layer) ผู้ใช้จะสามารถเขียน ไฮไลต์ และแทรกรูปโดยไม่ทำลายไฟล์ Markdown ต้นฉบับ

> สถานะปัจจุบัน: วางโครง Flutter และ Material Design 3 แล้ว กำลังพัฒนา Markdown workspace ใน feature branch

## เป้าหมายของโครงการ

- เปิดไฟล์ `.md`, `.markdown` และ `.txt` จากอุปกรณ์
- อ่านและแก้ไข Markdown ภายในแอป
- แสดงผล heading, list, quote, code block, link และ image
- แทรกรูปลงในเอกสารและบันทึกกลับไปยังไฟล์เดิม
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

- Flutter project สำหรับ Android และ iOS
- Material 3 theme และโครง feature-first
- เอกสาร architecture, roadmap และ Git workflow

### Milestone 2 — Markdown workspace

- เปิดไฟล์ Markdown/Text
- สลับ Edit/Preview
- แก้ไขและ render Markdown
- บันทึกและ Save As
- แทรกรูปเป็น Markdown image syntax
- unit/widget tests สำหรับ logic และหน้าจอหลัก

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
    └── workspace/          # document editor/viewer และ presentation
```

แต่ละ feature จะค่อย ๆ แยกเป็น `domain`, `data` และ `presentation` เมื่อมี business logic มากพอ เพื่อหลีกเลี่ยง abstraction ที่ยังไม่จำเป็นในช่วงต้น

## เริ่มต้นใช้งาน

ต้องมี Flutter SDK ที่รองรับ Dart `^3.12.2`

```bash
flutter pub get
flutter run
```

ตรวจคุณภาพก่อน commit:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## Git workflow

`main` เก็บเฉพาะ baseline ที่ผ่านการตรวจสอบแล้ว งานแต่ละชุดพัฒนาใน branch แยก โดยใช้ชื่อที่สื่อความหมาย เช่น `codex/markdown-editor`

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

## เอกสารอ้างอิงของโครงการ

รายละเอียดผลิตภัณฑ์ฉบับต้นทางอยู่ใน `Mnote.pdf` ซึ่งอธิบาย pain points, feature roadmap, Material Design 3, usability testing, testing strategy และขอบเขตเทคโนโลยี เอกสารดังกล่าวใช้เป็น product brief; การพัฒนาจริงแบ่งเป็น milestone ตาม README นี้
