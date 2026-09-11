import 'package:flutter/material.dart';

import '../data/people.dart';
import '../models/trace_models.dart';
import 'journey_panel.dart';
import 'media_components.dart';
import 'process_tree.dart';
import 'shared_components.dart';

/// Khối chính của trang tra cứu: sơ đồ quy trình bên trái, hồ sơ bên phải.
///
/// Bấm một nút trên sơ đồ thì panel phải đổi nội dung: nút thành phẩm ra hồ sơ
/// lô, nút nguyên liệu ra hồ sơ vùng trồng, nút công đoạn ra chi tiết công
/// đoạn đó gồm khối lượng, người làm và tham số kỹ thuật.
///
/// Vùng nguyên liệu hiện bằng ảnh chụp chứ không phải bản đồ tương tác. Hồ sơ
/// chỉ cần chỉ ra vùng nằm ở đâu; kéo theo một thư viện bản đồ và bộ tile chỉ
/// để làm việc đó là trả giá bằng vài trăm KB trên đường truyền của người vừa
/// quét mã QR ngoài chợ.
class SourcingSection extends StatefulWidget {
  const SourcingSection({
    required this.record,
    this.samples = const [],
    this.onOpenCode,
    super.key,
  });

  /// Vài lô đã công bố, chỉ dùng ở trạng thái chưa tra cứu.
  final List<BatchRef> samples;
  final void Function(String code)? onOpenCode;

  /// Null nghĩa là chưa tra cứu lô nào. Khung vẫn dựng y hệt, chỉ là sơ đồ
  /// chưa có gì và panel là lời mời nhập mã. Đổi layout giữa hai trạng thái
  /// làm trang giật một cái ngay khi vừa nhận kết quả.
  final TraceRecord? record;

  @override
  State<SourcingSection> createState() => _SourcingSectionState();
}

/// Hai cách nhìn cùng một hồ sơ.
enum SourcingView { tree, area }

class _SourcingSectionState extends State<SourcingSection> {
  /// Nút đang chọn, dùng chung cho sơ đồ và danh sách hành trình.
  TraceSelection selection = const TraceSelection.none();
  SourcingView view = SourcingView.tree;

  bool get _isWide => MediaQuery.sizeOf(context).width >= 900;

  /// Chiều cao khối bên trái trên desktop: thanh chuyển (34) + khoảng cách
  /// (10) + canvas. Panel bên phải khoá đúng con số này để hai thẻ cao bằng
  /// nhau; đổi bất kỳ số nào ở đây thì cả hai cùng đổi.
  static const _canvasHeight = 620.0;
  static const _deskHeight = 34 + 10 + _canvasHeight;

  /// Chọn một nút thì chỉ đổi nội dung panel, không kéo trang đi đâu.
  ///
  /// Bản trước tự cuộn xuống bản đồ trên màn hẹp cho người dùng thấy điểm vừa
  /// được làm nổi. Thực tế nó giật người đọc khỏi đúng chỗ họ vừa bấm.
  void _select(TraceSelection value) => setState(() => selection = value);

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final wide = _isWide;
    final facilityName = (record?.batch.facilityName ?? '').isEmpty
        ? 'Nơi sản xuất'
        : record!.batch.facilityName;

    final panel = _PanelShell(
      // Lúc chưa tra cứu, thẻ là chỗ giới thiệu sản phẩm nên mang tông xanh;
      // có kết quả rồi thì về nền trắng để ảnh và chữ của hồ sơ đứng rõ.
      tinted: record == null,
      centred: record == null && wide,
      child: record == null
          ? EmptyResultPanel(
              samples: widget.samples,
              onOpenCode: widget.onOpenCode,
            )
          : _ResultBody(
              record: record,
              selection: selection,
              facilityName: facilityName,
              // Chỉ khoá chiều cao trên desktop; màn hẹp để cả trang cuộn.
              locked: wide,
              onSelect: _select,
            ),
    );

    final canvasHeight = wide ? _canvasHeight : 380.0;
    final areaImage = record?.areaMap;

