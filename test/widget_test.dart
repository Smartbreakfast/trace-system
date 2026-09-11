import 'dart:convert';

import 'package:com_tule/data/geo_lookup.dart';
import 'package:com_tule/data/qr_scanner.dart';
import 'package:com_tule/data/trace_api.dart';
import 'package:com_tule/main.dart';
import 'package:com_tule/models/trace_models.dart';
import 'package:com_tule/pages/explorer_page.dart';
import 'package:com_tule/pages/management_page.dart';
import 'package:com_tule/ui/shared_components.dart';
import 'package:com_tule/ui/sourcing_section.dart';
import 'package:com_tule/ui/explorer_chrome.dart';
import 'package:com_tule/ui/trace_components.dart';
import 'package:com_tule/ui/explorer_tabs.dart';
import 'package:com_tule/ui/process_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' show Response;
import 'package:http/testing.dart';

const _traceJson = {
  'id': 1,
  'name': 'Tú Lệ Smart Breakfast',
  'code': 'TL-2026-001',
  'production_date': '12.08.2026',
  'expiry_date': '12.08.2027',
  'description': 'Bột ngũ cốc dinh dưỡng từ nông sản bản địa.',
  'status': 'PUBLISHED',
  'facility_name': 'Xưởng chế biến Tú Lệ',
  'latitude': 21.7167,
  'longitude': 104.2333,
  'ingredients': [
    {
      'id': 1,
      'name': 'Cốm Tú Lệ',
      'origin': 'Tú Lệ, Yên Bái',
      'supplier': 'Hợp tác xã Tú Lệ',
      'harvest_date': '10.08.2026',
      'received_date': '11.08.2026',
      'summary': 'Hạt nếp nương xanh.',
      'latitude': 21.7167,
      'longitude': 104.2333,
      'area_radius_km': 4.5,
      'processEvents': [
        {
          'id': 2,
          'title': 'Nghiền thành bột mịn',
          'description': '',
          'event_date': '12.08.2026',
          'entered_by': 'admin',
        },
        {
          'id': 1,
          'title': 'Thu hoạch lúa nếp nương',
          'description': '',
          'event_date': '10.08.2026',
          'entered_by': 'admin',
        },
      ],
    },
    {
      'id': 2,
      'name': 'Lạc đỏ Lục Yên',
      'origin': 'Lục Yên, Yên Bái',
      'supplier': 'Tổ hợp tác Lục Yên',
      'harvest_date': '08.08.2026',
      'received_date': '10.08.2026',
      'summary': 'Hạt lạc bản địa.',
      'processEvents': [
        {
          'id': 3,
          'title': 'Xay với nước',
          'event_date': '12.08.2026',
          'entered_by': 'admin',
        },
      ],
    },
  ],
  'media': [
    {
      'id': 10,
      'role': 'cover',
      'kind': 'image',
      'url': '/api/media/media/aaaa.jpg',
      'fileName': 'goi-san-pham.jpg',
      'contentType': 'image/jpeg',
      'size': 240000,
      'sha256': 'aaaa',
      'caption': 'Gói thành phẩm',
    },
    {
      'id': 11,
      'role': 'lab_report',
      'kind': 'document',
      'url': '/api/media/media/bbbb.pdf',
      'fileName': 'kiem-nghiem-2026.pdf',
      'contentType': 'application/pdf',
      'size': 120000,
      'sha256': 'bbbb',
      'caption': 'Phiếu kiểm nghiệm Quatest 1',
    },
  ],
  'integrity': {
    'status': 'VERIFIED',
    'version': 1,
    'snapshotHash':
        'aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff0000000011111111',
    'currentHash':
        'aaaaaaaabbbbbbbbccccccccddddddddeeeeeeeeffffffff0000000011111111',
    'publishedBy': 'admin',
    'publishedAt': '2026-08-12T03:00:00.000Z',
  },
};

TraceApi _api(MockClient client) =>
    TraceApi(baseUrl: 'http://test/api', client: client);

/// Trả hồ sơ thật cho mã hợp lệ và 404 cho mã lạ.
MockClient _healthyClient() => MockClient((request) async {
  final path = request.url.path;
  if (path.endsWith('/public/featured') ||
      path.contains('/public/traces/TL-2026-001')) {
    if (path.endsWith('/verify')) {
      return _json(_traceJson['integrity']);
    }
    return _json(_traceJson);
  }
  return _json({
    'error': 'TRACE_NOT_FOUND',
    'message': 'Không tìm thấy.',
  }, status: 404);
});

/// Trả JSON dạng byte UTF-8 giống server thật, vì `Response(String, ...)`
/// mã hoá latin1 và sẽ nổ ngay khi gặp tiếng Việt có dấu.
Response _json(Object? body, {int status = 200}) => Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Widget _app(TraceApi api, {String location = '/t/TL-2026-001'}) =>
    TuleTraceApp(
      router: GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => ExplorerPage(api: api),
          ),
          GoRoute(
            path: '/t/:code',
            builder: (context, state) => ExplorerPage(
              code: state.pathParameters['code'],
              demo: state.uri.queryParameters['demo'] == '1',
              api: api,
            ),
          ),
        ],
      ),
    );

