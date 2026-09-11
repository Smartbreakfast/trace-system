import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/trace_models.dart' show BatchPage, BatchRef;

/// Lỗi có ngữ cảnh để UI hiển thị đúng trạng thái thay vì một `Exception` chung.
sealed class TraceApiFailure implements Exception {
  const TraceApiFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Mã truy xuất không tồn tại. UI hiện màn "không tìm thấy", không phải lỗi mạng.
class TraceNotFound extends TraceApiFailure {
  const TraceNotFound(this.code)
    : super('Không tìm thấy mã truy xuất trong hệ thống.');
  final String code;
}

/// Không gọi được API (offline, sai địa chỉ, worker chưa chạy).
class TraceUnreachable extends TraceApiFailure {
  const TraceUnreachable([
    super.message = 'Không kết nối được máy chủ truy xuất.',
  ]);
}

/// Token quản trị sai hoặc chưa nhập.
class TraceUnauthorized extends TraceApiFailure {
  const TraceUnauthorized([super.message = 'Token quản trị không đúng.']);
}

/// Backend trả lỗi nghiệp vụ, ví dụ trùng mã lô hay file sai định dạng.
class TraceRequestRejected extends TraceApiFailure {
  const TraceRequestRejected(super.message, {this.statusCode = 400});
  final int statusCode;
}

class TraceApi {
  TraceApi({String? baseUrl, http.Client? client, this.timeout = defaultTimeout})
    : baseUrl = _normalize(baseUrl ?? resolvedBaseUrl),
      _client = client ?? http.Client();

  static const defaultTimeout = Duration(seconds: 15);

  /// Ghi đè lúc build: `--dart-define=API_BASE_URL=https://trace.tule.vn/api`
  static const _configured = String.fromEnvironment('API_BASE_URL');

  /// Worker phục vụ luôn bản web nên mặc định API cùng origin với trang.
  /// Không còn hardcode localhost như bản đầu.
  static String get resolvedBaseUrl {
    if (_configured.isNotEmpty) return _configured;
    if (kIsWeb) return '${Uri.base.origin}/api';
    return 'http://127.0.0.1:8787/api';
  }

