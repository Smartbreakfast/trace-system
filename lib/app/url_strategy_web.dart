import 'package:flutter_web_plugins/url_strategy.dart';

/// Bỏ dấu `#` khỏi đường dẫn. Worker đã bật SPA fallback nên mọi URL dạng
/// `/t/TL-2026-001` đều trả về ứng dụng, và mã QR in lên bao bì đọc sạch hơn
/// nhiều so với `/#/t/TL-2026-001`.
void configureUrlStrategy() => usePathUrlStrategy();
