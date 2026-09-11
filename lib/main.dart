import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/url_strategy.dart';
import 'pages/explorer_page.dart';
import 'pages/management_page.dart';
import 'ui/shared_components.dart';

void main() {
  configureUrlStrategy();

  runApp(const TuleTraceApp());
}

/// Địa chỉ công khai dùng để dựng QR khi build production.
/// `flutter build web --dart-define=PUBLIC_BASE_URL=https://trace.tule.vn`
const _publicBaseUrl = String.fromEnvironment('PUBLIC_BASE_URL');

/// URL đầy đủ của một lô, chính là nội dung in vào mã QR trên bao bì.
///
/// Bản đầu không có URL cho từng lô: toàn app là một `bool management` nên
/// không thể quét QR, không chia sẻ được liên kết và nút back của trình duyệt
/// thoát thẳng khỏi ứng dụng.
String traceUrlFor(String code) {
  final base = _publicBaseUrl.isNotEmpty
      ? _publicBaseUrl
      : kIsWeb
      ? Uri.base.origin
      : 'https://trace.tule.vn';
  final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$trimmed/t/$code';
}

final tuleRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) =>
          ExplorerPage(demo: state.uri.queryParameters['demo'] == '1'),
    ),
    GoRoute(
      path: '/t/:code',
      name: 'trace',
      builder: (context, state) => ExplorerPage(
        code: state.pathParameters['code'],
        demo: state.uri.queryParameters['demo'] == '1',
      ),
    ),
    GoRoute(
      path: '/admin',
      name: 'admin',
      builder: (context, state) => const ManagementPage(),
    ),
  ],
  errorBuilder: (context, state) => TuleWebFrame(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_outlined, size: 40, color: brandMuted),
            const SizedBox(height: 14),
            const Text(
              'Không có trang này',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: const TextStyle(color: brandMuted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Về trang tra cứu'),
            ),
          ],
        ),
      ),
    ),
  ),
);

class TuleTraceApp extends StatelessWidget {
  const TuleTraceApp({super.key, this.router});

  /// Test bơm router riêng để không phụ thuộc trạng thái toàn cục.
  final GoRouter? router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'Tú Lệ Trace',
    theme: buildTuleTheme(),
    routerConfig: router ?? tuleRouter,
  );
}
