import 'package:flutter/material.dart';

import '../models/trace_models.dart';
import 'shared_components.dart';

/// Dải đánh giá của người mua, đặt dưới dải kiểm chứng trong hồ sơ lô.
///
/// Hai nửa khác hẳn nhau về bản chất, nên để cạnh nhau cho người đọc thấy rõ:
/// phía trên là hồ sơ nhà sản xuất công bố, đã băm và neo lên blockchain, sửa
/// là bị phát hiện; phần này là ý kiến người mua gửi sau đó, không vào mã băm
/// và không neo lên chuỗi. Nhập nhằng hai thứ thì mất ý nghĩa của cả hai.
class RatingSection extends StatefulWidget {
  const RatingSection({
    required this.summary,
    required this.onSubmit,
    this.wide = false,
    super.key,
  });

  final RatingSummary summary;

  /// Gửi đánh giá và trả về bản tóm tắt mới. Trả null nghĩa là gửi không được;
  /// màn hình giữ nguyên nội dung người dùng vừa nhập để họ thử lại.
  final Future<RatingSummary?> Function({
    required int stars,
    required String comment,
    required String displayName,
  })
  onSubmit;

  final bool wide;

  @override
  State<RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<RatingSection> {
  final _comment = TextEditingController();
  final _name = TextEditingController();

  late RatingSummary summary = widget.summary;
  int stars = 0;
  bool sending = false;
  bool sent = false;

  @override
  void didUpdateWidget(RatingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mở lô khác thì bắt đầu lại, không mang đánh giá đang viết sang lô mới.
    if (oldWidget.summary != widget.summary && !sent) {
      summary = widget.summary;
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (stars < 1 || sending) return;
    setState(() => sending = true);
    final updated = await widget.onSubmit(
      stars: stars,
      comment: _comment.text,
      displayName: _name.text,
    );
    if (!mounted) return;
    setState(() {
      sending = false;
      if (updated != null) {
        summary = updated;
        sent = true;
        _comment.clear();
        _name.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final score = summary.isEmpty
        ? const _EmptyScore()
        : _Score(summary: summary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brandSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brandLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rate_rounded, color: componentOrange),
              const SizedBox(width: 8),
              // Tiêu đề dài, màn hình hẹp: để nó co và xuống dòng chứ không
              // đẩy cả hàng tràn ra ngoài mép thẻ.
              const Expanded(
                child: Text(
                  'Người mua nói gì về lô này',
                  style: sectionTitleStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Đánh giá do người mua gửi, không nằm trong bản công bố đã neo lên '
            'blockchain.',
            style: TextStyle(fontSize: 12.5, color: brandMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          if (widget.wide && !summary.isEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chia theo tỉ lệ chứ không đặt bề ngang cứng: con số điểm cỡ
                // 40px cộng chữ "/ 5" đã ngốn gần hết 150px, panel hẹp là tràn.
                Expanded(flex: 2, child: score),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: _Distribution(summary: summary)),
              ],
            )
          else ...[
            score,
            if (!summary.isEmpty) ...[
              const SizedBox(height: 16),
              _Distribution(summary: summary),
            ],
          ],
          if (summary.comments.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, color: brandLine),
            const SizedBox(height: 14),
            for (final item in summary.comments.take(4)) _Comment(item: item),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: brandLine),
          const SizedBox(height: 14),
          if (sent)
            const Row(
              children: [
                Icon(Icons.check_circle_outline, size: 18, color: landingTeal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã nhận đánh giá của bạn. Cảm ơn bạn đã phản hồi.',
                    style: TextStyle(fontSize: 13, color: landingTealInk),
                  ),
                ),
              ],
            )
          else
            _Form(
              stars: stars,
              sending: sending,
              comment: _comment,
              name: _name,
              onStars: (value) => setState(() => stars = value),
              onSend: _send,
            ),
        ],
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.summary});
  final RatingSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            summary.averageText,
            style: const TextStyle(
              fontFamily: displayFont,
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w600,
              color: componentInk,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '/ 5',
            style: TextStyle(fontSize: 14, color: brandMuted),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _Stars(value: summary.average),
      const SizedBox(height: 6),
      Text(
        '${summary.count} đánh giá',
        style: const TextStyle(fontSize: 12.5, color: brandMuted),
      ),
    ],
  );
}

class _EmptyScore extends StatelessWidget {
  const _EmptyScore();

  @override
  Widget build(BuildContext context) => const Text(
    'Chưa có ai đánh giá lô này. Bạn là người đầu tiên.',
    style: TextStyle(fontSize: 13.5, color: brandMuted, height: 1.4),
  );
}

/// Năm ngôi sao theo điểm trung bình, nửa sao khi phần thập phân đủ lớn.
class _Stars extends StatelessWidget {
  const _Stars({required this.value, this.size = 18});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 1; index <= 5; index++)
        Icon(
          value >= index
              ? Icons.star_rounded
              : value >= index - 0.5
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: componentOrange,
        ),
    ],
  );
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.summary});
  final RatingSummary summary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var stars = 5; stars >= 1; stars--)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '$stars sao',
                  style: const TextStyle(fontSize: 11, color: brandMuted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.count == 0
                        ? 0
                        : summary.starCount(stars) / summary.count,
                    minHeight: 7,
                    backgroundColor: brandPanel,
                    valueColor: const AlwaysStoppedAnimation(componentOrange),
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${summary.starCount(stars)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11.5, color: brandMuted),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _Comment extends StatelessWidget {
  const _Comment({required this.item});
  final RatingComment item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Stars(value: item.stars.toDouble(), size: 14),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                item.authorLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: componentInk,
                ),
              ),
            ),
            if (item.dateText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                item.dateText,
                style: const TextStyle(fontSize: 11.5, color: brandMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(
          item.comment,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: brandInkSoft,
          ),
        ),
      ],
    ),
  );
}

/// Ô gửi đánh giá. Các trường chỉ hiện sau khi chọn sao: người không muốn viết
/// gì vẫn gửi được bằng một lần chạm, mà trang thì không phải đeo sẵn một cái
/// biểu mẫu to đùng.
class _Form extends StatelessWidget {
  const _Form({
    required this.stars,
    required this.sending,
    required this.comment,
    required this.name,
    required this.onStars,
    required this.onSend,
  });

  final int stars;
  final bool sending;
  final TextEditingController comment;
  final TextEditingController name;
  final ValueChanged<int> onStars;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Bạn đã dùng sản phẩm của lô này?',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: componentInk,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          for (var value = 1; value <= 5; value++)
            IconButton(
              onPressed: sending ? null : () => onStars(value),
              visualDensity: VisualDensity.compact,
              tooltip: '$value sao',
              icon: Icon(
                stars >= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 30,
                color: stars >= value ? componentOrange : brandMuted,
              ),
            ),
        ],
      ),
      if (stars > 0) ...[
        const SizedBox(height: 10),
        TextField(
          controller: name,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Tên của bạn (không bắt buộc)',
            counterText: '',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: comment,
          maxLength: 400,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Nhận xét (không bắt buộc)',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 16),
              label: Text(sending ? 'Đang gửi' : 'Gửi đánh giá'),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Một máy gửi một lần cho mỗi lô; gửi lại là sửa đánh giá cũ.',
                style: TextStyle(fontSize: 11.5, color: brandMuted),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
