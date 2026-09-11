import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/file_download.dart';
import '../models/trace_models.dart';
import '../data/qr_scanner.dart';
import 'shared_components.dart';

/// Ô tra cứu thật: chuẩn hoá mã, kiểm tra định dạng rồi gọi ra ngoài.
/// Bản cũ chỉ so chuỗi với 'TL-2026-001' và in một câu thông báo.
class TraceSearch extends StatefulWidget {
  const TraceSearch({
    required this.onSubmit,
    this.initialCode = '',
    this.busy = false,
    this.dense = false,
    super.key,
  });

  final ValueChanged<String> onSubmit;
  final String initialCode;
  final bool busy;

  /// Bản gọn dùng trong navbar: hẹp và thấp hơn để không đội thanh lên.
  final bool dense;

  @override
  State<TraceSearch> createState() => _TraceSearchState();
}

class _TraceSearchState extends State<TraceSearch> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialCode,
  );
  final focus = FocusNode();
  String? error;
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    // Viền đổi theo tiêu điểm nên phải vẽ lại lúc vào/ra ô.
    focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  /// Mã in trên bao bì hay bị nhập kèm khoảng trắng hoặc chữ thường.
  static String normalize(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  /// Quét bằng camera rồi tra cứu luôn: người dùng vừa chĩa máy vào bao bì,
  /// bắt họ bấm thêm một nút nữa là thừa.
  Future<void> _scan() async {
    setState(() {
      scanning = true;
      error = null;
    });
    try {
      final raw = await scanQrCode();
      if (!mounted) return;
      final code = raw == null ? '' : codeFromScan(raw);
      if (code.isEmpty) return;
      controller.text = code;
      widget.onSubmit(code);
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  void _submit() {
    final code = normalize(controller.text);
    if (code.isEmpty) {
      setState(() => error = 'Nhập mã in trên bao bì, ví dụ TL-2026-001.');
      focus.requestFocus();
      return;
    }
    if (code.length < 4) {
      setState(() => error = 'Mã truy xuất quá ngắn, kiểm tra lại giúp mình.');
      return;
    }
    setState(() => error = null);
    widget.onSubmit(code);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.compact;
    final focused = focus.hasFocus;
    final height = widget.dense ? 54.0 : 58.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Một khối liền thay cho TextField mặc định: ô chữ, nút quét và nút
        // tra cứu nằm trong cùng một đường viền nên đọc ra là một việc, không
        // phải ba thứ rời nhau đặt cạnh nhau.
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: height,
          decoration: BoxDecoration(
            color: brandSurface,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: error != null
                  ? const Color(0xFFA02A22)
                  : focused
                  ? landingTeal
                  : landingLine2,
              width: focused || error != null ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: landingInk.withValues(alpha: focused ? .10 : .05),
                blurRadius: focused ? 18 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _LeadingScan(
                scanning: scanning,
                onScan: qrScanSupported && !scanning ? _scan : null,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                  style: monoStyle.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: compact ? 'Nhập mã lô' : 'Nhập mã lô, ví dụ TL-2026-001',
                    hintStyle: const TextStyle(
                      color: brandMuted,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.all(5),
                child: _SubmitButton(
                  compact: compact,
                  busy: widget.busy,
                  height: height - 10,
                  onTap: widget.busy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 18),
            child: Text(
              error!,
              style: const TextStyle(
                color: Color(0xFFA02A22),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Đầu ô: nút quét mã khi máy có camera, không thì chỉ là dấu hiệu cho biết
/// mã này in kèm mã QR.
class _LeadingScan extends StatelessWidget {
  const _LeadingScan({required this.scanning, this.onScan});

  final bool scanning;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    if (scanning) {
      return const SizedBox(
        width: 52,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (onScan == null) {
      return const SizedBox(
        width: 52,
        child: Center(
          child: Icon(Icons.qr_code_2, size: 21, color: brandMuted),
        ),
      );
    }
    return Tooltip(
      message: 'Quét mã QR trên bao bì',
      child: InkWell(
        onTap: onScan,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 52,
          child: Center(
            child: Icon(Icons.qr_code_scanner, size: 21, color: componentInk),
          ),
        ),
      ),
    );
  }
}

/// Nút tra cứu nằm trong ô, bám sát mép phải.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.compact,
    required this.busy,
    required this.height,
    this.onTap,
  });

  final bool compact;
  final bool busy;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Material(
      color: landingTeal,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          height: height,
          width: compact ? height : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 18),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : compact
                  ? const Icon(Icons.search, size: 20, color: Colors.white)
                  : const Text(
                      'Tra cứu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class IntegrityPanel extends StatelessWidget {
  const IntegrityPanel({
    required this.integrity,
    this.onVerify,
    this.verifying = false,
    this.showChain = true,
    this.showHash = false,
    super.key,
  });

  final IntegrityRecord integrity;
  final VoidCallback? onVerify;
  final bool verifying;

  /// Màn quản trị có dòng blockchain riêng, đủ chi tiết hơn, nên tắt dòng này
  /// ở đó để không nói hai lần cùng một chuyện.
  final bool showChain;

  /// Ô mã băm copy được. Chỉ bật ở màn quản trị, nơi người ta thật sự dán nó
  /// vào script kiểm chứng.
  final bool showHash;

  @override
  Widget build(BuildContext context) {
    final (background, icon, title, body) = switch (integrity.status) {
      IntegrityStatus.verified => (
        brandPanel,
        Icons.verified_outlined,
        'Dữ liệu khớp với bản đã công bố',
        'Mã băm tính lại trùng với bản ghi lúc công bố.',
      ),
      IntegrityStatus.mismatch => (
        const Color(0xFFFBE6E4),
        Icons.report_problem_outlined,
        'Dữ liệu đã thay đổi sau khi công bố',
        '',
      ),
      IntegrityStatus.notPublished => (
        const Color(0xFFFFF0E3),
        Icons.edit_note_outlined,
        'Lô này đang tạo',
        'Chưa có bản nào để đối chiếu.',
      ),
      IntegrityStatus.unknown => (
        const Color(0xFFEDEBE1),
        Icons.help_outline,
        'Chưa kiểm chứng được',
        'Không lấy được kết quả từ máy chủ.',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: componentInk, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: componentInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(body, style: sectionCaptionStyle),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (integrity.hasHash) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Mã băm chỉ có ích cho người đi kiểm chứng bằng công cụ, tức
                // là người vận hành. Khách quét QR không làm được gì với 64 ký
                // tự hex; thứ họ bấm được là nút xem giao dịch bên dưới.
                if (showHash) CopyableHash(hash: integrity.snapshotHash),
                if (integrity.version != null)
                  InfoPill(label: 'PHIÊN BẢN', value: 'v${integrity.version}'),
                if (integrity.publishedAt.isNotEmpty)
                  InfoPill(
                    label: 'CÔNG BỐ LÚC',
                    value: _readableTime(integrity.publishedAt),
                  ),
              ],
            ),
          ],
          if (showChain && integrity.chain.isOnChain) ...[
            const SizedBox(height: 12),
            ChainLine(
              chain: integrity.chain,
              version: integrity.version,
              stale: integrity.status == IntegrityStatus.mismatch,
            ),
          ],
          if (integrity.status == IntegrityStatus.mismatch &&
              integrity.currentHash.isNotEmpty) ...[
            const SizedBox(height: 10),
            CopyableHash(
              hash: integrity.currentHash,
              label: 'HASH HIỆN TẠI',
              dense: true,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              if (onVerify != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: verifying ? null : onVerify,
                  icon: verifying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(verifying ? 'Đang kiểm' : 'Kiểm lại'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _readableTime(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}

/// Mã QR trỏ tới đúng URL của lô, để admin in lên bao bì.
class TraceQrCard extends StatefulWidget {
  const TraceQrCard({required this.code, required this.url, super.key});
  final String code;
  final String url;

  @override
  State<TraceQrCard> createState() => _TraceQrCardState();
}

class _TraceQrCardState extends State<TraceQrCard> {
  bool saving = false;

  /// Ảnh in phải là một file riêng, không phải ảnh chụp màn hình.
  ///
  /// Vẽ lại mã ở 1024px trên nền trắng đặc và ghi mã lô bên dưới: nền trong
  /// suốt hoặc mã không kèm chữ đều dễ hỏng khi đưa sang bản in bao bì.
  Future<void> _download() async {
    setState(() => saving = true);
    try {
      final bytes = await _renderPrintablePng(widget.code, widget.url);
      await downloadBytes(
        bytes,
        '${widget.code}-qr.png',
        contentType: 'image/png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã tải ${widget.code}-qr.png.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tạo được file mã QR: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: brandSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: brandLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: QrImageView(
            data: widget.url,
            version: QrVersions.auto,
            size: 168,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: componentInk,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: componentInk,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(widget.code, style: monoStyle.copyWith(fontSize: 15)),
        const SizedBox(height: 6),
        SelectableText(
          widget.url,
          style: const TextStyle(color: brandMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: saving ? null : _download,
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download, size: 16),
              label: const Text('Tải mã QR'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.url));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép liên kết truy xuất.'),
                  ),
                );
              },
              icon: const Icon(Icons.link, size: 16),
              label: const Text('Sao chép liên kết'),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Dựng file PNG in được: nền trắng, mã QR đen, mã lô ở dưới.
Future<Uint8List> _renderPrintablePng(String code, String url) async {
  const size = 1024.0;
  const padding = 64.0;
  const footer = 132.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size + footer),
    Paint()..color = Colors.white,
  );

  final painter = QrPainter(
    data: url,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Color(0xFF000000),
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Color(0xFF000000),
    ),
  );
  canvas.save();
  canvas.translate(padding, padding);
  painter.paint(canvas, const Size(size - padding * 2, size - padding * 2));
  canvas.restore();

  final paragraph =
      (ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textAlign: TextAlign.center,
                fontSize: 56,
                fontWeight: FontWeight.w700,
              ),
            )
            ..pushStyle(ui.TextStyle(color: const Color(0xFF000000)))
            ..addText(code))
          .build()
        ..layout(const ui.ParagraphConstraints(width: size));
  canvas.drawParagraph(paragraph, Offset(0, size - padding * 0.4));

  final image = await recorder.endRecording().toImage(
    size.toInt(),
    (size + footer).toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('không dựng được ảnh PNG');
  return data.buffer.asUint8List();
}