    final Widget canvas;
    if (record == null || record.ingredients.isEmpty) {
      canvas = _CanvasShell(
        height: canvasHeight,
        child: Container(
          color: const Color(0xFFF2F4EE),
          child: Image.asset('assets/tule-box.jpg', fit: BoxFit.contain),
        ),
      );
    } else {
      final tree = ProcessTree(
        record: record,
        selection: selection,
        onSelect: _select,
        height: canvasHeight,
      );

      // Không có ảnh vùng thì không dựng thanh chuyển: một nút đứng một mình
      // chỉ làm người xem tưởng còn thứ gì đó chưa hiện ra.
      canvas = areaImage == null
          ? tree
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CanvasSwitch(
                  value: view,
                  onChanged: (value) => setState(() => view = value),
                ),
                const SizedBox(height: 10),
                if (view == SourcingView.tree)
                  tree
                else
                  _CanvasShell(
                    height: canvasHeight,
                    child: _AreaImage(asset: areaImage),
                  ),
              ],
            );
    }

    // Desktop: khoá chiều cao hai cột bằng đúng khối bên trái. Hồ sơ dài mấy
    // thì cuộn bên trong panel, để sơ đồ đứng yên thay vì trôi khỏi màn hình
    // mỗi lần người xem đọc tới công đoạn cuối.
    return wide
        ? SizedBox(
            height: areaImage == null ? _canvasHeight : _deskHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 70, child: canvas),
                const SizedBox(width: 18),
                Expanded(flex: 30, child: panel),
              ],
            ),
          )
        // Màn hẹp: thông tin lô lên trước để người vừa quét QR xác nhận ngay
        // đúng gói mình đang cầm, sơ đồ nằm ngay dưới.
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [panel, const SizedBox(height: 16), canvas],
          );
  }
}

/// Khung của khối bên trái, dùng chung cho ảnh vùng và trạng thái trống.
class _CanvasShell extends StatelessWidget {
  const _CanvasShell({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: brandLine),
      color: brandSurface,
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

/// Ảnh chụp vùng nguyên liệu, phóng to và kéo được như một tấm bản đồ giấy.
class _AreaImage extends StatelessWidget {
  const _AreaImage({required this.asset});
  final MediaAsset asset;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: InteractiveViewer(
          maxScale: 4,
          child: MediaImage(asset: asset, fit: BoxFit.contain),
        ),
      ),
      if (asset.caption.isNotEmpty)
        Positioned(
          left: 14,
          bottom: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              asset.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: componentInk, fontSize: 12.5),
            ),
          ),
        ),
    ],
  );
}

/// Chuyển giữa sơ đồ quy trình và ảnh vùng nguyên liệu.
class _CanvasSwitch extends StatelessWidget {
  const _CanvasSwitch({required this.value, required this.onChanged});

  final SourcingView value;
  final ValueChanged<SourcingView> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: brandLine),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _SwitchButton(
            icon: Icons.account_tree_outlined,
            label: 'Sơ đồ quy trình',
            active: value == SourcingView.tree,
            onTap: () => onChanged(SourcingView.tree),
          ),
        ),
        Flexible(
          child: _SwitchButton(
            icon: Icons.map_outlined,
            label: 'Vùng nguyên liệu',
            active: value == SourcingView.area,
            onTap: () => onChanged(SourcingView.area),
          ),
        ),
      ],
    ),
  );
}

class _SwitchButton extends StatelessWidget {
  const _SwitchButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? componentInk : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : brandMuted),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: active ? Colors.white : brandMuted,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Khung của panel bên phải. Tách riêng để trạng thái chưa tra cứu và trạng
/// thái có kết quả dùng đúng một cái thẻ, không đổi bố cục khi kết quả về.
class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.child,
    this.tinted = false,
    this.centred = false,
  });

  /// Canh nội dung vào giữa thẻ. Dùng cho trạng thái chưa tra cứu.
  final bool centred;

  static double padFor(BuildContext context) =>
      Breakpoints.isCompact(context) ? 14 : 18;

  final Widget child;

  /// Nền xanh nhạt thay cho trắng, dùng cho thẻ giới thiệu lúc chưa tra cứu.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    // `AnimatedSwitcher` canh giữa theo `layoutBuilder`, khiến panel rỗng trôi
    // xuống giữa thẻ trong khi panel có kết quả bám mép trên. Ép về mép trên.
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      child: child,
    );

    return Container(
      alignment: centred ? Alignment.center : null,
      padding: EdgeInsets.all(padFor(context)),
      decoration: BoxDecoration(
        color: tinted ? null : brandSurface,
        gradient: tinted
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFBFDF8), brandPanel],
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brandLine),
      ),
      child: content,
    );
  }
}

