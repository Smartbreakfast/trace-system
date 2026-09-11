import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/trace_models.dart';
import 'shared_components.dart';

/// Thứ nguyên của một nút trên sơ đồ.
enum TreeNodeKind { product, batchStep, ingredientStep, ingredient }

/// Một nút đã được xếp chỗ trên sơ đồ quy trình.
class TreeNode {
  const TreeNode({
    required this.kind,
    required this.label,
    required this.rect,
    required this.color,
    this.ingredientIndex,
    this.event,
    this.ingredient,
  });

  final TreeNodeKind kind;
  final String label;
  final Rect rect;
  final Color color;

  /// Vị trí trong `record.ingredients`, có ở nút nguyên liệu và nút công đoạn
  /// của nguyên liệu đó.
  final int? ingredientIndex;

  /// Công đoạn tương ứng, null ở nút sản phẩm và nút nguyên liệu.
  final ProcessEvent? event;

  /// Nguyên liệu của nút gốc nhánh, để lấy ảnh và biểu tượng.
  final Ingredient? ingredient;

  Offset get topCenter => Offset(rect.center.dx, rect.top);
  Offset get bottomCenter => Offset(rect.center.dx, rect.bottom);
}

/// Cái người dùng đang chọn trên sơ đồ.
///
/// Dùng chung cho sơ đồ và danh sách hành trình: chọn một nguyên liệu ở danh
/// sách và chọn nút gốc nhánh trên sơ đồ là cùng một việc, panel bên phải chỉ
/// dựng một lần.
class TraceSelection {
  const TraceSelection({
    this.ingredientIndex,
    this.event,
    this.facility = false,
  });

  const TraceSelection.none() : this();

  final int? ingredientIndex;
  final ProcessEvent? event;

  /// Đang xem nơi phối trộn và đóng gói.
  final bool facility;

  bool get isEmpty => ingredientIndex == null && event == null && !facility;

  bool matches(TreeNode node) => switch (node.kind) {
    TreeNodeKind.product => isEmpty,
    TreeNodeKind.batchStep => identical(event, node.event),
    TreeNodeKind.ingredientStep => identical(event, node.event),
    TreeNodeKind.ingredient =>
      event == null && ingredientIndex == node.ingredientIndex,
  };
}

/// Sơ đồ quy trình: thành phẩm ở trên, truy ngược xuống các nhánh nguyên liệu.
///
/// Không dùng thư viện vẽ đồ thị. Quy trình của sản phẩm này cố định về hình
/// dạng, một gốc rồi rẽ nhánh, nên tự xếp chỗ theo tầng vừa nhẹ hơn vừa kiểm
/// soát được bố cục.
class ProcessTree extends StatefulWidget {
  const ProcessTree({
    required this.record,
    required this.selection,
    required this.onSelect,
    required this.height,
    super.key,
  });

  final TraceRecord record;
  final TraceSelection selection;
  final void Function(TraceSelection value) onSelect;
  final double height;

  @override
  State<ProcessTree> createState() => _ProcessTreeState();
}

class _ProcessTreeState extends State<ProcessTree> {
  final controller = TransformationController();

