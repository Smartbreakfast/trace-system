import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Gốc của ứng dụng, đọc từ `<base href>` mà Flutter đặt trong index.html.
///
/// Bắt buộc phải tuyệt đối. Đường dẫn tương đối tới thư viện MapLibre sẽ được
/// trình duyệt giải theo URL hiện tại, nên ở route `/t/TL-2026-001` nó biến
/// thành `/t/vendor/...`; SPA fallback trả về index.html với kiểu `text/html`,
/// và trình duyệt từ chối import một module có MIME như vậy.
String appBaseUrl() {
  final document = globalContext.getProperty('document'.toJS) as JSObject?;
  final base = document?.getProperty('baseURI'.toJS).dartify();
  if (base is String && base.isNotEmpty) {
    return base.endsWith('/') ? base : '$base/';
  }
  return '/';
}