/// Phần thân panel kết quả. Đầu đứng yên, phần dưới cuộn.
///
/// Cuộn cả thẻ thì tên lô và mã lô trôi mất ngay khi người xem lướt xuống danh
/// sách thành phần, mà đó lại là hai thứ họ cần nhìn thấy suốt lúc đối chiếu
/// với bao bì đang cầm.
class _StickyHead extends StatelessWidget {
  const _StickyHead({
    required this.header,
    required this.body,
    required this.locked,
  });

  final List<Widget> header;
  final Widget body;

  /// True khi chiều cao thẻ bị khoá (desktop) — lúc đó mới cuộn bên trong được.
  final bool locked;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: locked ? MainAxisSize.max : MainAxisSize.min,
    children: [
      ...header,
      if (locked)
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              // Chừa chỗ cho thanh cuộn để chữ không bị nó đè lên.
              padding: const EdgeInsets.only(right: 8),
              child: body,
            ),
          ),
        )
      else
        body,
    ],
  );
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.record,
    required this.selection,
    required this.facilityName,
    required this.locked,
    required this.onSelect,
  });

  final TraceRecord record;
  final TraceSelection selection;
  final String facilityName;
  final bool locked;
  final ValueChanged<TraceSelection> onSelect;

  @override
  Widget build(BuildContext context) {
    final index = selection.ingredientIndex;
    final ingredient = index != null && index < record.ingredients.length
        ? record.ingredients[index]
        : null;

    final Widget body;
    if (selection.event case final event?) {
      // Quay lại từ một công đoạn là về hồ sơ của chủ sở hữu nó, không nhảy
      // thẳng về đầu: người xem đang đi dọc một nhánh.
      body = _StepDetail(
        event: event,
        owner: ingredient?.name ?? facilityName,
        color: ingredient?.color ?? componentInk,
        locked: locked,
        onBack: () => onSelect(
          selection.facility
              ? const TraceSelection.none()
              : TraceSelection(ingredientIndex: index),
        ),
      );
    } else if (ingredient != null) {
      body = _IngredientDetail(
        ingredient: ingredient,
        locked: locked,
        onBack: () => onSelect(const TraceSelection.none()),
        onSelectEvent: (event) =>
            onSelect(TraceSelection(ingredientIndex: index, event: event)),
      );
    } else {
      body = _BatchResult(
        record: record,
        facilityName: facilityName,
        locked: locked,
        onSelect: onSelect,
      );
    }

    return KeyedSubtree(
      key: ValueKey((
        selection.ingredientIndex,
        selection.event,
        selection.facility,
      )),
      child: body,
    );
  }
}

/// Hồ sơ lô vừa tra cứu, kèm danh sách thành phần bấm được.
class _BatchResult extends StatelessWidget {
  const _BatchResult({
    required this.record,
    required this.facilityName,
    required this.locked,
    required this.onSelect,
  });

  final TraceRecord record;
  final String facilityName;
  final bool locked;
  final ValueChanged<TraceSelection> onSelect;

  @override
  Widget build(BuildContext context) {
    final batch = record.batch;
    final steps = record.timeline.length + record.batchEvents.length;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const PanelEyebrow('Sản phẩm'),
        const SizedBox(height: 6),
        Text(batch.name, style: displayTitleStyle.copyWith(fontSize: 25)),
        if (batch.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            batch.description,
            style: sectionCaptionStyle.copyWith(fontSize: 13.5),
          ),
        ],
      ],
    );

    return _StickyHead(
      locked: locked,
      header: [
        // Thẻ xác minh chỉ đứng cạnh tiêu đề khi panel đủ rộng. Đo bề rộng
        // thật của panel chứ không đo màn hình: panel 30% của desktop cũng
        // hẹp ngang một chiếc điện thoại.
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 460
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    heading,
                    const SizedBox(height: 14),
                    VerifiedCard(integrity: record.integrity),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 16),
                    VerifiedCard(integrity: record.integrity),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        BatchFactRow(batch: batch),
        const SizedBox(height: 18),
      ],
      // Danh sách hành trình từng nằm ở đây, nhưng sơ đồ bên trái đã nói
      // đúng điều đó bằng hình. Panel mặc định giờ là hồ sơ sản phẩm; chi
      // tiết từng chặng chỉ hiện khi người xem chạm vào một ô trên sơ đồ.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              if (batch.facilityName.isNotEmpty)
                InfoPill(label: 'NƠI SẢN XUẤT', value: batch.facilityName),
              InfoPill(
                label: 'THÀNH PHẦN',
                value: '${record.ingredients.length} nguyên liệu',
              ),
              InfoPill(label: 'CÔNG ĐOẠN', value: '$steps bước'),
            ],
          ),
          if (record.gallery.isNotEmpty) ...[
            const SizedBox(height: 18),
            MediaStrip(assets: record.gallery, thumbSize: 76),
          ],
        ],
      ),
    );
  }
}

