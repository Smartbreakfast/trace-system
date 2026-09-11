import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../models/trace_models.dart';
import 'shared_components.dart';

/// Khung ngoài của trang tra cứu: thanh trên, dải kiểm chứng và chân trang.

/// Địa chỉ trang giới thiệu. Đổi lúc build nếu tên miền thay đổi:
/// `--dart-define=LANDING_URL=https://smartbreakfast.store`
const _landingUrl = String.fromEnvironment(
  'LANDING_URL',
  defaultValue: 'https://smartbreakfast.store',
);

/// Menu giữ đúng thứ tự và nhãn của trang giới thiệu. Hai trang cùng một
/// thương hiệu thì thanh điều hướng phải đọc như một, người dùng không cần
/// biết mình đang ở hai hệ thống khác nhau.
///
/// `path` rỗng là mục của chính trang này: không phải liên kết, chỉ tô đậm.
const _menu = <({String label, String path})>[
  (label: 'Trang chủ', path: '/'),
  (label: 'Sản phẩm', path: '/san-pham'),
  (label: 'Quy trình', path: '/quy-trinh'),
  (label: 'Công nghệ', path: '/cong-nghe'),
  (label: 'Truy xuất nguồn gốc', path: ''),
  (label: 'Thành tựu', path: '/thanh-tuu'),
  (label: 'Liên hệ', path: '/lien-he'),
];

/// Thanh điều hướng, dựng theo `.site-header` của trang giới thiệu: cao 68px,
/// nền trắng, viền đáy một nét, mục chữ 15px và nút đặt hàng dạng viên thuốc.
class ExplorerHeader extends StatefulWidget {
  const ExplorerHeader({this.onHome, super.key});

  final VoidCallback? onHome;

  /// Trang giới thiệu chuyển sang nút Menu dưới 1220px, lấy đúng ngưỡng đó.
  static const fullNavWidth = 1220.0;

  /// Chiều cao thanh, bằng `.site-header .bar { height: 68px }`.
  static const barHeight = 68.0;

  @override
  State<ExplorerHeader> createState() => _ExplorerHeaderState();
}

class _ExplorerHeaderState extends State<ExplorerHeader> {
  bool menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final full = width >= ExplorerHeader.fullNavWidth;
    final orderUrl = '$_landingUrl/lien-he#dat-hang';

    // `.wrap` của trang giới thiệu: rộng tối đa 1200px kể cả lề trong 24px.
    // Giữ nguyên con số để hai thanh trên đặt cạnh nhau thì thương hiệu và
    // nút đặt hàng rơi đúng một chỗ.
    Widget centred(Widget child, {required EdgeInsets padding}) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: padding.add(const EdgeInsets.symmetric(horizontal: 24)),
          child: child,
        ),
      ),
    );

    final bar = full
        ? Row(
            children: [
              TuleBrand(onTap: widget.onHome),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Wrap chứ không phải Row cứng: cỡ chữ hệ thống lớn hoặc
                    // font thay thế có thể làm bảy mục rộng hơn dự tính, và
                    // xuống dòng thì vẫn đọc được, còn tràn thì không.
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 18,
                        runSpacing: 2,
                        children: [
                          for (final item in _menu)
                            _MenuLink(
                              label: item.label,
                              url: item.path.isEmpty
                                  ? null
                                  : '$_landingUrl${item.path}',
                              current: item.path.isEmpty,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    _OrderButton(url: orderUrl),
                  ],
                ),
              ),
            ],
          )
        : Row(
            // Thương hiệu bọc Flexible để trên màn hẹp nó co lại nhường chỗ
            // cho nút Menu, thay vì đẩy cả hàng tràn ra ngoài.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: TuleBrand(onTap: widget.onHome)),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trang giới thiệu vẫn giữ nút đặt hàng từ 560px trở lên,
                  // chỉ giấu hẳn trên điện thoại.
                  if (width >= 560) ...[
                    _OrderButton(url: orderUrl),
                    const SizedBox(width: 12),
                  ],
                  _MenuToggle(
                    open: menuOpen,
                    onTap: () => setState(() => menuOpen = !menuOpen),
                  ),
                ],
              ),
            ],
          );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: landingLine)),
      ),
      child: Column(
        children: [
          // minHeight chứ không phải chiều cao cứng: bình thường thanh cao
          // đúng 68px như trang giới thiệu, còn khi menu phải xuống dòng thì
          // nó cao thêm thay vì cắt mất chữ.
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ExplorerHeader.barHeight,
            ),
            child: centred(
              bar,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          // Danh sách mục trên màn hẹp, mở ra ngay dưới thanh trên.
          if (!full && menuOpen)
            centred(
              _MobileMenu(onPick: () => setState(() => menuOpen = false)),
              padding: const EdgeInsets.only(bottom: 10),
            ),
        ],
      ),
    );
  }
}

