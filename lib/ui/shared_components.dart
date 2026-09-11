import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data/geo_lookup.dart' show foldVietnamese;
import '../models/trace_models.dart';
import 'tule_theme.dart';

export 'tule_theme.dart';

/// Khung ngoài chung cho cả hai trải nghiệm web.
class TuleWebFrame extends StatelessWidget {
  const TuleWebFrame({required this.child, this.ground, super.key});

  final Widget child;

  /// Nền của cả trang. Trang truy xuất truyền dải xanh tự nhiên; màn quản trị
  /// bỏ trống để dùng nền kem như cũ.
  final Gradient? ground;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: componentCream,
    body: SafeArea(
      child: ground == null
          ? child
          // Phải phủ hết khung nhìn, không chỉ phần có nội dung: trang ngắn thì
          // nửa dưới lộ nền kem của Scaffold, nhìn như hai trang dán vào nhau.
          : SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: ground),
                child: child,
              ),
            ),
    ),
  );
}

class TuleBrand extends StatelessWidget {
  const TuleBrand({this.inverse = false, this.onTap, super.key});
  final bool inverse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Dùng đúng logo của trang giới thiệu. Hai trang cùng một thương hiệu mà
    // mỗi trang một dấu hiệu nhận diện thì người quét mã không biết mình vừa
    // đi sang đâu.
    final mark = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/logo-mark.png',
          // 40px, bằng đúng `.logo .mark` bên trang giới thiệu.
          width: 40,
          height: 40,
          errorBuilder: (_, _, _) => Icon(
            Icons.spa_rounded,
            size: 30,
            color: inverse ? componentLeaf : componentInk,
          ),
        ),
        const SizedBox(width: 10),
        // Khoá bề ngang phần chữ: khối này nằm trong thanh bên rộng 248px của
        // màn quản trị, để tự do là tràn ra ngoài. Bọc Flexible để trên màn
        // hẹp nó còn co lại được thay vì đẩy cả hàng tràn.
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tú Lệ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.15,
                    letterSpacing: -.32,
                    color: inverse ? Colors.white : landingInk,
                  ),
                ),
                Text(
                  'SMART BREAKFAST',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    letterSpacing: 1.54,
                    color: inverse ? componentLeaf : landingInk3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Semantics(
      label: 'Tú Lệ Trace, trang chủ',
      button: onTap != null,
      child: onTap == null
          ? mark
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: mark,
              ),
            ),
    );
  }
}

/// Huy hiệu trạng thái. Bản cũ chỉ có hai màu xanh/cam; giờ tách riêng
/// trạng thái sai lệch dữ liệu vì đó là tín hiệu quan trọng nhất của sản phẩm.
enum BadgeTone { positive, pending, danger, neutral }

class IntegrityBadge extends StatelessWidget {
  const IntegrityBadge({
    required this.label,
    this.tone = BadgeTone.positive,
    this.icon,
    this.semanticsLabel,
    super.key,
  });

  /// Giữ API cũ `pending: true` cho các chỗ gọi đơn giản.
  factory IntegrityBadge.pending(String label) =>
      IntegrityBadge(label: label, tone: BadgeTone.pending);

  final String label;
  final BadgeTone tone;
  final IconData? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, fallbackIcon) = switch (tone) {
      BadgeTone.positive => (
        const Color(0xFFE5F1E4),
        componentInk,
        Icons.check_circle_rounded,
      ),
      BadgeTone.pending => (
        const Color(0xFFFFF0E3),
        brandOrangeText,
        Icons.schedule_rounded,
      ),
      BadgeTone.danger => (
        const Color(0xFFFBE6E4),
        const Color(0xFF7A1F19),
        Icons.report_problem_rounded,
      ),
      BadgeTone.neutral => (
        const Color(0xFFEDEBE1),
        brandMuted,
        Icons.info_outline_rounded,
      ),
    };

    return Semantics(
      label: semanticsLabel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? fallbackIcon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ánh xạ trạng thái kiểm chứng sang huy hiệu, dùng chung explorer và admin.
IntegrityBadge integrityBadgeFor(IntegrityStatus status) => switch (status) {
  IntegrityStatus.verified => const IntegrityBadge(
    label: 'DỮ LIỆU KHỚP',
    tone: BadgeTone.positive,
    semanticsLabel: 'Dữ liệu hiện tại khớp với bản đã công bố',
  ),
  IntegrityStatus.mismatch => const IntegrityBadge(
    label: 'DỮ LIỆU SAI LỆCH',
    tone: BadgeTone.danger,
    semanticsLabel: 'Dữ liệu đã bị thay đổi so với bản công bố',
  ),
  IntegrityStatus.notPublished => const IntegrityBadge(
    label: 'ĐANG TẠO',
    tone: BadgeTone.pending,
    semanticsLabel: 'Lô đang tạo, chưa lưu bản nào',
  ),
  IntegrityStatus.unknown => const IntegrityBadge(
    label: 'CHƯA KIỂM CHỨNG',
    tone: BadgeTone.neutral,
  ),
};

class WorkspaceTab extends StatelessWidget {
  const WorkspaceTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      selected: active,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [const BoxShadow(color: Color(0x10000000), blurRadius: 8)]
                : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 17,
                      color: active ? componentInk : brandMuted,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? componentInk : brandMuted,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Hash dài 64 ký tự không đọc nổi trên điện thoại, nên hiện dạng rút gọn,
/// cho chọn được bằng chuột và có nút copy để đối chiếu ngoài hệ thống.
class CopyableHash extends StatelessWidget {
  const CopyableHash({
    required this.hash,
    this.label = 'SHA-256',
    this.dense = false,
    super.key,
  });

  final String hash;
  final String label;
  final bool dense;

  String get _short => hash.length >= 20
      ? '${hash.substring(0, 10)}…${hash.substring(hash.length - 10)}'
      : hash;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 6 : 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F2E8),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: brandLine),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
            color: brandMuted,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: SelectableText(
            _short,
            maxLines: 1,
            style: monoStyle.copyWith(fontSize: dense ? 12 : 13),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Sao chép hash đầy đủ',
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: hash));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã sao chép hash SHA-256.')),
            );
          },
          icon: const Icon(Icons.copy_rounded),
        ),
      ],
    ),
  );
}