/// Skeleton lúc tải có animation lặp vô hạn nên `pumpAndSettle` sẽ quay
/// hết 8 giây thời gian giả và làm request tự timeout. Bơm vài khung là đủ.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Trang khách mở ở mục "Thông tin chung". Test nào cần sơ đồ quy trình hoặc
/// danh sách thành phần thì phải chuyển mục trước, đúng như người dùng làm.
Future<void> _openOrigin(WidgetTester tester) async {
  final tab = find.text('Nguồn gốc');
  // Trên màn hẹp thanh chuyển mục cuộn ngang, phải kéo nút vào tầm nhìn trước.
  await tester.ensureVisible(tab);
  await tester.pump();
  await tester.tap(tab);
  await _settle(tester);
}

/// Backend giả cho các màn quản trị: một lô đã công bố kèm bốn nguyên liệu.
MockClient _adminClient() => MockClient((request) async {
  final path = request.url.path;
  if (path.endsWith('/admin/session')) return _json({'ok': true});
  if (path.endsWith('/admin/summary')) {
    return _json({
      'products': 1,
      'published': 1,
      'ingredients': 4,
      'events': 12,
      'pendingBlockchain': 1,
    });
  }
  if (path.endsWith('/admin/product-batches')) {
    return _json({
      'items': [
        {
          'code': 'TL-2026-001',
          'name': 'Tú Lệ Smart Breakfast',
          'status': 'PUBLISHED',
          'production_date': '12.08.2026',
          'created_at': '2026-08-10T02:30:00.000Z',
          'ingredientCount': 4,
          'eventCount': 12,
          'version': 1,
        },
      ],
      'total': 1,
      'page': 1,
      'pages': 1,
    });
  }
  if (path.endsWith('/admin/chain')) {
    return _json({
      'configured': true,
      'reachable': true,
      'chainId': 54000,
      'address': '0xB00865B6CD6D725dE64E7B2461a343C53c94C243',
      'contract': '0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca',
      'explorer': 'https://vnidchain-explorer.vbsn.vn',
      'balance': '999999348337438394',
      'outbox': {
        'byStatus': {'PENDING_NETWORK': 1},
        'lastError': '',
      },
    });
  }
  if (path.endsWith('/snapshots')) {
    return _json([
      {
        'id': 1,
        'version': 1,
        'sha256': 'a' * 64,
        'publishedBy': 'admin',
        'publishedAt': '2026-08-12T07:00:00.000Z',
        'chainStatus': 'PENDING_NETWORK',
        'txHash': null,
      },
    ]);
  }
  if (path.endsWith('/verify')) return _json(_traceJson['integrity']);
  return _json(_traceJson);
});

