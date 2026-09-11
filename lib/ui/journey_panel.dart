import 'package:flutter/material.dart';

import '../models/trace_models.dart';
import 'shared_components.dart';

/// Panel kết quả theo bản thiết kế: nhãn nhỏ, tên lô kiểu chữ serif, thẻ xác
/// minh, dải thông tin lô, rồi danh sách hành trình có số thứ tự.
///
/// Tách khỏi sourcing_section vì phần này giờ đủ dài để đứng riêng, và vì nó
/// chỉ phụ thuộc dữ liệu chứ không dính gì tới bản đồ.

/// Nhãn nhỏ in hoa phía trên tiêu đề.
class PanelEyebrow extends StatelessWidget {
  const PanelEyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      letterSpacing: 1.6,
      fontWeight: FontWeight.w700,
      color: brandMuted,
    ),
  );
}

/// Thẻ trạng thái kiểm chứng ở góc phải tiêu đề.
class VerifiedCard extends StatelessWidget {
  const VerifiedCard({required this.integrity, super.key});
  final IntegrityRecord integrity;

  @override
  Widget build(BuildContext context) {
    final (background, border, icon, label, note) = switch (integrity.status) {
      IntegrityStatus.verified => (
        const Color(0xFFDFF0D6),
        const Color(0xFFA9CE94),
        Icons.check_circle,
        'ĐÃ XÁC MINH',
        'Dữ liệu lô hàng khớp với bản ghi đã công bố.',
      ),
      IntegrityStatus.mismatch => (
        const Color(0xFFFBE6E4),
        const Color(0xFFE4B4AE),
        Icons.error,
        'DỮ LIỆU SAI LỆCH',
        'Dữ liệu hiện tại khác bản đã công bố.',
      ),
      IntegrityStatus.notPublished => (
        const Color(0xFFFFF2E5),
        const Color(0xFFF0CCA6),
        Icons.edit_note,
        'ĐANG TẠO',
        'Lô chưa công bố bản nào.',
      ),
      IntegrityStatus.unknown => (
        const Color(0xFFEFEEE8),
        brandLine,
        Icons.help,
        'CHƯA KIỂM CHỨNG',
        'Không lấy được kết quả từ máy chủ.',
      ),
    };

    return Container(
      // Rộng vừa đủ chứ không cố định: nhãn "DỮ LIỆU SAI LỆCH" dài hơn "ĐÃ XÁC
      // MINH" và không được phép bị cắt.
      constraints: const BoxConstraints(minWidth: 196, maxWidth: 238),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                    color: componentInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: brandMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dải mã lô, ngày sản xuất, hạn dùng.
class BatchFactRow extends StatelessWidget {
  const BatchFactRow({required this.batch, super.key});
  final ProductBatch batch;

  @override
  Widget build(BuildContext context) {
    List<Widget> cellsFor(bool dense) => [
      _Fact(
        label: 'MÃ LÔ',
        value: batch.code,
        mono: true,
        dense: dense,
      ),
      if (batch.productionDate.isNotEmpty)
        _Fact(
          label: 'SẢN XUẤT',
          value: batch.productionDate,
          icon: dense ? null : Icons.calendar_today_outlined,
          dense: dense,
        ),
      if (batch.expiryDate.isNotEmpty)
        _Fact(
          label: 'HẠN DÙNG',
          value: batch.expiryDate,
          icon: dense ? null : Icons.calendar_today_outlined,
          dense: dense,
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: brandSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1F173529)),
      ),
      // Ba ô xếp ngang chỉ đọc được khi mỗi ô còn hơn trăm pixel. Panel hẹp
      // thì xếp dọc, thà cao thêm một chút còn hơn cắt mã lô thành "TL-2026…".
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, cell) in cellsFor(true).indexed) ...[
                  if (index > 0) ...[
                    const SizedBox(height: 9),
                    Container(height: 1, color: brandLine),
                    const SizedBox(height: 9),
                  ],
                  cell,
                ],
              ],
            );
          }
          return Row(
            children: [
              for (final (index, cell) in cellsFor(false).indexed) ...[
                if (index > 0) Container(width: 1, height: 34, color: brandLine),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 14),
                    child: cell,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.icon,
    this.mono = false,
    this.dense = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool mono;

  /// Nhãn và giá trị nằm cùng một dòng. Dùng khi panel hẹp: xếp dọc ba ô mỗi
  /// ô hai dòng thì thẻ cao gấp đôi phần hành trình bên dưới nó.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (dense) {
      return Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: brandMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: mono ? 15 : 14,
                fontWeight: FontWeight.w700,
                color: componentInk,
                letterSpacing: mono ? .4 : 0,
              ),
            ),
          ),
        ],
      );
    }
    return _stacked();
  }

  Widget _stacked() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: brandMuted,
        ),
      ),
      const SizedBox(height: 5),
      Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: brandMuted),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: mono ? 17 : 15,
                fontWeight: FontWeight.w700,
                color: componentInk,
                letterSpacing: mono ? .2 : 0,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Tiêu đề khối có vạch cam bên trái và một nhãn đếm bên phải.
class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.title, this.trailing, super.key});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: componentOrange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: componentInk,
            ),
          ),
        ),
      ],
    );

    // Màn hẹp thì nhãn đếm xuống dòng, không ép tiêu đề co lại tới mức khó đọc.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [heading, if (trailing != null) _CountPill(trailing!)],
    );
  }
}

/// Nhãn đếm nhỏ cạnh tiêu đề mục.
class _CountPill extends StatelessWidget {
  const _CountPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F3EE),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: brandMuted,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
