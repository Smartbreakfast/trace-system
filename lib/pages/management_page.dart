import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/admin_session.dart';
import '../data/trace_api.dart';
import '../main.dart' show traceUrlFor;
import '../models/ingredient_draft.dart';
import '../models/trace_models.dart';
import '../ui/admin_login.dart';
import '../ui/async_states.dart';
import '../ui/management_components.dart';
import '../ui/media_manager.dart';
import '../ui/shared_components.dart';
import '../ui/trace_components.dart';

/// Màn vận hành.
///
/// Chỉ có hai mục và một luồng: chọn hoặc tạo một lô, rồi làm mọi việc của lô
/// đó ở cùng một chỗ. Bản trước tách "Lô sản phẩm", "Nguyên liệu" và "Tính
/// toàn vẹn" thành ba tab, nên nguyên liệu có hai giao diện nhập khác nhau
/// (một cho bản nháp lúc tạo lô, một cho bản đã lưu) và người dùng phải đoán
/// mình đang ở cái nào.
class ManagementPage extends StatefulWidget {
  const ManagementPage({this.api, super.key});
  final TraceApi? api;

  @override
  State<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends State<ManagementPage> {
  late final TraceApi api = widget.api ?? TraceApi();

  AdminSection section = AdminSection.overview;

  bool authChecked = false;
  bool authorized = false;

  Map<String, dynamic>? summary;
  bool loadingSummary = true;

  List<BatchListItem> batches = const [];
  bool loadingBatches = true;
  String? listError;

  /// Bộ lọc của danh sách lô. Lọc chạy ở server nên trang nào cũng đúng thứ
  /// tự, không phải chỉ đúng trong đám vừa tải về.
  final searchController = TextEditingController();
  String searchTerm = '';
  String sort = 'newest';
  int page = 1;
  int pages = 1;
  int total = 0;
  Timer? searchDebounce;

  /// Lô đang mở. Null nghĩa là đang xem danh sách.
  String? openCode;
  Object? openBatchId;
  TraceRecord? openBatch;
  List<Map<String, dynamic>> snapshots = const [];
  Map<String, dynamic> chain = const {};
  bool sendingToChain = false;
  bool loadingBatch = false;
  bool publishing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- phiên

  Future<void> _bootstrap() async {
    final token = await AdminSession.load();
    if (token == null) {
      if (mounted) setState(() => authChecked = true);
      return;
    }
    api.adminToken = token;
    try {
      await api.checkSession();
      if (!mounted) return;
      setState(() {
        authChecked = true;
        authorized = true;
      });
      await _refresh();
    } on TraceApiFailure {
      api.adminToken = null;
      if (mounted) setState(() => authChecked = true);
    }
  }

  Future<void> _signIn(String token) async {
    api.adminToken = token;
    await api.checkSession();
    await AdminSession.save(token);
    if (!mounted) return;
    setState(() => authorized = true);
    await _refresh();
  }

  Future<void> _signOut() async {
    await AdminSession.clear();
    api.adminToken = null;
    if (!mounted) return;
    setState(() {
      authorized = false;
      batches = const [];
      openCode = null;
      openBatch = null;
      summary = null;
    });
  }

  void _notify(String text, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: danger ? const Color(0xFF7A1F19) : null,
        ),
      );
  }

  /// Token bị thu hồi giữa chừng thì đưa thẳng về màn đăng nhập.
  void _fail(TraceApiFailure error) {
    if (error is TraceUnauthorized) _signOut();
    _notify(error.message, danger: true);
  }

  // --------------------------------------------------------------- dữ liệu

  Future<void> _refresh() async {
    await Future.wait([_loadSummary(), _loadBatches(), _loadChain()]);
  }

  /// Trạng thái ví neo dữ liệu. Hỏng thì để trống: nó là thông tin phụ, không
  /// được chặn màn quản trị.
  Future<void> _loadChain() async {
    try {
      final data = await api.chainStatus();
      if (mounted) setState(() => chain = data);
    } on TraceApiFailure {
      if (mounted) setState(() => chain = const {});
    }
  }

  Future<void> _sendToChain() async {
    setState(() => sendingToChain = true);
    try {
      final result = await api.sendPendingToChain();
      final sent = result['sent'] as int? ?? 0;
      final failed = result['failed'] as int? ?? 0;
      await _loadSnapshots();
      await _loadChain();
      await _reloadBatch();
      _notify(
        failed > 0
            ? 'Gửi được $sent bản, $failed bản hỏng.'
            : sent > 0
            ? 'Đã lưu $sent bản lên blockchain.'
            : 'Không còn bản nào chờ.',
        danger: failed > 0,
      );
    } on TraceApiFailure catch (error) {
      _fail(error);
    } finally {
      if (mounted) setState(() => sendingToChain = false);
    }
  }

  Future<void> _loadSummary() async {
    setState(() => loadingSummary = true);
    try {
      final data = await api.getSummary();
      if (mounted) setState(() => summary = data);
    } on TraceApiFailure {
      if (mounted) setState(() => summary = null);
    } finally {
      if (mounted) setState(() => loadingSummary = false);
    }
  }

  Future<void> _loadBatches() async {
    setState(() {
      loadingBatches = true;
      listError = null;
    });
    try {
      final result = await api.listBatches(
        query: searchTerm,
        sort: sort,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        batches = [
          for (final item in result.items) BatchListItem.fromApi(item),
        ];
        page = result.page;
        pages = result.pages;
        total = result.total;
        loadingBatches = false;
      });
    } on TraceApiFailure catch (error) {
      if (!mounted) return;
      setState(() {
        loadingBatches = false;
        listError = error.message;
      });
      if (error is TraceUnauthorized) _signOut();
    }
  }

  /// Gõ tới đâu lọc tới đó, nhưng chờ nửa giây để không bắn một request
  /// cho mỗi ký tự.
  void _onSearchChanged(String value) {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        searchTerm = value;
        page = 1;
      });
      _loadBatches();
    });
  }

  void _onSortChanged(String value) {
    setState(() {
      sort = value;
      page = 1;
    });
    _loadBatches();
  }

  void _goToPage(int value) {
    setState(() => page = value);
    _loadBatches();
  }

  Future<void> _open(String code) async {
    setState(() {
      openCode = code;
      loadingBatch = true;
      section = AdminSection.batches;
    });
    await _reloadBatch();
  }

  Future<void> _reloadBatch() async {
    final code = openCode;
    if (code == null) return;
    setState(() => loadingBatch = true);
    try {
      final data = await api.getAdminTrace(code);
      if (!mounted) return;
      setState(() {
        openBatch = TraceRecord.fromApi(data);
        openBatchId = data['id'];
      });
      await _loadSnapshots();
    } on TraceApiFailure catch (error) {
      if (mounted) setState(() => openBatch = null);
      _fail(error);
    } finally {
      if (mounted) setState(() => loadingBatch = false);
    }
  }

  /// Lịch sử niêm phong không phải thứ chặn màn hình: hỏng thì để trống.
  Future<void> _loadSnapshots() async {
    final code = openCode;
    if (code == null) return;
    try {
      final data = await api.listSnapshots(code);
      if (mounted) setState(() => snapshots = data);
    } on TraceApiFailure {
      if (mounted) setState(() => snapshots = const []);
    }
  }

  void _closeBatch() => setState(() {
    openCode = null;
    openBatch = null;
    openBatchId = null;
    snapshots = const [];
  });

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);

    if (!authChecked) {
      return const TuleWebFrame(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!authorized) {
      return TuleWebFrame(
        child: AdminLogin(
          onSubmit: _signIn,
          onExplorer: () => context.go('/'),
          endpoint: api.baseUrl,
        ),
      );
    }

    return TuleWebFrame(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            ManagementSidebar(
              section: section,
              onSelect: _selectSection,
              onExplorer: () => context.go('/'),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 40 : 18,
                  22,
                  wide ? 40 : 18,
                  56,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(wide),
                    const SizedBox(height: 22),
                    if (!wide) ...[
                      _sectionPicker(),
                      const SizedBox(height: 18),
                    ],
                    if (section == AdminSection.overview)
                      _overview()
                    else if (openCode == null)
                      _batchList()
                    else
                      _workspace(wide),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectSection(AdminSection value) => setState(() {
    section = value;
    if (value == AdminSection.overview) {
      openCode = null;
      openBatch = null;
      openBatchId = null;
    }
  });

  Widget _topBar(bool wide) => Row(
    children: [
      if (!wide) TuleBrand(onTap: () => context.go('/')),
      const Spacer(),
      IconButton(
        tooltip: 'Tải lại dữ liệu',
        onPressed: loadingBatches ? null : _refresh,
        icon: const Icon(Icons.refresh),
      ),
      IconButton(
        tooltip: 'Đăng xuất quản trị',
        onPressed: _signOut,
        icon: const Icon(Icons.logout),
      ),
      const SizedBox(width: 6),
      OutlinedButton.icon(
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.visibility_outlined, size: 17),
        label: const Text('Mở explorer'),
      ),
    ],
  );

  Widget _sectionPicker() => SizedBox(
    height: 48,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final item in AdminSection.values)
            WorkspaceTab(
              label: item.label,
              icon: item.icon,
              active: item == section,
              onTap: () => _selectSection(item),
            ),
        ],
      ),
    ),
  );

  // ------------------------------------------------------------- tổng quan

  Widget _overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Tổng quan', style: pageTitleStyle),
      const SizedBox(height: 20),
      ManagementStats(summary: summary, loading: loadingSummary),
      if (summary == null && !loadingSummary) ...[
        const SizedBox(height: 16),
        StatusMessage(
          icon: Icons.cloud_off,
          tone: StatusTone.danger,
          title: 'Chưa kết nối được API',
          body:
              'Chạy backend bằng "npm run dev" trong thư mục worker rồi tải lại.',
          detail: 'Địa chỉ đang gọi: ${api.baseUrl}',
          actionLabel: 'Tải lại',
          onAction: _refresh,
        ),
      ],
      const SizedBox(height: 26),
      Row(
        children: [
          const Expanded(child: Text('Lô gần đây', style: sectionTitleStyle)),
          TextButton(
            onPressed: () => _selectSection(AdminSection.batches),
            child: const Text('Xem tất cả'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _batchRows(limit: 3),
    ],
  );

  // ---------------------------------------------------------- danh sách lô

  Widget _batchList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(child: Text('Lô sản phẩm', style: pageTitleStyle)),
          FilledButton.icon(
            onPressed: _createBatch,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tạo lô mới'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      BatchFilterBar(
        controller: searchController,
        sort: sort,
        onSearch: _onSearchChanged,
        onSort: _onSortChanged,
        total: total,
      ),
      const SizedBox(height: 16),
      _batchRows(),
      if (pages > 1) ...[
        const SizedBox(height: 8),
        BatchPager(
          page: page,
          pages: pages,
          onChange: loadingBatches ? null : _goToPage,
        ),
      ],
    ],
  );

  Widget _batchRows({int? limit}) {
    if (loadingBatches) {
      return const Column(
        children: [
          SkeletonBox(height: 74, radius: 14),
          SizedBox(height: 12),
          SkeletonBox(height: 74, radius: 14),
        ],
      );
    }
    if (listError != null) {
      return StatusMessage(
        icon: Icons.cloud_off,
        tone: StatusTone.danger,
        title: 'Không tải được danh sách lô',
        body: 'Kiểm tra backend rồi thử lại.',
        detail: listError,
        actionLabel: 'Thử lại',
        onAction: _loadBatches,
      );
    }
    if (batches.isEmpty && searchTerm.trim().isNotEmpty) {
      return StatusMessage(
        icon: Icons.search_off,
        title: 'Không có lô nào khớp "$searchTerm"',
        body: 'Thử mã lô hoặc tên khác.',
        actionLabel: 'Xoá tìm kiếm',
        onAction: () {
          searchController.clear();
          _onSearchChanged('');
        },
      );
    }
    if (batches.isEmpty) {
      return StatusMessage(
        icon: Icons.inventory_2_outlined,
        title: 'Chưa có lô nào',
        body:
            'Tạo lô thành phẩm đầu tiên để sinh mã truy xuất và mã QR cho bao bì.',
        actionLabel: 'Tạo lô mới',
        onAction: _createBatch,
      );
    }
    final items = limit == null ? batches : batches.take(limit).toList();
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BatchRow(
              item: item,
              selected: false,
              onTap: () => _open(item.code),
              onOpenPublic: () => context.go('/t/${item.code}'),
            ),
          ),
      ],
    );
  }

  Future<void> _createBatch() async {
    final result = await BatchCreateDialog.show(
      context,
      existingCodes: [for (final batch in batches) batch.code],
      suggestedCode:
          'TL-${DateTime.now().year}-'
          '${(batches.length + 1).toString().padLeft(3, '0')}',
    );
    if (result == null) return;

    try {
      final created = await api.createProduct(result.values);
      final code = created['code']?.toString() ?? '';
      final id = created['id'];

      if (result.withStarter && id != null) {
        // Bốn nguyên liệu quen thuộc của Tú Lệ, tạo sẵn cho đỡ gõ lại. Chúng
        // là nguyên liệu thật trong database, sửa bằng đúng form của nguyên
        // liệu tự thêm, không phải một loại bản nháp riêng.
        for (final draft in starterIngredients()) {
          final ingredient = await api.createIngredient(draft.toApi(id));
          for (final (index, step) in draft.steps.indexed) {
            await api.createEvent({
              'ingredientBatchId': ingredient['id'],
              'title': step.title,
              'description': step.description,
              'eventDate': result.values['productionDate'],
              'enteredBy': 'admin',
              'position': index,
            });
          }
        }

        // Hai công đoạn ở xưởng có trong mọi lô, tạo sẵn luôn.
        for (final (index, step) in facilitySteps().indexed) {
          await api.createEvent({
            'productBatchId': id,
            'title': step.title,
            'description': step.description,
            'eventDate': result.values['productionDate'],
            'enteredBy': 'admin',
            'position': index,
          });
        }
      }

      await _loadBatches();
      await _loadSummary();
      await _open(code);
      _notify('Đã tạo lô $code.');
    } on TraceApiFailure catch (error) {
      _fail(error);
    }
  }

  // ---------------------------------------------------------- màn làm việc

  Widget _workspace(bool wide) {
    if (loadingBatch && openBatch == null) {
      return const Column(
        children: [
          SkeletonBox(height: 120, radius: 16),
          SizedBox(height: 14),
          SkeletonBox(height: 220, radius: 16),
        ],
      );
    }
    final record = openBatch;
    if (record == null) {
      return StatusMessage(
        icon: Icons.cloud_off,
        tone: StatusTone.danger,
        title: 'Không mở được lô $openCode',
        body: 'Kiểm tra kết nối API rồi thử lại.',
        actionLabel: 'Thử lại',
        onAction: _reloadBatch,
        secondaryLabel: 'Về danh sách',
        onSecondary: _closeBatch,
      );
    }

    final batchId = openBatchId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _workspaceHeader(record),
        const SizedBox(height: 22),
        _card(
          title: 'Thông tin lô',
          child: BatchInfoForm(
            key: ValueKey(record.batch.code),
            batch: record.batch,
            wide: wide,
            onSave: _saveBatchInfo,
          ),
        ),
        const SizedBox(height: 16),
        if (batchId != null) ...[
          _card(
            title: 'Ảnh của lô',
            child: MediaManager(
              api: api,
              ownerType: 'product_batch',
              ownerId: batchId,
              assets: record.media,
              allowCover: true,
              allowLabReport: true,
              allowCertificate: true,
              allowAreaMap: true,
              onChanged: _reloadBatch,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _card(
          title: 'Nguyên liệu',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (record.ingredients.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Chưa có nguyên liệu nào.',
                    style: sectionCaptionStyle,
                  ),
                ),
              for (final item in record.ingredients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: IngredientEditorCard(
                    api: api,
                    item: item,
                    onChanged: _reloadBatch,
                    onEdit: () => _editIngredient(item),
                    onRemove: () => _removeIngredient(item),
                    onAddEvent: () => _addEvent(item),
                    onRemoveEvent: _removeEvent,
                    onEditEvent: (event) => _editEvent(event, item.name),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: batchId == null
                      ? null
                      : () => _addIngredient(batchId),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm nguyên liệu'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          title: 'Công đoạn tại xưởng',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (record.batchEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Chưa ghi phối trộn, đóng gói hay công đoạn nào của cả lô.',
                    style: sectionCaptionStyle,
                  ),
                ),
              for (final event in record.batchEvents)
                BatchEventRow(
                  api: api,
                  event: event,
                  onChanged: _reloadBatch,
                  onRemove: () => _removeEvent(event),
                  onEdit: () => _editEvent(event, record.batch.facilityName),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: batchId == null
                      ? null
                      : () => _addBatchEvent(batchId),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm công đoạn'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(title: 'Hoàn thành lô', child: _publishBlock(record, wide)),
      ],
    );
  }

  Widget _workspaceHeader(TraceRecord record) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconButton(
        tooltip: 'Về danh sách lô',
        onPressed: _closeBatch,
        icon: const Icon(Icons.arrow_back),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.batch.name, style: pageTitleStyle),
            const SizedBox(height: 6),
            Text(
              '${record.batch.code}  ·  ${record.ingredients.length} nguyên liệu'
              '  ·  ${record.timeline.length} công đoạn',
              style: sectionCaptionStyle,
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          integrityBadgeFor(record.integrity.status),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.go('/t/${record.batch.code}'),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Xem trang công khai'),
          ),
        ],
      ),
    ],
  );

  Widget _publishBlock(TraceRecord record, bool wide) {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntegrityPanel(
          integrity: record.integrity,
          verifying: loadingBatch,
          showChain: false,
          showHash: true,
        ),
        if (record.integrity.status == IntegrityStatus.mismatch) ...[
          const SizedBox(height: 14),
          StatusMessage(
            icon: Icons.published_with_changes,
            tone: StatusTone.warning,
            title: 'Có thay đổi chưa lưu',
            body:
                'Khách quét QR vẫn đang xem bản v${record.integrity.version ?? 1}. '
                'Thay đổi chỉ ra mắt sau khi lưu bản mới.',
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: publishing ? null : () => _publish(record.batch.code),
          icon: publishing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.publish, size: 18),
          label: Text(
            record.batch.isPublished ? 'Lưu bản mới' : 'Hoàn thành lô',
          ),
        ),
        if (snapshots.isNotEmpty) ...[
          const SizedBox(height: 14),
          ChainStatusLine(
            snapshots: snapshots,
            chain: chain,
            sending: sendingToChain,
            onSend: _sendToChain,
          ),
          const SizedBox(height: 18),
          SealHistory(
            snapshots: snapshots,
            explorer: (chain['explorer'] ?? '').toString(),
            onOpen: _showSnapshot,
          ),
        ],
      ],
    );

    final qr = TraceQrCard(
      code: record.batch.code,
      url: traceUrlFor(record.batch.code),
    );

    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 22),
              SizedBox(width: 250, child: qr),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [left, const SizedBox(height: 18), qr],
          );
  }

  Widget _card({required String title, required Widget child}) => Container(
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
        Text(title, style: sectionTitleStyle),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );

  // ---------------------------------------------------------------- thao tác

  Future<void> _saveBatchInfo(Map<String, dynamic> body) async {
    final code = openCode;
    if (code == null) return;
    try {
      await api.updateProduct(code, body);
      await _reloadBatch();
      await _loadBatches();
      _notify('Đã lưu thông tin lô.');
    } on TraceApiFailure catch (error) {
      _fail(error);
    }
  }

  Future<void> _addIngredient(Object batchId) async {
    final result = await IngredientDialog.show(context);
    if (result == null) return;
    try {
      await api.createIngredient(result.toApi(batchId));
      await _reloadBatch();
      await _loadSummary();
      _notify('Đã thêm ${result.name}.');
    } on TraceApiFailure catch (error) {
      _fail(error);
    }
  }

  Future<void> _editIngredient(Ingredient item) async {
    if (item.id == null) return;
    final result = await IngredientDialog.show(
      context,
      draft: IngredientDraft.fromIngredient(item),
    );
    if (result == null) return;
    try {
      await api.updateIngredient(item.id!, {
        'name': result.name,
        'origin': result.origin,
        'supplier': result.supplier,
        'harvestDate': result.harvestDate,
        'receivedDate': result.receivedDate,
        'summary': result.summary,
        'latitude': result.latitude,
        'longitude': result.longitude,
        'areaGeoJson': result.areaGeoJson,
      });
      await _reloadBatch();
      _notify('Đã cập nhật ${result.name}.');
    } on TraceApiFailure catch (error) {
      _fail(error);
    }
  }

  Future<void> _removeIngredient(Ingredient item) async {
    if (item.id == null) return;
    final confirmed = await _confirm(
      title: 'Xoá nguyên liệu',
      body:
          'Xoá "${item.name}" cùng ${item.events.length} công đoạn và ảnh của nó?',
    );
    if (!confirmed) return;
    try {
      await api.deleteIngredient(item.id!);
      await _reloadBatch();
      await _loadSummary();
      _notify('Đã xoá ${item.name}.');
    } on TraceApiFailure catch (error) {
      _fail(error);
    }
  }

  /// Công đoạn của cả lô: phối trộn, đóng gói. Tài liệu quy trình có hai công
  /// đoạn này ở xưởng, trước đây không có chỗ nào nhập.
  Future<void> _addBatchEvent(Object batchId) async {
    final record = openBatch;
    final result = await EventDialog.show(
      context,
      record?.batch.facilityName.isNotEmpty == true
          ? record!.batch.facilityName
          : 'lô này',
    );
    if (result == null) return;
    try {
      await api.createEvent({
        'productBatchId': batchId,
        'enteredBy': 'admin',
        ...eventBody(result),
      });
      await _reloadBatch();
      await _loadSummary();
      _notify('Đã ghi nhận công đoạn tại xưởng.');
    } on TraceApiFailure catch (error) {
      _fail(error);
    }
  }

  /// Sửa chi tiết một công đoạn đã có: khối lượng, người làm, tham số.
  ///
  /// Đây là đường nhập chính của quy trình, vì bộ công đoạn đã được tạo sẵn
  /// theo sơ đồ khi lập lô. Thêm công đoạn mới là việc hiếm.
  Future<void> _editEvent(ProcessEvent event, String owner) async {
    final id = event.id;
    if (id == null) return;
    final result = await EventDialog.show(context, owner, initial: event);
    if (result == null) return;
    try {
      await api.updateEvent(id, eventBody(result));
      await _reloadBatch();
      _notify('Đã lưu công đoạn ${result.title}.');
    } on TraceApiFailure catch (error) {
      _fail(error);
    }
  }

  Future<void> _addEvent(Ingredient item) async {
    if (item.id == null) return;
    final result = await EventDialog.show(context, item.name);
    if (result == null) return;
    try {
      await api.createEvent({
        'ingredientBatchId': item.id,
        'enteredBy': 'admin',
        ...eventBody(result),
      });
      await _reloadBatch();
      await _loadSummary();
      _notify('Đã ghi nhận công đoạn cho ${item.name}.');
    } on TraceApiFailure catch (error) {
      _fail(error);
    }
  }

  Future<void> _removeEvent(ProcessEvent event) async {
    if (event.id == null) return;
    final confirmed = await _confirm(
      title: 'Xoá công đoạn',
      body: 'Xoá "${event.title}" khỏi hồ sơ?',
    );
    if (!confirmed) return;
    try {
      await api.deleteEvent(event.id!);
      await _reloadBatch();
      await _loadSummary();
      _notify('Đã xoá công đoạn.');
    } on TraceApiFailure catch (error) {
      _fail(error);
    }
  }

  Future<bool> _confirm({required String title, required String body}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _publish(String code) async {
    setState(() => publishing = true);
    try {
      final result = await api.publish(code);
      if (!mounted) return;
      setState(() => publishing = false);
      await _reloadBatch();
      await _loadBatches();
      await _loadSummary();
      await _loadChain();
      if (!mounted) return;
      await _showPublishResult(code, result);
    } on TraceApiFailure catch (error) {
      if (!mounted) return;
      setState(() => publishing = false);
      _fail(error);
    }
  }

  /// Mở nội dung một bản cũ.
  ///
  /// Sửa dữ liệu không xoá bản đã chốt: payload nằm nguyên trong
  /// published_snapshots. Không có màn này thì điều đó chỉ đúng trong database
  /// mà người vận hành không bao giờ thấy.
  Future<void> _showSnapshot(int version) async {
    final code = openCode;
    if (code == null) return;
    Map<String, dynamic> data;
    try {
      data = await api.getSnapshot(code, version);
    } on TraceApiFailure catch (error) {
      _fail(error);
      return;
    }
    if (!mounted) return;

    final payload = data['payload'] as Map<String, dynamic>? ?? const {};
    final ingredients = payload['ingredients'] as List<dynamic>? ?? const [];
    final chainInfo = data['chain'] as Map<String, dynamic>? ?? const {};
    final tx = (chainInfo['txHash'] ?? '').toString();
    final explorer = (chain['explorer'] ?? '').toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Bản v$version'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['publishedAt'] ?? ''} · ${data['publishedBy'] ?? ''}',
                  style: sectionCaptionStyle.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                CopyableHash(hash: (data['sha256'] ?? '').toString()),
                if (tx.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ChainLine(
                    chain: ChainRecord(
                      status: (chainInfo['status'] ?? '').toString(),
                      txHash: tx,
                      explorer: explorer,
                    ),
                    version: version,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  (payload['name'] ?? '').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: componentInk,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if ((payload['productionDate'] ?? '').toString().isNotEmpty)
                      'SX ${payload['productionDate']}',
                    if ((payload['expiryDate'] ?? '').toString().isNotEmpty)
                      'HSD ${payload['expiryDate']}',
                    if ((payload['facilityName'] ?? '').toString().isNotEmpty)
                      payload['facilityName'].toString(),
                  ].join('  ·  '),
                  style: sectionCaptionStyle.copyWith(fontSize: 12.5),
                ),
                if ((payload['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    payload['description'].toString(),
                    style: sectionCaptionStyle.copyWith(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                for (final raw in ingredients)
                  if (raw is Map<String, dynamic>)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${raw['name'] ?? ''} — ${raw['origin'] ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: componentInk,
                              fontSize: 13.5,
                            ),
                          ),
                          for (final event
                              in (raw['processEvents'] as List<dynamic>? ??
                                  const []))
                            if (event is Map<String, dynamic>)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 2,
                                ),
                                child: Text(
                                  '· ${event['title'] ?? ''}'
                                  '${(event['eventDate'] ?? '').toString().isEmpty ? '' : ' (${event['eventDate']})'}',
                                  style: const TextStyle(
                                    color: brandMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPublishResult(
    String code,
    Map<String, dynamic> result,
  ) async {
    final hash = result['sha256']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xong'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lô $code đã lưu bản v${result['version'] ?? 1}.',
                style: sectionCaptionStyle,
              ),
              const SizedBox(height: 16),
              TraceQrCard(code: code, url: traceUrlFor(code)),
              if (hash.isNotEmpty) ...[
                const SizedBox(height: 14),
                CopyableHash(hash: hash),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/t/$code');
            },
            child: const Text('Xem trang công khai'),
          ),
        ],
      ),
    );
  }
}
