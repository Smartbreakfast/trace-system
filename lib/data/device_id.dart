import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Mã ẩn danh của máy, chỉ dùng để một máy không gửi hai đánh giá cho cùng một
/// lô.
///
/// Sinh ngẫu nhiên ngay trên máy rồi lưu lại; không lấy số máy, không lấy
/// thông tin hệ điều hành, không gắn với người dùng nào. Máy chủ còn băm nó
/// một lần nữa trước khi lưu, nên trong database cũng không có mã gốc này.
class DeviceId {
  static const _key = 'tule_device_v1';
  static String? _cached;

  static Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && saved.length >= 8) return _cached = saved;
      final fresh = _fresh();
      await prefs.setString(_key, fresh);
      return _cached = fresh;
    } catch (_) {
      // Trình duyệt ở chế độ riêng tư chặn lưu trữ. Vẫn gửi được đánh giá, chỉ
      // là lần sau máy này được coi như một máy khác.
      return _cached = _fresh();
    }
  }

  /// Đặt sẵn một mã, dùng trong test để không phải chạm vào bộ nhớ máy.
  static void overrideForTest(String? value) => _cached = value;

  static String _fresh() {
    final random = Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return 'd-'
        '${List.generate(24, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
  }
}
