import 'package:flutter/material.dart';

import '../data/trace_api.dart';
import 'shared_components.dart';

/// Cửa vào Management.
///
/// Trước đây `/api/admin/*` mở cho bất kỳ ai biết địa chỉ: tạo lô giả, công bố
/// hồ sơ giả và đổ file vào R2 đều được. Giờ worker đòi bearer token, còn màn
/// này là chỗ nhập token đó.
class AdminLogin extends StatefulWidget {
  const AdminLogin({
    required this.onSubmit,
    required this.onExplorer,
    required this.endpoint,
    super.key,
  });

  final Future<void> Function(String token) onSubmit;
  final VoidCallback onExplorer;
  final String endpoint;

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final controller = TextEditingController();
  final focus = FocusNode();
  bool busy = false;
  bool obscured = true;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = controller.text.trim();
    if (token.isEmpty) {
      setState(() => error = 'Nhập token quản trị.');
      focus.requestFocus();
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSubmit(token);
    } on TraceUnauthorized {
      if (mounted) {
        setState(() => error = 'Token không đúng. Kiểm tra lại ADMIN_TOKEN.');
      }
    } on TraceApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: brandSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: brandLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const TuleBrand(),
              const SizedBox(height: 26),
              const Text(
                'Đăng nhập quản trị',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: componentInk,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                focusNode: focus,
                autofocus: true,
                obscureText: obscured,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (error != null) setState(() => error = null);
                },
                decoration: InputDecoration(
                  labelText: 'Token quản trị',
                  errorText: error,
                  prefixIcon: const Icon(Icons.key_outlined, color: brandMuted),
                  suffixIcon: IconButton(
                    tooltip: obscured ? 'Hiện token' : 'Ẩn token',
                    onPressed: () => setState(() => obscured = !obscured),
                    icon: Icon(
                      obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : _submit,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_open, size: 18),
                  label: Text(busy ? 'Đang kiểm tra' : 'Vào Management'),
                ),
              ),
              const SizedBox(height: 14),
              // Giữ đúng một dòng địa chỉ API: gọi nhầm máy chủ là lỗi hay gặp
              // nhất ở đây. Câu lệnh đặt secret là việc của lúc dựng hệ thống,
              // đã có trong DEPLOY.md, không cần nằm trên màn đăng nhập.
              Text(
                widget.endpoint,
                style: const TextStyle(color: brandMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onExplorer,
                  child: const Text('Về trang tra cứu'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
