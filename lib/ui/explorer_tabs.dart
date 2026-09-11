import 'package:flutter/material.dart';

import '../models/trace_models.dart';
import 'journey_panel.dart';
import 'media_components.dart';
import 'shared_components.dart';

/// Ba mục của hồ sơ, đúng cách khách hàng chia khi mô tả sản phẩm.
enum ExplorerTab { general, origin, quality }

extension ExplorerTabLabel on ExplorerTab {
  String get label => switch (this) {
    ExplorerTab.general => 'Thông tin chung',
    ExplorerTab.origin => 'Nguồn gốc',
    ExplorerTab.quality => 'Kiểm định chất lượng',
  };

  /// Nhãn ngắn cho màn hẹp, để ba mục nằm vừa một hàng thay vì phải kéo
  /// ngang mới thấy mục cuối.
  String get shortLabel => switch (this) {
    ExplorerTab.general => 'Thông tin',
    ExplorerTab.origin => 'Nguồn gốc',
    ExplorerTab.quality => 'Kiểm định',
  };

  IconData get icon => switch (this) {
    ExplorerTab.general => Icons.inventory_2_outlined,
    ExplorerTab.origin => Icons.account_tree_outlined,
    ExplorerTab.quality => Icons.verified_outlined,
  };
}

/// Thanh chuyển mục. Cuộn ngang được để trên điện thoại không phải cắt chữ.
class ExplorerTabBar extends StatelessWidget {
  const ExplorerTabBar({
    required this.value,
    required this.onChanged,
    this.qualityCount = 0,
    super.key,
  });

  final ExplorerTab value;
  final ValueChanged<ExplorerTab> onChanged;

  /// Số hồ sơ trong mục kiểm định, hiện thành một con số nhỏ cạnh nhãn.
  final int qualityCount;

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    final bar = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: brandSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: brandLine),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final tab in ExplorerTab.values)
            if (compact)
              // Màn hẹp chia đều ba phần: kéo ngang để tìm mục cuối là kiểu
              // giao diện chỉ người làm ra nó mới biết đường dùng.
              Expanded(
                child: _TabButton(
                  tab: tab,
                  compact: true,
                  active: tab == value,
                  badge: tab == ExplorerTab.quality && qualityCount > 0
                      ? '$qualityCount'
                      : null,
                  onTap: () => onChanged(tab),
                ),
              )
            else
              _TabButton(
                tab: tab,
                active: tab == value,
                badge: tab == ExplorerTab.quality && qualityCount > 0
                    ? '$qualityCount'
                    : null,
                onTap: () => onChanged(tab),
              ),
        ],
      ),
    );
    return compact
        ? bar
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: bar,
          );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.active,
    required this.onTap,
    this.badge,
    this.compact = false,
  });

  final ExplorerTab tab;
  final bool active;
  final VoidCallback onTap;
  final String? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: active ? componentInk : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.icon,
              size: 16,
              color: active ? Colors.white : brandMuted,
            ),
            SizedBox(width: compact ? 5 : 8),
            Flexible(
              child: Text(
                compact ? tab.shortLabel : tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  color: active ? Colors.white : brandMuted,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (badge case final text?) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: .22)
                      : const Color(0xFFEDEFE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : brandMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Mục "Thông tin chung": thứ người vừa quét mã QR nhìn thấy đầu tiên.
class GeneralInfoSection extends StatelessWidget {
  const GeneralInfoSection({required this.record, super.key});

  final TraceRecord record;

  /// Chiều cao khối trên desktop, dùng chung cho ảnh và thẻ thông tin.
  static const _wideHeight = 600.0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final batch = record.batch;
    final cover = record.cover;

    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: wide ? _wideHeight : 240,
        width: double.infinity,
        child: cover == null
            // Chưa có ảnh bìa thì dùng ảnh sản phẩm của thương hiệu, đỡ hơn
            // một ô xám: người mua vẫn nhận ra đúng dòng sản phẩm.
            ? Image.asset('assets/tule-products.jpg', fit: BoxFit.cover)
            : MediaImage(asset: cover, fit: BoxFit.cover),
      ),
    );

    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const PanelEyebrow('Sản phẩm'),
        const SizedBox(height: 8),
        Text(batch.name, style: displayTitleStyle.copyWith(fontSize: 28)),
        const SizedBox(height: 14),
        VerifiedCard(integrity: record.integrity),
        const SizedBox(height: 18),
        BatchFactRow(batch: batch),
        if (batch.description.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            batch.description,
            style: const TextStyle(
              color: componentInk,
              fontSize: 14.5,
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            if (batch.facilityName.isNotEmpty)
              InfoPill(label: 'NƠI SẢN XUẤT', value: batch.facilityName),
            InfoPill(
              label: 'THÀNH PHẦN',
              value: '${record.ingredients.length} nguyên liệu',
            ),
          ],
        ),
        if (record.gallery.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeading(title: 'Hình ảnh sản phẩm'),
          const SizedBox(height: 12),
          MediaStrip(assets: record.gallery, thumbSize: 96),
        ],
      ],
    );

    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brandSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brandLine),
      ),
      // Desktop khoá chiều cao bằng đúng ảnh bên trái, nội dung dài thì cuộn
      // bên trong. Dùng IntrinsicHeight cho việc này thì chữ xuống dòng làm
      // phép đo hụt vài pixel và cả hàng tràn.
      child: wide
          ? Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8),
                child: facts,
              ),
            )
          : facts,
    );

    return wide
        ? SizedBox(
            height: _wideHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 96, child: picture),
                const SizedBox(width: 20),
                Expanded(flex: 104, child: card),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [picture, const SizedBox(height: 16), card],
          );
  }
}

