import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'tule_theme.dart';

/// Màn quét QR của bản di động.
///
/// Trả về chuỗi đọc được qua `Navigator.pop`, hoặc null nếu người dùng đóng.
/// Camera chỉ bật trong lúc màn này mở, và tắt ngay khi thoát.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Chặn trường hợp camera bắn liên tiếp vài khung cùng một mã.
  bool handled = false;
  bool torch = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue ?? '')
        .firstWhere((text) => text.trim().isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final window = size.shortestSide * 0.68;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraProblem(error: error),
          ),
          // Khung ngắm: chỉ là lớp vẽ, không chặn thao tác bên dưới.
          IgnorePointer(
            child: Center(
              child: Container(
                width: window,
                height: window,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Text(
              'Đưa mã QR trên bao bì vào khung',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(
                    icon: Icons.close,
                    label: 'Đóng',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _RoundButton(
                    icon: torch ? Icons.flashlight_on : Icons.flashlight_off,
                    label: 'Đèn',
                    onTap: () async {
                      await controller.toggleTorch();
                      if (mounted) setState(() => torch = !torch);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkResponse(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    ),
  );
}

/// Không mở được camera thì nói thẳng và chừa đường nhập tay, không để màn đen.
class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: componentInk,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white70, size: 40),
              const SizedBox(height: 14),
              Text(
                denied
                    ? 'Ứng dụng chưa được phép dùng camera'
                    : 'Không mở được camera trên máy này',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'Bật quyền camera trong Cài đặt, hoặc nhập mã in trên bao bì.'
                    : 'Bạn vẫn nhập được mã in trên bao bì để tra cứu.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Nhập mã bằng tay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