Widget _adminApp(TraceApi api) => TuleTraceApp(
  router: GoRouter(
    initialLocation: '/admin',
    routes: [
      GoRoute(path: '/admin', builder: (_, _) => ManagementPage(api: api)),
      GoRoute(path: '/', builder: (_, _) => ExplorerPage(api: api)),
    ],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hiển thị hồ sơ lô từ API', (tester) async {
    await tester.pumpWidget(_app(_api(_healthyClient())));
    await _settle(tester);
    await _openOrigin(tester);

    expect(find.text('Tú Lệ'), findsWidgets);
    // Ô tra cứu nằm ngay dưới thanh điều hướng, hiện ở mọi trạng thái.
    expect(find.byType(ExplorerHeader), findsOneWidget);
    // Trang khách không quảng cáo đường vào quản trị.
    expect(find.text('Management'), findsNothing);
    expect(find.text('Admin'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(TraceSearchBand),
        matching: find.byType(TraceSearch),
      ),
      findsOneWidget,
    );
    expect(find.text('Tú Lệ Smart Breakfast'), findsWidgets);
    expect(find.text('Cốm Tú Lệ'), findsWidgets);
    expect(find.text('ĐÃ XÁC MINH'), findsOneWidget);
  });

  testWidgets('trang chủ chưa tra cứu thì không tự tải lô nào', (tester) async {
    final asked = <String>[];
    final api = _api(
      MockClient((request) async {
        asked.add(request.url.path);
        if (request.url.path.endsWith('/public/batches')) {
          return _json([
            {
              'code': 'TL-2026-002',
              'name': 'Bột ngũ cốc Tú Lệ Smart Breakfast',
              'productionDate': '07.09.2026',
            },
          ]);
        }
        return _json(_traceJson);
      }),
    );

    await tester.pumpWidget(_app(api, location: '/'));
    await _settle(tester);

    // Hỏi danh sách lô gợi ý thì được, nhưng không được tự mở hồ sơ lô nào.
    expect(
      asked.where((path) => path.contains('/traces/')),
      isEmpty,
      reason: 'trang chủ không được tự tải hồ sơ lô',
    );
    expect(find.text('TL-2026-002'), findsOneWidget);
    expect(find.text('Lô đã công bố'.toUpperCase()), findsOneWidget);
    expect(find.text('Tra cứu một lô sản phẩm'), findsOneWidget);
    expect(find.text('Tú Lệ Smart Breakfast'), findsNothing);

    // Khung giống hệt trang có kết quả, chỉ là panel đang rỗng: đổi bố cục
    // giữa hai trạng thái làm trang giật ngay lúc kết quả về.
    expect(find.byType(SourcingSection), findsOneWidget);
    expect(find.byType(EmptyResultPanel), findsOneWidget);
    // Khung trái lúc chưa tra cứu là ảnh sản phẩm, không phải một dòng chữ
    // báo rằng chỗ này sẽ có gì.
    expect(
      find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/tule-box.jpg',
      ),
      findsOneWidget,
    );

    // Ô tra cứu ở navbar có mặt ở cả hai trạng thái, không nhảy chỗ.
    expect(
      find.descendant(
        of: find.byType(TraceSearchBand),
        matching: find.byType(TraceSearch),
      ),
      findsOneWidget,
    );
  });

  testWidgets('nhập mã ở trang chủ thì mới ra hồ sơ lô', (tester) async {
    await tester.pumpWidget(_app(_api(_healthyClient()), location: '/'));
    await _settle(tester);
    expect(find.text('Tú Lệ Smart Breakfast'), findsNothing);

    // Gõ vào ô trong navbar, đúng ô mà người dùng thấy ở cả hai trạng thái.
    await tester.enterText(
      find.descendant(
        of: find.byType(TraceSearchBand),
        matching: find.byType(TextField),
      ),
      'tl-2026-001',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(TraceSearchBand),
        matching: find.text('Tra cứu'),
      ),
    );
    await _settle(tester);

    // Mã nhập chữ thường vẫn phải ra đúng lô.
    expect(find.text('Tú Lệ Smart Breakfast'), findsWidgets);
    // Kết quả mở ở mục thông tin chung, đúng thứ người vừa quét mã cần thấy.
    expect(find.byType(GeneralInfoSection), findsOneWidget);
  });

  testWidgets('mã không tồn tại hiện màn không tìm thấy chứ không phải mock', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_api(_healthyClient()), location: '/t/SAI-MA'),
    );
    await _settle(tester);

    expect(find.textContaining('Không tìm thấy mã SAI-MA'), findsOneWidget);
    expect(find.text('Tú Lệ Smart Breakfast'), findsNothing);
  });

  testWidgets('API lỗi thì báo lỗi, tuyệt đối không lặng lẽ hiện dữ liệu mẫu', (
    tester,
  ) async {
    final api = _api(MockClient((_) async => _json({'message': 'boom'}, status: 500)));
    await tester.pumpWidget(_app(api));
    await _settle(tester);

    expect(
      find.text('Không kết nối được máy chủ truy xuất'),
      findsOneWidget,
    );
    expect(find.text('Cốm Tú Lệ'), findsNothing);
  });

  testWidgets('chế độ demo luôn kèm cảnh báo dữ liệu không thật', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_api(_healthyClient()), location: '/t/TL-2026-001?demo=1'),
    );
    await _settle(tester);

    expect(find.textContaining('không phải bản ghi thật'), findsOneWidget);
  });

  // Bản cũ dựng BatchSummary bằng Row cứng với ảnh 175px và ô tìm kiếm
  // SizedBox(width: 450), nên vỡ trên màn hình điện thoại. Quét lại ba khổ
  // màn hình để chặn hồi quy.
  for (final size in const [
    Size(360, 800),
    Size(768, 1024),
    Size(1440, 900),
  ]) {
    testWidgets('không tràn layout ở ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(_api(_healthyClient())));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Management chặn người chưa có token quản trị', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final api = _api(
      MockClient(
        (_) async => _json({'message': 'Token quản trị không đúng.'}, status: 401),
      ),
    );
    await tester.pumpWidget(_adminApp(api));
    await _settle(tester);

    expect(find.text('Đăng nhập quản trị'), findsOneWidget);
    expect(find.text('Tổng quan'), findsNothing);

    // Token sai phải báo ngay tại ô nhập, không cho vào Management.
    await tester.enterText(find.byType(TextField).first, 'sai-token');
    await tester.tap(find.text('Vào Management'));
    await _settle(tester);
    expect(find.textContaining('Token không đúng'), findsOneWidget);
  });

  testWidgets('Management mở lô ra một màn làm việc duy nhất', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'tule_admin_token': 'dev-token'});

    await tester.pumpWidget(_adminApp(_api(_adminClient())));
    await _settle(tester);

    expect(find.text('Lô gần đây'), findsOneWidget);
    // Ngày tạo hiện theo giờ máy nên chỉ khẳng định nó có mặt, phần còn lại
    // của dòng thì so đúng từng chữ.
    expect(find.textContaining('TL-2026-001  ·  tạo '), findsOneWidget);
    expect(
      find.textContaining('SX 12.08.2026  ·  4 nguyên liệu  ·  12 công đoạn  ·  v1'),
      findsOneWidget,
    );

    // Sang danh sách lô rồi mở một lô: mọi việc của lô nằm chung một màn,
    // không còn phải nhảy giữa các tab.
    await tester.tap(find.text('Lô sản phẩm').last);
    await _settle(tester);
    expect(find.text('Tạo lô mới'), findsOneWidget);

    await tester.tap(find.text('Tú Lệ Smart Breakfast'));
    await _settle(tester);
    expect(find.text('Thông tin lô'), findsOneWidget);
    expect(find.text('Nguyên liệu'), findsOneWidget);
    expect(find.text('Hoàn thành lô'), findsWidgets);
    expect(find.text('Tải mã QR'), findsOneWidget);

    // Chưa nối mạng thì màn quản trị phải nói thẳng là mã băm mới nằm ở hàng
    // chờ, không được để người vận hành tưởng dữ liệu đã lên chuỗi.
    expect(find.textContaining('Đang chờ lưu lên blockchain'), findsOneWidget);
    expect(find.text('CHỜ LƯU CHUỖI'), findsOneWidget);
    // Ví ký và mạng phải hiện ra, để người vận hành biết đang gửi bằng ví nào.
    expect(find.textContaining('mạng 54000'), findsOneWidget);
    expect(find.text('Thêm nguyên liệu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('danh sách lô lọc và phân trang ở server', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'tule_admin_token': 'dev-token'});

    // Ghi lại từng lần gọi để chắc chắn bộ lọc đi tới server chứ không phải
    // lọc lại đám vừa tải về: danh sách sẽ dài ra theo từng vụ.
    final calls = <Uri>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/admin/session')) return _json({'ok': true});
      if (path.endsWith('/admin/summary')) return _json({'products': 30});
      if (path.endsWith('/admin/product-batches')) {
        calls.add(request.url);
        final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
        final term = request.url.queryParameters['q'] ?? '';
        if (term.isNotEmpty) {
          return _json({
            'items': [
              {
                'code': 'TL-2026-007',
                'name': 'Lô tìm thấy',
                'status': 'DRAFT',
                'created_at': '2026-09-01T03:00:00.000Z',
              },
            ],
            'total': 1,
            'page': 1,
            'pages': 1,
          });
        }
        return _json({
          'items': [
            {
              'code': 'TL-2026-${page.toString().padLeft(3, '0')}',
              'name': 'Lô trang $page',
              'status': 'DRAFT',
              'created_at': '2026-09-01T03:00:00.000Z',
            },
          ],
          'total': 30,
          'page': page,
          'pages': 3,
        });
      }
      return _json(_traceJson);
    });

    await tester.pumpWidget(_adminApp(_api(client)));
    await _settle(tester);
    await tester.tap(find.text('Lô sản phẩm').last);
    await _settle(tester);

    expect(find.text('Lô trang 1'), findsOneWidget);
    expect(find.text('30 lô'), findsOneWidget);
    expect(find.text('Trang 1 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await _settle(tester);
    expect(find.text('Lô trang 2'), findsOneWidget);
    expect(calls.last.queryParameters['page'], '2');

    await tester.enterText(find.widgetWithText(TextField, 'Tìm mã lô hoặc tên'), 'tìm');
    await tester.pump(const Duration(milliseconds: 500));
    await _settle(tester);
    expect(calls.last.queryParameters['q'], 'tìm');
    // Lọc lại thì phải quay về trang một, không giữ trang 2 của kết quả cũ.
    expect(calls.last.queryParameters['page'], '1');
    expect(find.text('Lô tìm thấy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tạo lô hỏi đúng những gì cần và chặn mã trùng', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'tule_admin_token': 'dev-token'});

    await tester.pumpWidget(_adminApp(_api(_adminClient())));
    await _settle(tester);
    await tester.tap(find.text('Lô sản phẩm').last);
    await _settle(tester);
    await tester.tap(find.text('Tạo lô mới'));
    await _settle(tester);

    expect(find.text('Tạo lô sản phẩm'), findsOneWidget);

    // Mã đã có lô khác dùng thì không cho tạo, tránh hai lô cùng một QR.
    await tester.enterText(find.byType(TextFormField).at(1), 'TL-2026-001');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo lô'));
    await _settle(tester);
    expect(find.text('Mã này đã có lô khác dùng.'), findsOneWidget);
    expect(find.text('Tạo lô sản phẩm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn làm việc của lô không tràn ở màn hẹp', (tester) async {
    tester.view.physicalSize = const Size(820, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'tule_admin_token': 'dev-token'});

    await tester.pumpWidget(_adminApp(_api(_adminClient())));
    await _settle(tester);
    await tester.tap(find.text('Lô sản phẩm').last);
    await _settle(tester);
    await tester.tap(find.text('Tú Lệ Smart Breakfast'));
    await _settle(tester);

    expect(find.text('Thông tin lô'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -700),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('trang công khai chỉ khoe blockchain khi đã có giao dịch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Chưa có giao dịch: không được hiện chữ blockchain nào.
    await tester.pumpWidget(_app(_api(_healthyClient())));
    await _settle(tester);
    expect(find.text('HASH GIAO DỊCH'), findsNothing);

    final anchored = Map<String, dynamic>.from(_traceJson);
    anchored['integrity'] = {
      ...(_traceJson['integrity']! as Map<String, dynamic>),
      'chain': {
        'status': 'CONFIRMED',
        'txHash':
            '0x15587512a7a82b6055a02816d4519d871d9a404a26ab573144c49acbcfeb8442',
        'blockNumber': '4963794',
        'chainId': 54000,
        'contract': '0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca',
        'explorer': 'https://vnidchain-explorer.vbsn.vn',
      },
    };

    await tester.pumpWidget(
      _app(_api(MockClient((_) async => _json(anchored)))),
    );
    await _settle(tester);
    expect(find.text('HASH GIAO DỊCH'), findsOneWidget);
    expect(find.text('Xem giao dịch trên blockchain'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dữ liệu đổi sau khi lên chuỗi thì nói rõ chuỗi giữ bản nào', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Bản v38 đã nằm trên chuỗi, nhưng dữ liệu hiện tại đã bị sửa nên hash
    // không còn khớp. Trang công khai phải nói thẳng là thứ trên chuỗi là bản
    // cũ, chứ không phải bản đang xem.
    final drifted = Map<String, dynamic>.from(_traceJson);
    drifted['integrity'] = {
      'status': 'MISMATCH',
      'version': 38,
      'snapshotHash': 'a' * 64,
      'currentHash': 'b' * 64,
      'chain': {
        'status': 'CONFIRMED',
        'txHash':
            '0x9f99bc7041a3cd4bfbbec94c41c50e7cc8b8acbe3497807c621639905e1d309e',
        'chainId': 54000,
        'explorer': 'https://vnidchain-explorer.vbsn.vn',
      },
    };

    await tester.pumpWidget(
      _app(_api(MockClient((_) async => _json(drifted)))),
    );
    await _settle(tester);

    expect(find.text('DỮ LIỆU SAI LỆCH'), findsWidgets);
    expect(find.text('HASH GIAO DỊCH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop: panel cuộn bên trong, khung không đổi chiều cao', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_api(_healthyClient())));
    await _settle(tester);
    await _openOrigin(tester);

    // Mở hồ sơ một nguyên liệu: đây là lúc nội dung dài ra nhiều nhất.
    final section = find.byType(SourcingSection);
    final before = tester.getSize(section);
    await tester.tap(find.text('Cốm Tú Lệ').first);
    await _settle(tester);

    // Khối bản đồ + panel phải giữ nguyên chiều cao, nếu không thì bản đồ trôi
    // khỏi màn hình mỗi lần người xem đọc tới công đoạn cuối.
    expect(tester.getSize(section).height, before.height);

    // Và chỉ phần danh sách cuộn, không phải cả thẻ: tiêu đề vẫn nằm yên.
    final inner = find.descendant(
      of: section,
      matching: find.byType(Scrollbar),
    );
    expect(inner, findsOneWidget);
    expect(find.text('Cốm Tú Lệ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trang khách bỏ hẳn ô chưa có dữ liệu', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Nguyên liệu thiếu ngày thu hoạch và ngày nhập kho.
    final sparse = Map<String, dynamic>.from(_traceJson);
    sparse['ingredients'] = [
      {
        'id': 1,
        'name': 'Cốm Tú Lệ',
        'origin': 'Tú Lệ, Yên Bái',
        'supplier': 'Hợp tác xã Tú Lệ',
        'harvest_date': '',
        'received_date': '',
        'latitude': 21.7167,
        'longitude': 104.2333,
        'processEvents': const [],
      },
    ];

    await tester.pumpWidget(
      _app(_api(MockClient((_) async => _json(sparse)))),
    );
    await _settle(tester);
    await _openOrigin(tester);
    await tester.tap(find.text('Cốm Tú Lệ').first);
    await _settle(tester);

    expect(find.text('Hợp tác xã Tú Lệ'), findsOneWidget);
    // Nhãn của trường rỗng phải biến mất, không hiện kèm chữ "Chưa có".
    expect(find.text('THU HOẠCH'), findsNothing);
    expect(find.text('NHẬP KHO'), findsNothing);
    expect(find.text('Chưa có'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nguyên liệu dùng ảnh thật, khớp theo tên', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_api(_healthyClient())));
    await _settle(tester);
    await _openOrigin(tester);

    // Khớp theo tên chứ không theo thứ tự: đổi chỗ nguyên liệu trong lô thì
    // ảnh vẫn phải đi theo đúng nguyên liệu đó.
    expect(ingredientImageFor('Cốm Tú Lệ'), contains('com-tu-le'));
    expect(ingredientImageFor('Lạc đỏ Lục Yên'), contains('lac-do-luc-yen'));
    expect(ingredientImageFor('Chuối tiêu xanh'), contains('chuoi-tieu-xanh'));
    expect(ingredientImageFor('Khoai môn Lục Yên'), contains('khoai-mon'));
    // Nguyên liệu lạ thì không có ảnh, giao diện rơi về icon.
    expect(ingredientImageFor('Mật ong rừng'), isNull);

    expect(find.byType(IngredientAvatar), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile: chọn thành phần không kéo trang đi chỗ khác', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_api(_healthyClient())));
    await _settle(tester);
    await _openOrigin(tester);

    // Trang dài hơn màn hình nên phải cuộn tới nút cần bấm trước; đo vị trí
    // cuộn ngay trước cú chạm mới trả lời được câu hỏi "chọn có kéo trang không".
    final node = find
        .descendant(
          of: find.byType(ProcessTree),
          matching: find.text('Cốm Tú Lệ'),
        )
        .first;
    await tester.ensureVisible(node);
    await _settle(tester);

    final scroller = find.byType(Scrollable).first;
    final before = tester.widget<Scrollable>(scroller).controller?.offset;

    await tester.tap(node, warnIfMissed: false);
    await _settle(tester);

    // Panel đổi sang hồ sơ thành phần và trang không tự nhảy xuống sơ đồ.
    //
    // Không đòi vị trí cuộn giữ y nguyên: hồ sơ một thành phần ngắn hơn danh
    // sách hành trình, trang co lại nên vị trí cuộn bị kẹp xuống theo. Điều
    // phải giữ là trang không kéo người đọc đi xa hơn chỗ họ đang đứng.
    expect(find.text('Công đoạn'), findsOneWidget);
    final after = tester.widget<Scrollable>(scroller).controller?.offset;
    expect(after, isNotNull);
    expect(after! <= before!, isTrue, reason: 'không được kéo trang xuống');
    expect(tester.takeException(), isNull);
  });

  test('mã quét được có thể là cả đường dẫn, không chỉ mã lô', () {
    expect(
      codeFromScan('https://tule-trace.sontm.workers.dev/t/TL-2026-001'),
      'TL-2026-001',
    );
    expect(codeFromScan('http://127.0.0.1:8787/t/tl-2026-002?x=1'), 'TL-2026-002');
    expect(codeFromScan('  tl-2026-003 '), 'TL-2026-003');
    expect(codeFromScan(''), '');
  });

  testWidgets('công đoạn ở xưởng nằm trong hồ sơ nơi sản xuất', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final withFacility = Map<String, dynamic>.from(_traceJson);
    withFacility['batchEvents'] = [
      {
        'id': 90,
        'title': 'Phối trộn',
        'description': 'Trộn bốn loại bột cùng phụ gia theo định mức.',
        'event_date': '12.08.2026',
        'entered_by': 'admin',
      },
      {
        'id': 91,
        'title': 'Đóng gói',
        'event_date': '12.08.2026',
        'entered_by': 'admin',
      },
    ];

    await tester.pumpWidget(
      _app(_api(MockClient((_) async => _json(withFacility)))),
    );
    await _settle(tester);
    await _openOrigin(tester);

    // Hai công đoạn của xưởng là nút riêng trên sơ đồ, không lẫn vào nhánh
    // của nguyên liệu nào.
    expect(
      find.descendant(
        of: find.byType(ProcessTree),
        matching: find.text('Phối trộn'),
      ),
      findsOneWidget,
    );

    // Chạm vào nó thì panel mở chi tiết đúng công đoạn ấy.
    await tester.tap(
      find
          .descendant(
            of: find.byType(ProcessTree),
            matching: find.text('Phối trộn'),
          )
          .first,
      warnIfMissed: false,
    );
    await _settle(tester);
    expect(find.byTooltip('Quay lại'), findsOneWidget);
    expect(
      find.textContaining('Trộn bốn loại bột'),
      findsOneWidget,
      reason: 'panel phải hiện mô tả của công đoạn vừa chạm',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn quản trị đọc dữ liệu sống, không đọc bản đã công bố', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'tule_admin_token': 'dev-token'});

    final paths = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      paths.add(path);
      if (path.endsWith('/admin/session')) return _json({'ok': true});
      if (path.endsWith('/admin/summary')) return _json({'products': 1});
      if (path.endsWith('/admin/chain')) {
        return _json({'configured': false, 'reachable': false, 'outbox': {}});
      }
      if (path.endsWith('/snapshots')) return _json([]);
      if (path.endsWith('/admin/product-batches')) {
        return _json({
          'items': [
            {
              'code': 'TL-2026-001',
              'name': 'Tú Lệ Smart Breakfast',
              'status': 'PUBLISHED',
              'created_at': '2026-08-10T02:30:00.000Z',
            },
          ],
          'total': 1,
          'page': 1,
          'pages': 1,
        });
      }
      return _json(_traceJson);
    });

    await tester.pumpWidget(_adminApp(_api(client)));
    await _settle(tester);
    await tester.tap(find.text('Lô sản phẩm').last);
    await _settle(tester);
    await tester.tap(find.text('Tú Lệ Smart Breakfast'));
    await _settle(tester);

    // Trang khách phục vụ bản đã công bố, nên admin phải đi đường riêng để
    // thấy đúng thứ mình vừa sửa.
    expect(
      paths.any((p) => p.endsWith('/admin/product-batches/TL-2026-001/trace')),
      isTrue,
    );
    expect(paths.any((p) => p.contains('/public/traces/')), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mục kiểm định hiện giấy chứng nhận và phiếu kiểm nghiệm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final withCert = Map<String, dynamic>.from(_traceJson);
    withCert['media'] = [
      ...(_traceJson['media'] as List<dynamic>),
      {
        'id': 77,
        'role': 'certificate',
        'kind': 'document',
        'url': '/api/media/media/cccc.pdf',
        'fileName': 'ocop.pdf',
        'contentType': 'application/pdf',
        'size': 120000,
        'sha256': 'cccc',
        'caption': 'OCOP 4 sao tỉnh Yên Bái',
        'certType': 'OCOP',
        'certNumber': '12/2026',
        'validUntil': '31/12/2028',
      },
    ];

    await tester.pumpWidget(
      _app(_api(MockClient((_) async => _json(withCert)))),
    );
    await _settle(tester);

    // Mục thông tin chung không dựng hồ sơ kiểm định: nó có mục riêng.
    expect(find.text('Phiếu kiểm nghiệm Quatest 1'), findsNothing);

    await tester.tap(find.text('Kiểm định chất lượng'));
    await _settle(tester);

    // Hai mục, mỗi mục là một lưới thẻ tài liệu.
    expect(find.text('Giấy chứng nhận'), findsOneWidget);
    expect(find.text('OCOP'), findsOneWidget);
    expect(find.textContaining('Số 12/2026'), findsOneWidget);
    expect(find.textContaining('31/12/2028'), findsOneWidget);
    expect(find.text('Phiếu kiểm nghiệm'), findsWidgets);
    expect(find.text('Xem cỡ đầy đủ'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lô chưa có hồ sơ kiểm định thì nói rõ, không để trống', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bare = Map<String, dynamic>.from(_traceJson);
    bare['media'] = const <dynamic>[];

    await tester.pumpWidget(_app(_api(MockClient((_) async => _json(bare)))));
    await _settle(tester);

    await tester.tap(find.text('Kiểm định chất lượng'));
    await _settle(tester);

    expect(
      find.textContaining('Chưa có giấy chứng nhận'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sơ đồ quy trình dựng từ thành phẩm xuống nguyên liệu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_api(_healthyClient())));
    await _settle(tester);
    await _openOrigin(tester);

    expect(find.byType(SourcingSection), findsOneWidget);
    expect(find.byType(ProcessTree), findsOneWidget);
    // Nơi sản xuất là điểm hội tụ, phải có trong danh sách hành trình.
    expect(find.text('Xưởng chế biến Tú Lệ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bấm một nút công đoạn trên sơ đồ thì panel mở chi tiết', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_api(_healthyClient())));
    await _settle(tester);
    await _openOrigin(tester);

    // Nút trên sơ đồ và dòng trong danh sách trùng tên, nên lấy nút nằm
    // trong ProcessTree.
    await tester.tap(
      find
          .descendant(
            of: find.byType(ProcessTree),
            matching: find.text('Nghiền thành bột mịn'),
          )
          .first,
      warnIfMissed: false,
    );
    await _settle(tester);

    // Panel đổi sang chi tiết công đoạn, có nút quay lại.
    expect(find.text('Nghiền thành bột mịn'), findsWidgets);
    expect(find.byTooltip('Quay lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bấm một điểm thì panel bên phải mở hồ sơ vùng đó', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_api(_healthyClient())));
    await _settle(tester);
    await _openOrigin(tester);

    // Chưa chọn gì: panel là hồ sơ sản phẩm, không phải hồ sơ một thành phần.
    expect(find.textContaining('2 nguyên liệu'), findsOneWidget);
    expect(find.text('Công đoạn'), findsNothing);

    // Chạm nút gốc nhánh trên sơ đồ.
    await tester.tap(
      find
          .descendant(
            of: find.byType(ProcessTree),
            matching: find.text('Cốm Tú Lệ'),
          )
          .first,
      warnIfMissed: false,
    );
    await _settle(tester);

    expect(find.text('Công đoạn'), findsOneWidget);
    expect(find.text('Hợp tác xã Tú Lệ'), findsWidgets);
    expect(find.text('Nghiền thành bột mịn'), findsWidgets);
    // Đã vào chi tiết thì hồ sơ lô nhường chỗ.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('2 nguyên liệu'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sơ đồ phóng to, thu nhỏ và về vừa khung', (tester) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_api(_healthyClient())));
    await _settle(tester);
    await _openOrigin(tester);

    expect(find.byTooltip('Phóng to'), findsOneWidget);
    expect(find.byTooltip('Thu nhỏ'), findsOneWidget);
    expect(find.byTooltip('Vừa khung'), findsOneWidget);

    await tester.tap(find.byTooltip('Phóng to'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Thu nhỏ'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Vừa khung'));
    await _settle(tester);

    // Sơ đồ vẫn dựng được sau ba lần đổi mức phóng.
    expect(find.byType(ProcessTree), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('bỏ dấu tiếng Việt để dò tên tỉnh', () {
    expect(foldVietnamese('Yên Bái'), 'yenbai');
    expect(foldVietnamese('  lào   cai '), 'laocai');
    expect(foldVietnamese('Đắk Lắk'), 'daklak');
  });

  test('đọc ngày dd.MM.yyyy và từ chối chuỗi rác', () {
    expect(parseTraceDate('12.08.2026'), DateTime(2026, 8, 12));
    expect(parseTraceDate('12/08/2026'), DateTime(2026, 8, 12));
    expect(parseTraceDate('hôm qua'), isNull);
    expect(parseTraceDate('32.13.2026'), isNull);
  });

  test('phân loại media theo vai trò', () {
    final record = TraceRecord.fromApi(Map<String, dynamic>.from(_traceJson));
    expect(record.cover?.caption, 'Gói thành phẩm');
    expect(record.cover?.kind, MediaKind.image);
    expect(record.labReports.single.kind, MediaKind.document);
    expect(record.gallery, isEmpty);
    // Tài liệu không nằm trong dải ảnh/video xem nhanh.
    expect(record.allVisualMedia.length, 1);
  });

  test('chi tiết công đoạn: khối lượng, người làm, tham số', () {
    final event = ProcessEvent.fromApi({
      'title': 'Sấy phun',
      'event_date': '12.08.2026',
      'operator': 'Nguyễn Văn A',
      'inputQuantity': 1000,
      'output_quantity': '210,5',
      'quantityUnit': 'g',
      'params': {'Nhiệt độ': '180°C', 'Thời gian': ' '},
    });
    expect(event.operator, 'Nguyễn Văn A');
    expect(event.inputQuantity, 1000);
    // Dấu phẩy thập phân của bàn phím tiếng Việt vẫn phải đọc được.
    expect(event.outputQuantity, 210.5);
    expect(event.yieldRatio, closeTo(0.2105, 0.0001));
    // Tham số rỗng bị loại chứ không hiện thành dòng trống.
    expect(event.params, {'Nhiệt độ': '180°C'});
    // Người làm thay chỗ của người ghi nhận trong dòng phụ.
    expect(event.meta, contains('Nguyễn Văn A'));
  });

  test('params đọc được cả object lẫn chuỗi JSON', () {
    final fromString = ProcessEvent.fromApi({
      'title': 'Rang',
      'params': '{"Nhiệt độ":"100°C"}',
    });
    expect(fromString.params, {'Nhiệt độ': '100°C'});

    final broken = ProcessEvent.fromApi({'title': 'Rang', 'params': 'x{'});
    expect(broken.params, isEmpty);
    expect(broken.hasDetails, isFalse);
  });

  test('giấy chứng nhận tách khỏi hồ sơ kiểm nghiệm', () {
    final cert = MediaAsset.fromApi({
      'role': 'certificate',
      'kind': 'document',
      'url': '/api/media/media/abc.pdf',
      'cert_type': 'OCOP',
      'certNumber': '12/2026',
      'valid_until': '31/12/2028',
      'caption': 'OCOP 4 sao',
    });
    expect(cert.isCertificate, isTrue);
    expect(cert.isLabReport, isFalse);
    expect(cert.certLabel, 'OCOP · 12/2026');
    expect(cert.validUntil, '31/12/2028');
  });

  test('timeline sắp theo ngày dù API trả lộn xộn', () {
    final record = TraceRecord.fromApi(
      Map<String, dynamic>.from(_traceJson),
    );
    final titles = [for (final entry in record.timeline) entry.event.title];
    expect(titles, [
      'Thu hoạch lúa nếp nương',
      'Nghiền thành bột mịn',
      'Xay với nước',
    ]);
  });

  test('đọc được trạng thái toàn vẹn từ API', () {
    final record = TraceRecord.fromApi(
      Map<String, dynamic>.from(_traceJson),
    );
    expect(record.integrity.status, IntegrityStatus.verified);
    expect(record.integrity.version, 1);
    expect(record.ingredients.first.supplier, 'Hợp tác xã Tú Lệ');
  });

  test('field thiếu hoặc null không làm sập parser', () {
    final record = TraceRecord.fromApi({
      'code': 'TL-2026-009',
      'name': null,
      'ingredients': [
        {'name': 'Chỉ có tên'},
      ],
    });
    expect(record.batch.name, 'Lô chưa đặt tên');
    expect(record.batch.description, '');
    expect(record.ingredients.single.origin, 'Chưa có vùng nguyên liệu');
    expect(record.integrity.status, IntegrityStatus.unknown);
  });
}
