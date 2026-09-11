import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data/geo_lookup.dart';
import '../data/trace_api.dart';
import '../models/ingredient_draft.dart';
import '../models/trace_models.dart';
import 'media_manager.dart';
import 'shared_components.dart';

/// Chỉ còn hai mục. Trước đây "Lô sản phẩm", "Nguyên liệu" và "Tính toàn vẹn"
/// là ba tab tách rời, nên tạo một lô phải chạy qua lại giữa chúng và mỗi tab
/// lại có một cách nhập khác nhau cho cùng một thứ.
enum AdminSection { overview, batches }

extension AdminSectionMeta on AdminSection {
  String get label => switch (this) {
    AdminSection.overview => 'Tổng quan',
    AdminSection.batches => 'Lô sản phẩm',
  };

  IconData get icon => switch (this) {
    AdminSection.overview => Icons.grid_view_rounded,
    AdminSection.batches => Icons.inventory_2_outlined,
  };
}

/// Rail trái. Bản cũ hardcode 'Tổng quan' luôn active và ba mục còn lại
/// không bấm được, nên trông như menu thật mà thực chất là hình trang trí.
class ManagementSidebar extends StatelessWidget {
  const ManagementSidebar({
    required this.section,
    required this.onSelect,
    required this.onExplorer,
    super.key,
  });

  final AdminSection section;
  final ValueChanged<AdminSection> onSelect;
  final VoidCallback onExplorer;

  @override
  Widget build(BuildContext context) => Container(
    width: 248,
    color: brandInkSoft,
    padding: const EdgeInsets.fromLTRB(20, 30, 16, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: TuleBrand(inverse: true),
        ),
        const SizedBox(height: 46),
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 12),
          child: Text(
            'WORKSPACE',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.6,
            ),
          ),
        ),
        for (final item in AdminSection.values)
          WorkspaceLink(
            icon: item.icon,
            label: item.label,
            active: item == section,
            onTap: () => onSelect(item),
          ),
        const Spacer(),
        const Text(
          'ADMIN / TÚ LỆ LAB',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onExplorer,
          icon: const Icon(Icons.open_in_new, color: componentLeaf, size: 17),
          label: const Text(
            'Mở explorer',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    ),
  );
}

class WorkspaceLink extends StatelessWidget {
  const WorkspaceLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    button: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: .12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: active ? componentLeaf : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 12),
              // Nhãn đậm khi active rộng hơn nhãn thường; không cho co lại thì
              // mục dài nhất tràn khỏi rail đúng lúc được chọn.
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Bốn ô số liệu. Ô hash tách riêng kiểu hiển thị vì nó là trạng thái,
/// không phải con số, để hàng thẻ không đọc như bốn ô giống hệt nhau.
class ManagementStats extends StatelessWidget {
  const ManagementStats({required this.summary, this.loading = false, super.key});
  final Map<String, dynamic>? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    String read(String key) {
      final value = summary?[key];
      if (loading || value == null) return '—';
      return value.toString();
    }

    final pending = summary?['pendingBlockchain'];
    final pendingCount = pending is int ? pending : 0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        StatCard(
          label: 'LÔ THÀNH PHẨM',
          value: read('products'),
          icon: Icons.inventory_2_outlined,
        ),
        StatCard(
          label: 'NGUYÊN LIỆU',
          value: read('ingredients'),
          icon: Icons.eco_outlined,
        ),
        StatCard(
          label: 'CÔNG ĐOẠN ĐÃ GHI',
          value: read('events'),
          icon: Icons.timeline_outlined,
        ),
        StatCard(
          label: 'HASH CHỜ LÊN CHUỖI',
          value: loading || summary == null ? '—' : '$pendingCount',
          caption: pendingCount > 0 ? 'đang chờ' : 'không có bản chờ',
          icon: Icons.shield_outlined,
          tone: pendingCount > 0 ? BadgeTone.pending : BadgeTone.positive,
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.tone,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final BadgeTone? tone;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      BadgeTone.pending => brandOrangeText,
      BadgeTone.danger => const Color(0xFF7A1F19),
      _ => componentInk,
    };
    return Container(
      width: 186,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: brandMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: .6,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: const TextStyle(fontSize: 11, color: brandMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Một dòng lô trong danh sách, bấm để chọn làm lô đang làm việc.
class BatchRow extends StatelessWidget {
  const BatchRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onOpenPublic,
    super.key,
  });

  final BatchListItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenPublic;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFEFF5EC) : brandSurface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? componentInk : brandLine),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: componentInk,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IntegrityBadge(
                        label: item.isPublished ? 'ĐÃ XONG' : 'ĐANG TẠO',
                        tone: item.isPublished
                            ? BadgeTone.positive
                            : BadgeTone.pending,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      item.code,
                      if (item.createdLabel.isNotEmpty)
                        'tạo ${item.createdLabel}',
                      if (item.productionDate.isNotEmpty)
                        'SX ${item.productionDate}',
                      '${item.ingredientCount} nguyên liệu',
                      '${item.eventCount} công đoạn',
                      if (item.version != null) 'v${item.version}',
                    ].join('  ·  '),
                    style: const TextStyle(color: brandMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Xem trang công khai',
              onPressed: onOpenPublic,
              icon: const Icon(Icons.open_in_new, size: 18),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Ô ngày dùng date picker thay vì bắt admin gõ tay đúng định dạng.
class DateField extends StatelessWidget {
  const DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
    this.validator,
    super.key,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final String? Function(String?)? validator;

  static String format(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  static DateTime? parse(String raw) {
    final parts = raw.split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: value,
    validator: validator,
    builder: (field) {
      // Giá trị do cha quản lý nên phải đồng bộ lại mỗi lần build.
      if (field.value != value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (field.mounted) field.didChange(value);
        });
      }
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: parse(value) ?? now,
            firstDate: DateTime(now.year - 3),
            lastDate: DateTime(now.year + 6),
            helpText: label,
          );
          if (picked == null) return;
          final formatted = format(picked);
          field.didChange(formatted);
          onChanged(formatted);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            errorText: field.errorText,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(
            value.isEmpty ? 'Chọn ngày' : value,
            style: TextStyle(
              color: value.isEmpty ? brandMuted : componentInk,
              fontWeight: value.isEmpty ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ),
      );
    },
  );
}

