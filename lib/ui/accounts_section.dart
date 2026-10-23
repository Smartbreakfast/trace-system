import 'package:flutter/material.dart';

import '../models/trace_models.dart';
import 'tule_theme.dart';

/// Quản lý tài khoản và nhật ký thao tác.
///
/// Hai mục này là phần nhìn thấy được của việc phân quyền: trước đây hệ thống
/// chỉ có một token dùng chung nên không có gì để hiện ở đây, và dòng "người
/// nhập" trong hồ sơ lô nào cũng là "admin".

const _roleLabels = {
  'ADMIN': 'Quản trị hệ thống',
  'FACILITY': 'Phụ trách cơ sở',
  'STAFF': 'Nhân viên công đoạn',
};

const _roleNotes = {
  'ADMIN': 'Thấy mọi cơ sở, quản lý tài khoản, gửi dữ liệu lên blockchain.',
  'FACILITY': 'Toàn quyền trên dữ liệu của cơ sở mình, kể cả công bố lô.',
  'STAFF': 'Chỉ khai công đoạn và đính ảnh cho lô của cơ sở mình.',
};

String roleName(String role) => _roleLabels[role] ?? role;

/// Giá trị người quản trị nhập khi tạo một tài khoản mới.
class NewAccount {
  const NewAccount({
    required this.username,
    required this.password,
    required this.fullName,
    required this.role,
    required this.facilityId,
  });

  final String username;
  final String password;
  final String fullName;
  final String role;
  final int? facilityId;
}

class AccountsPanel extends StatelessWidget {
  const AccountsPanel({
    required this.accounts,
    required this.facilities,
    required this.loading,
    required this.onCreate,
    required this.onToggleActive,
    required this.onResetPassword,
    super.key,
  });