/// Nút mở danh sách mục trên màn hẹp, theo `.nav-toggle`: viên thuốc viền
/// mảnh, chỉ có chữ.
class _MenuToggle extends StatelessWidget {
  const _MenuToggle({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: open,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: landingLine2, width: 1.5),
        ),
        // Nhãn giữ nguyên khi mở, đúng như trang giới thiệu.
        child: const Text(
          'Menu',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: landingInk,
          ),
        ),
      ),
    ),
  );
}

/// Danh sách mục trên màn hẹp, theo `.mobile-nav`: mỗi mục một hàng chữ 18px,
/// gạch dưới một nét.
class _MobileMenu extends StatelessWidget {
  const _MobileMenu({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final item in _menu)
        _MobileMenuRow(
          label: item.label,
          url: item.path.isEmpty ? null : '$_landingUrl${item.path}',
          current: item.path.isEmpty,
          onPick: onPick,
        ),
    ],
  );
}

class _MobileMenuRow extends StatelessWidget {
  const _MobileMenuRow({
    required this.label,
    required this.current,
    required this.onPick,
    this.url,
  });

  final String label;
  final String? url;
  final bool current;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: current
        ? null
        : () {
            onPick();
            launchUrlString(url!, webOnlyWindowName: '_self');
          },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: landingLine)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          color: current ? landingTealInk : landingInk,
          fontWeight: current ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

/// Nút đặt hàng, theo `.btn.sm`: viên thuốc nền teal, chữ trắng 15px, rê chuột
/// thì đậm lại.
class _OrderButton extends StatefulWidget {
  const _OrderButton({required this.url});
  final String url;

  @override
  State<_OrderButton> createState() => _OrderButtonState();
}

class _OrderButtonState extends State<_OrderButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colour = hover ? landingTealInk : landingTeal;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: () => launchUrlString(widget.url, webOnlyWindowName: '_blank'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: colour,
            border: Border.all(color: colour, width: 1.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Đặt hàng',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Một mục menu, theo `.site-nav a`: chữ 15px, gạch chân 2px chỉ hiện ở mục
/// đang mở, và đổi sang teal khi rê chuột.
class _MenuLink extends StatefulWidget {
  const _MenuLink({required this.label, this.url, this.current = false});

  final String label;

  /// Null nghĩa là mục của chính trang đang mở.
  final String? url;
  final bool current;

  @override
  State<_MenuLink> createState() => _MenuLinkState();
}

class _MenuLinkState extends State<_MenuLink> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final colour = widget.current
        ? landingInk
        : hover
        ? landingTealInk
        : landingInk2;

    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: widget.current ? landingTealBright : Colors.transparent,
          ),
        ),
      ),
      child: Text(
        widget.label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 15,
          height: 1.2,
          color: colour,
          fontWeight: widget.current ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );

    if (widget.current) return content;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: () => launchUrlString(widget.url!, webOnlyWindowName: '_self'),
        child: content,
      ),
    );
  }
}

/// Dải tra cứu nằm ngay dưới thanh điều hướng. Tách khỏi thanh để thanh trên
/// giữ đúng hình dạng của trang giới thiệu, còn việc riêng của trang này thì
/// có chỗ của nó.
class TraceSearchBand extends StatelessWidget {
  const TraceSearchBand({required this.search, super.key});

  final Widget search;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      Breakpoints.gutter(context),
      20,
      Breakpoints.gutter(context),
      18,
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: search,
      ),
    ),
  );
}

/// Dải kiểm chứng chạy hết chiều ngang dưới hai cột.
class VerificationBar extends StatelessWidget {
  const VerificationBar({
    required this.integrity,
    required this.wide,
    this.onVerify,
    this.verifying = false,
    super.key,
  });

