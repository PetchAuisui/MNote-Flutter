// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get save => 'บันทึก';

  @override
  String get close => 'ปิด';

  @override
  String get done => 'เสร็จสิ้น';

  @override
  String get reset => 'คืนค่าเริ่มต้น';

  @override
  String get followDevice => 'ตามเครื่อง';

  @override
  String get settingsTitle => 'การตั้งค่า';

  @override
  String get accentTitle => 'สีของแอป (Accent)';

  @override
  String accentName(String color) {
    return 'สี$color';
  }

  @override
  String get accentBlue => 'ฟ้า';

  @override
  String get accentPurple => 'ม่วง';

  @override
  String get accentGreen => 'เขียว';

  @override
  String get accentRed => 'แดง';

  @override
  String get accentYellow => 'เหลือง';

  @override
  String get accentPink => 'ชมพู';

  @override
  String get accentOrange => 'ส้ม';

  @override
  String get themeTitle => 'โหมดการแสดงผล (Theme)';

  @override
  String get themeSystem => 'ตามเครื่อง';

  @override
  String get themeLight => 'สว่าง';

  @override
  String get themeDark => 'มืด';

  @override
  String get themeHintSystem =>
      'ค่าเริ่มต้น: ปรับมืด/สว่างอัตโนมัติตามโหมดของเครื่อง';

  @override
  String get themeHintDark => 'เปิดใช้งานโหมดมืด';

  @override
  String get themeHintLight => 'เปิดใช้งานโหมดสว่าง';

  @override
  String get languageTitle => 'ภาษา (Language)';

  @override
  String get languageSystem => 'ตามภาษาเครื่อง';

  @override
  String get languageThai => 'ไทย';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHint =>
      'ถ้าเครื่องใช้ภาษาที่แอปยังไม่รองรับ จะแสดงเป็นภาษาไทย';

  @override
  String get accountTitle => 'บัญชี (Account)';

  @override
  String get noName => 'ไม่ระบุชื่อ';

  @override
  String get signOut => 'ออกจากระบบ';

  @override
  String get displayNameLabel => 'ชื่อที่แสดง';

  @override
  String get editName => 'แก้ไขชื่อ';

  @override
  String memberSince(String date) {
    return 'สมาชิกตั้งแต่ $date';
  }

  @override
  String get changePasswordByEmail => 'เปลี่ยนรหัสผ่านทางอีเมล';

  @override
  String get deleteAccount => 'ลบบัญชี';

  @override
  String get providerGoogle => 'เข้าสู่ระบบด้วย Google';

  @override
  String get providerEmail => 'เข้าสู่ระบบด้วยอีเมล';

  @override
  String get providerMnote => 'บัญชี Mnote';

  @override
  String get nameSaved => 'บันทึกชื่อแล้ว';

  @override
  String resetLinkSentTo(String email) {
    return 'ส่งลิงก์รีเซ็ตรหัสผ่านไปที่ $email แล้ว';
  }

  @override
  String deleteAccountBody(String email) {
    return 'บัญชี $email และไฟล์ทั้งหมดบน cloud จะถูกลบถาวร ไฟล์ในเครื่องนี้จะถูกลบด้วย และกู้คืนไม่ได้';
  }

  @override
  String get deleteEnterPassword => 'กรอกรหัสผ่านเพื่อยืนยัน';

  @override
  String get deleteGoogleReauth => 'ระบบจะให้ยืนยันตัวตนด้วย Google อีกครั้ง';

  @override
  String get deleteForever => 'ลบบัญชีถาวร';

  @override
  String get syncTitle => 'ซิงก์กับบัญชี (Cloud sync)';

  @override
  String get syncFiles => 'ซิงก์ไฟล์ขึ้นบัญชี';

  @override
  String get syncFilesOffHint => 'ปิดแล้วเก็บในเครื่องนี้เท่านั้น';

  @override
  String get syncInk => 'ซิงก์หมึกปากกา';

  @override
  String get syncWifiOnly => 'ซิงก์เฉพาะ Wi-Fi';

  @override
  String get syncWifiOnlyHint => 'ไม่ใช้เน็ตมือถือในการซิงก์';

  @override
  String get syncFailed => 'ซิงก์ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';

  @override
  String get syncNotYet => 'ยังไม่ได้ซิงก์ในรอบนี้';

  @override
  String get syncJustNow => 'เมื่อสักครู่';

  @override
  String syncMinutesAgo(int n) {
    return '$n นาทีที่แล้ว';
  }

  @override
  String syncHoursAgo(int n) {
    return '$n ชั่วโมงที่แล้ว';
  }

  @override
  String syncDaysAgo(int n) {
    return '$n วันที่แล้ว';
  }

  @override
  String syncLast(String ago) {
    return 'ซิงก์ล่าสุด: $ago';
  }

  @override
  String get syncOff => 'ปิดการซิงก์อยู่';

  @override
  String get syncNow => 'ซิงก์ตอนนี้';

  @override
  String get editorTitle => 'ตัวแก้ไข (Editor)';

  @override
  String get editorOpenIn => 'เปิดโน้ตด้วยโหมด';

  @override
  String get tabWrite => 'เขียน';

  @override
  String get tabMarkdown => 'Markdown';

  @override
  String get editorFont => 'ฟอนต์ของข้อความ';

  @override
  String get fontApp => 'ตามแอป';

  @override
  String get editorFontSize => 'ขนาดตัวอักษร';

  @override
  String get editorLineHeight => 'ระยะบรรทัด';

  @override
  String get editorSample => 'ตัวอย่างข้อความ The quick brown fox';

  @override
  String get editorNote =>
      'มีผลกับแท็บเขียนและ Markdown โน้ตที่วาดหมึกไว้แล้วจะคงขนาดเดิม เพื่อให้หมึกตรงกับตัวอักษรเสมอ';

  @override
  String get inkTitle => 'ปากกา (Ink)';

  @override
  String get inkFinger => 'วาดด้วยนิ้วได้';

  @override
  String get inkFingerHint =>
      'ปิดไว้: วาดได้เฉพาะปากกา/Apple Pencil นิ้วใช้เลื่อนหน้า';

  @override
  String get login => 'เข้าสู่ระบบ';

  @override
  String get register => 'สมัครสมาชิก';

  @override
  String get registerNew => 'สมัครสมาชิกใหม่';

  @override
  String get email => 'อีเมล';

  @override
  String get password => 'รหัสผ่าน';

  @override
  String get confirmPassword => 'ยืนยันรหัสผ่าน';

  @override
  String get forgotPassword => 'ลืมรหัสผ่าน?';

  @override
  String get noAccountRegister => 'ยังไม่มีบัญชี? สมัครสมาชิก';

  @override
  String get haveAccountLogin => 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ';

  @override
  String get registerWithGoogle => 'สมัครด้วย Google';

  @override
  String get orDivider => 'หรือ';

  @override
  String get enterEmailFirst => 'กรอกอีเมลก่อนเพื่อรีเซ็ตรหัสผ่าน';

  @override
  String get resetLinkSent => 'ส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลแล้ว';

  @override
  String get loginSuccess => 'ล็อกอินสำเร็จ';

  @override
  String get showPassword => 'แสดงรหัสผ่าน';

  @override
  String get hidePassword => 'ซ่อนรหัสผ่าน';

  @override
  String get enterPassword => 'กรุณากรอกรหัสผ่าน';

  @override
  String get enterEmail => 'กรุณากรอกอีเมล';

  @override
  String get invalidEmail => 'รูปแบบอีเมลไม่ถูกต้อง';

  @override
  String passwordTooShort(int min) {
    return 'รหัสผ่านต้องมีอย่างน้อย $min ตัวอักษร';
  }

  @override
  String get enterName => 'กรุณากรอกชื่อ';

  @override
  String get enterConfirmPassword => 'กรุณายืนยันรหัสผ่าน';

  @override
  String get passwordMismatch => 'รหัสผ่านไม่ตรงกัน';

  @override
  String get errWrongCredentials => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';

  @override
  String get errUserDisabled => 'บัญชีนี้ถูกระงับการใช้งาน';

  @override
  String get errEmailInUse => 'อีเมลนี้ถูกใช้งานแล้ว';

  @override
  String get errWeakPassword => 'รหัสผ่านง่ายเกินไป';

  @override
  String get errTooManyRequests => 'ลองใหม่หลายครั้งเกินไป กรุณารอสักครู่';

  @override
  String get errNetwork => 'เชื่อมต่ออินเทอร์เน็ตไม่ได้';

  @override
  String get errCancelled => 'ยกเลิกการเข้าสู่ระบบ';

  @override
  String get errGoogleConfig =>
      'เข้าสู่ระบบด้วย Google ไม่ได้ในขณะนี้ กรุณาลองใหม่ภายหลัง';

  @override
  String get errUnknown => 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

  @override
  String noteImported(String name) {
    return 'ดึงไฟล์ \"$name\" เข้ามาแล้ว';
  }

  @override
  String noteImportFailed(String error) {
    return 'เกิดข้อผิดพลาดในการดึงไฟล์: $error';
  }

  @override
  String defaultDocName(int n) {
    return 'เอกสาร_$n';
  }

  @override
  String defaultTextName(int n) {
    return 'ข้อความ_$n';
  }

  @override
  String get newMarkdownTitle => 'สร้างไฟล์ Markdown ใหม่';

  @override
  String get newTextTitle => 'สร้างไฟล์ข้อความ (.txt) ใหม่';

  @override
  String get fileNameLabel => 'ชื่อไฟล์';

  @override
  String get createFile => 'สร้างไฟล์';

  @override
  String newMarkdownBody(String name) {
    return '# $name\n\nเริ่มพิมพ์ข้อความหรือจดโน้ตของคุณที่นี่...';
  }

  @override
  String newTextBody(String name) {
    return 'บันทึกข้อความ $name\n\n';
  }

  @override
  String get newFolderTitle => 'สร้างโฟลเดอร์ใหม่';

  @override
  String get folderNameLabel => 'ชื่อโฟลเดอร์';

  @override
  String get folderNameHint => 'เช่น วิชาสัมมนา, บันทึกย่อ';

  @override
  String get create => 'สร้าง';

  @override
  String folderCreated(String name) {
    return 'สร้างโฟลเดอร์ \"$name\" เรียบร้อยแล้ว';
  }

  @override
  String get trashedDocTitle => 'เอกสารอยู่ในถังขยะ';

  @override
  String trashedDocBody(String name) {
    return 'คุณต้องการกู้คืน \"$name\" เพื่อเปิดดูหรือไม่?';
  }

  @override
  String get restoreAndOpen => 'กู้คืนและเปิด';

  @override
  String get unsyncedTitle => 'มีไฟล์ที่ไม่ได้ซิงก์';

  @override
  String unsyncedBody(int count) {
    return 'ไฟล์ $count ไฟล์ไม่ได้อยู่บน cloud การออกจากระบบจะลบไฟล์เหล่านี้ออกจากเครื่องนี้ถาวร';
  }

  @override
  String get signOutAndDelete => 'ออกจากระบบและลบ';

  @override
  String get syncModeAuto => 'ซิงก์';

  @override
  String get syncModeNever => 'ไม่ซิงก์';

  @override
  String syncModeTitle(String name) {
    return 'การซิงก์ \"$name\"';
  }

  @override
  String get syncModeAutoDesc => 'อัปโหลดขึ้นบัญชีและรับการแก้ไขจากเครื่องอื่น';

  @override
  String get syncModeNeverDesc => 'ไม่อัปโหลดและไม่รับการแก้ไขจากเครื่องอื่น';

  @override
  String get undo => 'เลิกทำ';

  @override
  String folderTrashed(String name) {
    return 'ย้ายโฟลเดอร์ \"$name\" ไปยังถังขยะแล้ว';
  }

  @override
  String folderRestored(String name) {
    return 'กู้คืนโฟลเดอร์ \"$name\" เรียบร้อยแล้ว';
  }

  @override
  String get deleteFolderTitle => 'ลบโฟลเดอร์ถาวร?';

  @override
  String deleteFolderBody(String name) {
    return 'คุณต้องการลบโฟลเดอร์ \"$name\" และเอกสารภายในทั้งหมดอย่างถาวรหรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้';
  }

  @override
  String get deleteForeverBtn => 'ลบถาวร';

  @override
  String folderDeleted(String name) {
    return 'ลบโฟลเดอร์ \"$name\" ถาวรแล้ว';
  }

  @override
  String get renameDocTitle => 'เปลี่ยนชื่อเอกสาร';

  @override
  String get docNameLabel => 'ชื่อเอกสาร';

  @override
  String get docNameHint => 'กรอกชื่อเอกสารใหม่';

  @override
  String get docNameRequired => 'กรุณาระบุชื่อเอกสาร';

  @override
  String docRenamed(String name) {
    return 'เปลี่ยนชื่อเอกสารเป็น \"$name\" แล้ว';
  }

  @override
  String get noFoldersToMove =>
      'ยังไม่มีโฟลเดอร์สำหรับย้ายเอกสาร กรุณาสร้างโฟลเดอร์ก่อน';

  @override
  String get moveDocTitle => 'ย้ายเอกสารไปที่...';

  @override
  String get moveToHome => 'หน้าหลัก (นอกสุด)';

  @override
  String get homeName => 'หน้าหลัก';

  @override
  String get folderFallback => 'โฟลเดอร์';

  @override
  String docMoved(String name, String dest) {
    return 'ย้าย \"$name\" ไปที่ \"$dest\" แล้ว';
  }

  @override
  String get renameFolderTitle => 'เปลี่ยนชื่อโฟลเดอร์';

  @override
  String get folderNameNewHint => 'กรอกชื่อโฟลเดอร์ใหม่';

  @override
  String get folderNameRequired => 'กรุณาระบุชื่อโฟลเดอร์';

  @override
  String folderRenamed(String name) {
    return 'เปลี่ยนชื่อโฟลเดอร์เป็น \"$name\" แล้ว';
  }

  @override
  String docTrashed(String name) {
    return 'ย้ายไฟล์ \"$name\" ไปยังถังขยะแล้ว';
  }

  @override
  String docRestored(String name) {
    return 'กู้คืนไฟล์ \"$name\" เรียบร้อยแล้ว';
  }

  @override
  String get deleteDocTitle => 'ลบไฟล์ถาวร?';

  @override
  String deleteDocBody(String name) {
    return 'คุณต้องการลบ \"$name\" อย่างถาวรหรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้';
  }

  @override
  String docDeleted(String name) {
    return 'ลบไฟล์ \"$name\" ถาวรแล้ว';
  }

  @override
  String get emptyTrashTitle => 'ล้างถังขยะ?';

  @override
  String get emptyTrashBody =>
      'รายการทั้งหมดในถังขยะจะถูกลบอย่างถาวรและไม่สามารถกู้คืนได้';

  @override
  String get emptyTrash => 'ล้างถังขยะ';

  @override
  String get trashEmptied => 'ล้างถังขยะเรียบร้อยแล้ว';

  @override
  String get trashedFolderTitle => 'โฟลเดอร์อยู่ในถังขยะ';

  @override
  String trashedFolderBody(String name) {
    return 'คุณต้องการกู้คืนโฟลเดอร์ \"$name\" หรือไม่?';
  }

  @override
  String get restore => 'กู้คืน';

  @override
  String get searchHint => 'ค้นหาไฟล์หรือโฟลเดอร์...';

  @override
  String get trash => 'ถังขยะ';

  @override
  String get closeSearch => 'ปิดการค้นหา';

  @override
  String get search => 'ค้นหา';

  @override
  String get settingsTooltip => 'การตั้งค่า (Settings)';

  @override
  String get filterAll => 'ทั้งหมด';

  @override
  String get filterStarred => 'ติดดาว (รายการโปรด)';

  @override
  String get filterStarredShort => 'ติดดาว';

  @override
  String get filterFolders => 'โฟลเดอร์';

  @override
  String get filterAllDocs => 'เอกสารทั้งหมด';

  @override
  String get openFolder => 'เปิดโฟลเดอร์';

  @override
  String get renameFolder => 'เปลี่ยนชื่อโฟลเดอร์';

  @override
  String get folderColor => 'เปลี่ยนสีโฟลเดอร์';

  @override
  String get unfavorite => 'ยกเลิกรายการโปรด';

  @override
  String get favorite => 'เพิ่มในรายการโปรด';

  @override
  String get moveToTrash => 'ย้ายไปถังขยะ';

  @override
  String get openDoc => 'เปิดเอกสาร';

  @override
  String get renameDoc => 'เปลี่ยนชื่อไฟล์';

  @override
  String get moveToFolder => 'ย้ายไปยังโฟลเดอร์';

  @override
  String get export => 'ส่งออก';

  @override
  String get syncSettingsMenu => 'ตั้งค่าการซิงก์';

  @override
  String get listView => 'มุมมองรายการ';

  @override
  String get gridView => 'มุมมองตาราง';

  @override
  String get sortBy => 'จัดเรียงตาม';

  @override
  String get sortNewest => 'แก้ไขล่าสุด';

  @override
  String get sortOldest => 'เก่าที่สุด';

  @override
  String get sortNameAsc => 'ชื่อ (ก - ฮ)';

  @override
  String get sortNameDesc => 'ชื่อ (ฮ - ก)';

  @override
  String get createOrImport => 'สร้างใหม่หรือดึงไฟล์';

  @override
  String get newMarkdownItem => 'เอกสาร Markdown ใหม่ (.md)';

  @override
  String get newTextItem => 'ไฟล์ข้อความใหม่ (.txt)';

  @override
  String get newFolderItem => 'โฟลเดอร์ใหม่';

  @override
  String get importItem => 'ดึงไฟล์จากเครื่อง (Import)';

  @override
  String get newButton => 'ใหม่';

  @override
  String fileCount(int count) {
    return '$count ไฟล์';
  }

  @override
  String get folderOptions => 'ตัวเลือกโฟลเดอร์';

  @override
  String get docOptions => 'ตัวเลือกเอกสาร';

  @override
  String get emptyDoc => 'เอกสารว่าง';

  @override
  String get textTypeName => 'ข้อความ TXT';

  @override
  String get trashEmptyTitle => 'ถังขยะว่างเปล่า';

  @override
  String get trashEmptyBody => 'ไม่มีไฟล์หรือโฟลเดอร์ในถังขยะ';

  @override
  String get emptyLibraryTitle => 'ยังไม่มีไฟล์หรือโฟลเดอร์';

  @override
  String get emptyLibraryBody =>
      'กดปุ่ม \"+ ใหม่\" ด้านบน เพื่อสร้างไฟล์ Markdown, ไฟล์ TXT หรือโฟลเดอร์';

  @override
  String get folderColorTitle => 'เปลี่ยนสีโฟลเดอร์';

  @override
  String get defaultColor => 'สีเริ่มต้น';

  @override
  String get folderColorLabel => 'สีโฟลเดอร์';

  @override
  String get badgeSynced => 'Sync แล้ว';

  @override
  String get badgePending => 'รอ sync';

  @override
  String get badgeOffSyncOff => 'ปิดการซิงก์อยู่';

  @override
  String get badgeOffNever => 'ไฟล์นี้ตั้งเป็นไม่ซิงก์';

  @override
  String get badgeOffTooBig => 'ไฟล์ใหญ่เกิน 900 KB จึงไม่ซิงก์';

  @override
  String get aboutTitle => 'เกี่ยวกับ (About)';

  @override
  String aboutVersion(String version) {
    return 'เวอร์ชัน $version';
  }

  @override
  String get aboutLicenses => 'ใบอนุญาตโอเพนซอร์ส';

  @override
  String get aboutFeedback => 'แจ้งปัญหาหรือส่งความคิดเห็น';

  @override
  String get aboutFeedbackHint => 'เปิดหน้า GitHub Issues ในเบราว์เซอร์';

  @override
  String get aboutSource => 'ซอร์สโค้ดบน GitHub';

  @override
  String get aboutOpenFailed => 'เปิดลิงก์ไม่สำเร็จ';
}
