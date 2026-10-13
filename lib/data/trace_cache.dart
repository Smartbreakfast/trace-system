import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Một lô đã mở, lưu lại trên máy.
class CachedTrace {
  const CachedTrace({
    required this.code,
    required this.name,
    required this.savedAt,
    this.data,
  });

  final String code;
  final String name;
  final DateTime savedAt;

  /// Hồ sơ đầy đủ như API trả về. Danh sách "đã xem" không cần tới nó nên
  /// chỉ đọc khi thật sự mở lại một lô.
  final Map<String, dynamic>? data;

  String get savedAtText {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(savedAt.day)}.${two(savedAt.month)}.${savedAt.year} '
        '${two(savedAt.hour)}:${two(savedAt.minute)}';
  }
}

/// Hồ sơ đã xem, giữ lại trên máy để mở được khi mất mạng.
///
/// Người mua hay quét QR ngay tại quầy hoặc giữa vùng trồng, chỗ sóng chập
/// chờn. Bản đã tải về vẫn xem lại được, nhưng luôn kèm nhãn nói rõ là bản lưu
/// và kèm thời điểm tải: trạng thái kiểm chứng trong đó là của lúc tải, không
/// phải của lúc này.
class TraceCache {
  static const _indexKey = 'tule_recent_v1';
  static const _max = 12;

  static String _key(String code) => 'tule_trace_${code.toUpperCase()}';

  static Future<void> save(
    String code,
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final upper = code.toUpperCase();
      await prefs.setString(
        _key(upper),
        jsonEncode({
          'name': name,
          'savedAt': DateTime.now().toIso8601String(),
          'data': data,
        }),
      );
      final index = _readIndex(prefs)
        ..removeWhere((item) => item['code'] == upper)
        ..insert(0, {
          'code': upper,
          'name': name,
          'savedAt': DateTime.now().toIso8601String(),
        });
      // Cắt bớt phần đuôi và xoá luôn hồ sơ của những lô đã rơi khỏi danh sách,
      // để bộ nhớ không phình theo số lần quét.
      for (final dropped in index.skip(_max)) {
        await prefs.remove(_key(dropped['code'] as String));
      }
      await prefs.setString(
        _indexKey,
        jsonEncode(index.take(_max).toList()),
      );
    } catch (_) {
      // Máy chặn lưu trữ thì chỉ mất tiện lợi, không phải lỗi chặn dùng.
    }
  }

  /// Hồ sơ đã lưu của một lô, null nếu chưa từng mở lô đó.
  static Future<CachedTrace?> load(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(code));
      if (raw == null || raw.isEmpty) return null;
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final data = parsed['data'];
      if (data is! Map) return null;
      return CachedTrace(
        code: code.toUpperCase(),
        name: (parsed['name'] as String?) ?? '',
        savedAt:
            DateTime.tryParse(parsed['savedAt'] as String? ?? '') ??
            DateTime.now(),
        data: Map<String, dynamic>.from(data),
      );
    } catch (_) {
      return null;
    }
  }

  /// Các lô đã mở, mới nhất trước.
  static Future<List<CachedTrace>> recent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _readIndex(prefs)
          .map(
            (item) => CachedTrace(
              code: item['code'] as String? ?? '',
              name: item['name'] as String? ?? '',
              savedAt:
                  DateTime.tryParse(item['savedAt'] as String? ?? '') ??
                  DateTime.now(),
            ),
          )
          .where((item) => item.code.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final item in _readIndex(prefs)) {
        await prefs.remove(_key(item['code'] as String));
      }
      await prefs.remove(_indexKey);
    } catch (_) {}
  }

  static List<Map<String, dynamic>> _readIndex(SharedPreferences prefs) {
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (_) {
      return [];
    }
  }
}
