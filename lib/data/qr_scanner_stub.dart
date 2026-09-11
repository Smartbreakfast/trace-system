/// Ngoài web thì chưa mở camera được, nút quét cũng không hiện.
bool get qrScanSupported => false;

Future<String?> scanQrCode() async => null;

/// Mã QR trên bao bì chứa cả đường dẫn, không phải mỗi mã lô.
String codeFromScan(String raw) => _codeFromScan(raw);

String _codeFromScan(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  final match = RegExp(r'/t/([^/?#]+)').firstMatch(text);
  final code = match != null ? match.group(1)! : text;
  return Uri.decodeComponent(code).trim().toUpperCase();
}
