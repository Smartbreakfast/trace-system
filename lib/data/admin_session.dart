import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Giữ phiên quản trị trên máy người vận hành.
///
/// Trước đây đây là chỗ giữ một ADMIN_TOKEN dùng chung. Giờ mỗi người một tài
/// khoản, nên thứ lưu ở đây là token của phiên đăng nhập, kèm bản sao hồ sơ
/// người dùng để mở lại trang không bị nháy một nhịp "chưa biết mình là ai".
///
/// Bản sao đó chỉ để vẽ giao diện. Quyền thật luôn do worker chốt lại ở mỗi
/// request: sửa tay thứ nằm trong trình duyệt không mở thêm được cửa nào.
class AdminSession {
  static const _tokenKey = 'tule_admin_token';
  static const _userKey = 'tule_admin_user';

  static Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      return (token?.isEmpty ?? true) ? null : token;
    } catch (_) {
      // Trình duyệt chặn storage thì chỉ mất tiện lợi, không phải lỗi chặn dùng.
      return null;
    }
  }

  static Future<void> save(String token, [Map<String, dynamic>? user]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      if (user != null) await prefs.setString(_userKey, jsonEncode(user));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (_) {}
  }
}