  /// Đường dẫn tuyệt đối của một file media do API trả về dạng `/api/media/...`.
  static String mediaUrl(String path) {
    if (path.startsWith('http')) return path;
    final origin = Uri.parse(_normalize(resolvedBaseUrl));
    final base = '${origin.scheme}://${origin.authority}';
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  /// Token quản trị, do màn đăng nhập của Management đặt vào.
  String? adminToken;

  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Map<String, String> _headers({bool json = false, bool admin = false}) => {
    if (json) 'Content-Type': 'application/json; charset=utf-8',
    if (admin && (adminToken?.isNotEmpty ?? false))
      'Authorization': 'Bearer $adminToken',
  };

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    late http.Response response;
    try {
      response = await call().timeout(timeout);
    } on TimeoutException {
      throw const TraceUnreachable('Máy chủ phản hồi quá chậm. Thử lại sau.');
    } catch (_) {
      throw const TraceUnreachable();
    }
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    dynamic body;
    if (response.bodyBytes.isNotEmpty) {
      try {
        // Giải mã UTF-8 tường minh: package:http rơi về latin1 khi header
        // thiếu charset, và khi đó tên tiếng Việt biến thành ký tự rác.
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw const TraceUnreachable('Máy chủ trả về dữ liệu không hợp lệ.');
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw TraceUnauthorized(
        _messageOf(body) ?? 'Token quản trị không đúng hoặc đã hết hạn.',
      );
    }
    if (response.statusCode >= 400) {
      throw TraceRequestRejected(
        _messageOf(body) ?? 'Yêu cầu không hợp lệ (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  static String? _messageOf(dynamic body) {
    if (body is Map && body['message'] != null) {
      final message = body['message'];
      return message is List ? message.join('. ') : message.toString();
    }
    return null;
  }

  // ----------------------------------------------------------------- public

  Future<Map<String, dynamic>> getTrace(String code) async {
    try {
      final data = await _send(() => _client.get(_uri('/public/traces/$code')));
      if (data is! Map<String, dynamic>) throw TraceNotFound(code);
      return data;
    } on TraceRequestRejected catch (error) {
      if (error.statusCode == 404) throw TraceNotFound(code);
      rethrow;
    }
  }

  /// Backend tính lại hash từ dữ liệu hiện tại và so với snapshot đã công bố.
  /// Vài lô đã công bố, cho trang chủ gợi ý mã tra cứu.
  Future<List<BatchRef>> publicBatches() async {
    final data = await _send(() => _client.get(_uri('/public/batches')));
    // Worker trả thẳng một mảng; đọc cả dạng bọc trong {items: []} cho chắc.
    final list = data is Map<String, dynamic> ? data['items'] : data;
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map<String, dynamic>) BatchRef.fromApi(item),
    ];
  }

  Future<Map<String, dynamic>> verify(String code) async {
    final data = await _send(
      () => _client.get(_uri('/public/traces/$code/verify')),
    );
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Map<String, dynamic>> getHealth() async {
    final data = await _send(() => _client.get(_uri('/health')));
    return data is Map<String, dynamic> ? data : const {};
  }

  // ------------------------------------------------------------------ admin

  /// Kiểm tra token trước khi mở Management, để báo sai ngay tại màn đăng nhập.
  Future<bool> checkSession() async {
    await _send(
      () => _client.get(_uri('/admin/session'), headers: _headers(admin: true)),
    );
    return true;
  }

  Future<Map<String, dynamic>> getSummary() async {
    final data = await _send(
      () => _client.get(_uri('/admin/summary'), headers: _headers(admin: true)),
    );
    return data is Map<String, dynamic> ? data : const {};
  }

  /// Một trang danh sách lô. Lọc và sắp xếp chạy ở D1 chứ không tải hết về
  /// rồi lọc ở client: số lô sẽ tăng theo từng vụ, không có trần.
  Future<BatchPage> listBatches({
    String query = '',
    String sort = 'newest',
    int page = 1,
    int limit = 10,
  }) async {
    final data = await _send(
      () => _client.get(
        _uri('/admin/product-batches', {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'sort': sort,
          'page': '$page',
          'limit': '$limit',
        }),
        headers: _headers(admin: true),
      ),
    );
    if (data is! Map<String, dynamic>) return const BatchPage.empty();
    return BatchPage(
      items: _mapList(data['items']),
      total: data['total'] as int? ?? 0,
      page: data['page'] as int? ?? 1,
      pages: data['pages'] as int? ?? 1,
    );
  }

  /// Hồ sơ theo dữ liệu đang có, dành cho màn quản trị.
  ///
  /// Trang khách đọc bản đã công bố, nên người vận hành phải có đường riêng để
  /// thấy đúng thứ mình vừa sửa.
  Future<Map<String, dynamic>> getAdminTrace(String code) async {
    final data = await _send(
      () => _client.get(
        _uri('/admin/product-batches/$code/trace'),
        headers: _headers(admin: true),
      ),
    );
    if (data is! Map<String, dynamic>) {
      throw TraceNotFound('Không đọc được hồ sơ lô $code.');
    }
    return data;
  }

  /// Nội dung đầy đủ của một bản đã chốt, để đối chiếu với dữ liệu hiện tại.
  Future<Map<String, dynamic>> getSnapshot(String code, int version) async {
    final data = await _send(
      () => _client.get(
        _uri('/admin/product-batches/$code/snapshots/$version'),
        headers: _headers(admin: true),
      ),
    );
    return data is Map<String, dynamic> ? data : const {};
  }

  /// Trạng thái ví neo dữ liệu và hàng chờ ghi chuỗi.
  Future<Map<String, dynamic>> chainStatus() async {
    final data = await _send(
      () => _client.get(_uri('/admin/chain'), headers: _headers(admin: true)),
    );
    return data is Map<String, dynamic> ? data : const {};
  }

  /// Gửi ngay những bản còn nằm trong hàng chờ.
  Future<Map<String, dynamic>> sendPendingToChain() =>
      _write('POST', '/admin/chain/send');

  Future<Map<String, dynamic>> retryChain() =>
      _write('POST', '/admin/chain/retry');

  Future<List<Map<String, dynamic>>> listSnapshots(String code) async {
    final data = await _send(
      () => _client.get(
        _uri('/admin/product-batches/$code/snapshots'),
        headers: _headers(admin: true),
      ),
    );
    return _mapList(data);
  }

  static List<Map<String, dynamic>> _mapList(dynamic data) {
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map<String, dynamic>) item,
    ];
  }

