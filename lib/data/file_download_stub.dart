import 'dart:typed_data';

/// Ngoài web thì chưa có nhu cầu tải file, nên báo rõ thay vì im lặng.
Future<void> downloadBytes(
  Uint8List bytes,
  String fileName, {
  String contentType = 'application/octet-stream',
}) async {
  throw UnsupportedError('Tải file chỉ hỗ trợ trên web.');
}