/// Nhãn nhỏ + giá trị, dùng cho mã lô, ngày sản xuất, nhà cung cấp.
class InfoPill extends StatelessWidget {
  const InfoPill({
    required this.label,
    required this.value,
    this.selectable = false,
    super.key,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final text = value.isEmpty ? 'Chưa có' : value;
    final style = TextStyle(
      fontWeight: FontWeight.w700,
      color: value.isEmpty ? brandMuted : componentInk,
    );
    return Semantics(
      label: '$label: $text',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: brandMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 3),
          selectable
              ? SelectableText(text, style: style)
              : Text(text, style: style),
        ],
      ),
    );
  }
}

/// Một dòng nói mã băm đã nằm trên chuỗi nào, kèm liên kết tới giao dịch.
///
/// Chỉ hiện khi thật sự đã có giao dịch. Trạng thái chờ là chuyện nội bộ của
/// người vận hành, không phải thứ để khoe với khách quét mã.
class ChainLine extends StatelessWidget {
  const ChainLine({
    required this.chain,
    this.version,
    this.stale = false,
    this.dense = false,
    super.key,
  });

  final ChainRecord chain;

  /// Phiên bản đang nằm trên chuỗi. Có số thì nói rõ, vì khi dữ liệu hiện tại
  /// đã đổi thì thứ trên chuỗi là bản cũ chứ không phải bản đang xem.
  final int? version;

  /// True khi dữ liệu hiện tại khác bản đã neo.
  final bool stale;
  final bool dense;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(dense ? 10 : 12),
    decoration: BoxDecoration(
      color: brandPanel,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.link, size: 16, color: componentInk),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            stale
                ? 'Bản v${version ?? '?'} đã lưu lên blockchain, dữ liệu hiện tại khác bản đó'
                : 'Đã lưu lên blockchain${version == null ? '' : ' (bản v$version)'} · ${chain.shortTx}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: componentInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (chain.txUrl.isNotEmpty)
          TextButton(
            onPressed: () => launchUrlString(
              chain.txUrl,
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Xem giao dịch'),
          ),
      ],
    ),
  );
}

/// Ảnh của bốn nguyên liệu chính, khớp theo tên chứ không theo thứ tự.
///
/// Khớp theo thứ tự thì đổi chỗ nguyên liệu trong lô là ảnh nhảy lung tung.
/// Nguyên liệu ngoài danh sách này (admin thêm tay) không có ảnh, và đó là lý
/// do vẫn giữ đường rơi về icon.
const _ingredientImages = <String, String>{
  'com': 'assets/ingredients/com-tu-le.png',
  'lac': 'assets/ingredients/lac-do-luc-yen.png',
  'chuoi': 'assets/ingredients/chuoi-tieu-xanh.png',
  'khoai': 'assets/ingredients/khoai-mon-luc-yen.png',
};

String? ingredientImageFor(String name) {
  final folded = foldVietnamese(name);
  for (final entry in _ingredientImages.entries) {
    if (folded.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Ô vuông bo góc đựng ảnh nguyên liệu, dùng chung cho explorer và admin.
class IngredientAvatar extends StatelessWidget {
  const IngredientAvatar({
    required this.name,
    required this.icon,
    required this.color,
    this.size = 34,
    this.radius = 10,
    super.key,
  });

  final String name;
  final IconData icon;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final asset = ingredientImageFor(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: asset == null
          ? Icon(icon, color: color, size: size * .53)
          : Image.asset(
              asset,
              fit: BoxFit.cover,
              // Ảnh hỏng hoặc chưa nạp được thì vẫn phải có gì đó để nhìn.
              errorBuilder: (_, _, _) =>
                  Icon(icon, color: color, size: size * .53),
            ),
    );
  }
}
