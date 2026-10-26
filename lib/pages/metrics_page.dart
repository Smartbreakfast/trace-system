import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/trace_api.dart';
import '../models/trace_models.dart';
import '../ui/async_states.dart';
import '../ui/explorer_chrome.dart';
import '../ui/shared_components.dart';

/// Trang chỉ số công khai, dựng đúng theo bảng trong báo cáo đề tài.
///
/// Mở cho mọi người xem vì mục đích của nó là để đối chiếu: người đọc báo cáo
/// gõ địa chỉ này vào trình duyệt là thấy hệ thống đang chạy nói gì, không phải
/// tin vào con số in trên giấy.
///
/// Bảng chia hai phần và ranh giới đó là điều quan trọng nhất của trang:
/// phần trên hệ thống tự đếm được, phần dưới do cơ sở sản xuất khai nên mỗi
/// dòng in kèm nguồn.
class MetricsPage extends StatefulWidget {
  const MetricsPage({this.api, super.key});

  final TraceApi? api;

  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends State<MetricsPage> {
  late final TraceApi api = widget.api ?? TraceApi();

  LoadPhase phase = LoadPhase.loading;
  PublicMetrics? data;
  String? failureMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => phase = LoadPhase.loading);
    try {
      final result = await api.publicMetrics();
      if (!mounted) return;
      setState(() {
        data = result;
        phase = LoadPhase.ready;
      });
    } on TraceApiFailure catch (error) {
      if (!mounted) return;
      setState(() {
        failureMessage = error.message;
        phase = LoadPhase.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = Breakpoints.gutter(context);
    return TuleWebFrame(
      ground: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [traceGroundTop, traceGroundBottom],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExplorerHeader(onHome: () => context.go('/')),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 940),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 56),
                    child: _body(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() => switch (phase) {
    LoadPhase.failed => StatusMessage(
      icon: Icons.wifi_off,
      tone: StatusTone.danger,
      title: 'Không đọc được bảng chỉ số',
      body: 'Trang này chỉ hiện số lấy từ hệ thống, không có số dự phòng.',
      detail: failureMessage,
      actionLabel: 'Thử lại',
      onAction: _load,
    ),
    LoadPhase.ready => _table(data!),
    _ => const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(child: CircularProgressIndicator()),
    ),
  };

  Widget _table(PublicMetrics metrics) {
    final lots = StringBuffer('${metrics.batches} lô');
    if (metrics.ingredientBatches > 0) {
      lots.write(
        ' (${metrics.finishedBatches} lô thành phẩm, '
        '${metrics.ingredientBatches} lô nguyên liệu)',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chỉ số hệ thống', style: pageTitleStyle),
        const SizedBox(height: 10),
        const Text(
          'Các con số dưới đây đọc trực tiếp từ hệ thống đang chạy. Mỗi dòng '
          'đều kiểm lại được trên chính trang truy xuất công khai.',
          style: TextStyle(fontSize: 14.5, color: brandMuted, height: 1.55),
        ),
        const SizedBox(height: 26),
        const _GroupHeading(
          'Hệ thống tự đếm',
          'Đếm từ dữ liệu đang chạy. Không ai khai tay được, kể cả quản trị.',
        ),
        _Row(
          label: 'Số cơ sở sản xuất',
          value: '${metrics.facilities} cơ sở',
          source: 'Danh mục cơ sở trên hệ thống',
        ),
        _Row(
          label: 'Số sản phẩm, số lô đưa lên hệ thống',
          value: '${metrics.products} sản phẩm; $lots',
          source: 'Danh mục sản phẩm và trang truy xuất công khai',
        ),
        _Row(
          label: 'Số lô đã neo lên blockchain',
          value: '${metrics.anchored} lô, giao dịch đã được xác nhận',
          source: 'Mạng VBSN, chainId 84001',
        ),
        _Row(
          label: 'Đánh giá của người sử dụng',
          value: metrics.ratings == 0
              ? 'Chưa có đánh giá'
              : '${metrics.ratings} lượt; trung bình '
                    '${metrics.average.toStringAsFixed(2).replaceAll('.', ',')}/5 sao',
          source: 'Mục đánh giá trên trang truy xuất',
        ),
        _Row(
          label: 'Lượt mở hồ sơ truy xuất',
          value: '${metrics.views} lượt',
          source: 'Bộ đếm của hệ thống, tính từ ngày bật bộ đếm',
          // Nói rõ đây là lượt chứ không phải người: hệ thống cố tình không lưu
          // gì để nhận ra người xem, nên nó không thể đếm người được.
          note: 'Một người mở lại hồ sơ thì tính thêm một lượt. Hệ thống không '
              'lưu địa chỉ IP hay mã thiết bị của người xem.',
          last: true,
        ),
        const SizedBox(height: 30),
        const _GroupHeading(
          'Cơ sở sản xuất cung cấp',
          'Hệ thống không đo được những số này nên chỉ chép lại đúng như cơ sở '
              'khai, kèm nguồn.',
        ),
        if (metrics.reported.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Chưa có số nào được khai.',
              style: TextStyle(fontSize: 14, color: brandMuted),
            ),
          ),
        for (final (index, metric) in metrics.reported.indexed)
          _Row(
            label: metric.label,
            value: metric.value,
            source: metric.source,
            note: metric.note.isEmpty ? null : metric.note,
            last: index == metrics.reported.length - 1,
          ),
        const SizedBox(height: 28),
        const ExplorerFooter(wide: true),
      ],
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.title, this.caption);
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: sectionTitleStyle),
        const SizedBox(height: 5),
        Text(
          caption,
          style: const TextStyle(fontSize: 13, color: brandMuted, height: 1.5),
        ),
      ],
    ),
  );
}

/// Một dòng chỉ số. Nguồn nằm ngay dưới con số chứ không dồn xuống cuối trang:
/// người đọc nhìn thấy con số lúc nào thì nhìn thấy xuất xứ của nó lúc đó.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.source,
    this.note,
    this.last = false,
  });

  final String label;
  final String value;
  final String source;
  final String? note;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: componentInk,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Nguồn: $source',
          style: const TextStyle(fontSize: 12.5, color: brandMuted, height: 1.5),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note!,
            style: const TextStyle(
              fontSize: 12.5,
              color: brandMuted,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
    final title = Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: brandInkSoft,
        height: 1.45,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: brandLine)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 8), body],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 280, child: title),
                const SizedBox(width: 24),
                Expanded(child: body),
              ],
            ),
    );
  }
}