  /// Kích thước vùng nhìn của lần dựng gần nhất, để canh lại khi đổi cỡ.
  Size? viewport;
  Size? content;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Canh sơ đồ vừa khít vùng nhìn. Người xem mở trang phải thấy trọn cây
  /// trước đã; phóng to là việc họ chủ động làm sau.
  void _fit(Size view, Size size) {
    if (view.isEmpty || size.isEmpty) return;
    const pad = 28.0;
    final scale = math.min(
      math.min(
        (view.width - pad) / size.width,
        (view.height - pad) / size.height,
      ),
      1.0,
    );
    final dx = (view.width - size.width * scale) / 2;
    final dy = (view.height - size.height * scale) / 2;
    controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoom(double factor) {
    final view = viewport;
    if (view == null) return;
    final current = controller.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.3, 2.5);
    // Phóng quanh tâm vùng nhìn để nội dung không nhảy ra ngoài.
    final centre = Offset(view.width / 2, view.height / 2);
    final scene = controller.toScene(centre);
    controller.value = Matrix4.identity()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(next, next, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final layout = _TreeLayout(widget.record);
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brandLine),
        color: const Color(0xFFFCFCF9),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final view = Size(constraints.maxWidth, constraints.maxHeight);
          if (viewport != view || content != layout.size) {
            viewport = view;
            content = layout.size;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fit(view, layout.size);
            });
          }
          return Stack(
            children: [
              // Lưới chấm mờ: báo cho người xem biết đây là mặt phẳng kéo
              // được, không phải một tấm ảnh tĩnh.
              const Positioned.fill(child: CustomPaint(painter: _DotGrid())),
              InteractiveViewer(
                transformationController: controller,
                minScale: 0.3,
                maxScale: 2.5,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(240),
                child: SizedBox(
                  width: layout.size.width,
                  height: layout.size.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _EdgePainter(
                            edges: layout.edges,
                            selection: widget.selection,
                            originBand: layout.originBand,
                          ),
                        ),
                      ),
                      for (final node in layout.nodes)
                        Positioned(
                          left: node.rect.left,
                          top: node.rect.top,
                          width: node.rect.width,
                          height: node.rect.height,
                          child: _NodeChip(
                            node: node,
                            selected: widget.selection.matches(node),
                            onTap: () => widget.onSelect(_select(node)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _ZoomButtons(
                  onIn: () => _zoom(1.25),
                  onOut: () => _zoom(0.8),
                  onFit: () {
                    final view = viewport;
                    if (view != null) _fit(view, layout.size);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  TraceSelection _select(TreeNode node) => switch (node.kind) {
    TreeNodeKind.product => const TraceSelection.none(),
    TreeNodeKind.batchStep => TraceSelection(event: node.event, facility: true),
    TreeNodeKind.ingredientStep => TraceSelection(
      ingredientIndex: node.ingredientIndex,
      event: node.event,
    ),
    TreeNodeKind.ingredient => TraceSelection(
      ingredientIndex: node.ingredientIndex,
    ),
  };
}

/// Xếp chỗ cho các nút theo tầng và nối chúng lại.
class _TreeLayout {
  _TreeLayout(TraceRecord record) {
    const nodeW = 200.0;
    const stepH = 42.0;
    const productH = 66.0;
    const originH = 64.0;
    const hGap = 24.0;
    const vGap = 22.0;
    const colStep = nodeW + hGap;
    const rowStep = stepH + vGap;

    final ingredients = record.ingredients;
    final columns = math.max(ingredients.length, 1);
    final width = columns * colStep - hGap;

    // Công đoạn ở xưởng đọc ngược: đóng gói nằm sát thành phẩm, phối trộn ở
    // dưới nó, vì sơ đồ đi từ thành phẩm truy về nguyên liệu.
    final batchSteps = record.batchEvents.reversed.toList();
    final branchTop = 1 + batchSteps.length;
    final deepest = ingredients.fold<int>(
      0,
      (top, item) => math.max(top, item.events.length),
    );
    final bottomRow = branchTop + deepest;
    final height = bottomRow * rowStep + originH;
    size = Size(width, height);

    // Dải nền dưới cùng gom các nút vùng nguyên liệu thành một nhóm.
    originBand = Rect.fromLTWH(
      -14,
      bottomRow * rowStep - 16,
      width + 28,
      originH + 30,
    );

    final centre = (width - nodeW) / 2;
    final product = TreeNode(
      kind: TreeNodeKind.product,
      label: record.batch.name.isEmpty ? 'Thành phẩm' : record.batch.name,
      rect: Rect.fromLTWH(centre, 0, nodeW, productH),
      color: componentInk,
    );
    nodes.add(product);

    var previous = product;
    for (final (index, event) in batchSteps.indexed) {
      final node = TreeNode(
        kind: TreeNodeKind.batchStep,
        label: event.title,
        rect: Rect.fromLTWH(centre, (1 + index) * rowStep, nodeW, stepH),
        color: componentInk,
        event: event,
      );
      nodes.add(node);
      edges.add((from: previous, to: node, color: componentInk));
      previous = node;
    }

    for (final (column, item) in ingredients.indexed) {
      final left = column * colStep;
      final steps = item.events.reversed.toList();
      var parent = previous;
      for (final (index, event) in steps.indexed) {
        final node = TreeNode(
          kind: TreeNodeKind.ingredientStep,
          label: event.title,
          rect: Rect.fromLTWH(left, (branchTop + index) * rowStep, nodeW, stepH),
          color: item.color,
          ingredientIndex: column,
          event: event,
        );
        nodes.add(node);
        edges.add((from: parent, to: node, color: item.color));
        parent = node;
      }
      final origin = TreeNode(
        kind: TreeNodeKind.ingredient,
        label: item.name,
        rect: Rect.fromLTWH(left, bottomRow * rowStep, nodeW, originH),
        color: item.color,
        ingredientIndex: column,
        ingredient: item,
      );
      nodes.add(origin);
      edges.add((from: parent, to: origin, color: item.color));
    }
  }

  final List<TreeNode> nodes = [];
  final List<({TreeNode from, TreeNode to, Color color})> edges = [];
  late final Size size;
  late final Rect originBand;
}

/// Lưới chấm rất mờ làm nền cho mặt phẳng sơ đồ.
class _DotGrid extends CustomPainter {
  const _DotGrid();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x14173529);
    const step = 22.0;
    for (var y = step; y < size.height; y += step) {
      for (var x = step; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGrid old) => false;
}

/// Nối hai nút bằng đường cong, mỗi nhánh mang màu của nguyên liệu nhánh đó.
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.edges,
    required this.selection,
    required this.originBand,
  });

  final List<({TreeNode from, TreeNode to, Color color})> edges;
  final TraceSelection selection;
  final Rect originBand;

  @override
  void paint(Canvas canvas, Size size) {
    // Dải nền gom nhóm vùng nguyên liệu.
    canvas.drawRRect(
      RRect.fromRectAndRadius(originBand, const Radius.circular(20)),
      Paint()..color = const Color(0x0F173529),
    );

    for (final edge in edges) {
      final touches =
          selection.matches(edge.to) || selection.matches(edge.from);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = touches ? 2.4 : 1.6
        ..color = touches
            ? componentOrange
            : edge.color.withValues(alpha: .38);

      final start = edge.from.bottomCenter;
      final end = edge.to.topCenter;
      final lift = (end.dy - start.dy) * 0.55;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx,
          start.dy + lift,
          end.dx,
          end.dy - lift,
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, paint);

      // Chấm tròn ở đầu mỗi cạnh: mắt bắt được điểm nối ngay cả khi đường
      // cong đi sát nhau ở chỗ rẽ nhánh.
      canvas.drawCircle(
        end,
        touches ? 3.2 : 2.2,
        Paint()
          ..color = touches ? componentOrange : edge.color.withValues(alpha: .5),
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edges != edges || old.selection != selection;
}

/// Một nút trên sơ đồ.
class _NodeChip extends StatefulWidget {
  const _NodeChip({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final TreeNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NodeChip> createState() => _NodeChipState();
}

class _NodeChipState extends State<_NodeChip> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final selected = widget.selected;
    final isProduct = node.kind == TreeNodeKind.product;
    final isOrigin = node.kind == TreeNodeKind.ingredient;

    final background = isProduct
        ? componentInk
        : isOrigin
        ? Colors.white
        : Colors.white;
    final border = selected
        ? componentOrange
        : isProduct
        ? componentInk
        : isOrigin
        ? node.color.withValues(alpha: .5)
        : brandLine;

    return Semantics(
      button: true,
      selected: selected,
      label: node.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: border, width: selected ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? componentOrange.withValues(alpha: .22)
                      : const Color(0x14173529),
                  blurRadius: selected || hovering ? 14 : 6,
                  offset: Offset(0, selected || hovering ? 4 : 2),
                ),
              ],
            ),
            child: isOrigin
                ? _OriginContent(node: node)
                : _StepContent(node: node, isProduct: isProduct),
          ),
        ),
      ),
    );
  }
}

