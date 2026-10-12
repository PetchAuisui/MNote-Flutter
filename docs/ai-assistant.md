# AI Assistant (Gemini Chat)

เอกสารนี้อธิบายฟีเจอร์ผู้ช่วย AI ใน Mnote: ปุ่ม ✨ มุมขวาบนของหน้าแก้ไขที่เปิดแชทคุยกับ Gemini ทำอะไรได้ ใช้วิธีไหนและเพราะอะไร ข้อมูลไหลผ่านไฟล์ใดบ้าง ความปลอดภัย การทดสอบ สิ่งที่ตั้งค่าใน Firebase Console และถ้าจะต่อยอดต้องทำอย่างไร

- Branch: `feature/ai-chat`
- ตอบโจทย์อาจารย์ข้อ "ใช้ AI อย่างน้อย 1 Feature (Gemini API)" และเป็น Firebase บริการที่ 3 ของโปรเจกต์ (ต่อจาก Auth และ Firestore)
- สถานะ: ใช้งานได้บน Android (ทดสอบบนแท็บเล็ตจริงแล้ว), CI ผ่านทั้ง Android และ iOS build

> ⚠️ **มีเส้นตายวันที่ 2 พฤศจิกายน 2026** ที่คนดูแล Firebase ต้องรู้ ดูหัวข้อ 7

---

## 1. ปัญหาและแนวทาง

ทีมต้องการให้ผู้ใช้คุยกับ AI ได้ทันทีที่เปิดแอป **โดยไม่ต้องไปสมัครหรือหา API key มาใส่เอง**

| ทาง | ผล |
|---|---|
| ให้ผู้ใช้ใส่ Gemini API key เอง | ❌ ยุ่งยาก ผู้ใช้ส่วนใหญ่ไม่มี key |
| ฝัง API key ไว้ในแอป | ❌ **อันตราย** repo เป็นสาธารณะ และใครก็แกะ key ออกจากไฟล์ APK ได้ |
| ทำเซิร์ฟเวอร์ (Cloud Functions) ถือ key เอง | ⚠️ ปลอดภัย แต่ต้องใช้แผน Blaze (ผูกบัตร) และเป็นงานใหญ่ |
| **Firebase AI Logic** (เลือกใช้) | ✅ key อยู่ที่ Firebase แอปเรียกผ่าน SDK ใช้แผน Spark (ฟรี) ได้ และอยู่ในโปรเจกต์ Firebase เดิมของทีม |

งานนี้ใช้โปรเจกต์ Firebase เดิม `mnote-8db27` **ไม่ได้สร้างโปรเจกต์ใหม่ และไม่ได้รัน `flutterfire configure`** จึงไม่กระทบ config ของ Auth/Firestore

---

## 2. ความสามารถ

### 2.1 ปุ่มเปิดแชท

ปุ่ม ✨ (`Icons.auto_awesome`) อยู่หน้าปุ่ม "ส่งออก" ที่มุมขวาบนของหน้าแก้ไข

| ขนาดจอ | รูปแบบ (Material Design 3) |
|---|---|
| กว้างน้อยกว่า 600 (มือถือ) | หน้าต่างเต็มจอ (`Dialog.fullscreen`) |
| กว้าง 600 ขึ้นไป (แท็บเล็ต) | แผงลอยเลื่อนเข้าจากขวา กว้าง 400 (modal side sheet) ยังเห็นโน้ตด้านซ้าย กดพื้นที่ว่างเพื่อปิด |

ปิดแผงแล้วเปิดใหม่ **บทสนทนายังอยู่** จนกว่าจะออกจากหน้าแก้ไข

### 2.2 หน้าแชท

