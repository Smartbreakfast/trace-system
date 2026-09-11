import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/image_shrink.dart';
import '../data/trace_api.dart';
import '../models/trace_models.dart';
import 'media_components.dart';
import 'shared_components.dart';

/// Đuôi file chấp nhận, khớp với danh sách trắng phía worker.
const _imageTypes = XTypeGroup(
  label: 'Ảnh',
  extensions: ['jpg', 'jpeg', 'png', 'webp', 'avif', 'gif'],
  mimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'image/avif', 'image/gif'],
);
const _videoTypes = XTypeGroup(
  label: 'Video',
  extensions: ['mp4', 'webm', 'mov'],
  mimeTypes: ['video/mp4', 'video/webm', 'video/quicktime'],
);
const _documentTypes = XTypeGroup(
  label: 'Hồ sơ kiểm nghiệm',
  extensions: ['pdf', 'jpg', 'jpeg', 'png'],
  mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
);

/// Trình duyệt không phải lúc nào cũng khai mimeType, nên suy từ đuôi file.
String _contentTypeOf(XFile file) {
  final declared = file.mimeType;
  if (declared != null && declared.contains('/')) return declared;
  final ext = file.name.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'avif' => 'image/avif',
    'gif' => 'image/gif',
    'mp4' => 'video/mp4',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

/// Khối quản lý media cho một chủ thể: lô, nguyên liệu hoặc công đoạn.
///
/// Hai nút "Thêm hồ sơ kiểm nghiệm" và "Thêm ảnh / video" trước đây chỉ hiện
/// snackbar mock; giờ tải thật lên R2 qua worker.
class MediaManager extends StatefulWidget {
  const MediaManager({
    required this.api,
    required this.ownerType,
    required this.ownerId,
    required this.assets,
    required this.onChanged,
    this.allowCover = false,
    this.allowLabReport = false,
    this.allowCertificate = false,
    this.allowAreaMap = false,
    this.title,
    this.compactStrip = false,
    super.key,
  });

  final TraceApi api;
  final String ownerType;
  final Object ownerId;
  final List<MediaAsset> assets;
  final Future<void> Function() onChanged;
  final bool allowCover;
  final bool allowLabReport;

  /// Giấy chứng nhận của cơ sở: OCOP, VietGAP, ATTP. Khác hồ sơ kiểm nghiệm
  /// ở chỗ có loại giấy, số hiệu và hạn hiệu lực riêng.
  final bool allowCertificate;

  /// Ảnh chụp vùng nguyên liệu, hiện thay cho bản đồ tương tác ở trang khách.
  final bool allowAreaMap;
  final String? title;
  final bool compactStrip;

  @override
  State<MediaManager> createState() => _MediaManagerState();
}

class _MediaManagerState extends State<MediaManager> {
  bool busy = false;

  List<MediaAsset> get _visual => widget.assets
      .where(
        (item) =>
            !item.isLabReport && !item.isCertificate && !item.isAreaMap,
      )
      .toList();

  MediaAsset? get _areaMap =>
      widget.assets.where((item) => item.isAreaMap).firstOrNull;

  List<MediaAsset> get _reports =>
      widget.assets.where((item) => item.isLabReport).toList();

  List<MediaAsset> get _certificates =>
      widget.assets.where((item) => item.isCertificate).toList();

  void _notify(String text, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: danger ? const Color(0xFF7A1F19) : null,
        ),
      );
  }

  Future<void> _pickAndUpload({
    required List<XTypeGroup> types,
    required String role,
  }) async {
    CertificateValues? cert;
    final file = await openFile(acceptedTypeGroups: types);
    if (file == null || !mounted) return;

    final original = await file.readAsBytes();
    if (!mounted) return;

    // Ảnh minh hoạ thu nhỏ trước khi gửi. Máy ảnh điện thoại cho ra file 4-8MB,
    // mà trang quét QR chỉ hiện nó rộng vài trăm pixel: gửi nguyên bản là bắt
    // người mua tải về gấp mười lần thứ họ thật sự nhìn thấy.
    //
    // Hồ sơ kiểm nghiệm và giấy chứng nhận thì giữ nguyên: người xem cần đọc
    // được chữ trên đó, nén xuống là mất chính thứ làm nó có giá trị.
    var bytes = original;
    var fileName = file.name;
    var contentType = _contentTypeOf(file);
    final recipe = _shrinkFor(role);
    if (recipe != null && contentType.startsWith('image/')) {
      final smaller = await shrinkImage(
        original,
        maxEdge: recipe.maxEdge,
        quality: recipe.quality,
      );
      if (smaller != null && smaller.lengthInBytes < original.lengthInBytes) {
        bytes = smaller;
        // Trình duyệt trả WebP khi mã hoá được, JPEG khi không, nên đọc đúng
        // mấy byte đầu thay vì đoán: worker kiểm tra nội dung có khớp kiểu
        // khai báo không, khai sai là bị chặn.
        final produced = _sniffImage(smaller) ?? 'image/jpeg';
        contentType = produced;
        final ext = produced == 'image/webp' ? 'webp' : 'jpg';
        final dot = fileName.lastIndexOf('.');
        fileName = '${dot > 0 ? fileName.substring(0, dot) : fileName}.$ext';
      }
      if (!mounted) return;
    }

    // Kiểm cỡ file ngay tại client để admin không phải chờ upload rồi mới biết.
    try {
      final config = await widget.api.mediaConfig();
      if (bytes.lengthInBytes > config.maxBytes) {
        _notify(
          'File $fileName nặng ${(bytes.lengthInBytes / 1048576).toStringAsFixed(1)}MB, '
          'vượt giới hạn ${(config.maxBytes / 1048576).round()}MB.',
          danger: true,
        );
        return;
      }
    } on TraceApiFailure {
      // Không lấy được cấu hình thì cứ thử tải, worker vẫn chặn nếu quá cỡ.
    }

    if (!mounted) return;

    // Giấy chứng nhận hỏi thêm loại giấy, số hiệu và hạn thay vì chỉ chú thích.
    String caption = '';
    if (role == 'certificate') {
      cert = await CertificateDialog.show(context);
      if (cert == null || !mounted) return;
      caption = cert.caption;
    } else {
      final entered = await _askCaption(file.name);
      if (entered == null || !mounted) return;
      caption = entered;
    }

    setState(() => busy = true);
    try {
      await widget.api.uploadMedia(
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
        role: role,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
        caption: caption,
        certType: cert?.type ?? '',
        certNumber: cert?.number ?? '',
        validUntil: cert?.validUntil ?? '',
      );
      await widget.onChanged();
      _notify(
        bytes.lengthInBytes < original.lengthInBytes
            // Nói ra con số để người vận hành thấy việc nén là có thật, và
            // biết ảnh trên trang khách nhẹ tới mức nào.
            ? 'Đã tải lên $fileName, nén từ ${_size(original.lengthInBytes)} '
                  'xuống ${_size(bytes.lengthInBytes)}.'
            : 'Đã tải lên $fileName.',
      );
    } on TraceApiFailure catch (error) {
      _notify(error.message, danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Nhận ra định dạng ảnh từ mấy byte đầu. Chỉ cần phân biệt WebP với JPEG,
  /// đó là hai thứ mà `tuleShrinkImage` có thể trả về.
  static String? _sniffImage(Uint8List bytes) {
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    return null;
  }

  /// Mức nén cho từng vai trò ảnh. Null nghĩa là giữ nguyên file gốc.
  ///
  /// Đo trên đúng bộ ảnh của lô TL-2026-002, cùng kích thước hiển thị:
  /// WebP nhỏ hơn JPEG khoảng 45%, còn ảnh PNG thì giảm hơn 90%. Chất lượng
  /// để cao hơn mức JPEG cũ một chút vì WebP ở cùng số vẫn nhẹ hơn.
  static ({int maxEdge, double quality})? _shrinkFor(String role) =>
      switch (role) {
        // Ảnh bìa là thứ hiện to nhất: rộng 660px trên desktop, nhân đôi trên
        // màn hình retina là 1320px. Dưới 1400 thì bắt đầu thấy mờ.
        'cover' => (maxEdge: 1400, quality: 0.82),
        // Ảnh bản đồ vùng có chữ và nét mảnh, nén mạnh là nhoè quanh chữ.
        'area_map' => (maxEdge: 1600, quality: 0.88),
        // Hồ sơ kiểm nghiệm và giấy chứng nhận phải đọc được từng dòng chữ.
        // 2000px vẫn đọc rõ khi phóng to trên điện thoại, và người cần soi kỹ
        // thì bấm "Xem cỡ đầy đủ" để mở file gốc.
        'lab_report' || 'certificate' => (maxEdge: 2000, quality: 0.86),
        // Ảnh minh hoạ và ảnh công đoạn hiện ở dải nhỏ, mở ra cũng chỉ vừa
        // màn hình điện thoại.
        _ => (maxEdge: 1280, quality: 0.8),
      };

  static String _size(int bytes) => bytes >= 1048576
      ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  Future<String?> _askCaption(String fileName) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chú thích cho file'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: const TextStyle(color: brandMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Chú thích',
                  hintText: 'Chú thích (không bắt buộc)',
                ),
                onSubmitted: (value) =>
                    Navigator.of(dialogContext).pop(value.trim()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Tải lên'),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(MediaAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá file'),
        content: Text(
          'Xoá "${asset.caption.isEmpty ? asset.fileName : asset.caption}" khỏi hồ sơ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true || asset.id == null) return;
    setState(() => busy = true);
    try {
      await widget.api.deleteMedia(asset.id!);
      await widget.onChanged();
      _notify('Đã xoá file khỏi hồ sơ.');
    } on TraceApiFailure catch (error) {
      _notify(error.message, danger: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = widget.assets.any((item) => item.isCover);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: componentInk,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_visual.isEmpty && _reports.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Chưa có ảnh, video hay hồ sơ nào.',
              style: TextStyle(color: brandMuted, fontSize: 13),
            ),
          ),
        if (_visual.isNotEmpty) ...[
          MediaStrip(
            assets: _visual,
            thumbSize: widget.compactStrip ? 80 : 104,
            onRemove: busy ? null : _remove,
          ),
          const SizedBox(height: 12),
        ],
        if (_reports.isNotEmpty) ...[
          LabReportList(assets: _reports, onRemove: busy ? null : _remove),
          const SizedBox(height: 4),
        ],
        if (_areaMap case final area?) ...[
          AreaMapPreview(asset: area, onRemove: busy ? null : _remove),
          const SizedBox(height: 12),
        ],
        if (_certificates.isNotEmpty) ...[
          CertificateList(
            assets: _certificates,
            onRemove: busy ? null : _remove,
          ),
          const SizedBox(height: 4),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => _pickAndUpload(
                      types: const [_imageTypes, _videoTypes],
                      role: 'gallery',
                    ),
              icon: const Icon(Icons.perm_media_outlined, size: 17),
              label: const Text('Thêm ảnh / video'),
            ),
            if (widget.allowCover)
              OutlinedButton.icon(
                onPressed: busy || hasCover
                    ? null
                    : () => _pickAndUpload(
                        types: const [_imageTypes],
                        role: 'cover',
                      ),
                icon: const Icon(Icons.image_outlined, size: 17),
                label: Text(hasCover ? 'Đã có ảnh bìa' : 'Đặt ảnh bìa'),
              ),
            if (widget.allowLabReport)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _pickAndUpload(
                        types: const [_documentTypes],
                        role: 'lab_report',
                      ),
                icon: const Icon(Icons.upload_file, size: 17),
                label: const Text('Thêm hồ sơ kiểm nghiệm'),
              ),
            if (widget.allowAreaMap)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _pickAndUpload(
                        types: const [_imageTypes],
                        role: 'area_map',
                      ),
                icon: const Icon(Icons.map_outlined, size: 17),
                label: Text(
                  _areaMap == null ? 'Ảnh vùng nguyên liệu' : 'Đổi ảnh vùng',
                ),
              ),
            if (widget.allowCertificate)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _pickAndUpload(
                        types: const [_documentTypes],
                        role: 'certificate',
                      ),
                icon: const Icon(Icons.workspace_premium_outlined, size: 17),
                label: const Text('Thêm giấy chứng nhận'),
              ),
            if (busy)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Đang xử lý file',
                    style: TextStyle(color: brandMuted, fontSize: 12.5),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
