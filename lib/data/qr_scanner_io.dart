import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../app/nav.dart';
import '../ui/qr_scan_screen.dart';

/// Chỉ Android và iOS mới có camera cầm tay để chĩa vào bao bì. Trên máy bàn
/// hay trong test chạy bằng Dart VM thì ẩn nút đi cho khỏi hứa suông.
bool get qrScanSupported => Platform.isAndroid || Platform.isIOS;

/// Mở màn camera và chờ tới khi đọc được một mã, hoặc người dùng đóng.
Future<String?> scanQrCode() async {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return null;
  return navigator.push<String>(
    MaterialPageRoute(
      builder: (_) => const QrScanScreen(),
      fullscreenDialog: true,
    ),
  );
}

/// Mã QR trên bao bì chứa cả đường dẫn `.../t/TL-2026-001`, không phải mỗi mã.
String codeFromScan(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  final match = RegExp(r'/t/([^/?#]+)').firstMatch(text);
  final code = match != null ? match.group(1)! : text;
  return Uri.decodeComponent(code).trim().toUpperCase();
}
