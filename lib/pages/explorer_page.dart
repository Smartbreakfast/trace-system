import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/demo_data.dart';
import '../data/device_id.dart';
import '../data/trace_api.dart';
import '../data/trace_cache.dart';
import '../models/trace_models.dart';
import '../ui/async_states.dart';
import '../ui/explorer_chrome.dart';
import '../ui/explorer_tabs.dart';
import '../ui/rating_section.dart';
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
  List<PublicProduct> products = const [];
  String selectedSku = 'tule-breakfast';
  int batchPage = 0;
  static const batchesPerPage = 3;
  String? failureMessage;
  bool verifying = false;

  /// Hồ sơ đang xem lấy từ bản lưu trên máy chứ không phải từ máy chủ.
  CachedTrace? offlineCopy;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSamples();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final items = await api.publicCatalog();
      if (!mounted || items.isEmpty) return;
      final code = widget.code?.toUpperCase();
      final fromCode = code == null
          ? null
          : items
                .where(
                  (product) =>
                      product.batches.any((batch) => batch.code == code),
                )
                .firstOrNull;
      setState(() {
        products = items;
        selectedSku =
            fromCode?.sku ??
            (items.any((item) => item.sku == selectedSku)
                ? selectedSku
                : items.first.sku);
      });
    } on TraceApiFailure {
      // The trace itself remains usable if the optional product menu is down.
    }
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
      final loaded = TraceRecord.fromApi(data);
      setState(() {
        record = loaded;
        offlineCopy = null;
        phase = LoadPhase.ready;
        tab = ExplorerTab.general;
        _selectProductForCode(widget.code);
      });
      // Lưu bản sao để lần sau mất mạng vẫn mở lại được. Không chờ việc này:
      // hồ sơ đã hiện rồi, lưu được hay không cũng không đổi màn hình.
      unawaited(TraceCache.save(code, loaded.batch.name, data));
    } on TraceNotFound {
      if (!mounted) return;
      setState(() => phase = LoadPhase.notFound);
    } on TraceApiFailure catch (error) {
      if (!mounted) return;
      // Báo lỗi trước đã. Bản lưu trên máy chỉ là lối thoát thêm, không được
      // phép giữ người dùng ngồi chờ một lần đọc bộ nhớ.
      setState(() {
        phase = LoadPhase.failed;
        failureMessage = error.message;
      });
      // Mất mạng mà máy đã có bản tải trước thì mở bản đó ra, kèm nhãn nói rõ.
      // Đây vẫn là bản ghi của chính lô này, không phải dữ liệu mẫu.
      final saved = await TraceCache.load(code);
      if (!mounted || saved?.data == null) return;
      if (phase != LoadPhase.failed || widget.code != code) return;
      setState(() {
        record = TraceRecord.fromApi(saved!.data!);
        offlineCopy = saved;
        phase = LoadPhase.ready;
        tab = ExplorerTab.general;
        _selectProductForCode(widget.code);
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
        // Chỉ thay kết quả kiểm chứng. Trước đây dựng lại TraceRecord bằng ba
        // trường nên ảnh, công đoạn của lô và đánh giá rụng hết sau khi bấm
        // "Kiểm lại".
        record = TraceRecord(
          batch: current.batch,
          ingredients: current.ingredients,
          integrity: IntegrityRecord.fromApi(data),
          batchEvents: current.batchEvents,
          media: current.media,
          ratings: current.ratings,
          isDemo: current.isDemo,
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

  /// Gửi đánh giá của người mua. Trả null khi gửi không được: ô nhập giữ
  /// nguyên nội dung để họ thử lại, kèm một dòng báo lỗi.
  Future<RatingSummary?> _submitRating({
    required int stars,
    required String comment,
    required String displayName,
  }) async {
    final code = record?.batch.code ?? '';
    if (code.isEmpty) return null;
    try {
      return await api.submitRating(
        code: code,
        stars: stars,
        deviceId: await DeviceId.get(),
        comment: comment,
        displayName: displayName,
      );
    } on TraceApiFailure catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return null;
    }
  }

  void _openCode(String code) {
    if (code == widget.code) {
      _load();
      return;
    }
    context.go('/t/$code');
  }

  PublicProduct? get _selectedProduct =>
      products.where((product) => product.sku == selectedSku).firstOrNull;

  List<BatchRef> get _visibleBatches {
    final batches = _selectedProduct?.batches ?? const <BatchRef>[];
    final start = batchPage * batchesPerPage;
    if (start >= batches.length) return const [];
    final end = (start + batchesPerPage).clamp(0, batches.length);
    return batches.sublist(start, end);
  }

  int get _batchPageCount {
    final count = _selectedProduct?.batches.length ?? 0;
    return count == 0 ? 1 : (count + batchesPerPage - 1) ~/ batchesPerPage;
  }

  void _changeProduct(String sku) {
    setState(() {
      selectedSku = sku;
      batchPage = 0;
    });
  }

  void _selectProductForCode(String? code) {
    if (code == null) return;
    final match = products
        .where(
          (product) =>
              product.batches.any((batch) => batch.code == code.toUpperCase()),
        )
        .firstOrNull;
    if (match != null) selectedSku = match.sku;
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
          ExplorerHeader(
            onHome: () => context.go('/'),
            products: products,
            selectedSku: selectedSku,
            currentCode: widget.code,
            onProductChanged: _changeProduct,
            onOpenCode: _openCode,
          ),
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
    LoadPhase.idle => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SourcingSection(
          record: null,
          samples: _visibleBatches.isEmpty ? samples : _visibleBatches,
          onOpenCode: _openCode,
          productName: _selectedProduct?.name,
          page: batchPage,
          pageCount: _batchPageCount,
          onPageChanged: (page) => setState(() => batchPage = page),
        ),
      ],
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
    LoadPhase.ready => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_content(context, wide, record!)],
    ),
  };

  Widget _content(BuildContext context, bool wide, TraceRecord data) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (data.isDemo) ...[
        _DemoBanner(onExit: () => context.go('/')),
        const SizedBox(height: 20),
      ],
      if (offlineCopy != null) ...[
        _OfflineBanner(saved: offlineCopy!, onRetry: _load),
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
      // Hồ sơ mẫu không nhận đánh giá: nó không phải một lô thật nên không có
      // gì để đánh giá, và phiếu gửi vào đó chỉ làm bẩn số liệu.
      if (!data.isDemo && data.batch.code.isNotEmpty) ...[
        const SizedBox(height: 20),
        RatingSection(
          summary: data.ratings,
          wide: wide,
          onSubmit: _submitRating,
        ),
      ],
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

/// Nhãn cho hồ sơ mở từ bản lưu trên máy.
///
/// Không giấu chuyện mất mạng: trạng thái kiểm chứng trong hồ sơ là của lúc
/// tải về, nên phải ghi rõ thời điểm đó và chừa nút tải lại.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.saved, required this.onRetry});

  final CachedTrace saved;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: brandPanel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: landingTeal.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: landingTealInk),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Đang xem bản lưu trên máy, tải lúc ${saved.savedAtText}. '
            'Kết quả kiểm chứng bên dưới là của lần tải đó.',
            style: const TextStyle(
              color: landingTealInk,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(onPressed: onRetry, child: const Text('Tải lại')),
      ],
    ),
  );
}