- **หน้าว่าง:** คำแนะนำ 3 อันกดแล้วส่งทันที (ช่วยผู้ใช้ครั้งแรก และใช้เป็นงานใน Usability Testing ได้)
- **ฟองข้อความ:** ผู้ใช้ชิดขวาสี `primaryContainer` / AI ชิดซ้ายสี `surfaceContainerHigh` (สีจาก theme ทั้งหมด)
- **คำตอบทยอยขึ้นทีละส่วน** (streaming) ระหว่างรอแสดง "กำลังคิด…"
- **คำตอบแสดงเป็น Markdown** และถ้า AI ตอบเป็นบล็อก ` ```mermaid ` จะเห็นเป็นภาพไดอะแกรม (ใช้ `MermaidElementBuilder` เดิมของทีม)
- **แถบความเป็นส่วนตัว:** "ข้อความที่พิมพ์จะถูกส่งไปประมวลผลที่ Google Gemini · AI ยังไม่ได้อ่านเนื้อหาโน้ตของคุณ"
- ปุ่มล้างบทสนทนา, แถบ error สี `errorContainer`, จำกัดข้อความ 2000 ตัวอักษร

### 2.3 สิ่งที่ยังไม่ทำ (ตั้งใจ)

**AI ยังไม่อ่านเนื้อหาโน้ต** ตามที่ทีมกำหนด แต่เตรียมโครงไว้แล้ว (หัวข้อ 8.1)

---

## 3. โครงสร้างไฟล์

```
lib/
├── core/
│   └── app_check.dart                       ใหม่: เปิด App Check ให้ทั้งแอป
├── features/assistant/                      ใหม่ทั้งโฟลเดอร์
│   ├── domain/
│   │   ├── chat_message.dart                ข้อความแชท (role + text)
│   │   └── ai_assistant.dart                interface AiAssistant + exception + AiDocumentContext
│   ├── data/
│   │   └── firebase_ai_assistant.dart       ตัวจริง: เรียก Gemini ผ่าน Firebase AI Logic
│   └── presentation/
│       ├── assistant_chat_controller.dart   state ของแชท (ChangeNotifier)
│       └── assistant_chat_panel.dart        หน้าแชท + showAssistantChat()
├── main.dart                                แก้ +10 บรรทัด: เรียก ensureAppCheckActivated()
└── features/workspace/presentation/
    └── markdown_workspace_page.dart         แก้ +28/-1: ปุ่ม ✨ + พารามิเตอร์ assistant

test/
├── helpers/fake_ai_assistant.dart           ตัวปลอมสำหรับ test (ไม่ต่อเน็ต)
└── features/assistant/
    ├── assistant_chat_controller_test.dart  12 test
    ├── assistant_chat_panel_test.dart       13 test
    ├── assistant_entry_test.dart             6 test
    └── firebase_ai_assistant_test.dart       5 test
```

แพ็กเกจที่เพิ่มใน `pubspec.yaml`: `firebase_ai: ^4.0.0`, `firebase_app_check: ^0.4.8` (ต้องการ `firebase_core ^4.14.0` ซึ่งทีมใช้ `^4.15.0` อยู่แล้ว)

**ไฟล์ของทีมที่แตะ มีแค่ 2 ไฟล์ และเพิ่มอย่างเดียว:** `main.dart` (PM อนุญาต) และ `markdown_workspace_page.dart` (เปลี่ยนแค่บรรทัด `this.assistant,` เป็นค่าเริ่มต้น)

---

## 4. การไหลของข้อมูล

```
ผู้ใช้กด ✨
  → _openAssistant()            สร้าง AssistantChatController ครั้งแรก (เก็บไว้ในหน้า)
  → showAssistantChat()         เลือก fullscreen / side sheet ตามความกว้างจอ
  → AssistantChatPanel          ผู้ใช้พิมพ์แล้วกดส่ง
  → AssistantChatController.send()
       ตรวจ: ว่าง? ยาวเกิน 2000? กำลังตอบอยู่?
       ตัดประวัติเหลือ 20 ข้อความล่าสุด
       document: null           (ไม่ส่งโน้ต)
  → AiAssistant.sendMessage()   (interface)
  → FirebaseAiAssistant
       ensureAppCheckActivated()
       buildGeminiHistory()     กรองให้ผู้ใช้/AI สลับกัน
       chat.sendMessageStream() ──→ Firebase AI Logic ──→ Gemini
  ← คำตอบทีละชิ้น (Stream<String>) ← controller ต่อข้อความ ← หน้าจอวาดใหม่
