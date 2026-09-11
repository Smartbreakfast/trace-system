import 'package:flutter/material.dart';

import 'tule_theme.dart';

/// Ba trạng thái mà bản cũ hoàn toàn không có: đang tải, lỗi, và không tìm thấy.
/// Trước đây mọi lỗi đều bị nuốt trong `catch (_)` rồi hiện dữ liệu mẫu.
enum LoadPhase {
  /// Chưa nhập mã nào. Trang chủ dừng ở đây thay vì tự tải sẵn một lô rồi
  /// bày ra như thể người dùng vừa tra cứu.
  idle,
  loading,
  ready,
  failed,
  notFound,
}

/// Khối xám bo góc dùng dựng skeleton, có nhịp thở nhẹ để thấy trang đang tải.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    required this.height,
    this.width = double.infinity,
    this.radius = 12,
    super.key,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Người dùng bật "giảm chuyển động" thì giữ khối tĩnh.
    final animate = !MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFFE7E4D9),
            const Color(0xFFF1EFE6),
            animate ? _controller.value : 0.5,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Khung xương của trang tra cứu, giữ đúng nhịp bố cục của nội dung thật
/// để trang không nhảy khi dữ liệu về.
class TraceSkeleton extends StatelessWidget {
  const TraceSkeleton({required this.wide, super.key});
  final bool wide;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đang tải hồ sơ lô sản phẩm',
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(height: 26, width: 260),
        const SizedBox(height: 10),
        const SkeletonBox(height: 14, width: 340),
        const SizedBox(height: 22),
        SkeletonBox(height: wide ? 190 : 320, radius: 22),
        const SizedBox(height: 34),
        const SkeletonBox(height: 22, width: 220),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (var i = 0; i < 4; i++)
              SkeletonBox(
                height: wide ? 96 : 88,
                width: wide ? 246 : double.infinity,
                radius: 18,
              ),
          ],
        ),
      ],
    ),
  );
}

/// Màn thông báo dùng chung cho lỗi mạng, không tìm thấy mã và danh sách rỗng.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    required this.icon,
    required this.title,
    this.body = '',
    this.tone = StatusTone.neutral,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.detail,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final StatusTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      StatusTone.neutral => (const Color(0xFFEDEBE1), componentInk),
      StatusTone.warning => (const Color(0xFFFFF0E3), brandOrangeText),
      StatusTone.danger => (const Color(0xFFFBE6E4), const Color(0xFF7A1F19)),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: brandSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: brandLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: foreground, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: componentInk,
              ),
            ),
            // Tiêu đề đã nói đủ thì không cần một dòng giải thích thêm.
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(body, style: sectionCaptionStyle),
              ),
            ],
            if (detail != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F2E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  detail!,
                  style: monoStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: brandMuted,
                  ),
                ),
              ),
            ],
            if (actionLabel != null || secondaryLabel != null) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (actionLabel != null)
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(actionLabel!),
                    ),
                  if (secondaryLabel != null)
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum StatusTone { neutral, warning, danger }
