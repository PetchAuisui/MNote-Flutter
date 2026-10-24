import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @cancel.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิก'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In th, this message translates to:
  /// **'บันทึก'**
  String get save;

  /// No description provided for @close.
  ///
  /// In th, this message translates to:
  /// **'ปิด'**
  String get close;

  /// No description provided for @done.
  ///
  /// In th, this message translates to:
  /// **'เสร็จสิ้น'**
  String get done;

  /// No description provided for @reset.
  ///
  /// In th, this message translates to:
  /// **'คืนค่าเริ่มต้น'**
  String get reset;

  /// No description provided for @followDevice.
  ///
  /// In th, this message translates to:
  /// **'ตามเครื่อง'**
  String get followDevice;

  /// No description provided for @settingsTitle.
  ///
  /// In th, this message translates to:
  /// **'การตั้งค่า'**
  String get settingsTitle;

  /// No description provided for @accentTitle.
  ///
  /// In th, this message translates to:
  /// **'สีของแอป (Accent)'**
  String get accentTitle;

  /// No description provided for @accentName.
  ///
  /// In th, this message translates to:
  /// **'สี{color}'**
  String accentName(String color);

  /// No description provided for @accentBlue.
  ///
  /// In th, this message translates to:
  /// **'ฟ้า'**
  String get accentBlue;

  /// No description provided for @accentPurple.
  ///
  /// In th, this message translates to:
  /// **'ม่วง'**
  String get accentPurple;

  /// No description provided for @accentGreen.
  ///
  /// In th, this message translates to:
  /// **'เขียว'**
  String get accentGreen;

  /// No description provided for @accentRed.
  ///
  /// In th, this message translates to:
  /// **'แดง'**
  String get accentRed;

  /// No description provided for @accentYellow.
  ///
  /// In th, this message translates to:
  /// **'เหลือง'**
  String get accentYellow;

  /// No description provided for @accentPink.
  ///
  /// In th, this message translates to:
  /// **'ชมพู'**
  String get accentPink;

  /// No description provided for @accentOrange.
  ///
  /// In th, this message translates to:
  /// **'ส้ม'**
  String get accentOrange;

  /// No description provided for @themeTitle.
  ///
  /// In th, this message translates to:
  /// **'โหมดการแสดงผล (Theme)'**
  String get themeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In th, this message translates to:
  /// **'ตามเครื่อง'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In th, this message translates to:
  /// **'สว่าง'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In th, this message translates to:
  /// **'มืด'**
  String get themeDark;

  /// No description provided for @themeHintSystem.
  ///
  /// In th, this message translates to:
  /// **'ค่าเริ่มต้น: ปรับมืด/สว่างอัตโนมัติตามโหมดของเครื่อง'**
  String get themeHintSystem;

  /// No description provided for @themeHintDark.
  ///
  /// In th, this message translates to:
  /// **'เปิดใช้งานโหมดมืด'**
  String get themeHintDark;

  /// No description provided for @themeHintLight.
  ///
  /// In th, this message translates to:
  /// **'เปิดใช้งานโหมดสว่าง'**
  String get themeHintLight;

  /// No description provided for @languageTitle.
  ///
  /// In th, this message translates to:
  /// **'ภาษา (Language)'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In th, this message translates to:
  /// **'ตามภาษาเครื่อง'**
  String get languageSystem;

  /// No description provided for @languageThai.
  ///
  /// In th, this message translates to:
  /// **'ไทย'**
  String get languageThai;

  /// No description provided for @languageEnglish.
  ///
  /// In th, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHint.
  ///
  /// In th, this message translates to:
  /// **'ถ้าเครื่องใช้ภาษาที่แอปยังไม่รองรับ จะแสดงเป็นภาษาไทย'**
  String get languageHint;

  /// No description provided for @accountTitle.
  ///
  /// In th, this message translates to:
  /// **'บัญชี (Account)'**
  String get accountTitle;

  /// No description provided for @noName.
  ///
  /// In th, this message translates to:
  /// **'ไม่ระบุชื่อ'**
  String get noName;

  /// No description provided for @signOut.
  ///
  /// In th, this message translates to:
  /// **'ออกจากระบบ'**
  String get signOut;

  /// No description provided for @displayNameLabel.
  ///
  /// In th, this message translates to:
  /// **'ชื่อที่แสดง'**
  String get displayNameLabel;

  /// No description provided for @editName.
  ///
  /// In th, this message translates to:
  /// **'แก้ไขชื่อ'**
  String get editName;

  /// No description provided for @memberSince.
  ///
  /// In th, this message translates to:
  /// **'สมาชิกตั้งแต่ {date}'**
  String memberSince(String date);

  /// No description provided for @changePasswordByEmail.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนรหัสผ่านทางอีเมล'**
  String get changePasswordByEmail;

  /// No description provided for @deleteAccount.
  ///
  /// In th, this message translates to:
  /// **'ลบบัญชี'**
  String get deleteAccount;

  /// No description provided for @providerGoogle.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบด้วย Google'**
  String get providerGoogle;

  /// No description provided for @providerEmail.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบด้วยอีเมล'**
  String get providerEmail;

  /// No description provided for @providerMnote.
  ///
  /// In th, this message translates to:
  /// **'บัญชี Mnote'**
  String get providerMnote;

  /// No description provided for @nameSaved.
  ///
  /// In th, this message translates to:
  /// **'บันทึกชื่อแล้ว'**
  String get nameSaved;

  /// No description provided for @resetLinkSentTo.
  ///
  /// In th, this message translates to:
  /// **'ส่งลิงก์รีเซ็ตรหัสผ่านไปที่ {email} แล้ว'**
  String resetLinkSentTo(String email);

  /// No description provided for @deleteAccountBody.
  ///
  /// In th, this message translates to:
  /// **'บัญชี {email} และไฟล์ทั้งหมดบน cloud จะถูกลบถาวร ไฟล์ในเครื่องนี้จะถูกลบด้วย และกู้คืนไม่ได้'**
  String deleteAccountBody(String email);

  /// No description provided for @deleteEnterPassword.
  ///
  /// In th, this message translates to:
  /// **'กรอกรหัสผ่านเพื่อยืนยัน'**
  String get deleteEnterPassword;

  /// No description provided for @deleteGoogleReauth.
  ///
  /// In th, this message translates to:
  /// **'ระบบจะให้ยืนยันตัวตนด้วย Google อีกครั้ง'**
  String get deleteGoogleReauth;

  /// No description provided for @deleteForever.
  ///
  /// In th, this message translates to:
  /// **'ลบบัญชีถาวร'**
  String get deleteForever;

  /// No description provided for @syncTitle.
  ///
  /// In th, this message translates to:
  /// **'ซิงก์กับบัญชี (Cloud sync)'**
  String get syncTitle;

  /// No description provided for @syncFiles.
  ///
  /// In th, this message translates to:
  /// **'ซิงก์ไฟล์ขึ้นบัญชี'**
  String get syncFiles;

  /// No description provided for @syncFilesOffHint.
  ///
  /// In th, this message translates to:
  /// **'ปิดแล้วเก็บในเครื่องนี้เท่านั้น'**
  String get syncFilesOffHint;

  /// No description provided for @syncInk.
  ///
  /// In th, this message translates to:
  /// **'ซิงก์หมึกปากกา'**
  String get syncInk;

  /// No description provided for @syncWifiOnly.
  ///
  /// In th, this message translates to:
  /// **'ซิงก์เฉพาะ Wi-Fi'**
  String get syncWifiOnly;

  /// No description provided for @syncWifiOnlyHint.
  ///
  /// In th, this message translates to:
  /// **'ไม่ใช้เน็ตมือถือในการซิงก์'**
  String get syncWifiOnlyHint;

  /// No description provided for @syncFailed.
  ///
  /// In th, this message translates to:
  /// **'ซิงก์ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่'**
  String get syncFailed;

  /// No description provided for @syncNotYet.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่ได้ซิงก์ในรอบนี้'**
  String get syncNotYet;

  /// No description provided for @syncJustNow.
  ///
  /// In th, this message translates to:
  /// **'เมื่อสักครู่'**
  String get syncJustNow;

  /// No description provided for @syncMinutesAgo.
  ///
  /// In th, this message translates to:
  /// **'{n} นาทีที่แล้ว'**
  String syncMinutesAgo(int n);

  /// No description provided for @syncHoursAgo.
  ///
  /// In th, this message translates to:
  /// **'{n} ชั่วโมงที่แล้ว'**
  String syncHoursAgo(int n);

  /// No description provided for @syncDaysAgo.
  ///
  /// In th, this message translates to:
  /// **'{n} วันที่แล้ว'**
  String syncDaysAgo(int n);

  /// No description provided for @syncLast.
  ///
  /// In th, this message translates to:
  /// **'ซิงก์ล่าสุด: {ago}'**
  String syncLast(String ago);

  /// No description provided for @syncOff.
  ///
  /// In th, this message translates to:
  /// **'ปิดการซิงก์อยู่'**
  String get syncOff;

  /// No description provided for @syncNow.
  ///
  /// In th, this message translates to:
  /// **'ซิงก์ตอนนี้'**
  String get syncNow;

  /// No description provided for @editorTitle.
  ///
  /// In th, this message translates to:
  /// **'ตัวแก้ไข (Editor)'**
  String get editorTitle;

  /// No description provided for @editorOpenIn.
  ///
  /// In th, this message translates to:
  /// **'เปิดโน้ตด้วยโหมด'**
  String get editorOpenIn;

  /// No description provided for @tabWrite.
  ///
  /// In th, this message translates to:
  /// **'เขียน'**
  String get tabWrite;

  /// No description provided for @tabMarkdown.
  ///
  /// In th, this message translates to:
  /// **'Markdown'**
  String get tabMarkdown;

  /// No description provided for @editorFont.
  ///
  /// In th, this message translates to:
  /// **'ฟอนต์ของข้อความ'**
  String get editorFont;

  /// No description provided for @fontApp.
  ///
  /// In th, this message translates to:
  /// **'ตามแอป'**
  String get fontApp;

  /// No description provided for @editorFontSize.
  ///
  /// In th, this message translates to:
  /// **'ขนาดตัวอักษร'**
  String get editorFontSize;

  /// No description provided for @editorLineHeight.
  ///
  /// In th, this message translates to:
  /// **'ระยะบรรทัด'**
  String get editorLineHeight;

  /// No description provided for @editorSample.
  ///
  /// In th, this message translates to:
  /// **'ตัวอย่างข้อความ The quick brown fox'**
  String get editorSample;

  /// No description provided for @editorNote.
  ///
  /// In th, this message translates to:
  /// **'มีผลกับแท็บเขียนและ Markdown โน้ตที่วาดหมึกไว้แล้วจะคงขนาดเดิม เพื่อให้หมึกตรงกับตัวอักษรเสมอ'**
  String get editorNote;

  /// No description provided for @inkTitle.
  ///
  /// In th, this message translates to:
  /// **'ปากกา (Ink)'**
  String get inkTitle;

  /// No description provided for @inkFinger.
  ///
  /// In th, this message translates to:
  /// **'วาดด้วยนิ้วได้'**
  String get inkFinger;

  /// No description provided for @inkFingerHint.
  ///
  /// In th, this message translates to:
  /// **'ปิดไว้: วาดได้เฉพาะปากกา/Apple Pencil นิ้วใช้เลื่อนหน้า'**
  String get inkFingerHint;

  /// No description provided for @login.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบ'**
  String get login;

  /// No description provided for @register.
  ///
  /// In th, this message translates to:
  /// **'สมัครสมาชิก'**
  String get register;

  /// No description provided for @registerNew.
  ///
  /// In th, this message translates to:
  /// **'สมัครสมาชิกใหม่'**
  String get registerNew;

  /// No description provided for @email.
  ///
  /// In th, this message translates to:
  /// **'อีเมล'**
  String get email;

  /// No description provided for @password.
  ///
  /// In th, this message translates to:
  /// **'รหัสผ่าน'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In th, this message translates to:
  /// **'ยืนยันรหัสผ่าน'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In th, this message translates to:
  /// **'ลืมรหัสผ่าน?'**
  String get forgotPassword;

  /// No description provided for @noAccountRegister.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีบัญชี? สมัครสมาชิก'**
  String get noAccountRegister;

  /// No description provided for @haveAccountLogin.
  ///
  /// In th, this message translates to:
  /// **'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'**
  String get haveAccountLogin;

  /// No description provided for @registerWithGoogle.
  ///
  /// In th, this message translates to:
  /// **'สมัครด้วย Google'**
  String get registerWithGoogle;

  /// No description provided for @orDivider.
  ///
  /// In th, this message translates to:
  /// **'หรือ'**
  String get orDivider;

  /// No description provided for @enterEmailFirst.
  ///
  /// In th, this message translates to:
  /// **'กรอกอีเมลก่อนเพื่อรีเซ็ตรหัสผ่าน'**
  String get enterEmailFirst;

  /// No description provided for @resetLinkSent.
  ///
  /// In th, this message translates to:
  /// **'ส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลแล้ว'**
  String get resetLinkSent;

  /// No description provided for @loginSuccess.
  ///
  /// In th, this message translates to:
  /// **'ล็อกอินสำเร็จ'**
  String get loginSuccess;

  /// No description provided for @showPassword.
  ///
  /// In th, this message translates to:
  /// **'แสดงรหัสผ่าน'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In th, this message translates to:
  /// **'ซ่อนรหัสผ่าน'**
  String get hidePassword;

  /// No description provided for @enterPassword.
  ///
  /// In th, this message translates to:
  /// **'กรุณากรอกรหัสผ่าน'**
  String get enterPassword;

  /// No description provided for @enterEmail.
  ///
  /// In th, this message translates to:
  /// **'กรุณากรอกอีเมล'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In th, this message translates to:
  /// **'รูปแบบอีเมลไม่ถูกต้อง'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In th, this message translates to:
  /// **'รหัสผ่านต้องมีอย่างน้อย {min} ตัวอักษร'**
  String passwordTooShort(int min);

  /// No description provided for @enterName.
  ///
  /// In th, this message translates to:
  /// **'กรุณากรอกชื่อ'**
  String get enterName;

  /// No description provided for @enterConfirmPassword.
  ///
  /// In th, this message translates to:
  /// **'กรุณายืนยันรหัสผ่าน'**
  String get enterConfirmPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In th, this message translates to:
  /// **'รหัสผ่านไม่ตรงกัน'**
  String get passwordMismatch;

  /// No description provided for @errWrongCredentials.
  ///
  /// In th, this message translates to:
  /// **'อีเมลหรือรหัสผ่านไม่ถูกต้อง'**
  String get errWrongCredentials;

  /// No description provided for @errUserDisabled.
  ///
  /// In th, this message translates to:
  /// **'บัญชีนี้ถูกระงับการใช้งาน'**
  String get errUserDisabled;

  /// No description provided for @errEmailInUse.
  ///
  /// In th, this message translates to:
  /// **'อีเมลนี้ถูกใช้งานแล้ว'**
  String get errEmailInUse;

  /// No description provided for @errWeakPassword.
  ///
  /// In th, this message translates to:
  /// **'รหัสผ่านง่ายเกินไป'**
  String get errWeakPassword;

  /// No description provided for @errTooManyRequests.
  ///
  /// In th, this message translates to:
  /// **'ลองใหม่หลายครั้งเกินไป กรุณารอสักครู่'**
  String get errTooManyRequests;

  /// No description provided for @errNetwork.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่ออินเทอร์เน็ตไม่ได้'**
  String get errNetwork;

  /// No description provided for @errCancelled.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิกการเข้าสู่ระบบ'**
  String get errCancelled;

  /// No description provided for @errGoogleConfig.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบด้วย Google ไม่ได้ในขณะนี้ กรุณาลองใหม่ภายหลัง'**
  String get errGoogleConfig;

  /// No description provided for @errUnknown.
  ///
  /// In th, this message translates to:
  /// **'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'**
  String get errUnknown;

  /// No description provided for @noteImported.
  ///
  /// In th, this message translates to:
  /// **'ดึงไฟล์ \"{name}\" เข้ามาแล้ว'**
  String noteImported(String name);

  /// No description provided for @noteImportFailed.
  ///
  /// In th, this message translates to:
  /// **'เกิดข้อผิดพลาดในการดึงไฟล์: {error}'**
  String noteImportFailed(String error);

  /// No description provided for @defaultDocName.
  ///
  /// In th, this message translates to:
  /// **'เอกสาร_{n}'**
  String defaultDocName(int n);

  /// No description provided for @defaultTextName.
  ///
  /// In th, this message translates to:
  /// **'ข้อความ_{n}'**
  String defaultTextName(int n);

  /// No description provided for @newMarkdownTitle.
  ///
  /// In th, this message translates to:
  /// **'สร้างไฟล์ Markdown ใหม่'**
  String get newMarkdownTitle;

  /// No description provided for @newTextTitle.
  ///
  /// In th, this message translates to:
  /// **'สร้างไฟล์ข้อความ (.txt) ใหม่'**
  String get newTextTitle;

  /// No description provided for @fileNameLabel.
  ///
  /// In th, this message translates to:
  /// **'ชื่อไฟล์'**
  String get fileNameLabel;

  /// No description provided for @createFile.
  ///
  /// In th, this message translates to:
  /// **'สร้างไฟล์'**
  String get createFile;

  /// No description provided for @newMarkdownBody.
  ///
  /// In th, this message translates to:
  /// **'# {name}\n\nเริ่มพิมพ์ข้อความหรือจดโน้ตของคุณที่นี่...'**
  String newMarkdownBody(String name);

  /// No description provided for @newTextBody.
  ///
  /// In th, this message translates to:
  /// **'บันทึกข้อความ {name}\n\n'**
  String newTextBody(String name);

  /// No description provided for @newFolderTitle.
  ///
  /// In th, this message translates to:
  /// **'สร้างโฟลเดอร์ใหม่'**
  String get newFolderTitle;

  /// No description provided for @folderNameLabel.
  ///
  /// In th, this message translates to:
  /// **'ชื่อโฟลเดอร์'**
  String get folderNameLabel;

  /// No description provided for @folderNameHint.
  ///
  /// In th, this message translates to:
  /// **'เช่น วิชาสัมมนา, บันทึกย่อ'**
  String get folderNameHint;

  /// No description provided for @create.
  ///
  /// In th, this message translates to:
  /// **'สร้าง'**
  String get create;

  /// No description provided for @folderCreated.
  ///
  /// In th, this message translates to:
  /// **'สร้างโฟลเดอร์ \"{name}\" เรียบร้อยแล้ว'**
  String folderCreated(String name);

  /// No description provided for @trashedDocTitle.
  ///
  /// In th, this message translates to:
  /// **'เอกสารอยู่ในถังขยะ'**
  String get trashedDocTitle;

  /// No description provided for @trashedDocBody.
  ///
  /// In th, this message translates to:
  /// **'คุณต้องการกู้คืน \"{name}\" เพื่อเปิดดูหรือไม่?'**
  String trashedDocBody(String name);

  /// No description provided for @restoreAndOpen.
  ///
  /// In th, this message translates to:
  /// **'กู้คืนและเปิด'**
  String get restoreAndOpen;

  /// No description provided for @unsyncedTitle.
  ///
  /// In th, this message translates to:
  /// **'มีไฟล์ที่ไม่ได้ซิงก์'**
  String get unsyncedTitle;

  /// No description provided for @unsyncedBody.
  ///
  /// In th, this message translates to:
  /// **'ไฟล์ {count} ไฟล์ไม่ได้อยู่บน cloud การออกจากระบบจะลบไฟล์เหล่านี้ออกจากเครื่องนี้ถาวร'**
  String unsyncedBody(int count);

  /// No description provided for @signOutAndDelete.
  ///
  /// In th, this message translates to:
  /// **'ออกจากระบบและลบ'**
  String get signOutAndDelete;

  /// No description provided for @syncModeAuto.
  ///
  /// In th, this message translates to:
  /// **'ซิงก์'**
  String get syncModeAuto;

  /// No description provided for @syncModeNever.
  ///
  /// In th, this message translates to:
  /// **'ไม่ซิงก์'**
  String get syncModeNever;

  /// No description provided for @syncModeTitle.
  ///
  /// In th, this message translates to:
  /// **'การซิงก์ \"{name}\"'**
  String syncModeTitle(String name);

  /// No description provided for @syncModeAutoDesc.
  ///
  /// In th, this message translates to:
  /// **'อัปโหลดขึ้นบัญชีและรับการแก้ไขจากเครื่องอื่น'**
  String get syncModeAutoDesc;

  /// No description provided for @syncModeNeverDesc.
  ///
  /// In th, this message translates to:
  /// **'ไม่อัปโหลดและไม่รับการแก้ไขจากเครื่องอื่น'**
  String get syncModeNeverDesc;

  /// No description provided for @undo.
  ///
  /// In th, this message translates to:
  /// **'เลิกทำ'**
  String get undo;

  /// No description provided for @folderTrashed.
  ///
  /// In th, this message translates to:
  /// **'ย้ายโฟลเดอร์ \"{name}\" ไปยังถังขยะแล้ว'**
  String folderTrashed(String name);

  /// No description provided for @folderRestored.
  ///
  /// In th, this message translates to:
  /// **'กู้คืนโฟลเดอร์ \"{name}\" เรียบร้อยแล้ว'**
  String folderRestored(String name);

  /// No description provided for @deleteFolderTitle.
  ///
  /// In th, this message translates to:
  /// **'ลบโฟลเดอร์ถาวร?'**
  String get deleteFolderTitle;

  /// No description provided for @deleteFolderBody.
  ///
  /// In th, this message translates to:
  /// **'คุณต้องการลบโฟลเดอร์ \"{name}\" และเอกสารภายในทั้งหมดอย่างถาวรหรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้'**
  String deleteFolderBody(String name);

  /// No description provided for @deleteForeverBtn.
  ///
  /// In th, this message translates to:
  /// **'ลบถาวร'**
  String get deleteForeverBtn;

  /// No description provided for @folderDeleted.
  ///
  /// In th, this message translates to:
  /// **'ลบโฟลเดอร์ \"{name}\" ถาวรแล้ว'**
  String folderDeleted(String name);

  /// No description provided for @renameDocTitle.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนชื่อเอกสาร'**
  String get renameDocTitle;

  /// No description provided for @docNameLabel.
  ///
  /// In th, this message translates to:
  /// **'ชื่อเอกสาร'**
  String get docNameLabel;

  /// No description provided for @docNameHint.
  ///
  /// In th, this message translates to:
  /// **'กรอกชื่อเอกสารใหม่'**
  String get docNameHint;

  /// No description provided for @docNameRequired.
  ///
  /// In th, this message translates to:
  /// **'กรุณาระบุชื่อเอกสาร'**
  String get docNameRequired;

  /// No description provided for @docRenamed.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนชื่อเอกสารเป็น \"{name}\" แล้ว'**
  String docRenamed(String name);

  /// No description provided for @noFoldersToMove.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีโฟลเดอร์สำหรับย้ายเอกสาร กรุณาสร้างโฟลเดอร์ก่อน'**
  String get noFoldersToMove;

  /// No description provided for @moveDocTitle.
  ///
  /// In th, this message translates to:
  /// **'ย้ายเอกสารไปที่...'**
  String get moveDocTitle;

  /// No description provided for @moveToHome.
  ///
  /// In th, this message translates to:
  /// **'หน้าหลัก (นอกสุด)'**
  String get moveToHome;

  /// No description provided for @homeName.
  ///
  /// In th, this message translates to:
  /// **'หน้าหลัก'**
  String get homeName;

  /// No description provided for @folderFallback.
  ///
  /// In th, this message translates to:
  /// **'โฟลเดอร์'**
  String get folderFallback;

  /// No description provided for @docMoved.
  ///
  /// In th, this message translates to:
  /// **'ย้าย \"{name}\" ไปที่ \"{dest}\" แล้ว'**
  String docMoved(String name, String dest);

  /// No description provided for @renameFolderTitle.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนชื่อโฟลเดอร์'**
  String get renameFolderTitle;

  /// No description provided for @folderNameNewHint.
  ///
  /// In th, this message translates to:
  /// **'กรอกชื่อโฟลเดอร์ใหม่'**
  String get folderNameNewHint;

  /// No description provided for @folderNameRequired.
  ///
  /// In th, this message translates to:
  /// **'กรุณาระบุชื่อโฟลเดอร์'**
  String get folderNameRequired;

  /// No description provided for @folderRenamed.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนชื่อโฟลเดอร์เป็น \"{name}\" แล้ว'**
  String folderRenamed(String name);

  /// No description provided for @docTrashed.
  ///
  /// In th, this message translates to:
  /// **'ย้ายไฟล์ \"{name}\" ไปยังถังขยะแล้ว'**
  String docTrashed(String name);

  /// No description provided for @docRestored.
  ///
  /// In th, this message translates to:
  /// **'กู้คืนไฟล์ \"{name}\" เรียบร้อยแล้ว'**
  String docRestored(String name);

  /// No description provided for @deleteDocTitle.
  ///
  /// In th, this message translates to:
  /// **'ลบไฟล์ถาวร?'**
  String get deleteDocTitle;

  /// No description provided for @deleteDocBody.
  ///
  /// In th, this message translates to:
  /// **'คุณต้องการลบ \"{name}\" อย่างถาวรหรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้'**
  String deleteDocBody(String name);

  /// No description provided for @docDeleted.
  ///
  /// In th, this message translates to:
  /// **'ลบไฟล์ \"{name}\" ถาวรแล้ว'**
  String docDeleted(String name);

  /// No description provided for @emptyTrashTitle.
  ///
  /// In th, this message translates to:
  /// **'ล้างถังขยะ?'**
  String get emptyTrashTitle;

  /// No description provided for @emptyTrashBody.
  ///
  /// In th, this message translates to:
  /// **'รายการทั้งหมดในถังขยะจะถูกลบอย่างถาวรและไม่สามารถกู้คืนได้'**
  String get emptyTrashBody;

  /// No description provided for @emptyTrash.
  ///
  /// In th, this message translates to:
  /// **'ล้างถังขยะ'**
  String get emptyTrash;

  /// No description provided for @trashEmptied.
  ///
  /// In th, this message translates to:
  /// **'ล้างถังขยะเรียบร้อยแล้ว'**
  String get trashEmptied;

  /// No description provided for @trashedFolderTitle.
  ///
  /// In th, this message translates to:
  /// **'โฟลเดอร์อยู่ในถังขยะ'**
  String get trashedFolderTitle;

  /// No description provided for @trashedFolderBody.
  ///
  /// In th, this message translates to:
  /// **'คุณต้องการกู้คืนโฟลเดอร์ \"{name}\" หรือไม่?'**
  String trashedFolderBody(String name);

  /// No description provided for @restore.
  ///
  /// In th, this message translates to:
  /// **'กู้คืน'**
  String get restore;

  /// No description provided for @searchHint.
  ///
  /// In th, this message translates to:
  /// **'ค้นหาไฟล์หรือโฟลเดอร์...'**
  String get searchHint;

  /// No description provided for @trash.
  ///
  /// In th, this message translates to:
  /// **'ถังขยะ'**
  String get trash;

  /// No description provided for @closeSearch.
  ///
  /// In th, this message translates to:
  /// **'ปิดการค้นหา'**
  String get closeSearch;

  /// No description provided for @search.
  ///
  /// In th, this message translates to:
  /// **'ค้นหา'**
  String get search;

  /// No description provided for @settingsTooltip.
  ///
  /// In th, this message translates to:
  /// **'การตั้งค่า (Settings)'**
  String get settingsTooltip;

  /// No description provided for @filterAll.
  ///
  /// In th, this message translates to:
  /// **'ทั้งหมด'**
  String get filterAll;

  /// No description provided for @filterStarred.
  ///
  /// In th, this message translates to:
  /// **'ติดดาว (รายการโปรด)'**
  String get filterStarred;

  /// No description provided for @filterStarredShort.
  ///
  /// In th, this message translates to:
  /// **'ติดดาว'**
  String get filterStarredShort;

  /// No description provided for @filterFolders.
  ///
  /// In th, this message translates to:
  /// **'โฟลเดอร์'**
  String get filterFolders;

  /// No description provided for @filterAllDocs.
  ///
  /// In th, this message translates to:
  /// **'เอกสารทั้งหมด'**
  String get filterAllDocs;

  /// No description provided for @openFolder.
  ///
  /// In th, this message translates to:
  /// **'เปิดโฟลเดอร์'**
  String get openFolder;

  /// No description provided for @renameFolder.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนชื่อโฟลเดอร์'**
  String get renameFolder;

  /// No description provided for @folderColor.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนสีโฟลเดอร์'**
  String get folderColor;

  /// No description provided for @unfavorite.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิกรายการโปรด'**
  String get unfavorite;

  /// No description provided for @favorite.
  ///
  /// In th, this message translates to:
  /// **'เพิ่มในรายการโปรด'**
  String get favorite;

  /// No description provided for @moveToTrash.
  ///
  /// In th, this message translates to:
  /// **'ย้ายไปถังขยะ'**
  String get moveToTrash;

  /// No description provided for @openDoc.
  ///
  /// In th, this message translates to:
  /// **'เปิดเอกสาร'**
  String get openDoc;

  /// No description provided for @renameDoc.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนชื่อไฟล์'**
  String get renameDoc;

  /// No description provided for @moveToFolder.
  ///
  /// In th, this message translates to:
  /// **'ย้ายไปยังโฟลเดอร์'**
  String get moveToFolder;

  /// No description provided for @export.
  ///
  /// In th, this message translates to:
  /// **'ส่งออก'**
  String get export;

  /// No description provided for @syncSettingsMenu.
  ///
  /// In th, this message translates to:
  /// **'ตั้งค่าการซิงก์'**
  String get syncSettingsMenu;

  /// No description provided for @listView.
  ///
  /// In th, this message translates to:
  /// **'มุมมองรายการ'**
  String get listView;

  /// No description provided for @gridView.
  ///
  /// In th, this message translates to:
  /// **'มุมมองตาราง'**
  String get gridView;

  /// No description provided for @sortBy.
  ///
  /// In th, this message translates to:
  /// **'จัดเรียงตาม'**
  String get sortBy;

  /// No description provided for @sortNewest.
  ///
  /// In th, this message translates to:
  /// **'แก้ไขล่าสุด'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In th, this message translates to:
  /// **'เก่าที่สุด'**
  String get sortOldest;

  /// No description provided for @sortNameAsc.
  ///
  /// In th, this message translates to:
  /// **'ชื่อ (ก - ฮ)'**
  String get sortNameAsc;

  /// No description provided for @sortNameDesc.
  ///
  /// In th, this message translates to:
  /// **'ชื่อ (ฮ - ก)'**
  String get sortNameDesc;

  /// No description provided for @createOrImport.
  ///
  /// In th, this message translates to:
  /// **'สร้างใหม่หรือดึงไฟล์'**
  String get createOrImport;

  /// No description provided for @newMarkdownItem.
  ///
  /// In th, this message translates to:
  /// **'เอกสาร Markdown ใหม่ (.md)'**
  String get newMarkdownItem;

  /// No description provided for @newTextItem.
  ///
  /// In th, this message translates to:
  /// **'ไฟล์ข้อความใหม่ (.txt)'**
  String get newTextItem;

  /// No description provided for @newFolderItem.
  ///
  /// In th, this message translates to:
  /// **'โฟลเดอร์ใหม่'**
  String get newFolderItem;

  /// No description provided for @importItem.
  ///
  /// In th, this message translates to:
  /// **'ดึงไฟล์จากเครื่อง (Import)'**
  String get importItem;

  /// No description provided for @newButton.
  ///
  /// In th, this message translates to:
  /// **'ใหม่'**
  String get newButton;

  /// No description provided for @fileCount.
  ///
  /// In th, this message translates to:
  /// **'{count} ไฟล์'**
  String fileCount(int count);

  /// No description provided for @folderOptions.
  ///
  /// In th, this message translates to:
  /// **'ตัวเลือกโฟลเดอร์'**
  String get folderOptions;

  /// No description provided for @docOptions.
  ///
  /// In th, this message translates to:
  /// **'ตัวเลือกเอกสาร'**
  String get docOptions;

  /// No description provided for @emptyDoc.
  ///
  /// In th, this message translates to:
  /// **'เอกสารว่าง'**
  String get emptyDoc;

  /// No description provided for @textTypeName.
  ///
  /// In th, this message translates to:
  /// **'ข้อความ TXT'**
  String get textTypeName;

  /// No description provided for @trashEmptyTitle.
  ///
  /// In th, this message translates to:
  /// **'ถังขยะว่างเปล่า'**
  String get trashEmptyTitle;

  /// No description provided for @trashEmptyBody.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีไฟล์หรือโฟลเดอร์ในถังขยะ'**
  String get trashEmptyBody;

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีไฟล์หรือโฟลเดอร์'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryBody.
  ///
  /// In th, this message translates to:
  /// **'กดปุ่ม \"+ ใหม่\" ด้านบน เพื่อสร้างไฟล์ Markdown, ไฟล์ TXT หรือโฟลเดอร์'**
  String get emptyLibraryBody;

  /// No description provided for @folderColorTitle.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนสีโฟลเดอร์'**
  String get folderColorTitle;

  /// No description provided for @defaultColor.
  ///
  /// In th, this message translates to:
  /// **'สีเริ่มต้น'**
  String get defaultColor;

  /// No description provided for @folderColorLabel.
  ///
  /// In th, this message translates to:
  /// **'สีโฟลเดอร์'**
  String get folderColorLabel;

  /// No description provided for @badgeSynced.
  ///
  /// In th, this message translates to:
  /// **'Sync แล้ว'**
  String get badgeSynced;

  /// No description provided for @badgePending.
  ///
  /// In th, this message translates to:
  /// **'รอ sync'**
  String get badgePending;

  /// No description provided for @badgeOffSyncOff.
  ///
  /// In th, this message translates to:
  /// **'ปิดการซิงก์อยู่'**
  String get badgeOffSyncOff;

  /// No description provided for @badgeOffNever.
  ///
  /// In th, this message translates to:
  /// **'ไฟล์นี้ตั้งเป็นไม่ซิงก์'**
  String get badgeOffNever;

  /// No description provided for @badgeOffTooBig.
  ///
  /// In th, this message translates to:
  /// **'ไฟล์ใหญ่เกิน 900 KB จึงไม่ซิงก์'**
  String get badgeOffTooBig;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