```

**ถ้าผิดพลาด:** `FirebaseAiAssistant` แปลง error ของ Firebase เป็น `AiAssistantException` ข้อความไทย controller แสดงในแถบ error และลบฟองคำตอบที่ว่างทิ้ง แอปไม่ค้างหรือเด้ง

**ถ้าออกจากหน้าแก้ไขระหว่าง AI กำลังตอบ:** `dispose()` ของหน้าเรียก `_assistantChat?.dispose()` ซึ่งยกเลิกการรับคำตอบทันที ไม่มีการเชื่อมต่อค้างในพื้นหลัง

---

## 5. การตัดสินใจหลักและเหตุผล

| การตัดสินใจ | เหตุผล |
|---|---|
| **interface `AiAssistant` + ตัวจริง/ตัวปลอม** | test ทั้ง UI และ controller ได้โดยไม่ต่อเน็ตและไม่ใช้โควตา และเปลี่ยนผู้ให้บริการ AI ได้โดยไม่แก้หน้าจอ |
| **พารามิเตอร์ `assistant` ค่าเริ่มต้น `const FirebaseAiAssistant()`** | หน้าแก้ไขถูกสร้างจาก 4 จุดในไฟล์ของเพื่อน ใช้ค่าเริ่มต้นทำให้ปุ่มขึ้นทุกหน้าโดยไม่ต้องแก้ไฟล์เหล่านั้น ส่ง `null` เพื่อซ่อนปุ่มได้ |
| **side sheet แบบลอย ไม่ใช่แผงแทรกในหน้า** | ไม่ต้องรื้อโครง `build()` ของหน้าแก้ไข (ไฟล์ที่ทุกคนแก้) และเป็นรูปแบบที่ MD3 มี |
| **App Check เปิดใน `main()` แบบไม่ `await` และ AI เรียกซ้ำ** | แอปเป็น local-first ถ้า App Check ช้าหรือพัง แอปต้องยังเปิดได้ และ AI ลองเปิดใหม่ได้เองถ้าครั้งแรกล้มเหลว (`ensureAppCheckActivated()` ใช้ `??=` จึงเปิดจริงครั้งเดียว) |
| **debug provider เฉพาะ debug build** | ถ้าปล่อยไปถึงแอปจริง ใครก็ขอ token ผ่านได้ ทำให้ App Check ไร้ประโยชน์ |
| **`buildGeminiHistory()` ส่งเฉพาะคู่ที่สมบูรณ์** | ถ้า AI เคยตอบพลาด ประวัติจะมีข้อความผู้ใช้ติดกัน 2 อัน Gemini อาจปฏิเสธคำขอ |
| **ไม่แสดง error ดิบของ Google** | อาจมีรายละเอียดภายในของโปรเจกต์ และผู้ใช้อ่านไม่เข้าใจ |

---

## 6. ความปลอดภัย

| ความเสี่ยง                                       | การป้องกัน                                                                                                             | หลักฐาน                                 |
| ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| API key หลุด                                     | Gemini key ไม่อยู่ในแอปหรือ repo อยู่ที่ Firebase AI Logic (`firebase_options.dart` มีแค่ค่า config ซึ่งไม่ใช่ความลับ) | ไม่มีโค้ดส่วนไหนอ่านหรือเก็บ key        |
| คนนอกใช้โควตา                                    | App Check (ตอนนี้โหมด Monitoring ดูหัวข้อ 7)                                                                           | —                                       |
| ส่งข้อความยาวมากเพื่อผลาญโควตา                   | จำกัด 2000 ตัวอักษร ทั้งช่องพิมพ์และ controller                                                                        | test (Security) 2 ข้อ                   |
| ประวัติแชทยาวไม่สิ้นสุด                          | ส่งแค่ 20 ข้อความล่าสุด                                                                                                | test (Security)                         |
| **เนื้อหาโน้ตหลุดไปให้ AI**                      | controller ส่ง `document: null` เสมอ และ `FirebaseAiAssistant` มี `assert` กันไว้                                      | test (Security) ใน controller และ entry |
| **คำตอบ AI ใช้ติดตามผู้ใช้** (รูปจาก URL ภายนอก) | `imageBuilder` แสดงข้อความ alt แทน ไม่โหลดรูป                                                                          | test (Security): ไม่มี `Image`          |
| คำตอบ AI มีลิงก์อันตราย                          | ไม่ใส่ `onTapLink` ลิงก์ในคำตอบกดไม่ได้                                                                                | —                                       |
| log หลุดข้อมูล                                   | `debugPrint` แค่ชนิดของ error ไม่พิมพ์ข้อความผู้ใช้                                                                    | —                                       |

ผู้ใช้ถูกแจ้งตลอดเวลาว่าข้อความถูกส่งไป Google Gemini (แถบความเป็นส่วนตัวด้านบนของแชท)

---

## 7. การตั้งค่าใน Firebase Console (สำคัญสำหรับคนดูแล Firebase)

### 7.1 สิ่งที่เปิดแล้ว

| ที่ | ค่า |
|---|---|
| AI Logic → ผู้ให้บริการ | **Gemini Developer API** (ใช้กับแผน Spark ได้) |
| AI Logic → AI monitoring | **ปิด** (อาจเก็บข้อความผู้ใช้ไว้ใน log ควรตกลงกับทีมก่อนเปิด) |
| App Check → APIs → Firebase AI Logic | **Basic - Monitoring** (ไม่บังคับ) / Replay protection: Disabled |
| App Check → Apps → mnote (android) → debug tokens | `Tablet SM-T735 (Faa)` |
| App Check ของ Firestore / Auth | **ไม่ได้แตะ** (Unenforced เหมือนเดิม) |

### 7.2 ทำไมปิดการบังคับ App Check ของ AI

Firebase เปิดบังคับให้อัตโนมัติตอน setup ผลคือ**เฉพาะเครื่องที่ลงทะเบียน debug token เท่านั้นที่ใช้ AI ได้** ขัดกับเป้าหมาย "ทุกคนเปิดแอปแล้วใช้ได้เลย" จึงปิดการบังคับชั่วคราว

**ความเสี่ยงที่ยอมรับ:** คนที่เอาค่า Firebase จาก repo ไปเขียนสคริปต์เอง เรียก Gemini ด้วยโควตาของทีมได้ **แผน Spark จึงไม่มีค่าใช้จ่าย** กรณีแย่สุดคือโควตาฟรีหมดชั่วคราว ข้อมูลโน้ตและบัญชีไม่เกี่ยว (คนละบริการ)

### 7.3 ⚠️ เส้นตาย 2 พฤศจิกายน 2026

ตามคู่มือ Firebase: **ตั้งแต่วันนั้น Firebase จะบังคับ App Check กับ AI Logic อัตโนมัติ และปิดไม่ได้อีก**

| ถ้าไม่ทำอะไร | ผล |
|---|---|
| เครื่องที่ลงทะเบียน debug token | ใช้ AI ได้ปกติ (demo บนแท็บเล็ตได้) |
| เครื่องอื่นทั้งหมด | แชทขึ้น "ผู้ช่วย AI ไม่พร้อมใช้งานชั่วคราว" |
| ส่วนอื่นของแอป | ไม่กระทบ ไม่ค้าง ไม่เสียเงิน ไม่เสียข้อมูล |

**ถ้าต้องให้ทุกคนใช้ได้หลังวันนั้น** คนที่เป็น **Owner** ต้องลงทะเบียน Play Integrity (ไม่ต้องแก้โค้ด):
1. หา SHA-256 ของคีย์ที่ใช้เซ็นแอป release (`cd android && ./gradlew signingReport`)
2. Firebase Console → App Check → Apps → mnote (android) → **Play Integrity** → ใส่ SHA-256
3. ถ้าแอปไม่ได้ขึ้น Google Play: ในการตั้งค่า Play Integrity ของ App Check ปิดการบังคับ `PLAY_RECOGNIZED` และใช้ระดับ "Device integrity" (ตามคู่มือ Firebase หัวข้อแอปที่แจกนอก Google Play)
4. ทดสอบด้วย APK แบบ release แล้วค่อยกด Enforce กลับ

**ข้อที่ยังต้องทดสอบจริง:** คู่มือระบุว่าการผูก Play Integrity กับโปรเจกต์ทำใน Google Play Console ซึ่งอาจต้องมีบัญชีนักพัฒนา Google Play

### 7.4 นักพัฒนาคนอื่นในทีม

ตอนนี้ (Monitoring) **ไม่ต้องทำอะไร** รัน `flutter run` แล้วใช้ AI ได้เลย

ถ้าเปิดการบังคับกลับ (หรือหลัง 2 พ.ย.) แต่ละเครื่องต้องลงทะเบียน debug token:
1. `flutter run` → เปิดแชท → ส่งข้อความ 1 ครั้ง (จะ error)
2. `adb logcat -d | grep DebugAppCheckProvider` → คัดลอกรหัสหลัง `Firebase App Check debug token:`
3. App Check → Apps → mnote (android) → ⋮ → **Manage debug tokens** → Add (ตั้งชื่อ `อุปกรณ์ (ชื่อคน)`)

**debug token เป็นความลับ** ห้ามใส่ในโค้ด, README, PR หรือแชทกลุ่ม ถ้าล้างข้อมูลแอปหรือถอนการติดตั้ง จะได้รหัสใหม่และต้องลงทะเบียนอีกครั้ง

### 7.5 Checklist ก่อนปล่อยแอปจริง

- [ ] ลงทะเบียน Play Integrity (หัวข้อ 7.3)
- [ ] กด Enforce App Check ของ AI Logic กลับ
- [ ] ลบ debug token ที่ไม่ใช้แล้ว (โดยเฉพาะก่อนอัปเกรดเป็นแผน Blaze)
- [ ] พิจารณาเปิด **authenticated-users mode** ของ AI Logic (ให้เฉพาะคนที่ล็อกอินใช้ได้ แอปบังคับล็อกอินอยู่แล้ว ไม่ต้องแก้โค้ด)
- [ ] พิจารณาลด rate limit ต่อผู้ใช้ (ค่าเริ่มต้น 100 ครั้ง/นาที) ใน Google Cloud Console → Firebase AI Logic API → Quotas

---

## 8. ต่อยอด

### 8.1 ให้ AI อ่านโน้ต

โครงเตรียมไว้แล้ว: `AiAssistant.sendMessage()` รับ `AiDocumentContext? document` (title + content)

1. ใน `AssistantChatController` เพิ่มทางเลือกให้ผู้ใช้**กดเองอย่างชัดเจน** เช่น ปุ่ม "แนบโน้ตนี้" (ห้ามส่งอัตโนมัติ เพราะเป็นเรื่องความเป็นส่วนตัว)
2. ส่ง `AiDocumentContext(title: ..., content: ...)` แทน `null` และจำกัดความยาวเนื้อหา
3. ใน `FirebaseAiAssistant` ลบ `assert` และนำ `document` ไปรวมกับข้อความ (เช่น เป็นข้อความแรกในประวัติ)
4. เปลี่ยนแถบความเป็นส่วนตัวให้บอกว่าโน้ตถูกส่งไปด้วย และแก้ test (Security) ที่ตรวจ `document == null`

### 8.2 เปิด App Check กับ Firestore / Auth

ตั้งค่าโค้ดเสร็จแล้ว (`main.dart` เปิด App Check ให้ทั้งแอป) เหลือฝั่ง Console:
1. ตรวจ Firestore Security Rules ก่อน (App Check ไม่ได้แทน Rules)
2. ทุกคนในทีมลงทะเบียน debug token
3. ดูกราฟ verified/unverified ในหน้า App Check สักระยะ แล้วค่อยกด Enforce ทีละบริการ
4. พิจารณาเปลี่ยน `unawaited(...)` ใน `main.dart` เป็น `await` (มี timeout) เพื่อให้ token พร้อมก่อนคำขอแรก

### 8.3 เปลี่ยนโมเดลหรือข้อความระบบ

แก้ `FirebaseAiAssistant.modelName` และ `_systemPrompt` ในไฟล์เดียว

### 8.4 ใช้ผู้ช่วย AI ในหน้าอื่น

```dart
import 'package:mnote/features/assistant/data/firebase_ai_assistant.dart';
import 'package:mnote/features/assistant/presentation/assistant_chat_controller.dart';
import 'package:mnote/features/assistant/presentation/assistant_chat_panel.dart';