/// Mục "Kiểm định chất lượng": giấy chứng nhận và phiếu kiểm nghiệm.
class QualitySection extends StatelessWidget {
  const QualitySection({required this.record, super.key});

  final TraceRecord record;

  @override
  Widget build(BuildContext context) {
    final certificates = record.certificates;
    final reports = record.labReports;

    if (certificates.isEmpty && reports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: brandSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: brandLine),
        ),
        child: const Column(
          children: [
            Icon(Icons.verified_outlined, size: 34, color: brandMuted),
            SizedBox(height: 12),
            Text(
              'Chưa có giấy chứng nhận hay phiếu kiểm nghiệm.',
              textAlign: TextAlign.center,
              style: sectionCaptionStyle,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (certificates.isNotEmpty) ...[
          const SectionHeading(title: 'Giấy chứng nhận'),
          const SizedBox(height: 14),
          _DocGrid(items: certificates),
          if (reports.isNotEmpty) const SizedBox(height: 28),
        ],
        if (reports.isNotEmpty) ...[
          const SectionHeading(title: 'Phiếu kiểm nghiệm'),
          const SizedBox(height: 14),
          _DocGrid(items: reports),
        ],
      ],
    );
  }
}

/// Lưới thẻ tài liệu.
///
/// Cỡ thẻ do bề rộng màn quyết định, không do số tài liệu: một phiếu duy nhất
/// vẫn là một thẻ bằng một phần ba hàng, chứ không giãn ra full màn rồi để
/// tấm ảnh nằm chỏng chơ. Thêm tài liệu thì lưới tự lấp đầy.
class _DocGrid extends StatelessWidget {
  const _DocGrid({required this.items});

  final List<MediaAsset> items;

  static const _gap = 16.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 1000
          ? 3
          : width >= 620
          ? 2
          : 1;
      final card = (width - _gap * (columns - 1)) / columns;
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final item in items)
            SizedBox(width: card, child: _DocCard(asset: item)),
        ],
      );
    },
  );
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.asset});

  final MediaAsset asset;

  String get _title {
    if (asset.isCertificate) {
      return asset.certType.isEmpty ? 'Giấy chứng nhận' : asset.certType;
    }
    return asset.caption.isEmpty ? 'Phiếu kiểm nghiệm' : asset.caption;
  }

  /// Dòng phụ: thứ nào có thì hiện, không có thì thôi.
  String get _meta => [
    if (asset.isCertificate && asset.certNumber.isNotEmpty)
      'Số ${asset.certNumber}',
    if (asset.validUntil.isNotEmpty) 'Hiệu lực đến ${asset.validUntil}',
    if (asset.isCertificate && asset.caption.isNotEmpty) asset.caption,
  ].join('  ·  ');

  @override
  Widget build(BuildContext context) => Material(
    color: brandSurface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => openMedia(asset),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nền chìm phía sau ảnh: giấy tờ có tấm dọc tấm ngang, dùng
            // contain để không cắt mất góc nào của văn bản.
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                color: const Color(0xFFEDEFE9),
                child: asset.kind == MediaKind.image
                    ? MediaImage(asset: asset, fit: BoxFit.contain)
                    : const Center(
                        child: Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 40,
                          color: brandMuted,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        asset.isCertificate
                            ? Icons.workspace_premium_outlined
                            : Icons.science_outlined,
                        size: 18,
                        color: brandOrangeText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: componentInk,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: brandMuted, fontSize: 12.5),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Xem cỡ đầy đủ',
                        style: TextStyle(
                          color: brandOrangeText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: brandOrangeText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
