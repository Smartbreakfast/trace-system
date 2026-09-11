import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/demo_data.dart';
import '../data/trace_api.dart';
import '../models/trace_models.dart';
import '../ui/async_states.dart';
import '../ui/explorer_chrome.dart';
import '../ui/explorer_tabs.dart';
import '../ui/shared_components.dart';
import '../ui/sourcing_section.dart';
import '../ui/trace_components.dart';

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({this.code, this.demo = false, this.api, super.key});

  /// Mã lô lấy từ URL `/t/:code`. Null nghĩa là trang chủ, chỉ hiện ô tra cứu.
  final String? code;

  /// Bật bằng `?demo=1`. Dữ liệu mẫu chỉ hiện khi được yêu cầu rõ ràng
  /// và luôn kèm nhãn cảnh báo.
  final bool demo;

  final TraceApi? api;

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  late final TraceApi api = widget.api ?? TraceApi();

  LoadPhase phase = LoadPhase.idle;
  TraceRecord? record;

  /// Mục đang mở. Mặc định là thông tin chung: người vừa quét mã muốn xác nhận
  /// đúng gói mình đang cầm trước, rồi mới truy nguồn gốc.
  ExplorerTab tab = ExplorerTab.general;

  /// Vài lô đã công bố, gợi ý cho người mở trang mà chưa có mã nào trong tay.
  List<BatchRef> samples = const [];
  String? failureMessage;
  bool verifying = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSamples();
  }

  /// Danh sách gợi ý chỉ cần cho trang chưa tra cứu, hỏng thì im lặng bỏ qua:
  /// nó là tiện ích, không phải nội dung của trang.
  Future<void> _loadSamples() async {
    try {
      final list = await api.publicBatches();
      if (mounted) setState(() => samples = list);
    } on TraceApiFailure {
      // Không có gợi ý thì thôi, ô tra cứu vẫn dùng được.
    }
  }

  @override
  void didUpdateWidget(ExplorerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.demo != widget.demo) _load();
  }

  @override
  void dispose() {
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.demo) {
      setState(() {
        record = demoTrace;
        phase = LoadPhase.ready;
      });
      return;
    }

    // Chưa có mã thì không gọi API và không vẽ gì: hồ sơ chỉ xuất hiện sau khi
    // người dùng quét QR hoặc nhập mã.
    final code = widget.code;
    if (code == null) {
      setState(() {
        record = null;
        failureMessage = null;
        phase = LoadPhase.idle;
      });
      return;
    }

    setState(() {
      phase = LoadPhase.loading;
      failureMessage = null;
    });

    try {
      final data = await api.getTrace(code);
      if (!mounted) return;
      setState(() {
        record = TraceRecord.fromApi(data);
        phase = LoadPhase.ready;
        tab = ExplorerTab.general;
      });
    } on TraceNotFound {
      if (!mounted) return;
      setState(() => phase = LoadPhase.notFound);
    } on TraceApiFailure catch (error) {
      if (!mounted) return;
      setState(() {
        phase = LoadPhase.failed;
        failureMessage = error.message;
      });
    }
  }

  /// Bước 6 trong luồng hash của PROJECT_PLAN: tính lại và đối chiếu.
  /// `/public/traces/:code` đã kèm sẵn kết quả này, nút "Kiểm lại" dùng để
  /// khách tự chạy lại sau khi đã mở trang một lúc.
  Future<void> _verify() async {
    final current = record;
    if (current == null || current.isDemo || current.batch.code.isEmpty) return;
    setState(() => verifying = true);
    try {
      final data = await api.verify(current.batch.code);
      if (!mounted) return;
      setState(() {
        record = TraceRecord(
          batch: current.batch,
          ingredients: current.ingredients,
          integrity: IntegrityRecord.fromApi(data),
        );
      });
    } on TraceApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  void _openCode(String code) {
    if (code == widget.code) {
      _load();
      return;
    }
    context.go('/t/$code');
  }

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final gutter = Breakpoints.gutter(context);

    return TuleWebFrame(
      // Nền trắng ngà, hơi ngả xanh ở đáy: đủ để trang thấy khác màn quản trị
      // mà không nhuộm màu lên ảnh sản phẩm.
      ground: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [traceGroundTop, traceGroundBottom],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh điều hướng đứng yên khi cuộn, giống trang giới thiệu.
          ExplorerHeader(onHome: () => context.go('/')),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ô tra cứu hiện ở mọi trạng thái và luôn ở một chỗ, để nó
                  // không nhảy giữa lúc chưa tra cứu và lúc có kết quả.
                  TraceSearchBand(
                    search: TraceSearch(
                      dense: true,
                      initialCode: widget.code ?? '',
                      busy: phase == LoadPhase.loading,
                      onSubmit: _openCode,
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: Breakpoints.contentMaxWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(gutter, 6, gutter, 56),
                        child: _body(context, wide),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, bool wide) => switch (phase) {
    LoadPhase.idle => SourcingSection(
      record: null,
      samples: samples,
      onOpenCode: _openCode,
    ),
    LoadPhase.loading => TraceSkeleton(wide: wide),
    LoadPhase.notFound => StatusMessage(
      icon: Icons.search_off,
      tone: StatusTone.warning,
      title: 'Không tìm thấy mã ${widget.code}',
      body: 'Mã thường có dạng TL-2026-001.',
      actionLabel: 'Thử lại',
      onAction: _load,
      secondaryLabel: 'Xem hồ sơ mẫu',
      onSecondary: () => context.go('/t/$demoCode?demo=1'),
    ),
    LoadPhase.failed => StatusMessage(
      icon: Icons.wifi_off,
      tone: StatusTone.danger,
      title: 'Không kết nối được máy chủ truy xuất',
      body: 'Không hiển thị dữ liệu thay thế cho bản ghi thật.',
      detail: failureMessage,
      actionLabel: 'Thử lại',
      onAction: _load,
      secondaryLabel: 'Xem hồ sơ mẫu',
      onSecondary: () => context.go('/t/$demoCode?demo=1'),
    ),
    LoadPhase.ready => _content(context, wide, record!),
  };

  Widget _content(BuildContext context, bool wide, TraceRecord data) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (data.isDemo) ...[
        _DemoBanner(onExit: () => context.go('/')),
        const SizedBox(height: 20),
      ],
      ExplorerTabBar(
        value: tab,
        qualityCount: data.certificates.length + data.labReports.length,
        onChanged: (value) => setState(() => tab = value),
      ),
      const SizedBox(height: 18),
      switch (tab) {
        ExplorerTab.general => GeneralInfoSection(record: data),
        ExplorerTab.origin => SourcingSection(record: data),
        ExplorerTab.quality => QualitySection(record: data),
      },
      if (tab == ExplorerTab.origin && data.ingredients.isEmpty) ...[
        const SizedBox(height: 26),
        const StatusMessage(
          icon: Icons.inbox_outlined,
          title: 'Lô này chưa khai báo nguyên liệu',
        ),
      ],
      const SizedBox(height: 20),
      // Dải kiểm chứng nằm ngoài các mục: đó là thứ phân biệt hồ sơ này với
      // một trang giới thiệu, không nên giấu vào trong một tab.
      VerificationBar(
        integrity: data.integrity,
        wide: wide,
        verifying: verifying,
        onVerify: data.isDemo ? null : () => _verify(),
      ),
      ExplorerFooter(wide: wide),
    ],
  );
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.onExit});
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0E3),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: componentOrange.withValues(alpha: .4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, color: brandOrangeText),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Hồ sơ mẫu. Số liệu bên dưới không phải bản ghi thật.',
            style: TextStyle(color: brandOrangeText, height: 1.4, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(onPressed: onExit, child: const Text('Thoát')),
      ],
    ),
  );
}
