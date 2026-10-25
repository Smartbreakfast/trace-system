import 'package:flutter/material.dart';

import '../models/trace_models.dart';
import 'tule_theme.dart';

/// Màn Chỉ số: những con số đưa vào báo cáo, đọc thẳng từ hệ thống.
///
/// Chia làm hai nửa và cố ý không trộn vào nhau. Nửa trên là thứ hệ thống tự
/// đếm được, nửa dưới là thứ phải hỏi cơ sở sản xuất. Trộn hai nửa lại thì
/// người đọc báo cáo không còn phân biệt được số nào đo được, số nào do người
/// khai — mà đó đúng là chỗ người chấm soi đầu tiên.

/// Giá trị người dùng nhập khi khai một chỉ số.
class MetricDraft {
  const MetricDraft({
    required this.key,
    required this.label,
    required this.value,
    required this.source,
    required this.note,
  });

  final String key;
  final String label;
  final String value;
  final String source;
  final String note;
}

class MetricsPanel extends StatelessWidget {
  const MetricsPanel({
    required this.report,
    required this.loading,
    required this.canEdit,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final MetricsReport? report;
  final bool loading;

  /// Chỉ quản trị hệ thống mới khai được chỉ số; phụ trách cơ sở chỉ xem.
  final bool canEdit;
  final VoidCallback onAdd;
  final void Function(ReportedMetric metric) onEdit;
  final void Function(ReportedMetric metric) onDelete;

  @override
  Widget build(BuildContext context) {
    final data = report;
    if (loading && data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final views = data?.byBatch ?? const <BatchViews>[];
    final reported = data?.reported ?? const <ReportedMetric>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chỉ số', style: pageTitleStyle),
        const SizedBox(height: 8),
        const Text(
          'Các con số dùng cho báo cáo. Phần trên hệ thống tự đếm, phần dưới do '
          'cơ sở sản xuất cung cấp và luôn ghi kèm nguồn.',
          style: TextStyle(color: brandMuted, height: 1.5),
        ),
        const SizedBox(height: 22),

        const _Heading(
          'Hệ thống tự đếm',
          'Đếm số lần hồ sơ lô được mở. Không ghi IP, không ghi thiết bị, '
              'không ghi thời điểm từng lượt.',
        ),
        const SizedBox(height: 12),
        _TotalCard(total: data?.totalViews ?? 0, batches: views.length),
        const SizedBox(height: 14),
        if (views.isEmpty)
          const Text(
            'Chưa có lượt nào. Bộ đếm bắt đầu từ lúc được bật, nên số của '
            'giai đoạn trước vẫn phải lấy ở Cloudflare và khai ở phần dưới.',
            style: TextStyle(color: brandMuted, height: 1.5),
          )
        else
          for (final row in views) _ViewRow(row: row),

        const SizedBox(height: 30),
        Row(
          children: [
            const Expanded(
              child: _Heading(
                'Cơ sở sản xuất cung cấp',
                'Những số hệ thống không đo được: khách đã mua, phiếu khảo '
                    'sát, lượt truy cập trước khi bật bộ đếm.',
              ),
            ),
            if (canEdit)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Khai chỉ số'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (reported.isEmpty)
          const Text(
            'Chưa khai chỉ số nào.',
            style: TextStyle(color: brandMuted),
          )
        else
          for (final metric in reported)
            _MetricRow(
              metric: metric,
              canEdit: canEdit,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.note);

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: sectionTitleStyle),
      const SizedBox(height: 4),
      Text(note, style: const TextStyle(color: brandMuted, height: 1.5)),
    ],
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.batches});

  final int total;
  final int batches;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    decoration: BoxDecoration(
      color: brandPanel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: brandLine),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$total',
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            color: componentInk,
            height: 1,
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            batches == 0
                ? 'lượt mở hồ sơ'
                : 'lượt mở hồ sơ, trên $batches lô',
            style: const TextStyle(color: brandMuted),
          ),
        ),
      ],
    ),
  );
}

class _ViewRow extends StatelessWidget {
  const _ViewRow({required this.row});

  final BatchViews row;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: brandSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: brandLine),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.code,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: componentInk,
                ),
              ),
              if (row.name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    row.name,
                    style: const TextStyle(color: brandMuted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        Text(
          '${row.views}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: componentInk,
          ),
        ),
        const SizedBox(width: 6),
        const Text('lượt', style: TextStyle(color: brandMuted, fontSize: 13)),
      ],
    ),
  );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.metric,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final ReportedMetric metric;
  final bool canEdit;
  final void Function(ReportedMetric metric) onEdit;
  final void Function(ReportedMetric metric) onDelete;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
    decoration: BoxDecoration(
      color: brandSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: brandLine),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    metric.value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: componentInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      metric.label,
                      style: const TextStyle(color: componentInk),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Nguồn: ${metric.source}',
                style: const TextStyle(
                  color: brandOrangeText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (metric.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    metric.note,
                    style: const TextStyle(
                      color: brandMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              if (metric.updatedBy.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${metric.updatedBy} khai ${_shortTime(metric.updatedAt)}',
                    style: const TextStyle(color: brandMuted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        if (canEdit) ...[
          IconButton(
            tooltip: 'Sửa',
            onPressed: () => onEdit(metric),
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Xoá',
            onPressed: () => onDelete(metric),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ],
    ),
  );
}

/// Hộp khai một chỉ số. Ô nguồn bắt buộc, cùng lý do với máy chủ: một con số
/// không nói được nó lấy ở đâu thì không đưa vào báo cáo được.
class MetricDialog extends StatefulWidget {
  const MetricDialog({this.existing, super.key});

  final ReportedMetric? existing;

  @override
  State<MetricDialog> createState() => _MetricDialogState();
}

class _MetricDialogState extends State<MetricDialog> {
  late final TextEditingController _key = TextEditingController(
    text: widget.existing?.key ?? '',
  );
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late final TextEditingController _value = TextEditingController(
    text: widget.existing?.value ?? '',
  );
  late final TextEditingController _source = TextEditingController(
    text: widget.existing?.source ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    _label.dispose();
    _value.dispose();
    _source.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final key = _key.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9-]{2,40}$').hasMatch(key)) {
      setState(() => _error = 'Mã chỉ số chỉ gồm chữ thường, số và gạch ngang.');
      return;
    }
    if (_label.text.trim().isEmpty || _value.text.trim().isEmpty) {
      setState(() => _error = 'Phải có tên chỉ số và giá trị.');
      return;
    }
    if (_source.text.trim().isEmpty) {
      setState(() => _error = 'Phải ghi nguồn của số liệu này.');
      return;
    }
    Navigator.of(context).pop(
      MetricDraft(
        key: key,
        label: _label.text.trim(),
        value: _value.text.trim(),
        source: _source.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Khai chỉ số' : 'Sửa chỉ số'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _key,
              enabled: widget.existing == null,
              decoration: const InputDecoration(
                labelText: 'Mã chỉ số',
                hintText: 'nguoi-khao-sat',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Tên chỉ số',
                hintText: 'Số người tham gia khảo sát',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _value,
              decoration: const InputDecoration(
                labelText: 'Giá trị',
                hintText: '1.315 người',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _source,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nguồn số liệu (bắt buộc)',
                hintText: 'Phiếu khảo sát khách hàng do cơ sở cung cấp, 10/2026',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                hintText: 'Cách thu thập, khoảng thời gian, ai cung cấp',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFF7A1F19)),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Thôi'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Lưu')),
    ],
  );
}

String _shortTime(String iso) {
  final at = DateTime.tryParse(iso);
  if (at == null) return iso;
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