class _IngredientDetail extends StatelessWidget {
  const _IngredientDetail({
    required this.ingredient,
    required this.locked,
    required this.onBack,
    required this.onSelectEvent,
  });

  final Ingredient ingredient;
  final bool locked;
  final VoidCallback onBack;
  final void Function(ProcessEvent event) onSelectEvent;

  @override
  Widget build(BuildContext context) => _StickyHead(
    locked: locked,
    header: [
      _DetailHeader(
        color: ingredient.color,
        icon: ingredient.icon,
        title: ingredient.name,
        subtitle: ingredient.origin,
        onBack: onBack,
      ),
    ],
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ingredient.areaMap case final area?) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: MediaImage(asset: area, fit: BoxFit.cover),
            ),
          ),
        ],
        if (ingredient.summary.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            ingredient.summary,
            style: const TextStyle(
              color: componentInk,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            // Ô nào chưa có dữ liệu thì bỏ hẳn, đừng hiện nhãn kèm chữ "Chưa
            // có": khách quét mã không cần biết nhà sản xuất còn thiếu trường
            // nào, và một hàng toàn "Chưa có" chỉ làm hồ sơ trông rỗng.
            if (ingredient.supplier.isNotEmpty)
              InfoPill(label: 'NHÀ CUNG CẤP', value: ingredient.supplier),
            if (ingredient.harvestDate.isNotEmpty)
              InfoPill(label: 'THU HOẠCH', value: ingredient.harvestDate),
            if (ingredient.receivedDate.isNotEmpty)
              InfoPill(label: 'NHẬP KHO', value: ingredient.receivedDate),
          ],
        ),
        if (ingredient.photos.isNotEmpty) ...[
          const SizedBox(height: 20),
          MediaStrip(assets: ingredient.photos, thumbSize: 88),
        ],
        const SizedBox(height: 20),
        const _SubHeading('Công đoạn'),
        const SizedBox(height: 12),
        if (ingredient.events.isEmpty)
          const Text(
            'Chưa có công đoạn nào.',
            style: sectionCaptionStyle,
          ),
        for (final (index, event) in ingredient.events.indexed)
          _EventRow(
            index: index,
            event: event,
            color: ingredient.color,
            isLast: index == ingredient.events.length - 1,
            onTap: () => onSelectEvent(event),
          ),
      ],
    ),
  );
}

/// Chi tiết một công đoạn: khối lượng, thời gian, người làm, tham số, ảnh.
class _StepDetail extends StatelessWidget {
  const _StepDetail({
    required this.event,
    required this.owner,
    required this.color,
    required this.locked,
    required this.onBack,
  });

  final ProcessEvent event;
  final String owner;
  final Color color;
  final bool locked;
  final VoidCallback onBack;

  /// Bỏ đuôi `.0` cho số nguyên: 500 g chứ không phải 500.0 g.
  static String _amount(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final unit = event.quantityUnit.isEmpty ? 'g' : event.quantityUnit;
    final facts = <Widget>[
      if (event.eventDate.isNotEmpty)
        InfoPill(label: 'THỜI GIAN', value: event.eventDate),
      if (event.inputQuantity case final value?)
        InfoPill(label: 'KHỐI LƯỢNG VÀO', value: '${_amount(value)} $unit'),
      if (event.outputQuantity case final value?)
        InfoPill(label: 'KHỐI LƯỢNG RA', value: '${_amount(value)} $unit'),
      if (event.yieldRatio case final ratio?)
        InfoPill(
          label: 'TỶ LỆ THU HỒI',
          value: '${(ratio * 100).toStringAsFixed(ratio * 100 % 1 == 0 ? 0 : 1)}%',
        ),
      for (final entry in event.params.entries)
        InfoPill(label: entry.key.toUpperCase(), value: entry.value),
    ];

    return _StickyHead(
      locked: locked,
      header: [
        _DetailHeader(
          color: color,
          icon: Icons.timeline,
          title: event.title,
          subtitle: owner,
          onBack: onBack,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (event.operator.isNotEmpty) ...[
            const SizedBox(height: 16),
            _OperatorRow(name: event.operator),
          ],
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 20, runSpacing: 12, children: facts),
          ],
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              event.description,
              style: const TextStyle(
                color: componentInk,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ],
          // Ảnh công đoạn hiện luôn ở cỡ đọc được, không phải một dải ô
          // vuông nhỏ phải bấm mới thấy. Đây là bằng chứng của công đoạn,
          // không phải hình trang trí.
          for (final asset in event.media) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: MediaImage(asset: asset, fit: BoxFit.cover),
              ),
            ),
            if (asset.caption.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(asset.caption, style: sectionCaptionStyle.copyWith(fontSize: 12)),
            ],
          ],
          if (facts.isEmpty &&
              event.description.isEmpty &&
              event.media.isEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Chưa có chi tiết nào cho công đoạn này.',
              style: sectionCaptionStyle,
            ),
          ],
        ],
      ),
    );
  }
}

