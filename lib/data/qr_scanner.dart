// Quét mã QR bằng camera. Web gọi BarcodeDetector của trình duyệt, Android và
// iOS mở màn camera riêng; nền tảng nào không có cả hai thì dùng bản stub và
// nút quét tự ẩn.
export 'qr_scanner_stub.dart'
    if (dart.library.js_interop) 'qr_scanner_web.dart'
    if (dart.library.io) 'qr_scanner_io.dart';