/// Nội dung nút thành phẩm và nút công đoạn.
class _StepContent extends StatelessWidget {
  const _StepContent({required this.node, required this.isProduct});

  final TreeNode node;
  final bool isProduct;

  @override
  Widget build(BuildContext context) {
    final ink = isProduct ? Colors.white : componentInk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isProduct) ...[
            Text(
              'THÀNH PHẨM',
              style: TextStyle(
                color: componentOrange,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Flexible(
            child: Text(
              node.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontSize: isProduct ? 12.5 : 12.5,
                height: 1.22,
                fontWeight: isProduct ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nội dung nút gốc nhánh: ảnh nguyên liệu và nơi trồng.
class _OriginContent extends StatelessWidget {
  const _OriginContent({required this.node});

  final TreeNode node;

  @override
  Widget build(BuildContext context) {
    final item = node.ingredient;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          IngredientAvatar(
            name: node.label,
            icon: item?.icon ?? Icons.eco_outlined,
            color: node.color,
            size: 40,
            radius: 11,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    node.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: componentInk,
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if ((item?.origin ?? '').isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    item!.origin,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: brandMuted, fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({
    required this.onIn,
    required this.onOut,
    required this.onFit,
  });

  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _ZoomButton(icon: Icons.remove, tooltip: 'Thu nhỏ', onTap: onOut),
      const SizedBox(width: 6),
      _ZoomButton(icon: Icons.add, tooltip: 'Phóng to', onTap: onIn),
      const SizedBox(width: 6),
      _ZoomButton(
        icon: Icons.fit_screen_outlined,
        tooltip: 'Vừa khung',
        onTap: onFit,
      ),
    ],
  );
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: brandLine),
          ),
          child: Icon(icon, size: 17, color: componentInk),
        ),
      ),
    ),
  );
}
