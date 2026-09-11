import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Tạo một object URL rồi bấm hộ thẻ `<a download>`.
///
/// Trình duyệt không cho JavaScript ghi thẳng vào ổ đĩa, nên đây là cách duy
/// nhất để đưa file do app sinh ra xuống máy. URL được thu hồi ngay sau đó để
/// blob không nằm lại trong bộ nhớ tab.
Future<void> downloadBytes(
  Uint8List bytes,
  String fileName, {
  String contentType = 'application/octet-stream',
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: contentType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