/// Ô nhập toạ độ cho vùng nguyên liệu hoặc nơi sản xuất.
///
/// Có nút điền nhanh theo tỉnh, nhưng nói rõ rằng toạ độ tâm tỉnh chỉ là vị trí
/// tương đối. Trang công khai cũng vẽ khác đi cho trường hợp đó, nên đừng dùng
/// nút này để giả vờ đã biết chính xác vùng trồng.
class LocationField extends StatelessWidget {
  const LocationField({
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.label = 'Toạ độ vùng nguyên liệu',
    this.areaGeoJson,
    super.key,
  });

  final double? latitude;
  final double? longitude;
  final void Function(double? latitude, double? longitude) onChanged;
  final String label;

  /// Vùng tự khoanh còn lại từ bản có bản đồ. Giữ để không mất dữ liệu của
  /// những lô đã công bố, nhưng không còn màn nào vẽ nó nữa.
  final String? areaGeoJson;

  bool get _hasValue => latitude != null && longitude != null;
  bool get _hasArea => (areaGeoJson ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: componentInk,
          fontSize: 13.5,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _CoordInput(
              label: 'Vĩ độ',
              value: latitude,
              limit: 90,
              onChanged: (value) => onChanged(value, longitude),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CoordInput(
              label: 'Kinh độ',
              value: longitude,
              limit: 180,
              onChanged: (value) => onChanged(latitude, value),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDialog<(String, double, double)>(
                context: context,
                builder: (_) => const _ProvincePicker(),
              );
              if (picked != null) onChanged(picked.$2, picked.$3);
            },
            icon: const Icon(Icons.place_outlined, size: 16),
            label: const Text('Điền theo tỉnh'),
          ),
          if (_hasValue)
            TextButton(
              onPressed: () => onChanged(null, null),
              child: const Text('Xoá toạ độ'),
            ),
        ],
      ),
      // Toạ độ nằm trong bản công bố nên vẫn đáng khai, dù trang khách giờ
      // hiện vùng nguyên liệu bằng ảnh chụp chứ không vẽ bản đồ.
      if (!_hasArea && !_hasValue) ...[
        const SizedBox(height: 6),
        const Text(
          'Toạ độ không bắt buộc; nó nằm trong bản công bố như một khai báo.',
          style: TextStyle(color: brandMuted, fontSize: 12),
        ),
      ],
    ],
  );
}

