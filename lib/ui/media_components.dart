import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:video_player/video_player.dart';

import '../data/trace_api.dart';
import '../models/trace_models.dart';
import 'shared_components.dart';

/// Ảnh lấy từ R2 qua worker. Có khung chờ và khung lỗi riêng vì ảnh hỏng mà
/// hiện ô trống thì người xem không biết là chưa tải hay là không có.
class MediaImage extends StatelessWidget {
  const MediaImage({
    required this.asset,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
    super.key,
  });

  final MediaAsset asset;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: Image.network(
      TraceApi.mediaUrl(asset.url),
      fit: fit,
      semanticLabel: asset.caption.isEmpty ? asset.fileName : asset.caption,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: const Color(0xFFEDEBE1),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (context, _, _) => Container(
        color: const Color(0xFFEDEBE1),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: brandMuted),
      ),
    ),
  );
}

/// Ô vuông đại diện cho một media trong dải xem nhanh.
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    required this.asset,
    required this.onTap,
    this.size = 104,
    this.onRemove,
    super.key,
  });

  final MediaAsset asset;
  final VoidCallback onTap;
  final double size;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: _semantics,
    excludeSemantics: true,
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: const Color(0xFFEDEBE1),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: switch (asset.kind) {
                MediaKind.image => MediaImage(asset: asset, borderRadius: 0),
                MediaKind.video => const _KindPlaceholder(
                  icon: Icons.play_circle_outline,
                  label: 'Video',
                ),
                MediaKind.document => const _KindPlaceholder(
                  icon: Icons.description_outlined,
                  label: 'Tài liệu',
                ),
              },
            ),
          ),
          if (asset.kind == MediaKind.video)
            const IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white70,
                  size: 34,
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Xoá file này',
                  iconSize: 14,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  String get _semantics {
    final kind = switch (asset.kind) {
      MediaKind.image => 'Ảnh',
      MediaKind.video => 'Video',
      MediaKind.document => 'Tài liệu',
    };
    final name = asset.caption.isEmpty ? asset.fileName : asset.caption;
    return '$kind $name. Mở để xem lớn.';
  }
}

class _KindPlaceholder extends StatelessWidget {
  const _KindPlaceholder({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE4EAD9),
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: componentInk, size: 26),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: componentInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Dải media cuộn ngang. Rỗng thì không chiếm chỗ.
class MediaStrip extends StatelessWidget {
  const MediaStrip({
    required this.assets,
    this.title,
    this.onRemove,
    this.thumbSize = 104,
    super.key,
  });

  final List<MediaAsset> assets;
  final String? title;
  final void Function(MediaAsset asset)? onRemove;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: componentInk,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: thumbSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: assets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => MediaThumb(
              asset: assets[index],
              size: thumbSize,
              onTap: () => MediaViewer.show(context, assets, index),
              onRemove: onRemove == null
                  ? null
                  : () => onRemove!(assets[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Danh sách hồ sơ kiểm nghiệm. PDF mở tab mới vì trình duyệt đọc tốt hơn
/// bất kỳ trình xem nào nhúng trong Flutter web.
/// Loại giấy chứng nhận hay gặp của một cơ sở chế biến nông sản.
const certificateTypes = <String>[
  'OCOP',
  'VietGAP',
  'ATTP',
  'HACCP',
  'ISO 22000',
  'Hữu cơ',
  'Khác',
];

/// Thông tin nhập kèm khi tải một giấy chứng nhận.
typedef CertificateValues = ({
  String type,
  String number,
  String validUntil,
  String caption,
});

/// Hỏi loại giấy, số hiệu và hạn hiệu lực trước khi tải lên.
///
/// Giấy chứng nhận khác phiếu kiểm nghiệm ở chỗ nó có hạn: một tem OCOP đã
/// hết hiệu lực mà vẫn hiện như đang còn là một tuyên bố sai với người mua.
class CertificateDialog extends StatefulWidget {
  const CertificateDialog({super.key});

  static Future<CertificateValues?> show(BuildContext context) =>
      showDialog<CertificateValues>(
        context: context,
        builder: (_) => const CertificateDialog(),
      );

  @override
  State<CertificateDialog> createState() => _CertificateDialogState();
}

class _CertificateDialogState extends State<CertificateDialog> {
  final formKey = GlobalKey<FormState>();
  final number = TextEditingController();
  final caption = TextEditingController();
  final validUntil = TextEditingController();
  String type = certificateTypes.first;

  @override
  void dispose() {
    number.dispose();
    caption.dispose();
    validUntil.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      type: type,
      number: number.text.trim(),
      validUntil: validUntil.text.trim(),
      caption: caption.text.trim().isEmpty
          ? 'Giấy chứng nhận $type'
          : caption.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Giấy chứng nhận'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Loại giấy'),
              items: [
                for (final item in certificateTypes)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: (value) =>
                  setState(() => type = value ?? certificateTypes.first),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: number,
              decoration: const InputDecoration(
                labelText: 'Số hiệu',
                hintText: 'Ghi đúng như trên giấy',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: validUntil,
              decoration: const InputDecoration(
                labelText: 'Có hiệu lực đến',
                hintText: 'dd/mm/yyyy',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: caption,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                hintText: 'Để trống thì lấy theo loại giấy',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Huỷ'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Tải lên')),
    ],
  );
}

/// Danh sách giấy chứng nhận của một lô.
class CertificateList extends StatelessWidget {
  const CertificateList({required this.assets, this.onRemove, super.key});

  final List<MediaAsset> assets;
  final void Function(MediaAsset asset)? onRemove;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final asset in assets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: brandSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: brandLine),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    color: brandOrangeText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.certLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: componentInk,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (asset.validUntil.isNotEmpty)
                              'hiệu lực đến ${asset.validUntil}',
                            asset.fileName,
                            asset.readableSize,
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: brandMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => openMedia(asset),
                    child: const Text('Mở'),
                  ),
                  if (onRemove != null)
                    IconButton(
                      tooltip: 'Xoá giấy chứng nhận',
                      onPressed: () => onRemove!(asset),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Ảnh vùng nguyên liệu trong màn quản trị: xem nhanh và gỡ ra được.
class AreaMapPreview extends StatelessWidget {
  const AreaMapPreview({required this.asset, this.onRemove, super.key});

  final MediaAsset asset;
  final void Function(MediaAsset asset)? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: brandSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: brandLine),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: MediaImage(asset: asset, fit: BoxFit.cover),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              const Icon(Icons.map_outlined, size: 18, color: brandOrangeText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  asset.caption.isEmpty
                      ? 'Ảnh vùng nguyên liệu'
                      : asset.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: componentInk,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Xoá ảnh vùng',
                  onPressed: () => onRemove!(asset),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class LabReportList extends StatelessWidget {
  const LabReportList({required this.assets, this.onRemove, super.key});

  final List<MediaAsset> assets;
  final void Function(MediaAsset asset)? onRemove;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final asset in assets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: brandSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: brandLine),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Phiếu kiểm nghiệm là ảnh thì hiện thẳng ra. Bắt người xem
                  // bấm một lần nữa mới thấy tức là giấu đúng thứ họ vào đây
                  // để xem.
                  if (asset.kind == MediaKind.image)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: MediaImage(asset: asset, fit: BoxFit.contain),
                    ),
                  _ReportRow(asset: asset, onRemove: onRemove),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Dòng tên và nút mở của một hồ sơ.
class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.asset, this.onRemove});

