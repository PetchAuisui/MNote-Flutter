#!/usr/bin/env python3
"""Writes lib/l10n/app_th.arb and app_en.arb from the table below.

Edit the table, then run `python3 tool/gen_arb.py && flutter gen-l10n`.
A value is (thai, english) or (thai, english, [placeholder names]).
"""
import json, pathlib

S = {
 # general
 'cancel': ('ยกเลิก', 'Cancel'),
 'save': ('บันทึก', 'Save'),
 'close': ('ปิด', 'Close'),
 'done': ('เสร็จสิ้น', 'Done'),
 'reset': ('คืนค่าเริ่มต้น', 'Reset to default'),
 'followDevice': ('ตามเครื่อง', 'Device'),
 # settings
 'settingsTitle': ('การตั้งค่า', 'Settings'),
 'accentTitle': ('สีของแอป (Accent)', 'App color (Accent)'),
 'accentName': ('สี{color}', '{color}', ['color']),
 'accentBlue': ('ฟ้า', 'Blue'), 'accentPurple': ('ม่วง', 'Purple'),
 'accentGreen': ('เขียว', 'Green'), 'accentRed': ('แดง', 'Red'),
 'accentYellow': ('เหลือง', 'Yellow'), 'accentPink': ('ชมพู', 'Pink'),
 'accentOrange': ('ส้ม', 'Orange'),
 'themeTitle': ('โหมดการแสดงผล (Theme)', 'Appearance (Theme)'),
 'themeSystem': ('ตามเครื่อง', 'System'),
 'themeLight': ('สว่าง', 'Light'),
 'themeDark': ('มืด', 'Dark'),
 'themeHintSystem': ('ค่าเริ่มต้น: ปรับมืด/สว่างอัตโนมัติตามโหมดของเครื่อง', 'Default: follows your device\'s light or dark mode'),
 'themeHintDark': ('เปิดใช้งานโหมดมืด', 'Dark mode is on'),
 'themeHintLight': ('เปิดใช้งานโหมดสว่าง', 'Light mode is on'),
 'languageTitle': ('ภาษา (Language)', 'Language'),
 'languageSystem': ('ตามภาษาเครื่อง', 'Device'),
 'languageThai': ('ไทย', 'ไทย'),
 'languageEnglish': ('English', 'English'),
 'languageHint': ('ถ้าเครื่องใช้ภาษาที่แอปยังไม่รองรับ จะแสดงเป็นภาษาไทย', 'If your device uses a language the app does not support, it is shown in Thai'),
 # account
 'accountTitle': ('บัญชี (Account)', 'Account'),
 'noName': ('ไม่ระบุชื่อ', 'No name'),
 'signOut': ('ออกจากระบบ', 'Sign out'),
 'displayNameLabel': ('ชื่อที่แสดง', 'Display name'),
 'editName': ('แก้ไขชื่อ', 'Edit name'),
 'memberSince': ('สมาชิกตั้งแต่ {date}', 'Member since {date}', ['date']),
 'changePasswordByEmail': ('เปลี่ยนรหัสผ่านทางอีเมล', 'Change password by email'),
 'deleteAccount': ('ลบบัญชี', 'Delete account'),
 'providerGoogle': ('เข้าสู่ระบบด้วย Google', 'Signed in with Google'),
 'providerEmail': ('เข้าสู่ระบบด้วยอีเมล', 'Signed in with email'),
 'providerMnote': ('บัญชี Mnote', 'Mnote account'),
 'nameSaved': ('บันทึกชื่อแล้ว', 'Name saved'),
 'resetLinkSentTo': ('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่ {email} แล้ว', 'Password reset link sent to {email}', ['email']),
 'deleteAccountBody': ('บัญชี {email} และไฟล์ทั้งหมดบน cloud จะถูกลบถาวร ไฟล์ในเครื่องนี้จะถูกลบด้วย และกู้คืนไม่ได้', 'The account {email} and all your files in the cloud will be permanently deleted. Files on this device are deleted too, and this cannot be undone.', ['email']),
 'deleteEnterPassword': ('กรอกรหัสผ่านเพื่อยืนยัน', 'Enter your password to confirm'),
 'deleteGoogleReauth': ('ระบบจะให้ยืนยันตัวตนด้วย Google อีกครั้ง', 'You will be asked to confirm with Google again'),
 'deleteForever': ('ลบบัญชีถาวร', 'Delete permanently'),
 # sync
 'syncTitle': ('ซิงก์กับบัญชี (Cloud sync)', 'Cloud sync'),
 'syncFiles': ('ซิงก์ไฟล์ขึ้นบัญชี', 'Sync notes to your account'),
 'syncFilesOffHint': ('ปิดแล้วเก็บในเครื่องนี้เท่านั้น', 'When off, notes stay on this device only'),
 'syncInk': ('ซิงก์หมึกปากกา', 'Sync pen ink'),
 'syncWifiOnly': ('ซิงก์เฉพาะ Wi-Fi', 'Sync on Wi-Fi only'),
 'syncWifiOnlyHint': ('ไม่ใช้เน็ตมือถือในการซิงก์', 'Do not use mobile data to sync'),
 'syncFailed': ('ซิงก์ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่', 'Sync failed. Check your connection and try again.'),
 'syncNotYet': ('ยังไม่ได้ซิงก์ในรอบนี้', 'Not synced yet this session'),
 'syncJustNow': ('เมื่อสักครู่', 'just now'),
 'syncMinutesAgo': ('{n} นาทีที่แล้ว', '{n} min ago', ['n']),
 'syncHoursAgo': ('{n} ชั่วโมงที่แล้ว', '{n} h ago', ['n']),
 'syncDaysAgo': ('{n} วันที่แล้ว', '{n} d ago', ['n']),
 'syncLast': ('ซิงก์ล่าสุด: {ago}', 'Last synced: {ago}', ['ago']),
 'syncOff': ('ปิดการซิงก์อยู่', 'Sync is off'),
 'syncNow': ('ซิงก์ตอนนี้', 'Sync now'),
 # editor
 'editorTitle': ('ตัวแก้ไข (Editor)', 'Editor'),
 'editorOpenIn': ('เปิดโน้ตด้วยโหมด', 'Open notes in'),
 'tabWrite': ('เขียน', 'Write'),
 'tabMarkdown': ('Markdown', 'Markdown'),
 'editorFont': ('ฟอนต์ของข้อความ', 'Text font'),
 'fontApp': ('ตามแอป', 'App font'),
 'editorFontSize': ('ขนาดตัวอักษร', 'Font size'),
 'editorLineHeight': ('ระยะบรรทัด', 'Line spacing'),
 'editorSample': ('ตัวอย่างข้อความ The quick brown fox', 'Sample text The quick brown fox'),
 'editorNote': ('มีผลกับแท็บเขียนและ Markdown โน้ตที่วาดหมึกไว้แล้วจะคงขนาดเดิม เพื่อให้หมึกตรงกับตัวอักษรเสมอ', 'Applies to the Write and Markdown tabs. Notes that already have ink keep their size so the ink always lines up with the text.'),
 # ink
 'inkTitle': ('ปากกา (Ink)', 'Pen (Ink)'),
 'inkFinger': ('วาดด้วยนิ้วได้', 'Draw with a finger'),
 'inkFingerHint': ('ปิดไว้: วาดได้เฉพาะปากกา/Apple Pencil นิ้วใช้เลื่อนหน้า', 'Off: only a pen or Apple Pencil draws, and a finger scrolls the page'),
 # auth
 'login': ('เข้าสู่ระบบ', 'Sign in'),
 'register': ('สมัครสมาชิก', 'Sign up'),
 'registerNew': ('สมัครสมาชิกใหม่', 'Create an account'),
 'email': ('อีเมล', 'Email'),
 'password': ('รหัสผ่าน', 'Password'),
 'confirmPassword': ('ยืนยันรหัสผ่าน', 'Confirm password'),
 'forgotPassword': ('ลืมรหัสผ่าน?', 'Forgot password?'),
 'noAccountRegister': ('ยังไม่มีบัญชี? สมัครสมาชิก', 'No account yet? Sign up'),
 'haveAccountLogin': ('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ', 'Already have an account? Sign in'),
 'registerWithGoogle': ('สมัครด้วย Google', 'Sign up with Google'),
 'orDivider': ('หรือ', 'or'),
 'enterEmailFirst': ('กรอกอีเมลก่อนเพื่อรีเซ็ตรหัสผ่าน', 'Enter your email first to reset your password'),
 'resetLinkSent': ('ส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลแล้ว', 'Password reset link sent to your email'),
 'loginSuccess': ('ล็อกอินสำเร็จ', 'Signed in'),
 'showPassword': ('แสดงรหัสผ่าน', 'Show password'),
 'hidePassword': ('ซ่อนรหัสผ่าน', 'Hide password'),
 'enterPassword': ('กรุณากรอกรหัสผ่าน', 'Please enter your password'),
 'enterEmail': ('กรุณากรอกอีเมล', 'Please enter your email'),
 'invalidEmail': ('รูปแบบอีเมลไม่ถูกต้อง', 'The email format is not valid'),
 'passwordTooShort': ('รหัสผ่านต้องมีอย่างน้อย {min} ตัวอักษร', 'The password must be at least {min} characters', ['min']),
 'enterName': ('กรุณากรอกชื่อ', 'Please enter your name'),
 'enterConfirmPassword': ('กรุณายืนยันรหัสผ่าน', 'Please confirm your password'),
 'passwordMismatch': ('รหัสผ่านไม่ตรงกัน', 'The passwords do not match'),
 'errWrongCredentials': ('อีเมลหรือรหัสผ่านไม่ถูกต้อง', 'The email or password is incorrect'),
 'errUserDisabled': ('บัญชีนี้ถูกระงับการใช้งาน', 'This account has been disabled'),
 'errEmailInUse': ('อีเมลนี้ถูกใช้งานแล้ว', 'This email is already in use'),
 'errWeakPassword': ('รหัสผ่านง่ายเกินไป', 'The password is too weak'),
 'errTooManyRequests': ('ลองใหม่หลายครั้งเกินไป กรุณารอสักครู่', 'Too many attempts. Please wait a moment.'),
 'errNetwork': ('เชื่อมต่ออินเทอร์เน็ตไม่ได้', 'Cannot connect to the internet'),
 'errCancelled': ('ยกเลิกการเข้าสู่ระบบ', 'Sign-in cancelled'),
 'errGoogleConfig': ('เข้าสู่ระบบด้วย Google ไม่ได้ในขณะนี้ กรุณาลองใหม่ภายหลัง', 'Google sign-in is unavailable right now. Please try again later.'),
 'errUnknown': ('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง', 'Something went wrong. Please try again.'),
}

out = pathlib.Path(__file__).resolve().parent.parent / 'lib' / 'l10n'
for idx, (lang, name) in enumerate([('th', 'app_th.arb'), ('en', 'app_en.arb')]):
    data = {'@@locale': lang}
    for key, val in S.items():
        data[key] = val[idx]
        if idx == 0 and len(val) > 2:
            data['@' + key] = {'placeholders': {p: {'type': 'int' if p in ('n', 'min') else 'String'} for p in val[2]}}
    (out / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(len(S), 'strings')