  final List<AdminAccount> accounts;
  final List<Map<String, dynamic>> facilities;
  final bool loading;
  final VoidCallback onCreate;
  final void Function(AdminAccount account, bool active) onToggleActive;
  final void Function(AdminAccount account) onResetPassword;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(child: Text('Tài khoản', style: pageTitleStyle)),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('Thêm tài khoản'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Mỗi người một tài khoản, mỗi tài khoản một vai trò và một cơ sở. '
        'Công đoạn do ai khai thì ghi tên người đó, không ghi chung là admin.',
        style: TextStyle(color: brandMuted, height: 1.5),
      ),
      const SizedBox(height: 20),
      if (loading)
        const Center(child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ))
      else if (accounts.isEmpty)
        const Text('Chưa có tài khoản nào.', style: TextStyle(color: brandMuted))
      else
        for (final account in accounts)
          _AccountRow(
            account: account,
            onToggleActive: onToggleActive,
            onResetPassword: onResetPassword,
          ),
      const SizedBox(height: 24),
      _RoleLegend(),
    ],
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.onToggleActive,
    required this.onResetPassword,
  });

  final AdminAccount account;
  final void Function(AdminAccount account, bool active) onToggleActive;
  final void Function(AdminAccount account) onResetPassword;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      roleName(account.role),
      if (account.facilityName.isNotEmpty) account.facilityName,
      if (account.lastLoginAt.isEmpty)
        'chưa đăng nhập lần nào'
      else
        'vào lần cuối ${_shortTime(account.lastLoginAt)}',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: brandSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandLine),
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
                        account.fullName.isEmpty
                            ? account.username
                            : '${account.fullName} (${account.username})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: componentInk,
                        ),
                      ),
                    ),
                    if (!account.active)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          'ĐÃ KHOÁ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7A1F19),
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: brandMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đặt lại mật khẩu',
            onPressed: () => onResetPassword(account),
            icon: const Icon(Icons.password_outlined),
          ),
          IconButton(
            tooltip: account.active ? 'Khoá tài khoản' : 'Mở lại tài khoản',
            onPressed: () => onToggleActive(account, !account.active),
            icon: Icon(
              account.active ? Icons.lock_outline : Icons.lock_open_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .03),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ba vai trò', style: sectionTitleStyle),
        const SizedBox(height: 10),
        for (final role in _roleLabels.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: brandMuted,
                  fontSize: 13,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: '${_roleLabels[role]}: ',
                    style: const TextStyle(
                      color: componentInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: _roleNotes[role]),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Hộp thoại thêm tài khoản.
class AccountCreateDialog extends StatefulWidget {
  const AccountCreateDialog({required this.facilities, super.key});

  final List<Map<String, dynamic>> facilities;

  static Future<NewAccount?> show(
    BuildContext context,
    List<Map<String, dynamic>> facilities,
  ) => showDialog<NewAccount>(
    context: context,
    builder: (_) => AccountCreateDialog(facilities: facilities),
  );

  @override
  State<AccountCreateDialog> createState() => _AccountCreateDialogState();
}

class _AccountCreateDialogState extends State<AccountCreateDialog> {
  final formKey = GlobalKey<FormState>();
  final username = TextEditingController();
  final fullName = TextEditingController();
  final password = TextEditingController();
  String role = 'STAFF';
  int? facilityId;

  @override
  void initState() {
    super.initState();
    if (widget.facilities.isNotEmpty) {
      facilityId = (widget.facilities.first['id'] as num?)?.toInt();
    }
  }

  @override
  void dispose() {
    username.dispose();
    fullName.dispose();
    password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      NewAccount(
        username: username.text.trim().toLowerCase(),
        password: password.text,
        fullName: fullName.text.trim(),
        role: role,
        facilityId: role == 'ADMIN' ? null : facilityId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thêm tài khoản'),
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
                controller: fullName,
                decoration: const InputDecoration(labelText: 'Họ tên'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Nhập họ tên.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: username,
                decoration: const InputDecoration(
                  labelText: 'Tên đăng nhập',
                  hintText: 'vd: lan.thu-hoach',
                ),
                validator: (value) {
                  final raw = (value ?? '').trim().toLowerCase();
                  if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,39}$').hasMatch(raw)) {
                    return 'Chữ không dấu, số và . _ - ; từ 3 ký tự.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: password,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu ban đầu',
                  helperText: 'Từ 10 ký tự, có cả chữ và số.',
                ),
                validator: _passwordRule,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: [
                  for (final entry in _roleLabels.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) => setState(() => role = value ?? 'STAFF'),
              ),
              const SizedBox(height: 6),
              Text(
                _roleNotes[role] ?? '',
                style: const TextStyle(
                  color: brandMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              if (role != 'ADMIN') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: facilityId,
                  decoration: const InputDecoration(labelText: 'Cơ sở'),
                  items: [
                    for (final facility in widget.facilities)
                      DropdownMenuItem(
                        value: (facility['id'] as num?)?.toInt(),
                        child: Text('${facility['name'] ?? ''}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => facilityId = value),
                  validator: (value) =>
                      value == null ? 'Chọn cơ sở cho tài khoản này.' : null,
                ),
              ],
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
      FilledButton(onPressed: _submit, child: const Text('Tạo tài khoản')),
    ],
  );
}

String? _passwordRule(String? value) {
  final raw = value ?? '';
  if (raw.length < 10) return 'Mật khẩu phải dài từ 10 ký tự.';
  if (!RegExp(r'[a-zA-Z]').hasMatch(raw) || !RegExp(r'[0-9]').hasMatch(raw)) {
    return 'Phải có cả chữ và số.';
  }
  return null;
}

/// Hộp thoại nhập một mật khẩu (đặt lại cho người khác).
class PasswordDialog extends StatefulWidget {
  const PasswordDialog({required this.title, required this.label, super.key});

  final String title;
  final String label;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String label = 'Mật khẩu mới',
  }) => showDialog<String>(
    context: context,
    builder: (_) => PasswordDialog(title: title, label: label),
  );

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final formKey = GlobalKey<FormState>();
  final password = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 380,
      child: Form(
        key: formKey,
        child: TextFormField(
          controller: password,
          autofocus: true,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: 'Từ 10 ký tự, có cả chữ và số.',
          ),
          validator: _passwordRule,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Huỷ'),
      ),
      FilledButton(
        onPressed: () {
          if (formKey.currentState?.validate() ?? false) {
            Navigator.of(context).pop(password.text);
          }
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

/// Hộp thoại người đang đăng nhập tự đổi mật khẩu của mình.
class OwnPasswordDialog extends StatefulWidget {
  const OwnPasswordDialog({super.key});

  static Future<List<String>?> show(BuildContext context) =>
      showDialog<List<String>>(
        context: context,
        builder: (_) => const OwnPasswordDialog(),
      );

  @override
  State<OwnPasswordDialog> createState() => _OwnPasswordDialogState();
}

class _OwnPasswordDialogState extends State<OwnPasswordDialog> {
  final formKey = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đổi mật khẩu'),
    content: SizedBox(
      width: 380,
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: current,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu hiện tại',
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Nhập mật khẩu hiện tại.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                helperText: 'Từ 10 ký tự, có cả chữ và số.',
              ),
              validator: _passwordRule,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Huỷ'),
      ),
      FilledButton(
        onPressed: () {
          if (formKey.currentState?.validate() ?? false) {
            Navigator.of(context).pop([current.text, next.text]);
          }
        },
        child: const Text('Đổi mật khẩu'),
      ),
    ],
  );
}

/// Nhật ký thao tác.
class AuditPanel extends StatelessWidget {
  const AuditPanel({
    required this.entries,
    required this.loading,
    required this.onRefresh,
    super.key,
  });

  final List<AuditEntry> entries;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(child: Text('Nhật ký thao tác', style: pageTitleStyle)),
          OutlinedButton.icon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text('Tải lại'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Ai làm gì, trên lô nào, lúc nào. Nhật ký nằm ngoài vùng dữ liệu đã '
        'niêm phong nên ghi thêm bao nhiêu cũng không đổi mã băm của lô.',
        style: TextStyle(color: brandMuted, height: 1.5),
      ),
      const SizedBox(height: 20),
      if (loading)
        const Center(child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ))
      else if (entries.isEmpty)
        const Text('Chưa có thao tác nào.', style: TextStyle(color: brandMuted))
      else
        for (final entry in entries) _AuditRow(entry: entry),
    ],
  );
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final who = entry.fullName.isEmpty ? entry.username : entry.fullName;
    final what = [
      if (entry.target.isNotEmpty) entry.target,
      if (entry.detail.isNotEmpty) entry.detail,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              _shortTime(entry.createdAt),
              style: const TextStyle(color: brandMuted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.actionLabel}${what.isEmpty ? '' : ' — $what'}',
                  style: const TextStyle(color: componentInk, height: 1.4),
                ),
                const SizedBox(height: 2),
                Text(
                  '$who · ${roleName(entry.role)}',
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

/// ISO về dạng người đọc, giờ địa phương. Chuỗi rỗng hoặc sai thì trả lại
/// nguyên văn chứ không nuốt mất thông tin.
String _shortTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
