import 'dart:convert';

import 'package:flutter/material.dart';

import '../ui/tule_theme.dart';

/// Ngày trong hệ thống ghi dạng dd.MM.yyyy (đôi khi dùng / hoặc -).
/// Trả null nếu không đọc được, để phần vẽ biểu đồ bỏ qua thay vì đoán.
DateTime? parseTraceDate(String raw) {
  final parts = raw.trim().split(RegExp(r'[./-]'));
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

/// Đọc số thực an toàn: cột toạ độ có thể null hoặc về dạng chuỗi.
double? _num(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String && value.trim().isNotEmpty) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

/// Đọc chuỗi an toàn: API trả null hoặc thiếu field không được làm sập trang.
String _str(Map<String, dynamic> json, List<String> keys, {String or = ''}) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value != null && value is! String) return value.toString();
  }
  return or;
}


enum MediaKind { image, video, document }

/// Ảnh, video hoặc hồ sơ kiểm nghiệm gắn vào lô, nguyên liệu hay công đoạn.
///
/// Khoá lưu trữ chứa luôn sha256 của nội dung, và khoá đó nằm trong snapshot,
/// nên tráo ảnh sau khi công bố cũng bị bắt như tráo chữ.
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.kind,
    required this.role,
    required this.url,
    this.fileName = '',
    this.contentType = '',
    this.size = 0,
    this.sha256 = '',
    this.caption = '',
    this.certType = '',
    this.certNumber = '',
    this.validUntil = '',
  });

  final Object? id;
  final MediaKind kind;
  final String url;
  final String role;
  final String fileName;
  final String contentType;
  final int size;
  final String sha256;
  final String caption;

  /// Chỉ có ở role `certificate`: loại giấy, số hiệu, hạn hiệu lực.
  final String certType;
  final String certNumber;
  final String validUntil;

  bool get isCover => role == 'cover';
  bool get isLabReport => role == 'lab_report';
  bool get isCertificate => role == 'certificate';

  /// Ảnh chụp vùng nguyên liệu, hiện thay cho bản đồ tương tác.
  bool get isAreaMap => role == 'area_map';

  /// Nhãn hiển thị của một giấy chứng nhận.
  String get certLabel {
    if (certType.isEmpty) return caption.isEmpty ? fileName : caption;
    return certNumber.isEmpty ? certType : '$certType · $certNumber';
  }

  String get readableSize {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) return '${(size / 1024).round()} KB';
    return '$size B';
  }

  static MediaKind _kindOf(String raw) => switch (raw) {
    'video' => MediaKind.video,
    'document' => MediaKind.document,
    _ => MediaKind.image,
  };

  factory MediaAsset.fromApi(Map<String, dynamic> json) => MediaAsset(
    id: json['id'],
    kind: _kindOf(_str(json, ['kind'], or: 'image')),
    role: _str(json, ['role'], or: 'gallery'),
    url: _str(json, ['url']),
    fileName: _str(json, ['fileName', 'file_name']),
    contentType: _str(json, ['contentType', 'content_type']),
    size: (json['size'] as num?)?.toInt() ?? 0,
    sha256: _str(json, ['sha256']),
    caption: _str(json, ['caption']),
    certType: _str(json, ['certType', 'cert_type']),
    certNumber: _str(json, ['certNumber', 'cert_number']),
    validUntil: _str(json, ['validUntil', 'valid_until']),
  );
}

/// Số đo đọc từ API: chấp nhận cả số lẫn chuỗi, bỏ qua giá trị không hợp lệ.
double? _amount(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw is num) return raw.toDouble();
    if (raw is String && raw.trim().isNotEmpty) {
      final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
  }
  return null;
}

/// Tham số công đoạn. Bản công bố trả về object; bản ghi thô có thể là chuỗi
/// JSON, nên đọc được cả hai.
Map<String, String> _params(Object? raw) {
  Object? source = raw;
  if (source is String) {
    if (source.trim().isEmpty) return const {};
    try {
      source = jsonDecode(source);
    } catch (_) {
      return const {};
    }
  }
  if (source is! Map) return const {};
  final out = <String, String>{};
  source.forEach((key, value) {
    final name = key.toString().trim();
    final text = value?.toString().trim() ?? '';
    if (name.isNotEmpty && text.isNotEmpty) out[name] = text;
  });
  return out;
}

