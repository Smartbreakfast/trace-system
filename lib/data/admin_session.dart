import 'package:shared_preferences/shared_preferences.dart';

/// Lưu token quản trị trên máy admin.
///
/// API `/api/admin/*` giờ đã đóng bằng bearer token (trước đây mở cho cả
/// internet), nên client cần chỗ giữ token giữa các lần mở trang. Đây là
/// bí mật dùng chung ở mức đủ cho giai đoạn này; khi có nhiều người vận hành
/// thì thay bằng tài khoản riêng và phiên đăng nhập thật.
class AdminSession {
  static const _key = 'tule_admin_token';

  static Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_key);
      return (token?.isEmpty ?? true) ? null : token;
    } catch (_) {
      // Trình duyệt chặn storage thì chỉ mất tiện lợi, không phải lỗi chặn dùng.
      return null;
    }
  }

  static Future<void> save(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
