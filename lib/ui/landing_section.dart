import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data/trace_api.dart';
import '../models/trace_models.dart';
import 'explorer_chrome.dart';
import 'journey_panel.dart';
import 'shared_components.dart';

/// Trang chủ lúc chưa tra cứu lô nào.
///
/// Bản trước mở ra là vào thẳng dòng Tú Lệ Smart Breakfast, vì hồi đó hệ thống
/// chỉ có mỗi dòng ấy. Giờ đã có ba cơ sở và còn nhận thêm, nên mặc định đứng
/// về một mặt hàng là nói sai về chính mình: đây là hệ thống dùng chung, không
/// phải trang của một sản phẩm.
///
/// Danh sách dưới đây đọc từ danh mục đang chạy chứ không viết cứng trong mã.
/// Thêm một dòng sản phẩm vào hệ thống là trang chủ có thêm một mục, không ai
/// phải nhớ ra để sửa trang này.
class LandingSection extends StatelessWidget {
  const LandingSection({
    required this.products,
    this.onOpenCode,
    super.key,
  });

  final List<PublicProduct> products;
  final void Function(String code)? onOpenCode;

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    final lots = products.fold<int>(0, (sum, item) => sum + item.batches.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const PanelEyebrow('Hệ thống truy xuất nguồn gốc'),
        const SizedBox(height: 10),
        Text(
          'Mỗi lô hàng một hồ sơ riêng',
          style: compact
              ? pageTitleStyle
              : displayTitleStyle.copyWith(fontSize: 34),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const Text(
            'Quét mã QR trên bao bì hoặc nhập mã lô vào ô phía trên để xem lô '
            'đó làm từ nguyên liệu nào, đi qua những công đoạn nào, và đối '
            'chiếu với bản ghi đã neo lên blockchain.',
            style: TextStyle(fontSize: 16, color: brandMuted, height: 1.6),
          ),
        ),
        const SizedBox(height: 34),
        _Heading(
          'Sản phẩm đang truy xuất trên hệ thống',
          products.isEmpty
              ? 'Đang đọc danh mục.'
              : '${products.length} dòng sản phẩm, $lots lô đã công bố. '
                    'Bấm một mã lô để mở hồ sơ của lô đó.',
        ),
        const SizedBox(height: 16),
        for (final product in products) ...[
          _ProductRow(
            product: product,
            compact: compact,
            onOpenCode: onOpenCode,
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 22),
        _ServiceCard(compact: compact),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.caption);
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: sectionTitleStyle),
      const SizedBox(height: 6),
      Text(caption, style: sectionCaptionStyle),
    ],
  );
}

/// Một dòng sản phẩm: ảnh lô mới nhất, mô tả, rồi các mã lô.
///
/// Mã lô để ngay đây chứ không giấu sau một trang trung gian: người vào trang
/// này phần lớn đang cầm một gói hàng, họ cần đúng một cú bấm để tới hồ sơ.
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.compact,
    this.onOpenCode,
  });

  final PublicProduct product;
  final bool compact;
  final void Function(String code)? onOpenCode;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: sectionTitleStyle),
        if (product.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            product.description,
            style: const TextStyle(
              fontSize: 14,
              color: brandMuted,
              height: 1.55,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final batch in product.batches)
              _LotChip(batch: batch, onTap: onOpenCode),
          ],
        ),
      ],
    );

    final picture = _Cover(url: product.cover, size: compact ? 92 : 132);

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          picture,
          SizedBox(width: compact ? 12 : 18),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.size});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: componentCream,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.inventory_2_outlined, color: brandMuted),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        TraceApi.mediaUrl(url),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => Container(
          width: size,
          height: size,
          color: componentCream,
        ),
      ),
    );
  }
}

class _LotChip extends StatelessWidget {
  const _LotChip({required this.batch, this.onTap});
  final BatchRef batch;
  final void Function(String code)? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: componentCream,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap == null ? null : () => onTap!(batch.code),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(batch.code, style: monoStyle.copyWith(fontSize: 13)),
            if (batch.productionDate.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                batch.productionDate,
                style: const TextStyle(fontSize: 12, color: brandMuted),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Lời mời cơ sở khác đưa hàng lên hệ thống.
///
/// Chỉ kể đúng những thứ hệ thống đang làm được và người đọc kiểm lại được
/// ngay trên trang này. Không hứa gì về giá, thời gian triển khai hay chứng
/// nhận: những cái đó phải do người nhận đăng ký trả lời.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.compact});
  final bool compact;

  static const _points = <({IconData icon, String title, String body})>[
    (
      icon: Icons.qr_code_2,
      title: 'Mã QR riêng cho từng lô',
      body: 'In lên bao bì của chính lô đó. Người mua quét ra hồ sơ của mẻ họ '
          'đang cầm, không phải một trang giới thiệu chung.',
    ),
    (
      icon: Icons.account_tree_outlined,
      title: 'Hồ sơ theo công đoạn',
      body: 'Khai nguyên liệu đầu vào và từng bước chế biến kèm khối lượng vào '
          'ra, người thực hiện và ảnh chụp tại chỗ.',
    ),
    (
      icon: Icons.verified_outlined,
      title: 'Neo lên blockchain',
      body: 'Lúc công bố, hệ thống băm toàn bộ hồ sơ rồi ghi mã băm lên mạng '
          'VBSN. Sửa lại dữ liệu sau đó là trang truy xuất báo sai lệch ngay.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 18 : 26),
    decoration: BoxDecoration(
      color: brandPanel,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelEyebrow('Dành cho cơ sở sản xuất'),
        const SizedBox(height: 10),
        const Text(
          'Đưa sản phẩm của bạn lên hệ thống',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: componentInk,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: const Text(
            'Hệ thống này không gắn riêng với một mặt hàng nào. Ba dòng sản '
            'phẩm ở trên thuộc ba cơ sở khác nhau và chạy trên cùng một nền '
            'tảng. Cơ sở có nhu cầu truy xuất cho sản phẩm của mình đăng ký để '
            'được cấp tài khoản khai báo riêng.',
            style: TextStyle(fontSize: 15, color: brandMuted, height: 1.65),
          ),
        ),
        const SizedBox(height: 20),
        if (compact)
          for (final point in _points) ...[
            _Point(point: point),
            const SizedBox(height: 14),
          ]
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final point in _points) ...[
                Expanded(child: _Point(point: point)),
                if (point != _points.last) const SizedBox(width: 22),
              ],
            ],
          ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => launchUrlString(
            '$landingUrl/lien-he',
            webOnlyWindowName: '_blank',
          ),
          child: const Text('Liên hệ để đăng ký'),
        ),
      ],
    ),
  );
}

class _Point extends StatelessWidget {
  const _Point({required this.point});
  final ({IconData icon, String title, String body}) point;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(point.icon, size: 22, color: brandOrangeText),
      const SizedBox(height: 9),
      Text(
        point.title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: componentInk,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        point.body,
        style: const TextStyle(fontSize: 13.5, color: brandMuted, height: 1.6),
      ),
    ],
  );
}