List<MediaAsset> _mediaOf(Map<String, dynamic> json) => [
  for (final item in (json['media'] as List<dynamic>? ?? const []))
    if (item is Map<String, dynamic>) MediaAsset.fromApi(item),
];

class ProcessEvent {
  const ProcessEvent({
    required this.title,
    this.id,
    this.description = '',
    this.eventDate = '',
    this.enteredBy = '',
    this.media = const [],
    this.operator = '',
    this.inputQuantity,
    this.outputQuantity,
    this.quantityUnit = '',
    this.params = const {},
  });

  final Object? id;
  final String title;
  final String description;
  final String eventDate;
  final String enteredBy;
  final List<MediaAsset> media;

  /// Người trực tiếp làm công đoạn. Khác [enteredBy] là người gõ vào hệ thống.
  final String operator;

  /// Khối lượng vào và ra của công đoạn. Null nghĩa là chưa khai.
  final double? inputQuantity;
  final double? outputQuantity;
  final String quantityUnit;

  /// Tham số kỹ thuật dạng nhãn và giá trị: nhiệt độ, thời gian, tỷ lệ.
  final Map<String, String> params;

  factory ProcessEvent.fromApi(Map<String, dynamic> json) => ProcessEvent(
    id: json['id'],
    title: _str(json, ['title'], or: 'Công đoạn chưa đặt tên'),
    description: _str(json, ['description']),
    eventDate: _str(json, ['event_date', 'eventDate']),
    enteredBy: _str(json, ['entered_by', 'enteredBy']),
    media: _mediaOf(json),
    operator: _str(json, ['operator']),
    inputQuantity: _amount(json, ['inputQuantity', 'input_quantity']),
    outputQuantity: _amount(json, ['outputQuantity', 'output_quantity']),
    quantityUnit: _str(json, ['quantityUnit', 'quantity_unit']),
    params: _params(json['params']),
  );

  bool get hasQuantity => inputQuantity != null || outputQuantity != null;

  /// Tỷ lệ thu hồi, chỉ tính khi có đủ hai đầu và đầu vào khác 0.
  double? get yieldRatio {
    final input = inputQuantity;
    final output = outputQuantity;
    if (input == null || output == null || input <= 0) return null;
    return output / input;
  }

  /// Có gì để hiện trong panel chi tiết hay không.
  bool get hasDetails =>
      description.isNotEmpty ||
      operator.isNotEmpty ||
      hasQuantity ||
      params.isNotEmpty ||
      media.isNotEmpty;

  /// Dòng phụ hiển thị dưới tiêu đề công đoạn.
  String get meta {
    final parts = [
      if (eventDate.isNotEmpty) eventDate,
      if (operator.isNotEmpty)
        operator
      else if (enteredBy.isNotEmpty)
        'ghi nhận bởi $enteredBy',
    ];
    return parts.isEmpty ? 'Chưa có mốc thời gian' : parts.join('  ·  ');
  }
}

class Ingredient {
  const Ingredient({
    required this.name,
    this.id,
    required this.origin,
    required this.icon,
    required this.color,
    required this.summary,
    this.supplier = '',
    this.harvestDate = '',
    this.receivedDate = '',
    this.events = const [],
    this.media = const [],
    this.latitude,
    this.longitude,
    this.areaGeoJson,
    this.sourceBatch,
  });

  final Object? id;
  final String name;
  final String origin;
  final IconData icon;
  final Color color;
  final String summary;
  final String supplier;
  final String harvestDate;
  final String receivedDate;
  final List<ProcessEvent> events;
  final List<MediaAsset> media;

  /// Ảnh chụp vùng trồng, hiện thay cho bản đồ tương tác.
  MediaAsset? get areaMap => media.where((item) => item.isAreaMap).firstOrNull;

  /// Ảnh còn lại của nguyên liệu, bỏ ảnh vùng ra vì nó đã đứng riêng.
  List<MediaAsset> get photos =>
      media.where((item) => !item.isAreaMap).toList();

  /// Toạ độ vùng trồng do người vận hành nhập. Bỏ trống thì [location] rơi về
  /// tâm tỉnh suy từ [origin].
  final double? latitude;
  final double? longitude;