  final MediaAsset asset;
  final void Function(MediaAsset asset)? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Builder(
              builder: (context) => Row(
                children: [
                  Icon(
                    asset.kind == MediaKind.document
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    color: brandOrangeText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // Không có chú thích thì đặt tên theo loại hồ sơ,
                          // đừng lặp lại tên file ở cả hai dòng.
                          asset.caption.isEmpty
                              ? 'Phiếu kiểm nghiệm'
                              : asset.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: componentInk,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${asset.fileName}  ·  ${asset.readableSize}',
                          style: const TextStyle(
                            color: brandMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => openMedia(asset),
                    child: Text(
                      asset.kind == MediaKind.document ? 'Mở' : 'Xem cỡ đầy đủ',
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      tooltip: 'Xoá hồ sơ',
                      onPressed: () => onRemove!(asset),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                ],
              ),
            ),
          );
  }
}

Future<void> openMedia(MediaAsset asset) => launchUrlString(
  TraceApi.mediaUrl(asset.url),
  mode: LaunchMode.externalApplication,
);

/// Trình xem toàn màn hình: ảnh phóng to được, video phát tại chỗ,
/// tài liệu chuyển sang tab mới.
class MediaViewer extends StatefulWidget {
  const MediaViewer({required this.assets, required this.initialIndex, super.key});

  final List<MediaAsset> assets;
  final int initialIndex;

  static Future<void> show(
    BuildContext context,
    List<MediaAsset> assets,
    int index,
  ) {
    if (assets[index].kind == MediaKind.document) return openMedia(assets[index]);
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => MediaViewer(assets: assets, initialIndex: index),
    );
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int index = widget.initialIndex;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.assets[index];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  asset.caption.isEmpty ? asset.fileName : asset.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mở file gốc',
                onPressed: () => openMedia(asset),
                icon: const Icon(Icons.open_in_new, color: Colors.white70),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 640),
              child: PageView.builder(
                controller: controller,
                itemCount: widget.assets.length,
                onPageChanged: (value) => setState(() => index = value),
                itemBuilder: (context, i) {
                  final item = widget.assets[i];
                  return item.kind == MediaKind.video
                      ? _VideoPane(asset: item)
                      : InteractiveViewer(
                          maxScale: 4,
                          child: MediaImage(
                            asset: item,
                            fit: BoxFit.contain,
                            borderRadius: 16,
                          ),
                        );
                },
              ),
            ),
          ),
          if (widget.assets.length > 1) ...[
            const SizedBox(height: 10),
            Text(
              '${index + 1} / ${widget.assets.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoPane extends StatefulWidget {
  const _VideoPane({required this.asset});
  final MediaAsset asset;

  @override
  State<_VideoPane> createState() => _VideoPaneState();
}

class _VideoPaneState extends State<_VideoPane> {
  late final VideoPlayerController controller;
  bool ready = false;
  String? error;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(
      Uri.parse(TraceApi.mediaUrl(widget.asset.url)),
    );
    controller
        .initialize()
        .then((_) {
          if (mounted) setState(() => ready = true);
        })
        .catchError((Object _) {
          if (mounted) {
            setState(() => error = 'Không phát được video trong trình duyệt này.');
          }
        });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => openMedia(widget.asset),
              child: const Text('Mở file gốc'),
            ),
          ],
        ),
      );
    }
    if (!ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(controller),
            VideoProgressIndicator(controller, allowScrubbing: true),
            Center(
              child: IconButton(
                iconSize: 54,
                tooltip: controller.value.isPlaying ? 'Tạm dừng' : 'Phát',
                onPressed: () => setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                }),
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