class _CoordInput extends StatefulWidget {
  const _CoordInput({
    required this.label,
    required this.value,
    required this.limit,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final double limit;
  final ValueChanged<double?> onChanged;

  @override
  State<_CoordInput> createState() => _CoordInputState();
}

class _CoordInputState extends State<_CoordInput> {
  late final controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void didUpdateWidget(_CoordInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.value?.toString() ?? '';
    // Giá trị do cha giữ, ví dụ khi bấm "Điền theo tỉnh".
    if (incoming != (double.tryParse(controller.text)?.toString() ?? '')) {
      controller.text = incoming;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: widget.label, isDense: true),
    validator: (raw) {
      final text = (raw ?? '').trim();
      if (text.isEmpty) return null;
      final parsed = double.tryParse(text);
      if (parsed == null) return 'Phải là số';
      if (parsed.abs() > widget.limit) return 'Ngoài phạm vi';
      return null;
    },
    onChanged: (raw) {
      final text = raw.trim();
      if (text.isEmpty) {
        widget.onChanged(null);
        return;
      }
      final parsed = double.tryParse(text);
      if (parsed != null && parsed.abs() <= widget.limit) {
        widget.onChanged(parsed);
      }
    },
  );
}

class _ProvincePicker extends StatefulWidget {
  const _ProvincePicker();

  @override
  State<_ProvincePicker> createState() => _ProvincePickerState();
}

class _ProvincePickerState extends State<_ProvincePicker> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final needle = foldVietnamese(query);
    final matches = provinceOptions
        .where((item) => needle.isEmpty || foldVietnamese(item.$1).contains(needle))
        .toList();

    return AlertDialog(
      title: const Text('Chọn tỉnh'),
      content: SizedBox(
        width: 380,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tìm tỉnh, gõ không dấu cũng được',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: matches.isEmpty
                  ? const Center(
                      child: Text(
                        'Không có tỉnh nào khớp.',
                        style: TextStyle(color: brandMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final item = matches[index];
                        return ListTile(
                          dense: true,
                          title: Text(item.$1),
                          subtitle: Text(
                            '${item.$2}, ${item.$3}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
      ],
    );
  }
}

/// Kết quả của hộp thoại tạo lô: phần thân request và lựa chọn tạo sẵn bốn
/// nguyên liệu quen thuộc.
class BatchFormValues {
  const BatchFormValues({required this.values, required this.withStarter});
  final Map<String, dynamic> values;
  final bool withStarter;
}

/// Hộp thoại tạo lô mới.
///
/// Chỉ hỏi những gì bắt buộc phải có ngay lúc tạo. Nguyên liệu, ảnh và công
/// đoạn nhập tiếp trong màn làm việc của lô, không nhồi hết vào một biểu mẫu
/// dài như bản cũ.
class BatchCreateDialog extends StatefulWidget {
  const BatchCreateDialog({
    required this.existingCodes,
    required this.suggestedCode,
    super.key,
  });

  final List<String> existingCodes;
  final String suggestedCode;

  static Future<BatchFormValues?> show(
    BuildContext context, {
    required List<String> existingCodes,
    required String suggestedCode,
  }) => showDialog<BatchFormValues>(
    context: context,
    builder: (_) => BatchCreateDialog(
      existingCodes: existingCodes,
      suggestedCode: suggestedCode,
    ),
  );

  @override
  State<BatchCreateDialog> createState() => _BatchCreateDialogState();
}

class _BatchCreateDialogState extends State<BatchCreateDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(
    text: 'Tú Lệ Smart Breakfast',
  );
  late final code = TextEditingController(text: widget.suggestedCode);
  final facility = TextEditingController(text: 'Trung tâm Phát triển và Giao dịch Công nghệ thành phố Hà Nội');
  String productionDate = DateField.format(DateTime.now());
  String expiryDate = DateField.format(
    DateTime.now().add(const Duration(days: 365)),
  );
  bool withStarter = true;

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    facility.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      BatchFormValues(
        values: {
          'name': name.text.trim(),
          'code': code.text.trim().toUpperCase(),
          'productionDate': productionDate,
          'expiryDate': expiryDate,
          'facilityName': facility.text.trim(),
          'latitude': 21.7167,
          'longitude': 104.2333,
        },
        withStarter: withStarter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tạo lô sản phẩm'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên lô'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Nhập tên lô để khách biết mình đang xem gì.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Mã truy xuất'),
                validator: (value) {
                  final raw = (value ?? '').trim().toUpperCase();
                  if (raw.isEmpty) return 'Nhập mã truy xuất.';
                  if (!RegExp(r'^[A-Z0-9-]{4,32}$').hasMatch(raw)) {
                    return 'Chỉ dùng chữ in hoa, số và dấu gạch ngang (4-32 ký tự).';
                  }
                  if (widget.existingCodes.contains(raw)) {
                    return 'Mã này đã có lô khác dùng.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DateField(
                      label: 'Ngày sản xuất',
                      value: productionDate,
                      onChanged: (value) =>
                          setState(() => productionDate = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Hạn sử dụng',
                      value: expiryDate,
                      onChanged: (value) => setState(() => expiryDate = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: facility,
                decoration: const InputDecoration(labelText: 'Nơi sản xuất'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: withStarter,
                onChanged: (value) =>
                    setState(() => withStarter = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Tạo sẵn bốn nguyên liệu Tú Lệ'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Huỷ'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Tạo lô')),
    ],
  );
}

/// Biểu mẫu thông tin lô, nằm ngay trong màn làm việc.
class BatchInfoForm extends StatefulWidget {
  const BatchInfoForm({
    required this.batch,
    required this.onSave,
    this.wide = true,
    super.key,
  });

  final ProductBatch batch;
  final bool wide;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  @override
  State<BatchInfoForm> createState() => _BatchInfoFormState();
}

class _BatchInfoFormState extends State<BatchInfoForm> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.batch.name);
  late final facility = TextEditingController(text: widget.batch.facilityName);
  late final description = TextEditingController(text: widget.batch.description);
  late String productionDate = widget.batch.productionDate;
  late String expiryDate = widget.batch.expiryDate;
  late double? latitude = widget.batch.latitude;
  late double? longitude = widget.batch.longitude;
  bool dirty = false;
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    facility.dispose();
    description.dispose();
    super.dispose();
  }

  void _touch() {
    if (!dirty) setState(() => dirty = true);
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    await widget.onSave({
      'name': name.text.trim(),
      'productionDate': productionDate,
      'expiryDate': expiryDate,
      'description': description.text.trim(),
      'facilityName': facility.text.trim(),
      'latitude': latitude,
      'longitude': longitude,
    });
    if (!mounted) return;
    setState(() {
      saving = false;
      dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dates = [
      DateField(
        label: 'Ngày sản xuất',
        value: productionDate,
        onChanged: (value) => setState(() {
          productionDate = value;
          dirty = true;
        }),
      ),
      DateField(
        label: 'Hạn sử dụng',
        value: expiryDate,
        onChanged: (value) => setState(() {
          expiryDate = value;
          dirty = true;
        }),
      ),
    ];

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: name,
            onChanged: (_) => _touch(),
            decoration: const InputDecoration(labelText: 'Tên lô'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Nhập tên lô.' : null,
          ),
          const SizedBox(height: 14),
          if (widget.wide)
            Row(
              children: [
                Expanded(child: dates[0]),
                const SizedBox(width: 12),
                Expanded(child: dates[1]),
              ],
            )
          else ...[dates[0], const SizedBox(height: 14), dates[1]],
          const SizedBox(height: 14),
          TextFormField(
            controller: facility,
            onChanged: (_) => _touch(),
            decoration: const InputDecoration(labelText: 'Nơi sản xuất'),
          ),
          const SizedBox(height: 14),
          LocationField(
            label: 'Toạ độ nơi sản xuất',
            latitude: latitude,
            longitude: longitude,
            onChanged: (lat, lng) => setState(() {
              latitude = lat;
              longitude = lng;
              dirty = true;
            }),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: description,
            onChanged: (_) => _touch(),
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Mô tả ngắn'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: dirty && !saving ? _save : null,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Lưu thông tin'),
              ),
              const SizedBox(width: 12),
              if (dirty)
                const Flexible(
                  child: Text(
                    'Chưa lưu',
                    style: TextStyle(color: brandOrangeText, fontSize: 12.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Một nguyên liệu đã lưu, kèm ảnh và các công đoạn của nó.
///
/// Đây là chỗ duy nhất để sửa nguyên liệu. Bản cũ có thêm một thẻ nháp riêng
/// lúc tạo lô, hai giao diện cho cùng một thứ nên rất dễ nhầm.
class IngredientEditorCard extends StatefulWidget {
  const IngredientEditorCard({
    required this.api,
    required this.item,
    required this.onChanged,
    required this.onEdit,
    required this.onRemove,
    required this.onAddEvent,
    required this.onRemoveEvent,
    required this.onEditEvent,
    super.key,
  });

  final TraceApi api;
  final Ingredient item;
  final Future<void> Function() onChanged;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onAddEvent;
  final void Function(ProcessEvent event) onRemoveEvent;
  final void Function(ProcessEvent event) onEditEvent;

  @override
  State<IngredientEditorCard> createState() => _IngredientEditorCardState();
}

class _IngredientEditorCardState extends State<IngredientEditorCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  IngredientAvatar(
                    name: item.name,
                    icon: item.icon,
                    color: item.color,
                    size: 40,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: componentInk,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (item.origin.isNotEmpty)
                              item.origin
                            else
                              'chưa có vùng nguyên liệu',
                            '${item.events.length} công đoạn',
                            '${item.media.length} ảnh',
                            if (item.areaMap == null)
                              'chưa có ảnh vùng',
                          ].join('  ·  '),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: brandMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sửa nguyên liệu',
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Xoá khỏi lô',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: brandMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 22),
                  // Đúng những trường mà trang khách hiện ra, để người vận hành
                  // biết dữ liệu đó nhập ở đâu thay vì phải đoán.
                  Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    children: [
                      InfoPill(
                        label: 'NHÀ CUNG CẤP',
                        value: item.supplier,
                      ),
                      InfoPill(label: 'THU HOẠCH', value: item.harvestDate),
                      InfoPill(label: 'NHẬP KHO', value: item.receivedDate),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Sửa thông tin nguyên liệu'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (item.id case final ingredientId?) ...[
                    MediaManager(
                      api: widget.api,
                      ownerType: 'ingredient_batch',
                      ownerId: ingredientId,
                      assets: item.media,
                      title: 'Ảnh vùng nguyên liệu',
                      allowAreaMap: true,
                      compactStrip: true,
                      onChanged: widget.onChanged,
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Text('Công đoạn', style: sectionTitleStyle),
                  const SizedBox(height: 10),
                  if (item.events.isEmpty)
                    const Text(
                      'Chưa có công đoạn nào.',
                      style: sectionCaptionStyle,
                    ),
                  for (final event in item.events)
                    BatchEventRow(
                      api: widget.api,
                      event: event,
                      onChanged: widget.onChanged,
                      onRemove: () => widget.onRemoveEvent(event),
                      onEdit: () => widget.onEditEvent(event),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onAddEvent,
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('Thêm công đoạn'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Một công đoạn kèm dải ảnh của nó. Dùng cho cả công đoạn của nguyên liệu
/// lẫn công đoạn ở xưởng.
class BatchEventRow extends StatelessWidget {
  const BatchEventRow({
    required this.api,
    required this.event,
    required this.onChanged,
    required this.onRemove,
    this.onEdit,
    super.key,
  });

  final TraceApi api;
  final ProcessEvent event;
  final Future<void> Function() onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;

  /// Dòng tóm tắt những gì đã nhập cho công đoạn này.
  String get _summary {
    final unit = event.quantityUnit.isEmpty ? 'g' : event.quantityUnit;
    return [
      if (event.eventDate.isNotEmpty) event.eventDate,
      if (event.operator.isNotEmpty) event.operator,
      if (event.inputQuantity != null) 'vào ${_num(event.inputQuantity!)} $unit',
      if (event.outputQuantity != null)
        'ra ${_num(event.outputQuantity!)} $unit',
      for (final entry in event.params.entries) '${entry.key} ${entry.value}',
    ].join('  ·  ');
  }

  static String _num(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: brandSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: brandLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: componentInk,
                      fontSize: 14,
                    ),
                  ),
                  if (_summary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      _summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: brandMuted, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                tooltip: 'Sửa chi tiết công đoạn',
                onPressed: onEdit,
                icon: const Icon(Icons.tune, size: 17),
              ),
            IconButton(
              tooltip: 'Xoá công đoạn',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 17),
            ),
          ],
        ),
        if (event.id case final eventId?) ...[
          const SizedBox(height: 8),
          MediaManager(
            api: api,
            ownerType: 'process_event',
            ownerId: eventId,
            assets: event.media,
            title: 'Ảnh công đoạn',
            compactStrip: true,
            onChanged: onChanged,
          ),
        ],
      ],
    ),
  );
}

/// Hộp thoại thêm hoặc sửa nguyên liệu, dùng chung cho cả hai việc.
class IngredientDialog extends StatefulWidget {
  const IngredientDialog({this.draft, super.key});
  final IngredientDraft? draft;

  static Future<IngredientDraft?> show(
    BuildContext context, {
    IngredientDraft? draft,
  }) => showDialog<IngredientDraft>(
    context: context,
    builder: (_) => IngredientDialog(draft: draft),
  );

  @override
  State<IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<IngredientDialog> {
  final formKey = GlobalKey<FormState>();
  late final IngredientDraft draft = widget.draft?.copy() ?? IngredientDraft();
  late final name = TextEditingController(text: draft.name);
  late final origin = TextEditingController(text: draft.origin);
  late final supplier = TextEditingController(text: draft.supplier);
  late final summary = TextEditingController(text: draft.summary);

  @override
  void dispose() {
    name.dispose();
    origin.dispose();
    supplier.dispose();
    summary.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    draft
      ..name = name.text.trim()
      ..origin = origin.text.trim()
      ..supplier = supplier.text.trim()
      ..summary = summary.text.trim();
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.draft == null ? 'Thêm nguyên liệu' : 'Sửa ${widget.draft!.name}',
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên nguyên liệu'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Nhập tên nguyên liệu.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: origin,
                decoration: const InputDecoration(
                  labelText: 'Vùng nguyên liệu',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Nhập vùng nguyên liệu để tra được vị trí.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: supplier,
                decoration: const InputDecoration(labelText: 'Đơn vị cung cấp'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DateField(
                      label: 'Ngày thu hoạch',
                      value: draft.harvestDate,
                      onChanged: (value) =>
                          setState(() => draft.harvestDate = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Ngày nhập kho',
                      value: draft.receivedDate,
                      onChanged: (value) =>
                          setState(() => draft.receivedDate = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LocationField(
                latitude: draft.latitude,
                longitude: draft.longitude,
                areaGeoJson: draft.areaGeoJson,
                onChanged: (lat, lng) => setState(() {
                  draft.latitude = lat;
                  draft.longitude = lng;
                }),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: summary,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Mô tả ngắn'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Huỷ'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.draft == null ? 'Thêm' : 'Lưu'),
      ),
    ],
  );
}

/// Nội dung một công đoạn vừa nhập.
typedef EventFormValues = ({
  String title,
  String description,
  String date,
  String operator,
  double? inputQuantity,
  double? outputQuantity,
  String quantityUnit,
  Map<String, String> params,
});

/// Body gửi lên API cho cả tạo mới lẫn sửa. Trường để trống gửi chuỗi rỗng
/// hoặc null, đó là cách xoá giá trị đã nhập.
Map<String, dynamic> eventBody(EventFormValues form) => {
  'title': form.title,
  'description': form.description,
  'eventDate': form.date,
  'operator': form.operator,
  'inputQuantity': form.inputQuantity,
  'outputQuantity': form.outputQuantity,
  'quantityUnit': form.quantityUnit,
  'params': form.params.isEmpty ? null : form.params,
};

/// Hộp thoại ghi một công đoạn cho nguyên liệu.
class EventDialog extends StatefulWidget {
  const EventDialog({required this.ingredientName, this.initial, super.key});

  final String ingredientName;

  /// Null là thêm công đoạn mới. Có giá trị là sửa công đoạn đã có, trường
  /// hợp hay gặp hơn vì bộ công đoạn đã được tạo sẵn theo sơ đồ quy trình.
  final ProcessEvent? initial;

  static Future<EventFormValues?> show(
    BuildContext context,
    String ingredientName, {
    ProcessEvent? initial,
  }) => showDialog<EventFormValues>(
    context: context,
    builder: (_) =>
        EventDialog(ingredientName: ingredientName, initial: initial),
  );

  @override
  State<EventDialog> createState() => _EventDialogState();
}

/// Một dòng tham số kỹ thuật đang soạn.
class _ParamRow {
  _ParamRow([String name = '', String value = ''])
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  final TextEditingController name;
  final TextEditingController value;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _EventDialogState extends State<EventDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController operator;
  late final TextEditingController inputQuantity;
  late final TextEditingController outputQuantity;
  late final TextEditingController quantityUnit;
  late final List<_ParamRow> params;
  late String date;

  @override
  void initState() {
    super.initState();
    final source = widget.initial;
    title = TextEditingController(text: source?.title ?? '');
    description = TextEditingController(text: source?.description ?? '');
    operator = TextEditingController(text: source?.operator ?? '');
    inputQuantity = TextEditingController(text: _number(source?.inputQuantity));
    outputQuantity = TextEditingController(
      text: _number(source?.outputQuantity),
    );
    quantityUnit = TextEditingController(text: source?.quantityUnit ?? 'g');
    params = [
      for (final entry in (source?.params ?? const <String, String>{}).entries)
        _ParamRow(entry.key, entry.value),
    ];
    date = source != null && source.eventDate.isNotEmpty
        ? source.eventDate
        : DateField.format(DateTime.now());
  }

  /// Bỏ đuôi `.0` cho số nguyên: khối lượng 500 g không nên hiện là 500.0.
  static String _number(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toString();
  }

  static double? _parse(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String? _validateAmount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = _parse(text);
    if (parsed == null) return 'Chỉ nhập số.';
    if (parsed < 0) return 'Không âm.';
    return null;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    operator.dispose();
    inputQuantity.dispose();
    outputQuantity.dispose();
    quantityUnit.dispose();
    for (final row in params) {
      row.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final collected = <String, String>{};
    for (final row in params) {
      final name = row.name.text.trim();
      final value = row.value.text.trim();
      if (name.isNotEmpty && value.isNotEmpty) collected[name] = value;
    }
    Navigator.of(context).pop((
      title: title.text.trim(),
      description: description.text.trim(),
      date: date,
      operator: operator.text.trim(),
      inputQuantity: _parse(inputQuantity.text),
      outputQuantity: _parse(outputQuantity.text),
      quantityUnit: quantityUnit.text.trim(),
      params: collected,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(
        editing ? title.text : 'Công đoạn của ${widget.ingredientName}',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: title,
                  autofocus: !editing,
                  decoration: const InputDecoration(
                    labelText: 'Tên công đoạn',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Nhập tên công đoạn.'
                      : null,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DateField(
                        label: 'Ngày thực hiện',
                        value: date,
                        onChanged: (value) => setState(() => date = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: operator,
                        decoration: const InputDecoration(
                          labelText: 'Người thực hiện',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: inputQuantity,
                        decoration: const InputDecoration(
                          labelText: 'Khối lượng vào',
                        ),
                        validator: _validateAmount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: outputQuantity,
                        decoration: const InputDecoration(
                          labelText: 'Khối lượng ra',
                        ),
                        validator: _validateAmount,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: quantityUnit,
                        decoration: const InputDecoration(labelText: 'Đơn vị'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Tham số kỹ thuật', style: sectionTitleStyle),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => params.add(_ParamRow())),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Thêm dòng'),
                    ),
                  ],
                ),
                for (final (index, row) in params.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: row.name,
                            decoration: const InputDecoration(
                              labelText: 'Nhãn',
                              hintText: 'Nhiệt độ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: row.value,
                            decoration: const InputDecoration(
                              labelText: 'Giá trị',
                              hintText: '80-90°C',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Xoá dòng',
                          onPressed: () => setState(() {
                            params.removeAt(index).dispose();
                          }),
                          icon: const Icon(Icons.close, size: 17),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: description,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? 'Lưu công đoạn' : 'Ghi nhận'),
        ),
      ],
    );
  }
}

/// Tình trạng ghi lên chuỗi của một bản niêm phong.
///
/// Đọc thẳng từ hàng đợi `blockchain_outbox` chứ không suy đoán: chừng nào
/// chưa có mạng nào được cấu hình thì mọi bản đều nằm ở `PENDING_NETWORK`.
class ChainStatusLine extends StatelessWidget {
  const ChainStatusLine({
    required this.snapshots,
    required this.chain,
    this.onSend,
    this.sending = false,
    super.key,
  });

  final List<Map<String, dynamic>> snapshots;

  /// Trạng thái ví và mạng lấy từ /admin/chain. Rỗng nghĩa là chưa gọi được.
  final Map<String, dynamic> chain;
  final VoidCallback? onSend;
  final bool sending;

  String get _explorer => (chain['explorer'] ?? '').toString().replaceAll(RegExp(r'/\$'), '');

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) return const SizedBox.shrink();
    final latest = snapshots.first;
    final tx = (latest['txHash'] ?? '').toString();
    final onChain = tx.isNotEmpty;
    final configured = chain['configured'] == true;
    final reachable = chain['reachable'] == true;

    final (background, icon, colour, message) = switch ((onChain, configured, reachable)) {
      (true, _, _) => (
        brandPanel,
        Icons.link,
        componentInk,
        'Đã lưu lên blockchain.',
      ),
      (false, false, _) => (
        const Color(0xFFFFF0E3),
        Icons.settings_ethernet,
        brandOrangeText,
        'Chưa cấu hình mạng blockchain, mã băm đang nằm ở hàng chờ.',
      ),
      (false, true, false) => (
        const Color(0xFFFBE6E4),
        Icons.cloud_off,
        const Color(0xFF7A1F19),
        'Không gọi được mạng blockchain. ${chain['error'] ?? ''}',
      ),
      _ => (
        const Color(0xFFFFF0E3),
        Icons.schedule,
        brandOrangeText,
        chain['autoAnchor'] == false
            ? 'Đang chờ lưu lên blockchain. Môi trường này tắt gửi tự động, bấm "Gửi lên chuỗi" khi cần.'
            : 'Đang chờ lưu lên blockchain.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: colour),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colour, fontSize: 12.5, height: 1.4),
                ),
              ),
              if (onChain && _explorer.isNotEmpty)
                TextButton(
                  onPressed: () => launchUrlString(
                    '$_explorer/tx/$tx',
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Xem giao dịch'),
                )
              else if (!onChain && onSend != null)
                TextButton(
                  onPressed: sending ? null : onSend,
                  child: Text(sending ? 'Đang gửi' : 'Gửi lên chuỗi'),
                ),
            ],
          ),
          if (configured) ...[
            const SizedBox(height: 6),
            Text(
              'Ví ${_short(chain['address'])} · mạng ${chain['chainId'] ?? '?'}'
              '${chain['balance'] == null ? '' : ' · còn ${_vnx(chain['balance'])} VNX'}',
              style: TextStyle(color: colour.withValues(alpha: .8), fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  static String _short(Object? address) {
    final value = (address ?? '').toString();
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
  }

  /// Số dư trả về là wei dạng chuỗi, đổi sang VNX cho người đọc.
  static String _vnx(Object? wei) {
    final value = BigInt.tryParse((wei ?? '').toString()) ?? BigInt.zero;
    final whole = value ~/ BigInt.from(10).pow(18);
    final frac = (value % BigInt.from(10).pow(18))
        .toString()
        .padLeft(18, '0')
        .substring(0, 4);
    return '$whole.$frac';
  }
}

/// Danh sách các bản đã niêm phong, mới nhất trước.
class SealHistory extends StatelessWidget {
  const SealHistory({
    required this.snapshots,
    this.explorer = '',
    this.onOpen,
    super.key,
  });

  final List<Map<String, dynamic>> snapshots;
  final String explorer;

  /// Mở nội dung của một bản cũ. Snapshot lưu nguyên payload, nên đây là cách
  /// xem lại lô lúc đó trông thế nào, không phải dựng lại từ trí nhớ.
  final void Function(int version)? onOpen;

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lịch sử',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: componentInk,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in snapshots.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    'v${item['version']}',
                    style: monoStyle.copyWith(fontSize: 13),
                  ),
                ),
                if (onOpen != null && item['version'] is int)
                  IconButton(
                    tooltip: 'Xem nội dung bản này',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onOpen!(item['version'] as int),
                    icon: const Icon(Icons.history, size: 16),
                  ),
                Expanded(
                  child: Text(
                    [
                      _shortHash(item['sha256']?.toString() ?? ''),
                      if ((item['publishedAt'] ?? '').toString().isNotEmpty)
                        _readableStamp(item['publishedAt'].toString()),
                    ].join('  ·  '),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: brandMuted, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                if ((item['txHash'] ?? '').toString().isNotEmpty &&
                    explorer.isNotEmpty)
                  InkWell(
                    onTap: () => launchUrlString(
                      '$explorer/tx/${item['txHash']}',
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const IntegrityBadge(
                      label: 'ĐÃ LƯU CHUỖI',
                      tone: BadgeTone.positive,
                    ),
                  )
                else
                  IntegrityBadge(
                    label: switch ((item['chainStatus'] ?? '').toString()) {
                      'FAILED' => 'GỬI HỎNG',
                      'SKIPPED' => 'BỎ QUA',
                      _ => 'CHỜ LƯU CHUỖI',
                    },
                    tone: (item['chainStatus'] ?? '') == 'FAILED'
                        ? BadgeTone.danger
                        : BadgeTone.pending,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String _shortHash(String hash) =>
      hash.length <= 16 ? hash : '${hash.substring(0, 8)}…${hash.substring(hash.length - 6)}';

  static String _readableStamp(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}

/// Thanh lọc của danh sách lô: tìm theo mã hoặc tên, đổi cách sắp xếp.
class BatchFilterBar extends StatelessWidget {
  const BatchFilterBar({
    required this.controller,
    required this.sort,
    required this.onSearch,
    required this.onSort,
    required this.total,
    super.key,
  });

  final TextEditingController controller;
  final String sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSort;
  final int total;

  static const options = <({String value, String label})>[
    (value: 'newest', label: 'Mới tạo trước'),
    (value: 'oldest', label: 'Cũ nhất trước'),
    (value: 'name', label: 'Tên A tới Z'),
    (value: 'code', label: 'Mã lô'),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 44,
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm mã lô hoặc tên',
              prefixIcon: const Icon(Icons.search, size: 19),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xoá tìm kiếm',
                      icon: const Icon(Icons.close, size: 17),
                      onPressed: () {
                        controller.clear();
                        onSearch('');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        height: 44,
        child: DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: brandSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: brandLine),
            ),
            child: DropdownButton<String>(
              value: sort,
              onChanged: (value) => value == null ? null : onSort(value),
              icon: const Icon(Icons.sort, size: 18),
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(color: componentInk, fontSize: 13.5),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option.value,
                    child: Text(option.label),
                  ),
              ],
            ),
          ),
        ),
      ),
      if (total > 0) ...[
        const SizedBox(width: 14),
        Text(
          '$total lô',
          style: const TextStyle(color: brandMuted, fontSize: 13),
        ),
      ],
    ],
  );
}

/// Chuyển trang. Số lô sẽ tăng theo từng vụ nên danh sách không thể một trang.
class BatchPager extends StatelessWidget {
  const BatchPager({
    required this.page,
    required this.pages,
    required this.onChange,
    super.key,
  });

  final int page;
  final int pages;
  final ValueChanged<int>? onChange;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'Trang trước',
        onPressed: page > 1 && onChange != null ? () => onChange!(page - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        'Trang $page / $pages',
        style: const TextStyle(color: brandMuted, fontSize: 13),
      ),
      IconButton(
        tooltip: 'Trang sau',
        onPressed: page < pages && onChange != null
            ? () => onChange!(page + 1)
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}