  /// Vùng nguyên liệu do nhà sản xuất tự khoanh trên bản đồ, dạng GeoJSON.
  final String? areaGeoJson;
  final BatchRef? sourceBatch;

  List<String> get stepTitles => [for (final e in events) e.title];

  factory Ingredient.fromApi(Map<String, dynamic> json, int index) {
    final rawEvents = json['processEvents'] as List<dynamic>? ?? const [];
    return Ingredient(
      id: json['id'],
      name: _str(json, ['name'], or: 'Nguyên liệu chưa đặt tên'),
      origin: _str(json, ['origin'], or: 'Chưa có vùng nguyên liệu'),
      icon: ingredientIcons[index % ingredientIcons.length],
      color: ingredientAccents[index % ingredientAccents.length],
      summary: _str(json, ['summary']),
      supplier: _str(json, ['supplier']),
      harvestDate: _str(json, ['harvest_date', 'harvestDate']),
      receivedDate: _str(json, ['received_date', 'receivedDate']),
      events: [
        for (final event in rawEvents)
          if (event is Map<String, dynamic>) ProcessEvent.fromApi(event),
      ],
      media: _mediaOf(json),
      latitude: _num(json, ['latitude']),
      longitude: _num(json, ['longitude']),
      areaGeoJson: _str(json, ['area_geojson', 'areaGeoJson']),
      sourceBatch: json['sourceBatch'] is Map<String, dynamic>
          ? BatchRef.fromApi(json['sourceBatch'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ProductBatch {
  const ProductBatch({
    required this.name,
    required this.code,
    required this.productionDate,
    required this.expiryDate,
    required this.description,
    this.status = 'DRAFT',
    this.facilityName = '',
    this.latitude,
    this.longitude,
  });

  final String name;
  final String code;
  final String productionDate;
  final String expiryDate;
  final String description;
  final String status;

  /// Nơi sản xuất, là điểm hội tụ của mọi nguyên liệu trên bản đồ.
  final String facilityName;
  final double? latitude;
  final double? longitude;

  bool get isPublished => status.toUpperCase() == 'PUBLISHED';

  factory ProductBatch.fromApi(Map<String, dynamic> json) => ProductBatch(
    name: _str(json, ['name'], or: 'Lô chưa đặt tên'),
    code: _str(json, ['code']),
    productionDate: _str(json, ['production_date', 'productionDate']),
    expiryDate: _str(json, ['expiry_date', 'expiryDate']),
    description: _str(json, ['description']),
    status: _str(json, ['status'], or: 'DRAFT'),
    facilityName: _str(json, ['facility_name', 'facilityName']),
    latitude: _num(json, ['latitude']),
    longitude: _num(json, ['longitude']),
  );
}

enum IntegrityStatus { verified, mismatch, notPublished, unknown }

/// Kết quả kiểm chứng hash. `status` do backend tính lại từ dữ liệu hiện tại
/// rồi so với snapshot đã công bố, không phải chuỗi cứng ở UI.
/// Tình trạng ghi lên chuỗi của bản đã chốt gần nhất.
class ChainRecord {
  const ChainRecord({
    this.status = '',
    this.txHash = '',
    this.blockNumber = '',
    this.chainId,
    this.contract = '',
    this.explorer = '',
  });

  final String status;
  final String txHash;
  final String blockNumber;
  final int? chainId;
  final String contract;
  final String explorer;

  bool get isOnChain => txHash.isNotEmpty && status == 'CONFIRMED';
  bool get isPending => txHash.isEmpty && status != 'FAILED';
  bool get hasFailed => status == 'FAILED';

  /// Liên kết tới giao dịch trên explorer. Rỗng khi chưa lên chuỗi hoặc chưa
  /// khai explorer — lúc đó giao diện không hiện nút, thay vì hiện nút chết.
  String get txUrl =>
      explorer.isEmpty || txHash.isEmpty ? '' : '$explorer/tx/$txHash';

  String get shortTx => txHash.length <= 18
      ? txHash
      : '${txHash.substring(0, 10)}…${txHash.substring(txHash.length - 6)}';

  factory ChainRecord.fromApi(Map<String, dynamic>? json) {
    if (json == null) return const ChainRecord();
    return ChainRecord(
      status: _str(json, ['status']),
      txHash: _str(json, ['txHash', 'tx_hash']),
      blockNumber: _str(json, ['blockNumber', 'block_number']),
      chainId: json['chainId'] is int ? json['chainId'] as int : null,
      contract: _str(json, ['contract']),
      explorer: _str(json, ['explorer']),
    );
  }
}

class IntegrityRecord {
  const IntegrityRecord({
    required this.status,
    this.version,
    this.snapshotHash = '',
    this.currentHash = '',
    this.publishedBy = '',
    this.publishedAt = '',
    this.chain = const ChainRecord(),
  });

  static const empty = IntegrityRecord(status: IntegrityStatus.unknown);

  final IntegrityStatus status;
  final int? version;
  final String snapshotHash;
  final String currentHash;
  final String publishedBy;
  final String publishedAt;
  final ChainRecord chain;

  bool get hasHash => snapshotHash.isNotEmpty;

  String get shortHash => snapshotHash.length >= 16
      ? '${snapshotHash.substring(0, 8)}…${snapshotHash.substring(snapshotHash.length - 8)}'
      : snapshotHash;

  factory IntegrityRecord.fromApi(Map<String, dynamic>? json) {
    if (json == null) return empty;
    final raw = _str(json, ['status']).toUpperCase();
    final status = switch (raw) {
      'VERIFIED' => IntegrityStatus.verified,
      'MISMATCH' => IntegrityStatus.mismatch,
      'NOT_PUBLISHED' => IntegrityStatus.notPublished,
      _ =>
        json['sha256'] != null || json['snapshotHash'] != null
            ? IntegrityStatus.verified
            : IntegrityStatus.unknown,
    };
    return IntegrityRecord(
      status: status,
      version: json['version'] is int ? json['version'] as int : null,
      snapshotHash: _str(json, ['snapshotHash', 'sha256']),
      currentHash: _str(json, ['currentHash']),
      publishedBy: _str(json, ['publishedBy', 'published_by']),
      publishedAt: _str(json, ['publishedAt', 'published_at']),
      chain: ChainRecord.fromApi(json['chain'] as Map<String, dynamic>?),
    );
  }
}

/// Toàn bộ hồ sơ một lô, đúng chuỗi QR -> ProductBatch -> nguyên liệu -> công đoạn.
/// Một lô đã công bố, đủ để gợi ý mã cho người chưa cầm bao bì trên tay.
class BatchRef {
  const BatchRef({
    required this.code,
    required this.name,
    this.productionDate = '',
  });

  final String code;
  final String name;
  final String productionDate;

  factory BatchRef.fromApi(Map<String, dynamic> json) => BatchRef(
    code: _str(json, ['code']),
    name: _str(json, ['name']),
    productionDate: _str(json, ['productionDate', 'production_date']),
  );
}

class ProductCatalog {
  const ProductCatalog({
    required this.id,
    required this.sku,
    required this.name,
    this.description = '',
    this.templateKey = '',
  });

  final Object? id;
  final String sku;
  final String name;
  final String description;
  final String templateKey;

  factory ProductCatalog.fromApi(Map<String, dynamic> json) => ProductCatalog(
    id: json['id'],
    sku: _str(json, ['sku']),
    name: _str(json, ['name'], or: 'Sản phẩm chưa đặt tên'),
    description: _str(json, ['description']),
    templateKey: _str(json, ['templateKey', 'template_key']),
  );
}

class PublicProduct {
  const PublicProduct({
    required this.sku,
    required this.name,
    this.description = '',
    this.templateKey = '',
    this.batches = const [],
  });

  final String sku;
  final String name;
  final String description;
  final String templateKey;
  final List<BatchRef> batches;

  factory PublicProduct.fromApi(Map<String, dynamic> json) => PublicProduct(
    sku: _str(json, ['sku']),
    name: _str(json, ['name'], or: 'Sản phẩm chưa đặt tên'),
    description: _str(json, ['description']),
    templateKey: _str(json, ['templateKey', 'template_key']),
    batches: [
      for (final item in (json['batches'] as List<dynamic>? ?? const []))
        if (item is Map<String, dynamic>) BatchRef.fromApi(item),
    ],
  );
}

/// Một đánh giá của người mua sau khi quét mã.
///
/// Không nằm trong snapshot và không vào mã băm: hồ sơ lô là tuyên bố của nhà
/// sản xuất đã neo lên blockchain, còn đánh giá thì người mua còn gửi thêm mãi.
class RatingComment {
  const RatingComment({
    required this.stars,
    required this.comment,
    this.displayName = '',
    this.createdAt = '',
  });

  final int stars;
  final String comment;
  final String displayName;
  final String createdAt;

  String get authorLabel =>
      displayName.trim().isEmpty ? 'Khách ẩn danh' : displayName.trim();

  /// Chỉ ngày, không giờ: giờ gửi không giúp người đọc quyết định gì.
  String get dateText {
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year}';
  }

  factory RatingComment.fromApi(Map<String, dynamic> json) => RatingComment(
    stars: (json['stars'] as num?)?.toInt() ?? 0,
    comment: json['comment'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    createdAt: json['createdAt'] as String? ?? '',
  );
}

/// Điểm trung bình, phân bố sao và vài nhận xét mới nhất của một lô.
class RatingSummary {
  const RatingSummary({
    this.count = 0,
    this.average = 0,
    this.distribution = const {},
    this.comments = const [],
  });

  const RatingSummary.empty()
    : count = 0,
      average = 0,
      distribution = const {},
      comments = const [];

  final int count;
  final double average;
  final Map<int, int> distribution;
  final List<RatingComment> comments;

  bool get isEmpty => count == 0;

  int starCount(int stars) => distribution[stars] ?? 0;

  /// Một chữ số thập phân, dấu phẩy theo cách viết tiếng Việt.
  String get averageText => average.toStringAsFixed(1).replaceAll('.', ',');

  factory RatingSummary.fromApi(Map<String, dynamic>? json) {
    if (json == null) return const RatingSummary.empty();
    final raw = json['distribution'];
    final distribution = <int, int>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final stars = int.tryParse('${entry.key}');
        final value = (entry.value as num?)?.toInt();
        if (stars != null && value != null) distribution[stars] = value;
      }
    }
    return RatingSummary(
      count: (json['count'] as num?)?.toInt() ?? 0,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      distribution: distribution,
      comments: [
        for (final item in json['comments'] as List<dynamic>? ?? const [])
          if (item is Map<String, dynamic>) RatingComment.fromApi(item),
      ],
    );
  }
}

class TraceRecord {
  const TraceRecord({
    required this.batch,
    required this.ingredients,
    required this.integrity,
    this.batchEvents = const [],
    this.media = const [],
    this.ratings = const RatingSummary.empty(),
    this.isDemo = false,
  });

  final ProductBatch batch;
  final List<Ingredient> ingredients;
  final IntegrityRecord integrity;

  /// Công đoạn ở xưởng: phối trộn, đóng gói. Chúng thuộc cả lô chứ không thuộc
  /// nguyên liệu nào, nên đứng riêng thay vì gắn nhờ vào một nguyên liệu.
  final List<ProcessEvent> batchEvents;

  /// Media gắn thẳng vào lô thành phẩm: ảnh bìa, ảnh giới thiệu và hồ sơ kiểm nghiệm.
  final List<MediaAsset> media;

  /// Đánh giá của người mua. Rỗng khi lô chưa ai đánh giá.
  final RatingSummary ratings;

  MediaAsset? get cover => media.where((item) => item.isCover).firstOrNull;

  List<MediaAsset> get gallery => media
      .where(
        (item) =>
            !item.isCover &&
            !item.isLabReport &&
            !item.isCertificate &&
            !item.isAreaMap,
      )
      .toList();

  /// Ảnh bản đồ vùng nguyên liệu của cả lô.
  MediaAsset? get areaMap => media.where((item) => item.isAreaMap).firstOrNull;

  List<MediaAsset> get certificates =>
      media.where((item) => item.isCertificate).toList();

  List<MediaAsset> get labReports =>
      media.where((item) => item.isLabReport).toList();

  /// Toàn bộ ảnh và video của lô, gộp từ mọi cấp để dựng một dải xem nhanh.
  List<MediaAsset> get allVisualMedia => [
    for (final item in media)
      if (item.kind != MediaKind.document) item,
    for (final ingredient in ingredients) ...[
      for (final item in ingredient.media)
        if (item.kind != MediaKind.document) item,
      for (final event in ingredient.events)
        for (final item in event.media)
          if (item.kind != MediaKind.document) item,
    ],
  ];

  /// True khi dữ liệu đến từ bộ mẫu offline chứ không phải API thật.
  final bool isDemo;


  /// Tất cả công đoạn của mọi nguyên liệu, gộp và sắp theo ngày để dựng timeline.
  List<({Ingredient ingredient, ProcessEvent event})> get timeline {
    final all = <({Ingredient ingredient, ProcessEvent event})>[
      for (final ingredient in ingredients)
        for (final event in ingredient.events)
          (ingredient: ingredient, event: event),
    ];
    all.sort(
      (a, b) => _sortKey(a.event.eventDate).compareTo(_sortKey(b.event.eventDate)),
    );
    return all;
  }

  /// Ngày trong dữ liệu đang là dd.MM.yyyy nên phải đảo về yyyyMMdd mới sắp đúng.
  static String _sortKey(String date) {
    final parts = date.split(RegExp(r'[./-]'));
    if (parts.length == 3 && parts[2].length == 4) {
      return '${parts[2]}${parts[1].padLeft(2, '0')}${parts[0].padLeft(2, '0')}';
    }
    return date;
  }

  factory TraceRecord.fromApi(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'] as List<dynamic>? ?? const [];
    return TraceRecord(
      batch: ProductBatch.fromApi(json),
      ingredients: [
        for (var i = 0; i < rawIngredients.length; i++)
          if (rawIngredients[i] is Map<String, dynamic>)
            Ingredient.fromApi(rawIngredients[i] as Map<String, dynamic>, i),
      ],
      integrity: IntegrityRecord.fromApi(
        json['integrity'] as Map<String, dynamic>?,
      ),
      batchEvents: [
        for (final raw in json['batchEvents'] as List<dynamic>? ?? const [])
          if (raw is Map<String, dynamic>) ProcessEvent.fromApi(raw),
      ],
      media: _mediaOf(json),
      ratings: RatingSummary.fromApi(json['ratings'] as Map<String, dynamic>?),
    );
  }
}

/// Một dòng trong danh sách lô ở Management.
/// Một trang danh sách lô kèm số liệu để dựng thanh phân trang.
class BatchPage {
  const BatchPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  const BatchPage.empty() : items = const [], total = 0, page = 1, pages = 1;

  final List<Map<String, dynamic>> items;
  final int total;
  final int page;
  final int pages;
}

class BatchListItem {
  const BatchListItem({
    required this.code,
    required this.name,
    required this.status,
    this.productionDate = '',
    this.createdAt = '',
    this.ingredientCount = 0,
    this.eventCount = 0,
    this.version,
    this.productName = '',
    this.productSku = '',
  });

  final String code;
  final String name;
  final String status;
  final String productionDate;

  /// Ngày tạo bản ghi, ISO từ D1. Khác ngày sản xuất do người vận hành nhập.
  final String createdAt;
  final int ingredientCount;
  final int eventCount;
  final int? version;
  final String productName;
  final String productSku;

  /// dd.MM.yyyy cho dễ đọc; chuỗi lạ thì trả nguyên văn còn hơn trả rỗng.
  String get createdLabel {
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return createdAt;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year}';
  }

  bool get isPublished => status.toUpperCase() == 'PUBLISHED';

  factory BatchListItem.fromApi(Map<String, dynamic> json) => BatchListItem(
    code: _str(json, ['code']),
    name: _str(json, ['name'], or: 'Lô chưa đặt tên'),
    status: _str(json, ['status'], or: 'DRAFT'),
    productionDate: _str(json, ['production_date', 'productionDate']),
    createdAt: _str(json, ['created_at', 'createdAt']),
    ingredientCount: json['ingredientCount'] as int? ?? 0,
    eventCount: json['eventCount'] as int? ?? 0,
    version: json['version'] as int?,
    productName: _str(json, ['product_name', 'productName']),
    productSku: _str(json, ['product_sku', 'productSku']),
  );
}

/// Người đang đăng nhập màn quản trị, kèm bảng quyền do worker trả về.
///
/// Giao diện không tự suy quyền từ vai trò: worker là nơi duy nhất chốt, còn
/// đây chỉ đọc lại để ẩn những nút mà bấm vào cũng bị từ chối. Ẩn nút là lịch
/// sự với người dùng, không phải lớp bảo vệ.
class AdminUser {
  const AdminUser({
    required this.username,
    required this.fullName,
    required this.role,
    required this.roleLabel,
    required this.facilityId,
    required this.facilityName,
    required this.viaToken,
    required this.permissions,
  });

  final String username;
  final String fullName;
  final String role;
  final String roleLabel;
  final int? facilityId;
  final String facilityName;
  final bool viaToken;
  final Map<String, bool> permissions;

  bool can(String permission) => permissions[permission] ?? false;

  /// Tên hiện trên thanh trên: họ tên nếu có, không thì tên đăng nhập.
  String get displayName => fullName.isNotEmpty ? fullName : username;

  factory AdminUser.fromApi(Map<String, dynamic> json) {
    final raw = json['permissions'];
    return AdminUser(
      username: '${json['username'] ?? ''}',
      fullName: '${json['fullName'] ?? ''}',
      role: '${json['role'] ?? ''}',
      roleLabel: '${json['roleLabel'] ?? ''}',
      facilityId: (json['facilityId'] as num?)?.toInt(),
      facilityName: '${json['facilityName'] ?? ''}',
      viaToken: json['viaToken'] == true,
      permissions: {
        if (raw is Map)
          for (final entry in raw.entries)
            '${entry.key}': entry.value == true,
      },
    );
  }
}

/// Một tài khoản trong danh sách quản lý người dùng.
class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.active,
    required this.facilityId,
    required this.facilityName,
    required this.lastLoginAt,
  });

  final int id;
  final String username;
  final String fullName;
  final String role;
  final bool active;
  final int? facilityId;
  final String facilityName;
  final String lastLoginAt;

  factory AdminAccount.fromApi(Map<String, dynamic> json) => AdminAccount(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: '${json['username'] ?? ''}',
    fullName: '${json['fullName'] ?? ''}',
    role: '${json['role'] ?? ''}',
    active: (json['active'] as num?)?.toInt() == 1 || json['active'] == true,
    facilityId: (json['facilityId'] as num?)?.toInt(),
    facilityName: '${json['facilityName'] ?? ''}',
    lastLoginAt: '${json['lastLoginAt'] ?? ''}',
  );
}

