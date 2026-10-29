import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data/trace_api.dart';
import '../models/trace_models.dart';
import 'explorer_chrome.dart';
import 'shared_components.dart';

/// Trang chủ lúc chưa tra cứu lô nào.
///
/// Bản trước mở ra là vào thẳng dòng Tú Lệ Smart Breakfast, vì hồi đó hệ thống
/// chỉ có mỗi dòng ấy. Giờ đã có ba cơ sở và còn nhận thêm, nên mặc định đứng
/// về một mặt hàng là nói sai về chính mình.
///
/// Danh sách đọc từ danh mục đang chạy chứ không viết cứng trong mã: thêm một
/// dòng sản phẩm vào hệ thống là trang chủ có thêm một thẻ.
class LandingSection extends StatelessWidget {
  const LandingSection({required this.products, this.onOpenCode, super.key});

  final List<PublicProduct> products;
  final void Function(String code)? onOpenCode;

  /// Số thẻ một hàng. Ảnh sản phẩm là thứ người xem nhận ra trước chữ, nên
  /// thà ít cột mà ảnh lớn còn hơn nhồi cho kín bề ngang.
  static int _columns(double width) {
    if (width < 640) return 1;
    if (width < 1040) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = _columns(constraints.maxWidth);
      final compact = columns == 1;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: compact ? 14 : 26),
          Text(
            'Mỗi lô hàng một hồ sơ riêng',
            style: compact
                ? pageTitleStyle
                : displayTitleStyle.copyWith(fontSize: 38, height: 1.15),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: const Text(
              'Quét mã QR trên bao bì hoặc nhập mã lô để xem lô đó làm từ gì, '
              'qua những công đoạn nào.',
              style: TextStyle(fontSize: 16, color: brandMuted, height: 1.6),
            ),
          ),
          SizedBox(height: compact ? 30 : 44),
          Text('Sản phẩm trên hệ thống', style: sectionTitleStyle),
          const SizedBox(height: 16),
          _Grid(
            columns: columns,
            children: [
              for (final product in products)
                _ProductCard(product: product, onOpenCode: onOpenCode),
            ],
          ),
          SizedBox(height: compact ? 30 : 44),
          _ServiceBand(compact: compact),
        ],
      );
    },
  );
}

/// Lưới thẻ chia theo số cột cho trước, hàng cuối thiếu thì chừa chỗ trống
/// chứ không giãn thẻ ra cho đầy hàng.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  static const _gap = 18.0;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final end = (start + columns).clamp(0, children.length);
      final row = children.sublist(start, end);
      rows.add(
        // Căng cho các thẻ cùng một hàng cao bằng nhau: dòng có nhiều lô hơn
        // thì thẻ dài hơn, để nguyên thì đáy hàng răng cưa.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < columns; index++) ...[
                if (index > 0) const SizedBox(width: _gap),
                Expanded(
                  child: index < row.length ? row[index] : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
      );
      if (end < children.length) rows.add(const SizedBox(height: _gap));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Một dòng sản phẩm: ảnh lô mới nhất, tên, rồi các mã lô.
///
/// Mã lô để ngay trên thẻ chứ không giấu sau một trang trung gian: người vào
/// trang này phần lớn đang cầm một gói hàng, họ cần đúng một cú bấm tới hồ sơ.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, this.onOpenCode});

  final PublicProduct product;
  final void Function(String code)? onOpenCode;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: brandSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: brandLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: product.cover.isEmpty
              ? const ColoredBox(color: componentCream)
              : Image.network(
                  TraceApi.mediaUrl(product.cover),
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) =>
                      const ColoredBox(color: componentCream),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: componentInk,
                  height: 1.3,
                ),
              ),
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
          ),
        ),
      ],
    ),
  );
}

class _LotChip extends StatelessWidget {
  const _LotChip({required this.batch, this.onTap});

  final BatchRef batch;
  final void Function(String code)? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: componentCream,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onTap == null ? null : () => onTap!(batch.code),
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Text(batch.code, style: monoStyle.copyWith(fontSize: 12.5)),
      ),
    ),
  );
}

/// Lời mời cơ sở khác đưa hàng lên hệ thống.
///
/// Chỉ một câu: ai đọc tới đây đã xem ba dòng sản phẩm ở trên rồi, họ cần biết
/// mình liên hệ ai chứ không cần nghe giảng lại hệ thống làm được gì.
class _ServiceBand extends StatelessWidget {
  const _ServiceBand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đưa sản phẩm của bạn lên hệ thống',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: componentInk,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Các dòng sản phẩm ở trên thuộc những cơ sở khác nhau, chạy chung '
          'một hệ thống. Cơ sở muốn truy xuất cho sản phẩm của mình đăng ký '
          'để được cấp tài khoản khai báo riêng.',
          style: TextStyle(fontSize: 15, color: brandMuted, height: 1.65),
        ),
      ],
    );

    final button = FilledButton(
      onPressed: () =>
          launchUrlString('$landingUrl/lien-he', webOnlyWindowName: '_blank'),
      child: const Text('Liên hệ đăng ký'),
    );

    return Container(
      padding: EdgeInsets.all(compact ? 20 : 30),
      decoration: BoxDecoration(
        color: brandPanel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [words, const SizedBox(height: 18), button],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: words),
                const SizedBox(width: 32),
                button,
              ],
            ),
    );
  }
}
