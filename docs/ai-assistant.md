# AI Assistant (Gemini Chat)

เอกสารนี้อธิบายฟีเจอร์ผู้ช่วย AI ใน Mnote: ปุ่ม ✨ มุมขวาบนของหน้าแก้ไขที่เปิดแชทคุยกับ Gemini ทำอะไรได้ ใช้วิธีไหนและเพราะอะไร ข้อมูลไหลผ่านไฟล์ใดบ้าง ความปลอดภัย การทดสอบ สิ่งที่ตั้งค่าใน Firebase Console ใครใช้ AI ได้บ้าง และถ้าจะต่อยอดต้องทำอย่างไร

- Branch: `feature/ai-chat`
- ตอบโจทย์อาจารย์ข้อ "ใช้ AI อย่างน้อย 1 Feature (Gemini API)" และเป็น Firebase บริการที่ 3 ของโปรเจกต์ (ต่อจาก Auth และ Firestore)
- สถานะ: Android ทดสอบบนแท็บเล็ตจริงแล้วทั้ง debug และ release, iOS ทดสอบบน iPad แล้ว (debug + debug token), CI ผ่านทั้ง Android และ iOS build

> ⚠️ **ก่อนเทสหรือ demo อ่านหัวข้อ 7.5 (ใครใช้ AI ได้) และ 7.6 (โควตา)** และคนดูแล Firebase อ่านหัวข้อ 7 ทั้งหมด

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
- **คำตอบทยอยขึ้นทีละส่วน** (streaming) ระหว่างรอแสดง "กำลังคิด…" ถ้าผู้ใช้เลื่อนขึ้นไปอ่านระหว่างที่ AI ตอบ หน้าจอจะไม่ดึงกลับลงล่าง
- **คำตอบแสดงเป็น Markdown** และบล็อกโค้ดในคำตอบแสดงเป็นการ์ด:
  - **` ```mermaid `**: การ์ดไดอะแกรม ระหว่างที่ AI ยังพิมพ์แสดงเป็นโค้ด พอตอบจบแสดงเป็น**ภาพ** (ใช้ `MermaidDiagramView` เดิม) มีปุ่มสลับ **ภาพ / โค้ด** และปุ่ม **คัดลอก** ที่คัดลอกพร้อมรั้ว ` ```mermaid ` วางในโน้ตแล้วเป็นผังทันที
  - **ภาษาอื่น** (` ```dart `, ` ```python `, ` ``` ` ฯลฯ): การ์ดโค้ดมีชื่อภาษา ปุ่ม **คัดลอก** (คัดลอกโค้ดล้วน ไม่มีรั้ว) และเลื่อนซ้ายขวาได้ถ้าบรรทัดยาว
  - โค้ดในบรรทัด เช่น `print()` แสดงตามปกติ ไม่เป็นการ์ด
  - กดคัดลอกแล้วไอคอนเปลี่ยนเป็น ✓ 2 วินาที (ไม่ใช้ SnackBar เพราะจะโดนหน้าต่างแชทบัง)
- **แถบความเป็นส่วนตัว:** "ข้อความที่พิมพ์จะถูกส่งไปประมวลผลที่ Google Gemini · AI ยังไม่ได้อ่านเนื้อหาโน้ตของคุณ"
- ปุ่มล้างบทสนทนา, แถบ error สี `errorContainer`
- **จำกัดข้อความ 2000 ตัวอักษร** นับตามตัวอักษรที่เห็น (ภาษาไทยที่มีสระบน/ล่างไม่ถูกนับเกิน) ถ้ายาวเกิน ข้อความยังอยู่ในช่องพิมพ์ให้แก้ต่อ

### 2.3 สิ่งที่ยังไม่ทำ (ตั้งใจ)

**AI ยังไม่อ่านเนื้อหาโน้ต** ตามที่ทีมกำหนด แต่เตรียมโครงไว้แล้ว (หัวข้อ 8.1)

---

## 3. โครงสร้างไฟล์

```
lib/
├── features/assistant/                      ใหม่ทั้งโฟลเดอร์
│   ├── domain/
│   │   ├── chat_message.dart                ข้อความแชท (role + text)
│   │   └── ai_assistant.dart                interface AiAssistant + exception + AiDocumentContext
│   ├── data/
│   │   └── firebase_ai_assistant.dart       ตัวจริง: เรียก Gemini ผ่าน Firebase AI Logic
│   └── presentation/
│       ├── assistant_chat_controller.dart   state ของแชท (ChangeNotifier)
│       ├── assistant_chat_panel.dart        หน้าแชท + showAssistantChat()
│       └── assistant_code_block_builder.dart การ์ดโค้ดและการ์ดไดอะแกรม (เฉพาะในแชท)
└── features/workspace/presentation/
    └── markdown_workspace_page.dart         แก้ +28/-1: ปุ่ม ✨ + พารามิเตอร์ assistant

test/
├── helpers/fake_ai_assistant.dart           ตัวปลอมสำหรับ test (ไม่ต่อเน็ต)
└── features/assistant/
    ├── assistant_chat_controller_test.dart  15 test
    ├── assistant_chat_panel_test.dart       16 test
    ├── assistant_entry_test.dart             6 test
    ├── firebase_ai_assistant_test.dart      11 test
    └── assistant_code_block_builder_test.dart 9 test
```

แพ็กเกจที่เพิ่มใน `pubspec.yaml`: `firebase_ai: ^4.0.0` อย่างเดียว (`firebase_app_check` มาจาก PR #33 ของทีม)

**ไฟล์ของทีมที่แตะ มีแค่ไฟล์เดียว และเพิ่มอย่างเดียว:** `markdown_workspace_page.dart` (เปลี่ยนแค่บรรทัด `this.assistant,` เป็นค่าเริ่มต้น)

**App Check ไม่ได้อยู่ในงานนี้:** เปิดไว้ใน `main.dart` โดย PR #33 ของทีมแล้ว (`_activateAppCheck()`) งานนี้ใช้ตัวนั้นตรง ๆ ไม่ได้ตั้งค่าซ้ำ เดิมเคยมี `lib/core/app_check.dart` ของเราเอง แต่ลบออกหลัง #33 merge เพื่อไม่ให้มีจุดตั้งค่า 2 ที่ ถ้ามีคนเปลี่ยน provider ใน `main.dart` วันหลัง ค่าของเราจะไม่ไปทับเงียบ ๆ

---

## 4. การไหลของข้อมูล

```
แอปเปิด
  → main.dart (#33)              Firebase.initializeApp → _activateAppCheck()

ผู้ใช้กด ✨
  → _openAssistant()            สร้าง AssistantChatController ครั้งแรก (เก็บไว้ในหน้า)
  → showAssistantChat()         เลือก fullscreen / side sheet ตามความกว้างจอ
  → AssistantChatPanel          ผู้ใช้พิมพ์แล้วกดส่ง
  → AssistantChatController.send()
       ตรวจ: ว่าง? ยาวเกิน 2000 (นับตัวอักษรที่เห็น)? กำลังตอบอยู่?
       ตัดประวัติเหลือ 20 ข้อความล่าสุด
       document: null           (ไม่ส่งโน้ต)
  → AiAssistant.sendMessage()   (interface)
  → FirebaseAiAssistant
       buildGeminiHistory()     กรองให้ผู้ใช้/AI สลับกัน
       chat.sendMessageStream()
         → firebase_ai ขอ App Check token ──→ Firebase AI Logic ──→ Gemini
  ← คำตอบทีละชิ้น (Stream<String>) ← controller ต่อข้อความ ← หน้าจอวาดใหม่
```

**ถ้าผิดพลาด:** `FirebaseAiAssistant` แปลง error เป็น `AiAssistantException` ข้อความไทย controller แสดงในแถบ error แล้ว**ถอยกลับ** เอาทั้งคำถามและคำตอบที่ไม่จบออกจากรายการ (`send()` คืน `false`) หน้าจอคืนข้อความเข้าช่องพิมพ์ให้กดส่งซ้ำได้ แอปไม่ค้างหรือเด้ง

การแปลงอยู่ในฟังก์ชัน `aiErrorToException()` ที่เดียว (เช็กตามลำดับในตาราง):

| error | ข้อความที่ผู้ใช้เห็น | สาเหตุที่เคยเจอ |
|---|---|---|
| `QuotaExceeded` | "ใช้ผู้ช่วย AI ครบโควตาแล้ว รอสักครู่แล้วลองใหม่ ถ้ายังไม่ได้ แปลว่าโควตาของวันนี้หมด..." | โควตาฟรีหมด (หัวข้อ 7.6) |
| `FirebaseAIException` อื่น | "ผู้ช่วย AI ไม่พร้อมใช้งานชั่วคราว..." | เซิร์ฟเวอร์ตอบกลับมาว่าไม่ได้ |
| `FirebaseException` ของ `firebase_app_check` | "ยืนยันความปลอดภัยของแอปไม่สำเร็จ..." | debug token ไม่ได้ลงทะเบียน, Play Integrity ไม่ผ่าน |
| `Exception` อื่น | "เชื่อมต่อผู้ช่วย AI ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ต..." | เน็ตหลุด |

`QuotaExceeded` เป็นลูกของ `FirebaseAIException` จึงต้องเช็กก่อน แพ็กเกจสร้าง `QuotaExceeded` เมื่อข้อความจากเซิร์ฟเวอร์มีคำว่า "quota" ซึ่งรวมทั้งโควตาต่อนาทีและต่อวัน แยกกันไม่ได้ ข้อความจึงครอบคลุมทั้งสองกรณี

**log:** `describeAiError()` พิมพ์แค่ชนิดของ error หรือ `plugin/code` ของ Firebase เช่น `AI request failed: firebase_app_check/unknown` หรือ `AI request failed: QuotaExceeded` ไม่พิมพ์ข้อความเต็ม (อาจมีรายละเอียดภายในของโปรเจกต์) แค่นี้พอบอกสาเหตุได้แทบทุกกรณี ถ้าต้องดูข้อความเต็มจริง ๆ ให้แก้ชั่วคราวเป็น `debugPrint('...: $error')` แล้ว**แก้กลับก่อน commit ทุกครั้ง**

**ถ้าออกจากหน้าแก้ไขระหว่าง AI กำลังตอบ:** `dispose()` ของหน้าเรียก `_assistantChat?.dispose()` ซึ่งยกเลิกการรับคำตอบทันที ไม่มีการเชื่อมต่อค้างในพื้นหลัง

---

## 5. การตัดสินใจหลักและเหตุผล

| การตัดสินใจ | เหตุผล |
|---|---|
| **interface `AiAssistant` + ตัวจริง/ตัวปลอม** | test ทั้ง UI และ controller ได้โดยไม่ต่อเน็ตและไม่ใช้โควตา และเปลี่ยนผู้ให้บริการ AI ได้โดยไม่แก้หน้าจอ |
| **พารามิเตอร์ `assistant` ค่าเริ่มต้น `const FirebaseAiAssistant()`** | หน้าแก้ไขถูกสร้างจาก 4 จุดในไฟล์ของเพื่อน ใช้ค่าเริ่มต้นทำให้ปุ่มขึ้นทุกหน้าโดยไม่ต้องแก้ไฟล์เหล่านั้น ส่ง `null` เพื่อซ่อนปุ่มได้ ตัวจริงไม่ติดต่อ Firebase จนกว่าจะกดส่ง จึงไม่กระทบ test เดิม |
| **side sheet แบบลอย ไม่ใช่แผงแทรกในหน้า** | ไม่ต้องรื้อโครง `build()` ของหน้าแก้ไข (ไฟล์ที่ทุกคนแก้) และเป็นรูปแบบที่ MD3 มี |
| **ใช้ App Check จาก `main.dart` (#33) ไม่ตั้งเอง** | มีจุดตั้งค่าที่เดียว เราไม่ต้องแตะ `main.dart` ของทีม |
| **`Completer` ใน `send()`** | ให้ `dispose()` ยกเลิก subscription และปลด `send()` ได้ทันที ถ้าใช้ `await for` การเชื่อมต่อจะค้างจนกว่าจะมีข้อความชิ้นถัดไป |
| **นับความยาวข้อความตามตัวอักษรที่เห็น (`characters`)** | ช่องพิมพ์นับแบบนี้ ถ้า controller นับ `String.length` ภาษาไทยที่มีสระบน/ล่างจะนับเกิน ผู้ใช้โดนปฏิเสธทั้งที่ยังพิมพ์ไม่ถึง 2000 |
| **ล้างช่องพิมพ์เฉพาะเมื่อ controller รับข้อความ และคืนข้อความถ้าตอบไม่สำเร็จ** | ถ้าข้อความถูกปฏิเสธหรือเน็ตหลุด/โควตาหมด ผู้ใช้ไม่ต้องพิมพ์ใหม่ (controller ตรวจความยาวก่อน `await` แรก หน้าจอจึงเช็ก `isResponding` ได้ทันที และ `send()` คืน `bool` บอกผล) ถ้าระหว่างรอผู้ใช้พิมพ์อะไรใหม่ไว้ จะไม่เขียนทับ |
| **ตอบไม่สำเร็จแล้วถอยกลับทั้งคู่ (คำถาม + คำตอบที่ไม่จบ)** | คำตอบที่ขาดกลางทางถ้าเก็บไว้ จะถูกส่งเป็นประวัติรอบหน้า Gemini จะเข้าใจว่าเป็นคำตอบที่สมบูรณ์ |
| **เปิดแผงใหม่แล้วเลื่อนไปข้อความล่าสุด** | controller อยู่ต่อหลังปิดแผง แต่หน้าจอสร้างใหม่ ต้องตั้งค่าเริ่มต้นจากบทสนทนาเดิมใน `initState` ไม่งั้นบทสนทนายาวจะเริ่มที่ข้อความบนสุด |
| **ไม่ cache `GenerativeModel`** | สร้างใหม่ทุกครั้งที่ส่งเป็นแค่ object ไม่ได้ต่อเน็ต และ `static` ที่เปลี่ยนค่าได้ใน class ที่เป็น `const` รีเซ็ตไม่ได้ |
| **เลื่อนลงเองเฉพาะตอนอยู่ท้ายรายการหรือเพิ่งส่ง** | ผู้ใช้เลื่อนขึ้นไปอ่านระหว่างที่ AI ตอบได้โดยไม่ถูกดึงลง เช็กตำแหน่ง**ก่อน**ข้อความชิ้นใหม่ถูกวาด ไม่งั้นจะคิดว่าผู้ใช้เลื่อนหนีทั้งที่ไม่ได้เลื่อน |
| **Mermaid แสดงเป็นโค้ดระหว่าง AI พิมพ์ แล้วค่อยวาดตอนจบ** | โค้ดที่ยังพิมพ์ไม่จบทำให้ตัววาดผังขึ้น Syntax error `MarkdownBody` ใช้ `key: ValueKey(isStreaming)` เพราะมันแปลงใหม่เฉพาะตอน `data` เปลี่ยน ถ้าไม่มี key การ์ดจะค้างที่โค้ด |
| **การ์ดโค้ดในแชทแยกจาก `MermaidElementBuilder` ของหน้าโน้ต** | ปุ่มสลับ/คัดลอกเหมาะกับแชท ไม่ไปเปลี่ยนหน้าตาหน้าโน้ตของเพื่อน ใช้ `MermaidDiagramView` ตัวเดิม (ผ่าน `mermaid.dart`) จึงไม่ได้วาดผังซ้ำ ปุ่มคัดลอกเป็น `_CopyCodeButton` ตัวเดียวใช้ร่วมทั้ง 2 การ์ด |
| **แยกบล็อกโค้ดกับโค้ดในบรรทัดด้วย `\n` ท้ายข้อความ** | บล็อกที่ล้อมด้วย ``` ลงท้ายด้วยขึ้นบรรทัดใหม่เสมอ โค้ดในบรรทัดไม่มี |
| **`buildGeminiHistory()` ส่งเฉพาะคู่ที่สมบูรณ์** | ถ้า AI เคยตอบพลาด ประวัติจะมีข้อความผู้ใช้ติดกัน 2 อัน Gemini อาจปฏิเสธคำขอ |
| **ไม่แสดง error ดิบของ Google** | อาจมีรายละเอียดภายในของโปรเจกต์ และผู้ใช้อ่านไม่เข้าใจ |
| **`on Exception` ไม่ใช่ `catch` เปล่า** | ไม่กลืน `Error` ที่เป็นบั๊กของโปรแกรม ซึ่งควรเห็นตอนพัฒนา |
| **แยกข้อความ error ตามสาเหตุ และแยกเป็นฟังก์ชัน `aiErrorToException()`** | เดิมโควตาหมดขึ้นแค่ "ไม่พร้อมใช้งาน" และ App Check ไม่ผ่านขึ้นว่า "ตรวจสอบอินเทอร์เน็ต" ซึ่งพาไปผิดทาง แยกเป็นฟังก์ชันที่รับ error แล้วคืนข้อความ จึง test ได้ทุกกรณีโดยไม่ต้องเรียก Gemini จริง |

---

## 6. ความปลอดภัย

| ความเสี่ยง | การป้องกัน | หลักฐาน |
|---|---|---|
| API key หลุด | Gemini key ไม่อยู่ในแอปหรือ repo อยู่ที่ Firebase AI Logic (`firebase_options.dart` มีแค่ค่า config ซึ่งไม่ใช่ความลับ) | ไม่มีโค้ดส่วนไหนอ่านหรือเก็บ key |
| คนนอกใช้โควตา (สคริปต์, แอปปลอม, โปรแกรมจำลอง) | App Check: firebase_ai ไม่ส่งคำขอถ้าไม่มี token, release ต้องผ่าน Play Integrity ระดับ Device integrity และเซ็นด้วย key ที่ลงทะเบียน | ทดสอบบนเครื่องจริง (หัวข้อ 7.3) |
| ส่งข้อความยาวมากเพื่อผลาญโควตา | จำกัด 2000 ตัวอักษร ทั้งช่องพิมพ์และ controller (นับแบบเดียวกัน) | test (Security) 3 ข้อ |
| ประวัติแชทยาวไม่สิ้นสุด | ส่งแค่ 20 ข้อความล่าสุด | test (Security) |
| **เนื้อหาโน้ตหลุดไปให้ AI** | controller ส่ง `document: null` เสมอ และถ้ามีใครส่ง `document` มา `FirebaseAiAssistant` จะ `throw UnsupportedError` ทันที (ทำงานใน release ด้วย ต่างจาก `assert`) | test (Security) ใน controller และ entry, test ที่ส่ง document แล้วต้อง error |
| **คำตอบ AI ใช้ติดตามผู้ใช้** (รูปจาก URL ภายนอก) | `imageBuilder` แสดงข้อความ alt แทน ไม่โหลดรูป | test (Security): ไม่มี `Image` |
| คำตอบ AI มีลิงก์อันตราย | ไม่ใส่ `onTapLink` ลิงก์ในคำตอบกดไม่ได้ | — |
| log หลุดข้อมูล | `describeAiError()` พิมพ์แค่ชนิดของ error หรือ `plugin/code` ไม่พิมพ์ข้อความผู้ใช้หรือรายละเอียด error | test (Security) |
| debug token หลุด | ไม่อยู่ในโค้ด/repo/PR ลงทะเบียนผ่าน Console ทีละเครื่อง ลบได้ทันทีถ้าหลุด | หัวข้อ 7.4 |

ผู้ใช้ถูกแจ้งตลอดเวลาว่าข้อความถูกส่งไป Google Gemini (แถบความเป็นส่วนตัวด้านบนของแชท)

---

## 7. Firebase Console และการใช้งานจริง (สำคัญสำหรับคนดูแล Firebase และวันเทส)

### 7.1 การตั้งค่าปัจจุบัน

| ที่ | ค่า |
|---|---|
| AI Logic → ผู้ให้บริการ | **Gemini Developer API** (แผน Spark ฟรี ไม่ผูกบัตร) |
| AI Logic → AI monitoring | **ปิด** (อาจเก็บข้อความผู้ใช้ไว้ใน log ควรตกลงกับทีมก่อนเปิด) |
| App Check → APIs → Firebase AI Logic | **Basic - Monitoring** / Replay protection: **Disabled** |
| App Check → Apps → mnote (android) → Play Integrity | SHA-256 2 ตัว (`ba:25:...` และ `2E:66:...`) |
| Play Integrity → Advanced settings | ☐ `PLAY_RECOGNIZED`, ☐ `LICENSED`, ระดับขั้นต่ำ **Device integrity** |
| debug token (android) | `Tablet SM-T735 (Faa)` |
| debug token (ios) | `pet` (iPad) |
| App Check → Apps → mnote (ios) | ไม่ได้ลงทะเบียน App Attest / DeviceCheck (หัวข้อ 7.5) |
| App Check ของ Firestore / Auth | **ไม่ได้แตะ** (Monitoring) |

**ห้ามเปิด Replay protection:** ต้องใช้ token แบบใช้ครั้งเดียว (limited-use) ซึ่งโค้ดไม่ได้ขอ ถ้าเปิด AI จะโดนบล็อกทุกเครื่อง

**ห้ามกด Enforce ของ Firestore / Auth ตอนนี้:** หน้า App Check แสดงว่าคำขอส่วนใหญ่ยังไม่ผ่าน (Firestore unverified ~76%) ถ้ากด เพื่อนส่วนใหญ่จะล็อกอินหรือโหลดโน้ตไม่ได้ทันที

### 7.2 สิ่งที่ค้นพบจากการทดสอบจริง

1. **firebase_ai ไม่ส่งคำขอเลยถ้าขอ App Check token ไม่ได้ แม้ AI Logic ยังเป็นโหมด Monitoring** (เห็นจาก log: ขอ token ไม่ผ่าน → `FirebaseException` ทันที คำขอไม่ไปถึงเซิร์ฟเวอร์) โหมด Monitoring จึง**ไม่ได้**ทำให้เครื่องที่ไม่ได้ลงทะเบียนใช้ AI ได้อย่างที่เข้าใจตอนแรก ทุกเครื่องต้องผ่าน App Check เสมอ
2. **หน้า App Check นับเฉพาะคำขอที่ไปถึงเซิร์ฟเวอร์** คำขอที่ล้มตั้งแต่ขั้นขอ token ไม่ถูกนับ จึงอาจเห็น verified 100% ทั้งที่บางเครื่องใช้ไม่ได้
3. **เส้นตาย 2 พฤศจิกายน 2026:** Firebase จะบังคับ App Check กับ AI Logic อัตโนมัติและปิดไม่ได้อีก เพราะข้อ 1 ผลจริงจึง**เหมือนตอนนี้ทุกอย่าง**:
   - **Android:** ตั้งค่า Play Integrity ครบแล้ว (7.3) ไม่ต้องทำอะไรเพิ่ม debug build ยังต้องลงทะเบียน debug token เหมือนเดิม (7.4)
   - **iOS:** ใช้ AI ได้**เฉพาะเครื่องที่ลงทะเบียน debug token** เท่านั้น แอป iOS แบบ release ใช้ AI ไม่ได้ทั้งก่อนและหลังวันนั้น เพราะไม่ได้ลงทะเบียน App Attest / DeviceCheck (ต้องมีบัญชี Apple Developer แบบเสียเงิน, 7.5)

### 7.3 Play Integrity (แอป Android release)

แอป release ใช้ Play Integrity แทน debug token ต้องผ่าน 2 เงื่อนไข**พร้อมกัน**:

| เงื่อนไข | ทำไม | ถ้าไม่มี |
|---|---|---|
| SHA-256 ของ key ที่เซ็นแอป ลงทะเบียนใน Console | Firebase ตรวจว่าแอปเซ็นด้วย key ที่รู้จัก | `403 App attestation failed` |
| ปิด `PLAY_RECOGNIZED` | แอปเราไม่ได้ขึ้น Google Play จึงไม่มีทางผ่านข้อนี้ | `403 App attestation failed` ทุกครั้ง |

ทดสอบแล้ว: ลบ SHA-256 ออก → AI ใช้ไม่ได้, ใส่กลับ → ใช้ได้ (ต้องติดตั้งแอปใหม่เพื่อทิ้ง token เก่าที่ใช้ได้ 1 ชั่วโมง)

ใช้ระดับ **Device integrity** แทน `PLAY_RECOGNIZED` เพื่อยังกันโปรแกรมจำลอง เครื่องที่ root และสคริปต์ได้ (ไม่ใช้ Strong integrity เพราะเครื่องรุ่นเก่าอย่าง SM-T735 อาจไม่ผ่าน)

**SHA-256 ผูกกับคอมที่ build ไม่ใช่เครื่องที่ใช้แอป:** ตอนนี้ทีมเซ็นแอป release ด้วย debug key ของแต่ละคอม (`android/app/build.gradle.kts` บรรทัด 35) ซึ่งแต่ละคอมไม่เหมือนกัน
- ใครจะ build APK release ไปแจก ต้องเพิ่ม SHA-256 ของคอมตัวเองก่อน: `cd android && ./gradlew signingReport` → ค่า `SHA-256` ใต้ `Variant: release` → Console → Play Integrity → **Add another fingerprint** (**อย่าลบของคนอื่น**)
- หรือตกลงให้คนเดียวเป็นคน build APK
- ระยะยาว: Owner สร้าง release key ร่วมกันหนึ่งตัว (ไฟล์ key และรหัสผ่านเป็นความลับ ห้ามใส่ใน git) จะเหลือ SHA-256 ตัวเดียว
- SHA-256 **ไม่ใช่ความลับ** (เป็นลายนิ้วมือของ certificate) แชร์ในทีมได้

### 7.4 debug token (นักพัฒนาที่ใช้ `flutter run`)

debug build ใช้ debug token ไม่ใช้ Play Integrity / App Attest ทุกเครื่องที่ `flutter run` แล้วจะใช้ AI ต้องลงทะเบียน token ของเครื่องนั้น:

**Android**
1. `flutter run` → เปิดแชท → ส่งข้อความ 1 ครั้ง (จะ error)
2. `adb logcat -d | grep DebugAppCheckProvider` → คัดลอกรหัสหลัง `Firebase App Check debug token:`

**iOS (บน Mac)**
1. เปิด `ios/Runner.xcworkspace` ใน Xcode → เลือก iPhone/iPad Simulator หรือเครื่องจริง → กด ▶
2. ใน console ของ Xcode ค้น `App Check debug token` → คัดลอกรหัส (บรรทัด `Failed to exchange debug token` ก่อนหน้าเป็นเรื่องปกติ แปลว่ายังไม่ได้ลงทะเบียน)

**ลงทะเบียน (ทั้งสองแพลตฟอร์ม)**
App Check → Apps → แถวของแพลตฟอร์มนั้น → **⋮** → **Manage debug tokens** → Add → ตั้งชื่อ `อุปกรณ์ (ชื่อคน)` → วาง token → Save
- **อย่ากด Generate token** (ใช้สำหรับ CI จะได้ token ที่ไม่ตรงกับเครื่อง)
- **อย่าวางในช่อง SHA-256 ของ Play Integrity** (คนละช่อง ระบบจะฟ้องว่าต้องเป็น 64 ตัวอักษร)
- แอป iOS ไม่ต้องลงทะเบียน App Attest / DeviceCheck ก่อน ก็เพิ่ม debug token ได้ และไม่ต้องมีบัญชี Apple Developer แบบเสียเงิน (ทดสอบแล้วบน iPad)

**debug token เป็นความลับ** ห้ามใส่ในโค้ด, README, PR หรือแชทกลุ่ม ส่งให้คนลงทะเบียนทางแชทส่วนตัว ถ้าล้างข้อมูลแอป ถอนการติดตั้ง หรือรีเซ็ต simulator จะได้รหัสใหม่และต้องลงทะเบียนอีกครั้ง

### 7.5 ใครใช้ AI ได้บ้าง

| แพลตฟอร์ม / build | ใช้ AI ได้ไหม | ต้องทำอะไร |
|---|---|---|
| Android `flutter run` (debug) | ได้ | ลงทะเบียน debug token ของเครื่องนั้น (7.4) |
| Android APK release บนเครื่องจริง | **ได้ทุกเครื่อง** ไม่ต้องลงทะเบียน | ต้อง build จากคอมที่ใส่ SHA-256 ไว้แล้ว (7.3) |
| Android release บนโปรแกรมจำลอง | ไม่ได้ | ตั้งใจ: ไม่ผ่าน Device integrity |
| iOS `flutter run` / Xcode (debug) | **ได้เฉพาะเครื่องที่ลงทะเบียน debug token** (ทดสอบแล้วบน iPad) | ลงทะเบียน debug token ในแถว mnote (ios) |
| iOS แบบ release / แอปที่แจกคนอื่น | **ไม่ได้** (firebase_ai ไม่ส่งคำขอเพราะไม่มี App Check token) | ต้องลงทะเบียน App Attest / DeviceCheck ซึ่งต้องมีบัญชี Apple Developer แบบเสียเงิน และการแจกแอปผ่าน TestFlight / Ad Hoc ก็ต้องใช้บัญชีนี้ ทีมยังไม่มี |

**iOS แจกไม่ได้เป็นข้อจำกัดของ Apple ไม่ใช่ของ AI:** ถ้าไม่มีบัญชี Apple Developer แบบเสียเงิน แอปทั้งตัวก็ติดตั้งลง iPhone ของคนอื่นไม่ได้อยู่แล้ว (บัญชีฟรีใช้ TestFlight / App Store ไม่ได้ และ Ad Hoc ต้องเป็นบัญชีเสียเงิน) ถ้าอาจารย์ใช้ iPhone ให้ demo บนเครื่องของทีม

**แนะนำสำหรับวันเทส**
- คนที่แค่เทส ไม่ได้แก้โค้ด: ใช้ **APK release** (`flutter build apk --release` จากคอมที่ลงทะเบียน SHA-256 แล้ว ไฟล์อยู่ที่ `build/app/outputs/flutter-apk/app-release.apk`) ปลอดภัยที่สุดและเป็นการเทสแอปตัวจริง
- คนที่ต้อง `flutter run` เพื่อแก้โค้ด: ลงทะเบียน debug token ของเครื่องตัวเองล่วงหน้า
- APK ที่ CI สร้าง (`Build Android debug APK`) เป็น debug ใช้ AI ไม่ได้ถ้าไม่ลงทะเบียน token

### 7.6 โควตา (สำคัญ)

แผน Spark ใช้โควตาฟรีของ Gemini Developer API ซึ่ง**หมดเร็วกว่าที่คิด** (เคยหมดภายในวันเดียวระหว่างทดสอบหลายเครื่อง)
- พอหมด ผู้ใช้เห็น "ใช้ผู้ช่วย AI ครบโควตาแล้ว..." แอปไม่พัง และใน log เห็น `AI request failed: QuotaExceeded`
- โควตามีทั้งต่อนาทีและต่อวัน **โควตาต่อวันรีเซ็ตเที่ยงคืนเวลาแปซิฟิก** (ประมาณ 14:00 น. เวลาไทย และประมาณ 15:00 น. หลังสหรัฐฯ เลิกใช้เวลาออมแสงต้นเดือนพฤศจิกายน)
- ตัวเลขโควตาจริงของโมเดลดูได้ในหน้า rate limit ของ Google AI Studio หรือ Google Cloud Console (ต้องใช้บัญชีที่เป็นเจ้าของโปรเจกต์)
- **ช่วงก่อนวันเทส ไม่ควรเทส AI บ่อย** และวันเทสควร demo AI จากเครื่องเดียวหรือสองเครื่อง
- **ห้ามกด Upgrade เป็น Blaze** เพื่อแก้โควตาโดยไม่ได้ตกลงกับทีม (ต้องผูกบัตรและอาจเสียเงิน)

### 7.7 Checklist ก่อนปล่อยแอปจริง

- [x] ลงทะเบียน Play Integrity + ปิด `PLAY_RECOGNIZED` + Device integrity (7.3)
- [ ] ลงทะเบียน debug token ของทุกคนที่ `flutter run` (7.4)
- [ ] กด Enforce App Check ของ AI Logic (หรือรอ Firebase บังคับเองวันที่ 2 พ.ย. ผลเหมือนกัน)
- [ ] ลบ debug token ที่ไม่ใช้แล้ว (โดยเฉพาะก่อนอัปเกรดเป็นแผน Blaze)
- [ ] พิจารณาสร้าง release key ร่วมกันของทีม (7.3)
- [ ] พิจารณาเปิด **authenticated-users mode** ของ AI Logic (ให้เฉพาะคนที่ล็อกอินใช้ได้ แอปบังคับล็อกอินอยู่แล้ว ไม่ต้องแก้โค้ด)
- [ ] พิจารณาลด rate limit ต่อผู้ใช้ (ค่าเริ่มต้น 100 ครั้ง/นาที) ใน Google Cloud Console → Firebase AI Logic API → Quotas

---

## 8. ต่อยอด

### 8.1 ให้ AI อ่านโน้ต

โครงเตรียมไว้แล้ว: `AiAssistant.sendMessage()` รับ `AiDocumentContext? document` (title + content)

1. ใน `AssistantChatController` เพิ่มทางเลือกให้ผู้ใช้**กดเองอย่างชัดเจน** เช่น ชิป "แนบโน้ตนี้" (ห้ามส่งอัตโนมัติ เพราะเป็นเรื่องความเป็นส่วนตัว)
2. ส่ง `AiDocumentContext(title: ..., content: ...)` แทน `null` และจำกัดความยาวเนื้อหา (โน้ตยาวกินโควตาจำนวน token มาก หัวข้อ 7.6)
3. ใน `FirebaseAiAssistant` ลบ `throw UnsupportedError` แล้วนำ `document` ไปรวมกับข้อความ โดย**ห่อด้วยตัวคั่นและบอก AI ว่าเนื้อหาโน้ตเป็นข้อมูล ไม่ใช่คำสั่ง** (กัน prompt injection เช่น โน้ตที่มีคำว่า "ไม่ต้องสนใจคำสั่งก่อนหน้า")
4. เปลี่ยนแถบความเป็นส่วนตัวให้บอกว่าโน้ตถูกส่งไปด้วย และแก้ test (Security) ที่ตรวจ `document == null` กับ test ที่ตรวจ `UnsupportedError`
5. แก้ `_systemPrompt` ที่บอกว่า AI มองไม่เห็นโน้ต (หัวข้อ 8.3)

### 8.2 เปิด App Check กับ Firestore / Auth

โค้ดเปิด App Check ให้ทั้งแอปแล้ว (`main.dart` จาก #33) เหลือฝั่ง Console เป็นงานของ Owner:
1. ตรวจ Firestore Security Rules ก่อน (App Check ไม่ได้แทน Rules)
2. ทุกคนในทีมลงทะเบียน debug token
3. ดูกราฟ verified/unverified ในหน้า App Check จน unverified ใกล้ 0% แล้วค่อยกด Enforce ทีละบริการ

### 8.3 เปลี่ยนโมเดลหรือข้อความระบบ

แก้ `FirebaseAiAssistant.modelName` และ `_systemPrompt` ในไฟล์เดียว

`_systemPrompt` บอก AI ไว้ว่ามองไม่เห็นและแก้โน้ตไม่ได้ (เคยเจอ AI ตอบว่า "แก้โน้ตให้แล้ว" ทั้งที่ทำไม่ได้) ถ้าทำฟีเจอร์แนบโน้ตตามหัวข้อ 8.1 ต้องแก้ข้อความนี้ด้วย

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

### 8.5 ใช้การ์ดโค้ดในหน้าอื่น

```dart
MarkdownBody(
  data: text,
  builders: {'code': AssistantCodeBlockBuilder()},
)
```
บล็อก mermaid เป็นการ์ดภาพ/โค้ด บล็อกอื่นเป็นการ์ดโค้ดพร้อมปุ่มคัดลอก ถ้าข้อความยังพิมพ์ไม่จบ (เช่น สตรีม) ส่ง `isStreaming: true` และใส่ `key: ValueKey(isStreaming)` ให้ `MarkdownBody` ด้วย (หัวข้อ 5)

---

## 9. การทดสอบ

**อัตโนมัติ:** 57 test ใหม่ (รวมทั้งโปรเจกต์ 331) `flutter analyze --fatal-infos` ไม่มีปัญหา

| ไฟล์ | ครอบคลุม |
|---|---|
| `assistant_chat_controller_test.dart` | ส่ง/รับทีละส่วน, ข้อความว่าง, ส่งซ้ำระหว่างตอบ, error, ล้าง, dispose กลางคำตอบ, (Security) 2001 ตัวอักษร, (Security) ภาษาไทยนับตามตัวที่เห็น, (Security) ประวัติ 20, (Security) ไม่ส่งโน้ต, ส่งคืน true/false, ตอบไม่สำเร็จแล้วไม่เหลือคำตอบที่ไม่จบในประวัติ |
| `assistant_chat_panel_test.dart` | หน้าว่าง, ปุ่มส่ง, คำแนะนำ, error, Markdown, ไดอะแกรม, "กำลังคิด", ล้าง, (Security) ไม่โหลดรูป, (Security) maxLength, fullscreen 320 / side sheet 1024, ช่องพิมพ์อยู่เหนือแป้นพิมพ์, เปิดแผงใหม่เริ่มที่ข้อความล่าสุด, ส่งไม่สำเร็จแล้วข้อความกลับเข้าช่องพิมพ์ |
| `assistant_code_block_builder_test.dart` | Mermaid: เริ่มต้นเป็นภาพ, สลับเป็นโค้ดและกลับ, คัดลอกพร้อมรั้ว ` ```mermaid ` และไอคอน ✓ 2 วินาที, ระหว่างสตรีมแสดงโค้ดแล้วเปลี่ยนเป็นภาพเมื่อจบ / การ์ดโค้ด: ชื่อภาษา, คัดลอกโค้ดล้วน, ไม่ระบุภาษาขึ้น "โค้ด", โค้ดในบรรทัดไม่เป็นการ์ด |
| `assistant_entry_test.dart` | ไม่มี assistant ไม่มีปุ่ม, เปิดบนแท็บเล็ต/มือถือ, บทสนทนายังอยู่, (Security) โน้ตไม่ถูกส่ง, ออกจากหน้าไม่ error |
| `firebase_ai_assistant_test.dart` | `buildGeminiHistory` 4 กรณี, สร้างตัวจริงได้โดยไม่ต้องเปิด Firebase, ส่ง document แล้วได้ `UnsupportedError`, ข้อความ error 4 กรณี (โควตา / เซิร์ฟเวอร์ / App Check / เน็ต), (Security) log ไม่มีข้อความ error |

**บนเครื่องจริง (Samsung SM-T735)**
- debug: คุยได้, คำตอบทยอยขึ้น, ไดอะแกรมจาก AI แสดงเป็นภาพ, ปิด/เปิดแผงบทสนทนายังอยู่, ช่องพิมพ์ไม่โดนแป้นพิมพ์บัง, ขอให้แก้โน้ตแล้ว AI แจ้งว่าทำไม่ได้, Firestore/Auth ทำงานปกติ
- release: ใช้ AI ได้หลังตั้งค่า Play Integrity (หัวข้อ 7.3), ลบ SHA-256 แล้วใช้ไม่ได้ ใส่กลับแล้วใช้ได้
- โควตาหมด: แอปไม่พัง (ทดสอบก่อนแยกข้อความ ตอนนั้นขึ้น "ไม่พร้อมใช้งานชั่วคราว" ข้อความเรื่องโควตาแบบใหม่ยังไม่ได้เห็นบนเครื่อง)

**iPad (iOS, debug):** ลงทะเบียน debug token แล้วคุยกับ AI ได้ตามปกติ ไม่ต้องมีบัญชี Apple Developer แบบเสียเงิน

**ยังไม่ได้ทดสอบบนเครื่อง** (รอโควตารีเซ็ต): การ์ดโค้ดพร้อมปุ่มคัดลอก, Mermaid ระหว่างสตรีม, การเลื่อนอ่านระหว่าง AI ตอบ

**ไม่ได้ทดสอบอัตโนมัติ:** การเรียก Gemini จริง (ต้องใช้เน็ตและโควตา) จึงทดสอบด้วยมือ

---

## 10. อ้างอิง

- [Firebase AI Logic: Get started](https://firebase.google.com/docs/ai-logic/get-started?api=dev)
- [Firebase AI Logic: App Check](https://firebase.google.com/docs/ai-logic/app-check)
- [Firebase AI Logic: Production checklist](https://firebase.google.com/docs/ai-logic/production-checklist)
- [Firebase AI Logic: Rate limits and quotas](https://firebase.google.com/docs/ai-logic/quotas)
- [Gemini API: Rate limits](https://ai.google.dev/docs/increase_quota)
- [App Check: debug provider (Flutter)](https://firebase.google.com/docs/app-check/flutter/debug-provider)
- [App Check: debug provider (iOS)](https://firebase.google.com/docs/app-check/ios/debug-provider)
- [App Check: Play Integrity provider](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
- [App Check: App Attest provider](https://firebase.google.com/docs/app-check/ios/app-attest-provider)