/// Một dòng nhật ký thao tác.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.action,
    required this.target,
    required this.detail,
    required this.createdAt,
  });

  final int id;
  final String username;
  final String fullName;
  final String role;
  final String action;
  final String target;
  final String detail;
  final String createdAt;

  factory AuditEntry.fromApi(Map<String, dynamic> json) => AuditEntry(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: '${json['username'] ?? ''}',
    fullName: '${json['fullName'] ?? ''}',
    role: '${json['role'] ?? ''}',
    action: '${json['action'] ?? ''}',
    target: '${json['target'] ?? ''}',
    detail: '${json['detail'] ?? ''}',
    createdAt: '${json['createdAt'] ?? ''}',
  );

  /// Nhãn tiếng Việt của việc đã làm. Nhật ký để người đọc, không để máy đọc.
  String get actionLabel => switch (action) {
    'LOGIN' => 'Đăng nhập',
    'CREATE_USER' => 'Tạo tài khoản',
    'UPDATE_USER' => 'Sửa tài khoản',
    'CHANGE_PASSWORD' => 'Đổi mật khẩu',
    'CREATE_PRODUCT' => 'Thêm sản phẩm',
    'CREATE_BATCH' => 'Tạo lô',
    'UPDATE_BATCH' => 'Sửa lô',
    'PUBLISH' => 'Công bố lô',
    'CREATE_INGREDIENT' => 'Thêm nguyên liệu',
    'UPDATE_INGREDIENT' => 'Sửa nguyên liệu',
    'DELETE_INGREDIENT' => 'Xoá nguyên liệu',
    'CREATE_EVENT' => 'Khai công đoạn',
    'UPDATE_EVENT' => 'Sửa công đoạn',
    'DELETE_EVENT' => 'Xoá công đoạn',
    'UPLOAD_MEDIA' => 'Tải ảnh/tài liệu',
    'DELETE_MEDIA' => 'Xoá ảnh/tài liệu',
    'CHAIN_SEND' => 'Gửi lên blockchain',
    'CHAIN_RETRY' => 'Thử lại hàng chờ',
    'DELETE_RATINGS' => 'Xoá đánh giá',
    _ => action,
  };
}