// ใน State: สร้างครั้งเดียว และ dispose ใน dispose()
late final _chat = AssistantChatController(const FirebaseAiAssistant());

// เปิดแชท
showAssistantChat(context, controller: _chat);
```

ใน test ใช้ `FakeAiAssistant` จาก `test/helpers/fake_ai_assistant.dart` แทน

---

## 9. การทดสอบ

**อัตโนมัติ:** 36 test ใหม่ (รวมทั้งโปรเจกต์ 308) `flutter analyze --fatal-infos` ไม่มีปัญหา CI ผ่านทั้ง 4 งาน

| ไฟล์ | ครอบคลุม |
|---|---|
| `assistant_chat_controller_test.dart` | ส่ง/รับทีละส่วน, ข้อความว่าง, ส่งซ้ำระหว่างตอบ, error, ล้าง, dispose กลางคำตอบ, (Security) 2001 ตัวอักษร, (Security) ประวัติ 20, (Security) ไม่ส่งโน้ต |
| `assistant_chat_panel_test.dart` | หน้าว่าง, ปุ่มส่ง, คำแนะนำ, error, Markdown, ไดอะแกรม, "กำลังคิด", ล้าง, (Security) ไม่โหลดรูป, (Security) maxLength, fullscreen 320 / side sheet 1024 |
| `assistant_entry_test.dart` | ไม่มี assistant ไม่มีปุ่ม, เปิดบนแท็บเล็ต/มือถือ, บทสนทนายังอยู่, (Security) โน้ตไม่ถูกส่ง, ออกจากหน้าไม่ error |
| `firebase_ai_assistant_test.dart` | `buildGeminiHistory` 4 กรณี และสร้างตัวจริงได้โดยไม่ต้องเปิด Firebase |

**บนเครื่องจริง (Samsung SM-T735):** คุยได้, คำตอบทยอยขึ้น, ไดอะแกรมจาก AI แสดงเป็นภาพ, ปิด/เปิดแผงบทสนทนายังอยู่, Firestore/Auth ทำงานปกติระหว่างที่ App Check ทำงาน

**ไม่ได้ทดสอบอัตโนมัติ:** การเรียก Gemini จริง (ต้องใช้เน็ตและโควตา) จึงทดสอบด้วยมือ

---

## 10. อ้างอิง

- [Firebase AI Logic: Get started](https://firebase.google.com/docs/ai-logic/get-started?api=dev)
- [Firebase AI Logic: App Check](https://firebase.google.com/docs/ai-logic/app-check)
- [Firebase AI Logic: Production checklist](https://firebase.google.com/docs/ai-logic/production-checklist)
- [Firebase AI Logic: Quotas](https://firebase.google.com/docs/ai-logic/quotas)
- [App Check: debug provider (Flutter)](https://firebase.google.com/docs/app-check/flutter/debug-provider)
- [App Check: Play Integrity provider](https://firebase.google.com/docs/app-check/android/play-integrity-provider)