  final IntegrityRecord integrity;
  final bool wide;
  final VoidCallback? onVerify;
  final bool verifying;

  @override
  Widget build(BuildContext context) {
    final (title, note) = switch (integrity.status) {
      IntegrityStatus.verified => (
        'Dữ liệu khớp với bản đã công bố',
        'Mã băm tính lại trùng với bản ghi lúc công bố.',
      ),
      IntegrityStatus.mismatch => (
        'Dữ liệu đã thay đổi sau khi công bố',
        'Mã băm tính lại không trùng bản ghi lúc công bố.',
      ),
      IntegrityStatus.notPublished => (
        'Lô này đang tạo',
        'Chưa có bản nào để đối chiếu.',
      ),
      IntegrityStatus.unknown => (
        'Chưa kiểm chứng được',
        'Không lấy được kết quả từ máy chủ.',
      ),
    };

    final facts = <Widget>[
      if (integrity.version != null)
        _BarFact(label: 'PHIÊN BẢN', value: 'v${integrity.version}'),
      if (integrity.publishedAt.isNotEmpty)
        _BarFact(
          label: 'CÔNG BỐ LÚC',
          value: _readableTime(integrity.publishedAt),
        ),
      if (integrity.chain.txHash.isNotEmpty)
        _BarFact(
          label: 'HASH GIAO DỊCH',
          value: integrity.chain.shortTx,
          copyValue: integrity.chain.txHash,
        ),
    ];

    final heading = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: componentInk,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: componentInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                note,
                style: const TextStyle(fontSize: 12.5, color: brandMuted),
              ),
            ],
          ),
        ),
      ],
    );

    final action = integrity.chain.txUrl.isNotEmpty
        ? OutlinedButton.icon(
            onPressed: () => launchUrlString(
              integrity.chain.txUrl,
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Xem giao dịch trên blockchain'),
          )
        : OutlinedButton.icon(
            onPressed: verifying ? null : onVerify,
            icon: verifying
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(verifying ? 'Đang kiểm' : 'Kiểm lại'),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brandSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brandLine),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(flex: 5, child: heading),
                const SizedBox(width: 20),
                // Nhóm số liệu tự xuống dòng khi tiêu đề trạng thái dài, thay
                // vì đẩy nút ra ngoài mép thẻ.
                Expanded(
                  flex: 6,
                  child: Wrap(spacing: 24, runSpacing: 10, children: facts),
                ),
                const SizedBox(width: 20),
                action,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 16),
                Wrap(spacing: 26, runSpacing: 14, children: facts),
                const SizedBox(height: 16),
                action,
              ],
            ),
    );
  }

  static String _readableTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _BarFact extends StatelessWidget {
  const _BarFact({required this.label, required this.value, this.copyValue});

  final String label;
  final String value;
  final String? copyValue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: brandMuted,
        ),
      ),
      const SizedBox(height: 5),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (copyValue != null) ...[
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copyValue!));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mã giao dịch.')),
                  );
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.copy_rounded, size: 14, color: brandMuted),
              ),
            ),
          ],
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: componentInk,
            ),
          ),
        ],
      ),
    ],
  );
}

class ExplorerFooter extends StatelessWidget {
  const ExplorerFooter({required this.wide, super.key});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    // Chân trang co lại được: ở 360px thì dòng khẩu hiệu phải cắt bớt chứ
    // không đẩy tràn khung.
    final left = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.spa_rounded, size: 16, color: componentInk),
        const SizedBox(width: 8),
        const Text(
          'TÚ LỆ ',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: componentInk,
            letterSpacing: .6,
          ),
        ),
        const Text(
          'TRACE',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: brandOrangeText,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            'Truy xuất nguồn gốc  ·  Minh bạch  ·  Vì nông sản Việt',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: brandMuted),
          ),
        ),
      ],
    );

    const right = Text(
      'Kết nối giá trị từ những vùng đất lành',
      style: TextStyle(fontSize: 12.5, color: brandMuted),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: wide
          ? Row(
              children: [
                Flexible(child: left),
                const SizedBox(width: 16),
                const Spacer(),
                right,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 8), right],
            ),
    );
  }
}