/// Lượt mở hồ sơ của một lô. Hệ thống tự đếm, không kèm thông tin người xem.
class BatchViews {
  const BatchViews({
    required this.code,
    required this.name,
    required this.views,
    required this.firstAt,
    required this.lastAt,
  });

  factory BatchViews.fromApi(Map<String, dynamic> json) => BatchViews(
    code: (json['code'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    views: (json['views'] as num?)?.toInt() ?? 0,
    firstAt: (json['firstAt'] ?? '').toString(),
    lastAt: (json['lastAt'] ?? '').toString(),
  );

  final String code;
  final String name;
  final int views;
  final String firstAt;
  final String lastAt;
}

/// Chỉ số do cơ sở sản xuất khai. Luôn đi kèm nguồn: một con số không nói được
/// nó lấy ở đâu thì không dùng cho báo cáo được.
class ReportedMetric {
  const ReportedMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.source,
    required this.note,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory ReportedMetric.fromApi(Map<String, dynamic> json) => ReportedMetric(
    key: (json['key'] ?? '').toString(),
    label: (json['label'] ?? '').toString(),
    value: (json['value'] ?? '').toString(),
    source: (json['source'] ?? '').toString(),
    note: (json['note'] ?? '').toString(),
    updatedAt: (json['updatedAt'] ?? '').toString(),
    updatedBy: (json['updatedBy'] ?? '').toString(),
  );

  final String key;
  final String label;
  final String value;
  final String source;
  final String note;
  final String updatedAt;
  final String updatedBy;
}

/// Hai nửa của trang Chỉ số: nửa hệ thống đo được và nửa phải hỏi cơ sở.
class MetricsReport {
  const MetricsReport({
    required this.totalViews,
    required this.byBatch,
    required this.reported,
  });

  factory MetricsReport.fromApi(Map<String, dynamic> json) {
    final views = json['views'];
    final list = views is Map<String, dynamic> ? views['byBatch'] : null;
    return MetricsReport(
      totalViews: views is Map<String, dynamic>
          ? (views['total'] as num?)?.toInt() ?? 0
          : 0,
      byBatch: [
        if (list is List)
          for (final item in list)
            if (item is Map<String, dynamic>) BatchViews.fromApi(item),
      ],
      reported: [
        if (json['reported'] is List)
          for (final item in json['reported'] as List)
            if (item is Map<String, dynamic>) ReportedMetric.fromApi(item),
      ],
    );
  }

  final int totalViews;
  final List<BatchViews> byBatch;
  final List<ReportedMetric> reported;
}

/// Bảng chỉ số công khai, đúng theo bảng trong báo cáo đề tài.
///
/// [counted] là phần hệ thống tự đếm, [reported] là phần cơ sở sản xuất khai.
/// Giao diện phải giữ nguyên ranh giới đó: một con số do người khai mà trình
/// bày như số máy đo được thì cả bảng mất giá trị làm bằng chứng.
class PublicMetrics {
  const PublicMetrics({
    required this.facilities,
    required this.products,
    required this.batches,
    required this.finishedBatches,
    required this.ingredientBatches,
    required this.anchored,
    required this.ratings,
    required this.average,
    required this.views,
    required this.reported,
  });

  factory PublicMetrics.fromApi(Map<String, dynamic> json) {
    final counted = json['counted'];
    int number(String key) => counted is Map<String, dynamic>
        ? (counted[key] as num?)?.toInt() ?? 0
        : 0;
    return PublicMetrics(
      facilities: number('facilities'),
      products: number('products'),
      batches: number('batches'),
      finishedBatches: number('finishedBatches'),
      ingredientBatches: number('ingredientBatches'),
      anchored: number('anchored'),
      ratings: number('ratings'),
      average: counted is Map<String, dynamic>
          ? (counted['average'] as num?)?.toDouble() ?? 0
          : 0,
      views: number('views'),
      reported: [
        if (json['reported'] is List)
          for (final item in json['reported'] as List)
            if (item is Map<String, dynamic>) ReportedMetric.fromApi(item),
      ],
    );
  }

  final int facilities;
  final int products;
  final int batches;
  final int finishedBatches;
  final int ingredientBatches;
  final int anchored;
  final int ratings;
  final double average;
  final int views;
  final List<ReportedMetric> reported;
}