  Future<Map<String, dynamic>> _write(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = _uri(path);
    final headers = _headers(json: body != null, admin: true);
    final payload = body == null ? null : jsonEncode(body);
    final data = await _send(() => switch (method) {
      'POST' => _client.post(uri, headers: headers, body: payload),
      'PATCH' => _client.patch(uri, headers: headers, body: payload),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => throw ArgumentError('Phương thức không hỗ trợ: $method'),
    });
    return data is Map<String, dynamic> ? data : const {};
  }

  Future<Map<String, dynamic>> publish(
    String code, {
    String enteredBy = 'admin',
  }) => _write('POST', '/admin/product-batches/$code/publish', {
    'enteredBy': enteredBy,
  });

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> body) =>
      _write('POST', '/admin/product-batches', body);

  Future<Map<String, dynamic>> updateProduct(
    String code,
    Map<String, dynamic> body,
  ) => _write('PATCH', '/admin/product-batches/$code', body);

  Future<Map<String, dynamic>> createIngredient(Map<String, dynamic> body) =>
      _write('POST', '/admin/ingredient-batches', body);

  Future<void> deleteIngredient(Object id) =>
      _write('DELETE', '/admin/ingredient-batches/$id');

  Future<Map<String, dynamic>> updateIngredient(
    Object id,
    Map<String, dynamic> body,
  ) => _write('PATCH', '/admin/ingredient-batches/$id', body);

  /// Công đoạn: `ingredientBatchId` cho công đoạn của nguyên liệu,
  /// `productBatchId` cho công đoạn ở xưởng.
  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> body) =>
      _write('POST', '/admin/process-events', body);

  /// Sửa một công đoạn đã có. Bộ công đoạn sinh từ template chỉ có tên và mô
  /// tả; khối lượng, người làm và tham số nhập qua đường này.
  Future<Map<String, dynamic>> updateEvent(
    Object id,
    Map<String, dynamic> body,
  ) => _write('PATCH', '/admin/process-events/$id', body);

  Future<void> deleteEvent(Object id) =>
      _write('DELETE', '/admin/process-events/$id');

  Future<void> deleteMedia(Object id) => _write('DELETE', '/admin/media/$id');

  /// Giới hạn kích thước và danh sách định dạng do backend quyết định, client
  /// đọc về để báo trước cho admin thay vì để họ chờ upload rồi mới nhận lỗi.
  Future<({int maxBytes, List<String> contentTypes})> mediaConfig() async {
    final data = await _send(
      () => _client.get(
        _uri('/admin/media/config'),
        headers: _headers(admin: true),
      ),
    );
    final map = data is Map<String, dynamic> ? data : const {};
    return (
      maxBytes: (map['maxBytes'] as num?)?.toInt() ?? 30 * 1024 * 1024,
      contentTypes: [
        for (final item in (map['contentTypes'] as List<dynamic>? ?? const []))
          item.toString(),
      ],
    );
  }

  Future<Map<String, dynamic>> uploadMedia({
    required String ownerType,
    required Object ownerId,
    required String role,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    String caption = '',
    String certType = '',
    String certNumber = '',
    String validUntil = '',
  }) async {
    final request = http.MultipartRequest('POST', _uri('/admin/media'))
      ..headers.addAll(_headers(admin: true))
      ..fields['ownerType'] = ownerType
      ..fields['ownerId'] = '$ownerId'
      ..fields['role'] = role
      ..fields['caption'] = caption
      ..fields['certType'] = certType
      ..fields['certNumber'] = certNumber
      ..fields['validUntil'] = validUntil
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: _parseMediaType(contentType),
        ),
      );

    late http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const TraceUnreachable('Tải file quá lâu. Kiểm tra đường truyền.');
    } catch (_) {
      throw const TraceUnreachable('Không tải được file lên máy chủ.');
    }
    final data = _decode(response);
    return data is Map<String, dynamic> ? data : const {};
  }

  static MediaType? _parseMediaType(String value) {
    final parts = value.split('/');
    if (parts.length != 2) return null;
    return MediaType(parts[0], parts[1]);
  }

  void dispose() => _client.close();
}
