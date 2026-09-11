import 'dart:js_interop';

@JS('tuleQrScanSupported')
external JSFunction? get _supportedFn;

@JS('tuleScanQr')
external JSFunction? get _scanFn;

/// Trình duyệt có camera dùng được hay không. Trang chạy qua http (không phải
/// localhost) cũng bị chặn getUserMedia, nên nút chỉ hiện khi thật sự gọi được.
bool get qrScanSupported {
  final fn = _supportedFn;
  if (fn == null) return false;
  final result = fn.callAsFunction();
  return result != null && (result as JSBoolean).toDart;
}

/// Mở lớp phủ camera và chờ tới khi đọc được một mã, hoặc người dùng đóng.
Future<String?> scanQrCode() async {
  final fn = _scanFn;
  if (fn == null) return null;
  final promise = fn.callAsFunction() as JSPromise<JSAny?>?;
  if (promise == null) return null;
  final value = await promise.toDart;
  if (value == null) return null;
  final text = (value as JSString).toDart;
  return text.isEmpty ? null : text;
}

/// Mã QR trên bao bì chứa cả đường dẫn `.../t/TL-2026-001`, không phải mỗi mã.
String codeFromScan(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  final match = RegExp(r'/t/([^/?#]+)').firstMatch(text);
  final code = match != null ? match.group(1)! : text;
  return Uri.decodeComponent(code).trim().toUpperCase();
}
