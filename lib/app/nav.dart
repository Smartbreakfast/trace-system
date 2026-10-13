import 'package:flutter/widgets.dart';

/// Navigator gốc của ứng dụng.
///
/// Lớp quét QR trên di động phải mở một màn hình camera, mà hàm `scanQrCode()`
/// được gọi từ chỗ không giữ `BuildContext` nào. Giữ sẵn key ở đây thì bản web
/// và bản di động dùng chung một chữ ký hàm, không phải sửa nơi gọi.
final rootNavigatorKey = GlobalKey<NavigatorState>();
