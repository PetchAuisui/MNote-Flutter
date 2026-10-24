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
}
