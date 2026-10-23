import 'package:flutter/material.dart';

import '../data/trace_api.dart';
import 'shared_components.dart';

/// Cửa vào Management.
///
/// Bản đầu: `/api/admin/*` mở cho bất kỳ ai biết địa chỉ. Bản sau: một
/// ADMIN_TOKEN dùng chung, màn này là chỗ dán token đó. Bản này: mỗi người một
/// tài khoản, nên hỏi tên đăng nhập và mật khẩu.
///
/// Token vẫn vào được, nhưng lùi xuống một mục phụ: nó là cửa dự phòng cho lúc
/// mất mật khẩu và cho script vận hành, không phải cách dùng hằng ngày.
class AdminLogin extends StatefulWidget {
  const AdminLogin({
    required this.onSubmit,
    required this.onToken,
    required this.onExplorer,
    required this.endpoint,
    super.key,
  });

  /// Đăng nhập bằng tài khoản.
  final Future<void> Function(String username, String password) onSubmit;

  /// Đăng nhập bằng ADMIN_TOKEN.
  final Future<void> Function(String token) onToken;

  final VoidCallback onExplorer;
  final String endpoint;

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final username = TextEditingController();
  final password = TextEditingController();
  final token = TextEditingController();
  final usernameFocus = FocusNode();
  final passwordFocus = FocusNode();
  final tokenFocus = FocusNode();

  bool busy = false;
  bool obscured = true;
  bool tokenMode = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    token.dispose();
    usernameFocus.dispose();
    passwordFocus.dispose();
    tokenFocus.dispose();
    super.dispose();
  }

  void _clearError() {
    if (error != null) setState(() => error = null);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on TraceApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submitAccount() async {
    final name = username.text.trim();
    final secret = password.text;
    if (name.isEmpty) {
      setState(() => error = 'Nhập tên đăng nhập.');
      usernameFocus.requestFocus();
      return;
    }
    if (secret.isEmpty) {
      setState(() => error = 'Nhập mật khẩu.');
      passwordFocus.requestFocus();
      return;
    }
    await _run(() => widget.onSubmit(name, secret));
  }

  Future<void> _submitToken() async {
    final value = token.text.trim();
    if (value.isEmpty) {
      setState(() => error = 'Nhập token quản trị.');
      tokenFocus.requestFocus();
      return;
    }
    await _run(() => widget.onToken(value));
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
              Text(
                tokenMode ? 'Vào bằng token quản trị' : 'Đăng nhập quản trị',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: componentInk,
                ),
              ),
              const SizedBox(height: 24),
              if (tokenMode) ..._tokenFields() else ..._accountFields(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : tokenMode
                      ? _submitToken
                      : _submitAccount,
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          tokenMode = !tokenMode;
                          error = null;
                        }),
                  child: Text(
                    tokenMode
                        ? 'Đăng nhập bằng tài khoản'
                        : 'Dùng token quản trị',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Giữ đúng một dòng địa chỉ API: gọi nhầm máy chủ là lỗi hay gặp
              // nhất ở đây.
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

  List<Widget> _accountFields() => [
    TextField(
      controller: username,
      focusNode: usernameFocus,
      autofocus: true,
      autofillHints: const [AutofillHints.username],
      textInputAction: TextInputAction.next,
      onChanged: (_) => _clearError(),
      onSubmitted: (_) => passwordFocus.requestFocus(),
      decoration: const InputDecoration(
        labelText: 'Tên đăng nhập',
        prefixIcon: Icon(Icons.person_outline, color: brandMuted),
      ),
    ),
    const SizedBox(height: 14),
    TextField(
      controller: password,
      focusNode: passwordFocus,
      obscureText: obscured,
      autofillHints: const [AutofillHints.password],
      onChanged: (_) => _clearError(),
      onSubmitted: (_) => _submitAccount(),
      decoration: InputDecoration(
        labelText: 'Mật khẩu',
        errorText: error,
        prefixIcon: const Icon(Icons.lock_outline, color: brandMuted),
        suffixIcon: IconButton(
          tooltip: obscured ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: () => setState(() => obscured = !obscured),
          icon: Icon(
            obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    ),
  ];

  List<Widget> _tokenFields() => [
    TextField(
      controller: token,
      focusNode: tokenFocus,
      autofocus: true,
      obscureText: obscured,
      onChanged: (_) => _clearError(),
      onSubmitted: (_) => _submitToken(),
      decoration: InputDecoration(
        labelText: 'Token quản trị',
        errorText: error,
        prefixIcon: const Icon(Icons.key_outlined, color: brandMuted),
        suffixIcon: IconButton(
          tooltip: obscured ? 'Hiện token' : 'Ẩn token',
          onPressed: () => setState(() => obscured = !obscured),
          icon: Icon(
            obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    ),
    const SizedBox(height: 10),
    const Text(
      'Token mở toàn quyền và ghi nhật ký dưới tên token-quan-tri, không phải '
      'tên người. Dùng khi mất mật khẩu hoặc khi script vận hành cần chạy.',
      style: TextStyle(color: brandMuted, fontSize: 12, height: 1.45),
    ),
  ];
}
