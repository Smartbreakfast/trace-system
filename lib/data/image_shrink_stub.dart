import 'dart:typed_data';

/// Ngoài web thì không có canvas để nén; giữ nguyên file gốc.
Future<Uint8List?> shrinkImage(
  Uint8List bytes, {
  int maxEdge = 1600,
  double quality = 0.82,
}) async => null;
