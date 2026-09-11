import 'dart:js_interop';
import 'dart:typed_data';

@JS('tuleShrinkImage')
external JSFunction? get _shrinkFn;

/// Thu nhỏ và nén lại một tấm ảnh trước khi gửi lên worker.
///
/// Trả về null khi nên giữ nguyên file gốc: ảnh vốn đã nhỏ, trình duyệt không
/// có OffscreenCanvas, hoặc bản nén ra lại nặng hơn bản gốc.
Future<Uint8List?> shrinkImage(
  Uint8List bytes, {
  int maxEdge = 1600,
  double quality = 0.82,
}) async {
  final fn = _shrinkFn;
  if (fn == null) return null;
  try {
    final promise = fn.callAsFunction(
      null,
      bytes.toJS,
      maxEdge.toJS,
      quality.toJS,
    ) as JSPromise<JSAny?>?;
    if (promise == null) return null;
    final result = await promise.toDart;
    if (result == null) return null;
    return (result as JSUint8Array).toDart;
  } catch (_) {
    // Nén hỏng thì tải bản gốc, đừng chặn người vận hành lại vì một tối ưu.
    return null;
  }
}
