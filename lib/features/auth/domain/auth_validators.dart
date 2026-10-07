import 'package:mnote/features/auth/domain/auth_exception.dart';

class AuthValidators {
  const AuthValidators._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const minPasswordLength = 6;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'กรุณากรอกอีเมล';
    if (!_emailPattern.hasMatch(v)) return 'รูปแบบอีเมลไม่ถูกต้อง';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (v.length < minPasswordLength) {
      return 'รหัสผ่านต้องมีอย่างน้อย $minPasswordLength ตัวอักษร';
    }
    return null;
  }

  static String? displayName(String? value) {
    if ((value?.trim() ?? '').isEmpty) return 'กรุณากรอกชื่อ';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) return 'กรุณายืนยันรหัสผ่าน';
    if (value != password) return 'รหัสผ่านไม่ตรงกัน';
    return null;
  }

  static String messageFor(AuthException e) {
    switch (e.code) {
      case AuthErrorCode.invalidEmail:
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case AuthErrorCode.wrongCredentials:
      case AuthErrorCode.userNotFound:
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case AuthErrorCode.userDisabled:
        return 'บัญชีนี้ถูกระงับการใช้งาน';
      case AuthErrorCode.emailAlreadyInUse:
        return 'อีเมลนี้ถูกใช้งานแล้ว';
      case AuthErrorCode.weakPassword:
        return 'รหัสผ่านง่ายเกินไป';
      case AuthErrorCode.tooManyRequests:
        return 'ลองใหม่หลายครั้งเกินไป กรุณารอสักครู่';
      case AuthErrorCode.network:
        return 'เชื่อมต่ออินเทอร์เน็ตไม่ได้';
      case AuthErrorCode.cancelled:
        return 'ยกเลิกการเข้าสู่ระบบ';
      case AuthErrorCode.unknown:
        return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
    }
  }
}
