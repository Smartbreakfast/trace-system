import 'vn_provinces.dart';

/// Bỏ dấu tiếng Việt để so khớp chuỗi.
///
/// Dùng cho ô gợi ý tỉnh trong màn quản trị: người nhập gõ "yen bai" thì vẫn
/// phải ra "Yên Bái".
String foldVietnamese(String input) {
  const marks = {
    'aàáạảãâầấậẩẫăằắặẳẵ': 'a',
    'eèéẹẻẽêềếệểễ': 'e',
    'iìíịỉĩ': 'i',
    'oòóọỏõôồốộổỗơờớợởỡ': 'o',
    'uùúụủũưừứựửữ': 'u',
    'yỳýỵỷỹ': 'y',
    'dđ': 'd',
  };
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    var mapped = char;
    for (final entry in marks.entries) {
      if (entry.key.contains(char)) {
        mapped = entry.value;
        break;
      }
    }
    if (RegExp(r'[a-z0-9]').hasMatch(mapped)) buffer.write(mapped);
  }
  return buffer.toString();
}

/// Danh sách tỉnh thành cho ô gợi ý địa chỉ vùng nguyên liệu.
List<(String, double, double)> get provinceOptions => vietnamProvinces;