/// Người trực tiếp làm công đoạn, kèm ảnh nếu là thành viên nhóm thực hiện.
class _OperatorRow extends StatelessWidget {
  const _OperatorRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final person = personFor(name);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: brandPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brandLine),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE7EDE4),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: person == null
                ? const Icon(Icons.person_outline, color: brandMuted, size: 22)
                : Image.asset(
                    person.asset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person_outline,
                      color: brandMuted,
                      size: 22,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NGƯỜI THỰC HIỆN',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: brandMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: componentInk,
                  ),
                ),
                if (person != null)
                  Text(
                    person.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: brandMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      color: componentInk,
      fontSize: 15,
    ),
  );
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconButton(
        tooltip: 'Quay lại',
        visualDensity: VisualDensity.compact,
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back, size: 18),
      ),
      const SizedBox(width: 4),
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: componentInk,
                fontSize: 18,
                height: 1.25,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: brandMuted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// Một công đoạn trong danh sách, bấm được để mở chi tiết.
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.index,
    required this.event,
    required this.color,
    required this.isLast,
    required this.onTap,
  });

  final int index;
  final ProcessEvent event;
  final Color color;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: color.withValues(alpha: .16),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            if (!isLast) Expanded(child: Container(width: 2, color: brandLine)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 4 : 12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: componentInk,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: brandMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.meta,
                      style: const TextStyle(color: brandMuted, fontSize: 12),
                    ),
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        event.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: brandMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Panel khi chưa tra cứu lô nào.
///
/// Giữ đúng chỗ của panel kết quả để trang không đổi bố cục lúc kết quả về:
/// chỉ nội dung bên trong đổi, khung bên trái đứng yên.
class EmptyResultPanel extends StatelessWidget {
  const EmptyResultPanel({this.samples = const [], this.onOpenCode, super.key});

  final List<BatchRef> samples;
  final void Function(String code)? onOpenCode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // Ảnh sản phẩm thật thay cho một ô icon: người vừa cầm hộp trên tay nhận
      // ra ngay mình vào đúng chỗ.
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/tule-products.jpg',
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(height: 18),
      const Text('Tra cứu một lô sản phẩm', style: displayTitleStyle),
      const SizedBox(height: 8),
      const Text(
        'Quét mã QR trên bao bì, hoặc nhập mã lô.',
        style: sectionCaptionStyle,
      ),
      // Người chưa cầm bao bì trên tay thì không có mã nào để gõ. Đưa sẵn vài
      // lô đã công bố để họ xem thử được ngay.
      if (samples.isNotEmpty) ...[
        const SizedBox(height: 22),
        Container(height: 1, color: brandLine),
        const SizedBox(height: 16),
        const PanelEyebrow('Lô đã công bố'),
        const SizedBox(height: 10),
        for (final item in samples) ...[
          _SampleRow(batch: item, onTap: onOpenCode),
          const SizedBox(height: 8),
        ],
      ],
    ],
  );
}

/// Một lô gợi ý: mã lô đứng trước vì đó là thứ người dùng sẽ đối chiếu.
class _SampleRow extends StatelessWidget {
  const _SampleRow({required this.batch, this.onTap});

  final BatchRef batch;
  final void Function(String code)? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: brandSurface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap == null ? null : () => onTap!(batch.code),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: brandLine),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(batch.code, style: monoStyle.copyWith(fontSize: 14)),
                  if (batch.name.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      batch.productionDate.isEmpty
                          ? batch.name
                          : '${batch.name}  ·  SX ${batch.productionDate}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: brandMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: brandMuted),
          ],
        ),
      ),
    ),
  );
}
