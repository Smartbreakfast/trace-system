import { Hono } from 'hono';

import * as auth from './auth';
import { ApiError, badRequest } from './errors';
import {
  allowedContentTypes,
  certTypes,
  deleteMedia,
  mediaRoles,
  serveMedia,
  storeUpload,
} from './media';
import { chainStatus } from './chain';
import type { Env } from './env';
import { normalizeArea } from './geojson';
import * as trace from './trace';
import { renderTrace, tabFromSlug } from './page/trace-page';
import { renderHome, renderNotFound } from './page/home-page';
import type { PublicTrace } from './page/types';
import {
  coord,
  int,
  jsonBody,
  oneOf,
  optionalAmount,
  optionalIndex,
  optionalInt,
  optionalParams,
  optionalText,
  pathInt,
  str,
} from './validate';

export type { Env } from './env';

type Variables = { auth: auth.Auth };

const app = new Hono<{ Bindings: Env; Variables: Variables }>();

/** Bearer token của request, rỗng khi không có header. */
function bearer(c: { req: { header: (name: string) => string | undefined } }) {
  const header = c.req.header('authorization') ?? '';
  return header.startsWith('Bearer ') ? header.slice(7).trim() : '';
}

/**
 * Trước đây toàn bộ /api/admin/* mở cho cả internet. Rồi đóng bằng một
 * ADMIN_TOKEN dùng chung: chặn được người ngoài, nhưng mọi thao tác đều ký tên
 * "admin" nên nhật ký không nói được ai làm gì.
 *
 * Giờ bearer token có thể là một trong hai thứ:
 *   - token phiên của một tài khoản (đường thường dùng), hoặc
 *   - ADMIN_TOKEN, cửa dự phòng cho script vận hành và cho lúc mất mật khẩu.
 *
 * Quyền của từng vai trò chốt ở `auth.permissions`; mỗi route dưới đây gọi
 * `requirePermission` và, với dữ liệu của một cơ sở, gọi `assertFacility`.
 */
app.use('/api/admin/*', async (c, next) => {
  const given = bearer(c);
  if (!given) {
    throw new ApiError(401, 'UNAUTHORIZED', 'Thiếu token. Hãy đăng nhập lại.');
  }

  const session = await auth.sessionAuth(c.env.DB, given);
  if (session) {
    c.set('auth', session);
    await next();
    return;
  }

  const expected = c.env.ADMIN_TOKEN;
  if (expected && auth.tokenMatches(given, expected)) {
    c.set('auth', auth.tokenAuth());
    await next();
    return;
  }
  throw new ApiError(
    401,
    'UNAUTHORIZED',
    'Phiên đăng nhập đã hết hoặc token không đúng.',
  );
});

app.onError((error, c) => {
  if (error instanceof ApiError) return error.toResponse();
  console.error('Unhandled error', error);
  return c.json(
    { error: 'INTERNAL', message: 'Máy chủ gặp lỗi không mong muốn.' },
    500,
  );
});

// --------------------------------------------------------------- trang web
//
// Trang tra cứu dựng sẵn thành HTML ngay tại đây. Bản Flutter phải tải 3,8MB
// engine rồi mới gọi API rồi mới vẽ; ở đây nội dung đi cùng byte đầu tiên,
// còn JS chỉ là lớp sơn cho thao tác mượt hơn.
//
// Màn quản trị vẫn là Flutter: nó chạy mỗi ngày trên máy quen, tải một lần
// rồi thôi, nên cái giá 3,8MB ở đó không ai phải trả hai lần.

/** Mã in trên bao bì hay bị nhập kèm khoảng trắng hoặc chữ thường. */
function normalizeCode(raw: string) {
  return raw.trim().toUpperCase().replace(/\s+/g, '');
}

function htmlResponse(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      // Cache ở biên 30 giây: đủ để một lô vừa quét nhiều lần không phải dựng
      // lại, mà công bố bản mới vẫn hiện ra gần như ngay.
      'cache-control': 'public, max-age=0, s-maxage=30, stale-while-revalidate=60',
      'x-content-type-options': 'nosniff',
    },
  });
}

app.get('/', async (c) => {
  const asked = c.req.query('code');
  if (asked !== undefined) {
    const code = normalizeCode(asked);
    if (code) return c.redirect(`/t/${encodeURIComponent(code)}`, 302);
  }
  const samples = await trace.publicBatches(c.env.DB);
  const products = await trace.publicCatalog(c.env.DB);
  const origin = new URL(c.req.url).origin;
  return htmlResponse(
    renderHome(samples, origin, asked !== undefined ? 'Nhập mã in trên bao bì, ví dụ TL-2026-001.' : '', products),
  );
});

app.get('/t/:code', async (c) => {
  const code = normalizeCode(c.req.param('code'));
  const origin = new URL(c.req.url).origin;
  let record: PublicTrace | null = null;
  try {
    record = (await trace.publicTrace(c.env.DB, code, c.env)) as PublicTrace;
  } catch (error) {
    if (!(error instanceof ApiError) || error.status !== 404) throw error;
  }
  if (!record) {
    const samples = await trace.publicBatches(c.env.DB);
    return htmlResponse(renderNotFound(code, samples, origin), 404);
  }
  const tab = tabFromSlug(c.req.query('tab'));
  const products = await trace.publicCatalog(c.env.DB);
  return htmlResponse(renderTrace(record, tab, origin, products));
});

// ------------------------------------------------------------------- public

app.get('/api/health', (c) =>
  c.json({
    ok: true,
    service: 'tule-trace-api',
    runtime: 'cloudflare-workers',
    database: 'd1',
    storage: 'r2',
    blockchain: 'adapter-pending-network',
  }),
);

// Mặc định 6 lô cho trang chủ; `?limit=` để công cụ đo lấy hết danh sách đã
// công bố. publicBatches tự chặn trên ở 20.
app.get('/api/public/batches', async (c) => {
  const asked = Number(c.req.query('limit'));
  return c.json(
    await trace.publicBatches(
      c.env.DB,
      Number.isInteger(asked) && asked > 0 ? asked : 6,
    ),
  );
});

app.get('/api/public/catalog', async (c) =>
  c.json(await trace.publicCatalog(c.env.DB)),
);

app.get('/api/public/featured', async (c) => c.json(await trace.featured(c.env.DB)));

/**
 * Bảng chỉ số của đề tài, mở cho mọi người xem: người chấm hồ sơ cần đối chiếu
 * con số trong báo cáo với hệ thống đang chạy mà không phải xin tài khoản.
 * Chỉ đọc, không tham số, không ghi lại gì về người xem.
 */
app.get('/api/public/metrics', async (c) =>
  c.json(await trace.publicMetrics(c.env.DB)),
);

app.get('/api/public/traces/:code', async (c) =>
  c.json(await trace.publicTrace(c.env.DB, c.req.param('code'), c.env)),
);

app.get('/api/public/traces/:code/verify', async (c) =>
  c.json(await trace.publicVerify(c.env.DB, c.req.param('code'), c.env)),
);

/**
 * Đánh giá của người mua. Endpoint công khai duy nhất có quyền ghi, nên chặn
 * ngay tại đây: số sao phải 1-5, nhận xét có giới hạn độ dài, và nguồn chỉ
 * nhận APP hoặc WEB. SURVEY và DEMO là việc của màn quản trị, người ngoài
 * không tự gắn nhãn cho phiếu của mình được.
 */
app.post('/api/public/traces/:code/ratings', async (c) => {
  const body = await jsonBody(c.req.raw);
  const stars = int(body, 'stars', 'số sao');
  if (stars > 5) throw badRequest('Số sao phải từ 1 đến 5.');
  const summary = await trace.saveRating(
    c.env.DB,
    normalizeCode(c.req.param('code')),
    {
      stars,
      comment: str(body, 'comment', 'nhận xét', { optional: true, max: 400 }),
      displayName: str(body, 'displayName', 'tên người gửi', {
        optional: true,
        max: 60,
      }),
      deviceId: str(body, 'deviceId', 'mã thiết bị', { min: 8, max: 120 }),
      source: oneOf(
        body.source,
        ['APP', 'WEB'] as const,
        'nguồn đánh giá',
        'APP',
      ),
    },
  );
  return c.json(summary, 201);
});

/**
 * Ghi một lượt mở hồ sơ lô. Chỉ cộng một số đếm: không IP, không thiết bị,
 * không thời điểm từng lượt, nên vẫn khai được "không thu thập dữ liệu" ở hồ
 * sơ App Store. Lỗi ở đây không được làm hỏng việc xem hồ sơ.
 */
app.post('/api/public/traces/:code/view', async (c) => {
  try {
    return c.json(
      await trace.recordView(c.env.DB, normalizeCode(c.req.param('code'))),
    );
  } catch {
    return c.json({ views: null }, 200);
  }
});

app.get('/api/media/*', (c) => {
  const key = decodeURIComponent(
    new URL(c.req.url).pathname.replace('/api/media/', ''),
  );
  return serveMedia(c.env.MEDIA, key, c.req.raw);
});

// ------------------------------------------------------------------ đăng nhập
//
// Nằm ngoài /api/admin/* vì lúc đăng nhập thì chưa có token nào để mà kiểm.

app.post('/api/auth/login', async (c) => {
  const body = await jsonBody(c.req.raw);
  const result = await auth.login(
    c.env.DB,
    str(body, 'username', 'tên đăng nhập', { min: 3, max: 40 }),
    str(body, 'password', 'mật khẩu', { min: 1, max: 200 }),
  );
  await auth.writeAudit(c.env.DB, result.auth, 'LOGIN', result.auth.username);
  return c.json({
    token: result.token,
    expiresAt: result.expiresAt,
    user: publicAuth(result.auth),
  });
});

app.post('/api/auth/logout', async (c) => {
  const token = bearer(c);
  if (token) await auth.logout(c.env.DB, token);
  return c.json({ ok: true });
});

// -------------------------------------------------------------------- admin

/// Màn quản trị gọi đường này ngay khi mở để biết mình là ai và được làm gì.
app.get('/api/admin/session', (c) =>
  c.json({ ok: true, user: publicAuth(c.get('auth')) }),
);

app.get('/api/admin/summary', async (c) => {
  const me = c.get('auth');
  return c.json(await trace.summary(c.env.DB, scopeOf(me)));
});

/// Danh sách cơ sở, để màn quản trị hiện tên cơ sở và gán tài khoản.
app.get('/api/admin/facilities', async (c) =>
  c.json(await auth.listFacilities(c.env.DB)),
);

// ------------------------------------------------------------------ tài khoản

app.get('/api/admin/users', async (c) => {
  auth.requirePermission(c.get('auth'), 'manageUsers');
  return c.json(await auth.listUsers(c.env.DB));
});

app.post('/api/admin/users', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageUsers');
  const body = await jsonBody(c.req.raw);
  const created = await auth.createUser(c.env.DB, {
    username: str(body, 'username', 'tên đăng nhập', { max: 40 }),
    password: str(body, 'password', 'mật khẩu', { max: 200 }),
    fullName: str(body, 'fullName', 'họ tên', { optional: true, max: 120 }),
    role: oneOf(body.role, auth.roles, 'vai trò'),
    facilityId: optionalInt(body, 'facilityId', 'cơ sở') ?? null,
  });
  await auth.writeAudit(
    c.env.DB,
    me,
    'CREATE_USER',
    String(created.username),
    `vai trò ${created.role}`,
  );
  return c.json(created, 201);
});

app.patch('/api/admin/users/:id', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageUsers');
  const id = pathInt(c.req.param('id'), 'id tài khoản');
  const body = await jsonBody(c.req.raw);

  const role =
    body.role === undefined ? undefined : oneOf(body.role, auth.roles, 'vai trò');
  const active = body.active === undefined ? undefined : Boolean(body.active);

  const updated = await auth.updateUser(c.env.DB, id, {
    fullName:
      body.fullName === undefined
        ? undefined
        : str(body, 'fullName', 'họ tên', { optional: true, max: 120 }),
    password:
      body.password === undefined
        ? undefined
        : str(body, 'password', 'mật khẩu', { max: 200 }),
    active,
    role,
    facilityId:
      body.facilityId === undefined
        ? undefined
        : (optionalInt(body, 'facilityId', 'cơ sở') ?? null),
  });
  await auth.writeAudit(
    c.env.DB,
    me,
    'UPDATE_USER',
    updated.username,
    [
      body.password !== undefined ? 'đổi mật khẩu' : '',
      active === undefined ? '' : active ? 'mở lại' : 'khoá',
      role === undefined ? '' : `vai trò ${role}`,
    ]
      .filter(Boolean)
      .join(', '),
  );
  return c.json(updated);
});

/// Đổi mật khẩu của chính mình. Mọi vai trò đều được, và phải nhập mật khẩu cũ.
app.post('/api/admin/users/me/password', async (c) => {
  const me = c.get('auth');
  if (me.userId === null) {
    throw badRequest('Đang vào bằng token quản trị, không có mật khẩu để đổi.');
  }
  const body = await jsonBody(c.req.raw);
  await auth.verifyCredentials(
    c.env.DB,
    me.username,
    str(body, 'currentPassword', 'mật khẩu hiện tại', { max: 200 }),
  );
  await auth.updateUser(c.env.DB, me.userId, {
    password: str(body, 'newPassword', 'mật khẩu mới', { max: 200 }),
  });
  await auth.writeAudit(c.env.DB, me, 'CHANGE_PASSWORD', me.username);
  return c.json({ ok: true });
});

// -------------------------------------------------------------------- nhật ký

app.get('/api/admin/audit', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'viewAudit');
  return c.json(
    await auth.auditLog(c.env.DB, {
      limit: c.req.query('limit') ? Number(c.req.query('limit')) : undefined,
      target: c.req.query('target'),
      facilityId: scopeOf(me),
    }),
  );
});

/// Chỉ số cho báo cáo: phần hệ thống tự đếm và phần do cơ sở sản xuất khai.
app.get('/api/admin/metrics', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'viewMetrics');
  const [views, reported] = await Promise.all([
    trace.viewStats(c.env.DB, scopeOf(me)),
    trace.listReportedMetrics(c.env.DB),
  ]);
  return c.json({ views, reported });
});

/// Khai một chỉ số hệ thống không tự đo được. Bắt buộc ghi nguồn.
app.put('/api/admin/metrics/:key', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageMetrics');
  const body = await jsonBody(c.req.raw);
  const result = await trace.setReportedMetric(c.env.DB, {
    key: c.req.param('key'),
    label: str(body, 'label', 'tên chỉ số', { max: 120 }),
    value: str(body, 'value', 'giá trị', { max: 120 }),
    source: str(body, 'source', 'nguồn số liệu', { max: 200 }),
    note: str(body, 'note', 'ghi chú', { optional: true, max: 400 }),
    updatedBy: me.username,
  });
  await auth.writeAudit(c.env.DB, me, 'SET_METRIC', result.key, body.value ? String(body.value).slice(0, 120) : '');
  return c.json(result);
});

app.delete('/api/admin/metrics/:key', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageMetrics');
  const result = await trace.deleteReportedMetric(c.env.DB, c.req.param('key'));
  await auth.writeAudit(c.env.DB, me, 'DELETE_METRIC', result.key);
  return c.json(result);
});

/// Tổng hợp đánh giá theo lô và theo nguồn, để biết bao nhiêu phiếu là thật.
app.get('/api/admin/ratings', async (c) => {
  auth.requirePermission(c.get('auth'), 'manageRatings');
  return c.json(await trace.ratingReport(c.env.DB));
});

/// Nhập một đánh giá từ phiếu khảo sát giấy, hoặc gieo dữ liệu dựng sẵn.
app.post('/api/admin/ratings', async (c) => {
  auth.requirePermission(c.get('auth'), 'manageRatings');
  const body = await jsonBody(c.req.raw);
  const stars = int(body, 'stars', 'số sao');
  if (stars > 5) throw badRequest('Số sao phải từ 1 đến 5.');
  return c.json(
    await trace.saveRating(c.env.DB, normalizeCode(str(body, 'code', 'mã lô')), {
      stars,
      comment: str(body, 'comment', 'nhận xét', { optional: true, max: 400 }),
      displayName: str(body, 'displayName', 'tên người gửi', {
        optional: true,
        max: 60,
      }),
      deviceId: str(body, 'deviceId', 'mã phiếu', { min: 8, max: 120 }),
      source: oneOf(body.source, trace.ratingSources, 'nguồn đánh giá', 'SURVEY'),
      createdAt: str(body, 'createdAt', 'thời điểm', { optional: true, max: 40 }) || undefined,
    }),
    201,
  );
});

/// Xoá cả một nguồn, dùng khi thay dữ liệu dựng sẵn bằng số liệu thật.
app.delete('/api/admin/ratings/:source', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageRatings');
  const source = oneOf(c.req.param('source'), trace.ratingSources, 'nguồn đánh giá');
  const result = await trace.deleteRatings(c.env.DB, source);
  await auth.writeAudit(c.env.DB, me, 'DELETE_RATINGS', source);
  return c.json(result);
});

app.get('/api/admin/products', async (c) =>
  c.json(await trace.listProducts(c.env.DB, scopeOf(c.get('auth')))),
);

app.post('/api/admin/products', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageCatalog');
  const body = await jsonBody(c.req.raw);
  // Bắt buộc có cơ sở: lô thừa hưởng cơ sở từ sản phẩm, nên một mã sản phẩm
  // không thuộc cơ sở nào sẽ đẻ ra những lô mà chỉ quản trị mở được.
  const facilityId = int(body, 'facilityId', 'cơ sở sản xuất');
  await auth.assertFacilityExists(c.env.DB, facilityId);
  const created = await trace.createCatalogProduct(c.env.DB, {
      sku: str(body, 'sku', 'mã sản phẩm', { max: 80 }),
      name: str(body, 'name', 'tên sản phẩm', { min: 2, max: 160 }),
      description: str(body, 'description', 'mô tả', { optional: true }),
      templateKey: oneOf(
        str(body, 'templateKey', 'template', { optional: true, max: 80 }),
        ['', 'tule-breakfast', 'buffalo-dried'] as const,
        'template',
        '',
      ),
      facilityId,
  });
  await auth.writeAudit(
    c.env.DB,
    me,
    'CREATE_PRODUCT',
    String(created?.sku ?? ''),
    String(created?.name ?? ''),
  );
  return c.json(created, 201);
});

app.get('/api/admin/product-batches', async (c) => {
  const query = c.req.query();
  return c.json(
    await trace.listBatches(c.env.DB, {
      q: query.q,
      productSku: query.productSku,
      sort: query.sort,
      page: query.page ? Number(query.page) : undefined,
      limit: query.limit ? Number(query.limit) : undefined,
      facilityId: scopeOf(c.get('auth')),
    }),
  );
});

app.get('/api/admin/product-batches/:code/snapshots', async (c) => {
  const code = c.req.param('code');
  await assertBatchScope(c, code);
  return c.json(await trace.snapshots(c.env.DB, code));
});

app.post('/api/admin/product-batches', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageBatch');
  const body = await jsonBody(c.req.raw);
  const productId = int(body, 'productId', 'sản phẩm');
  // Lô mới phải thuộc một sản phẩm của chính cơ sở mình.
  auth.assertFacility(me, await auth.facilityOfProduct(c.env.DB, productId));
  const created = await trace.createProduct(c.env.DB, {
    productId,
    name: str(body, 'name', 'tên sản phẩm', { min: 2, max: 160 }),
    code: str(body, 'code', 'mã lô', { min: 4, max: 64 }),
    productionDate: str(body, 'productionDate', 'ngày sản xuất', { max: 40 }),
    expiryDate: str(body, 'expiryDate', 'hạn sử dụng', { max: 40 }),
    description: str(body, 'description', 'mô tả', { optional: true }),
    facilityName: str(body, 'facilityName', 'nơi sản xuất', {
      optional: true,
      max: 200,
    }),
    latitude: coord(body, 'latitude', 'vĩ độ nơi sản xuất', 90),
    longitude: coord(body, 'longitude', 'kinh độ nơi sản xuất', 180),
  });
  await auth.writeAudit(
    c.env.DB,
    me,
    'CREATE_BATCH',
    String(created?.code ?? ''),
    String(created?.name ?? ''),
  );
  return c.json(created, 201);
});

app.patch('/api/admin/product-batches/:code', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageBatch');
  const code = c.req.param('code');
  await assertBatchScope(c, code);
  const body = await jsonBody(c.req.raw);
  const updated = await trace.updateProduct(c.env.DB, code, {
    name: optional(body, 'name', 'tên sản phẩm', 160),
    productionDate: optional(body, 'productionDate', 'ngày sản xuất', 40),
    expiryDate: optional(body, 'expiryDate', 'hạn sử dụng', 40),
    description: optional(body, 'description', 'mô tả', 2000),
    facilityName: optional(body, 'facilityName', 'nơi sản xuất', 200),
    latitude: coord(body, 'latitude', 'vĩ độ nơi sản xuất', 90),
    longitude: coord(body, 'longitude', 'kinh độ nơi sản xuất', 180),
  });
  await auth.writeAudit(c.env.DB, me, 'UPDATE_BATCH', code);
  return c.json(updated);
});

app.delete('/api/admin/ingredient-batches/:id', async (c) => {
  const me = c.get('auth');
  // Xoá cả một nguyên liệu kèm công đoạn của nó là việc của người phụ trách,
  // không phải của nhân viên công đoạn.
  auth.requirePermission(me, 'manageBatch');
  const id = pathInt(c.req.param('id'), 'id nguyên liệu');
  auth.assertFacility(me, await auth.facilityOfIngredient(c.env.DB, id));
  const result = await trace.deleteIngredient(c.env.DB, id);
  await auth.writeAudit(c.env.DB, me, 'DELETE_INGREDIENT', String(id));
  return c.json(result);
});

/// Hồ sơ đầy đủ theo dữ liệu đang có, dành cho màn quản trị. Trang khách đọc
/// bản đã công bố, nên người vận hành phải có đường riêng để thấy thứ mình vừa
/// sửa.
app.get('/api/admin/product-batches/:code/trace', async (c) => {
  const code = c.req.param('code');
  await assertBatchScope(c, code);
  return c.json(await trace.adminTrace(c.env.DB, code, c.env));
});

app.get('/api/admin/product-batches/:code/snapshots/:version', async (c) => {
  const code = c.req.param('code');
  await assertBatchScope(c, code);
  return c.json(
    await trace.snapshotContent(
      c.env.DB,
      code,
      pathInt(c.req.param('version'), 'phiên bản'),
    ),
  );
});

app.get('/api/admin/chain', async (c) => {
  auth.requirePermission(c.get('auth'), 'viewChain');
  return c.json({
    ...(await chainStatus(c.env)),
    outbox: await trace.outboxSummary(c.env.DB),
  });
});

/// Gửi ngay những bản còn nằm trong hàng chờ. Dùng khi mạng vừa sập lúc công
/// bố, hoặc khi vừa sửa xong cấu hình chuỗi.
app.post('/api/admin/chain/send', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageChain');
  const result = await trace.drainOutbox(c.env, 10, true);
  await auth.writeAudit(c.env.DB, me, 'CHAIN_SEND', '', `gửi ${result.sent}`);
  return c.json(result);
});

app.post('/api/admin/chain/retry', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageChain');
  const result = await trace.retryOutbox(c.env.DB);
  await auth.writeAudit(c.env.DB, me, 'CHAIN_RETRY', '');
  return c.json(result);
});

app.post('/api/admin/product-batches/:code/publish', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'publish');
  const code = c.req.param('code');
  await assertBatchScope(c, code);
  // Tên người công bố lấy từ phiên đăng nhập, không nhận từ body: để client tự
  // khai tên thì dòng "công bố bởi" trong hồ sơ không còn là bằng chứng gì cả.
  const result = await trace.publish(c.env.DB, code, me.username);
  await auth.writeAudit(
    c.env.DB,
    me,
    'PUBLISH',
    code,
    `bản ${result.version}, mã băm ${result.sha256.slice(0, 12)}`,
  );
  // Gửi lên chuỗi ngay sau khi chốt, nhưng không bắt người vận hành đứng chờ
  // giao dịch: `waitUntil` cho worker chạy tiếp sau khi đã trả lời.
  c.executionCtx.waitUntil(
    trace.drainOutbox(c.env, 3).catch((error) => {
      console.error('Không gửi được lên chuỗi', error);
    }),
  );
  return c.json(result, 201);
});

app.post('/api/admin/ingredient-batches', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageBatch');
  const body = await jsonBody(c.req.raw);
  const productBatchId = int(body, 'productBatchId', 'lô thành phẩm');
  auth.assertFacility(me, await auth.facilityOfBatch(c.env.DB, productBatchId));
  const created = await trace.createIngredient(c.env.DB, {
    productBatchId,
    name: str(body, 'name', 'tên nguyên liệu', { max: 160 }),
    origin: str(body, 'origin', 'vùng nguyên liệu', { max: 200 }),
    supplier: str(body, 'supplier', 'nhà cung cấp', { optional: true, max: 200 }),
    harvestDate: str(body, 'harvestDate', 'ngày thu hoạch', {
      optional: true,
      max: 40,
    }),
    receivedDate: str(body, 'receivedDate', 'ngày nhập kho', {
      optional: true,
      max: 40,
    }),
    summary: str(body, 'summary', 'mô tả', { optional: true }),
    sourceProductBatchId: optionalInt(body, 'sourceProductBatchId', 'batch nguyên liệu nguồn'),
    latitude: coord(body, 'latitude', 'vĩ độ vùng nguyên liệu', 90),
    longitude: coord(body, 'longitude', 'kinh độ vùng nguyên liệu', 180),
    areaGeoJson: normalizeArea(body.areaGeoJson),
  });
  await auth.writeAudit(
    c.env.DB,
    me,
    'CREATE_INGREDIENT',
    String(created?.id ?? ''),
    String(created?.name ?? ''),
  );
  return c.json(created, 201);
});

app.patch('/api/admin/ingredient-batches/:id', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageBatch');
  const ingredientId = pathInt(c.req.param('id'), 'id nguyên liệu');
  auth.assertFacility(me, await auth.facilityOfIngredient(c.env.DB, ingredientId));
  const body = await jsonBody(c.req.raw);
  const updated = await trace.updateIngredient(
    c.env.DB,
    ingredientId,
    {
      name: optional(body, 'name', 'tên nguyên liệu', 160),
      origin: optional(body, 'origin', 'vùng nguyên liệu', 200),
      supplier: optional(body, 'supplier', 'nhà cung cấp', 200),
      harvestDate: optional(body, 'harvestDate', 'ngày thu hoạch', 40),
      receivedDate: optional(body, 'receivedDate', 'ngày nhập kho', 40),
      summary: optional(body, 'summary', 'mô tả', 2000),
      latitude: coord(body, 'latitude', 'vĩ độ vùng nguyên liệu', 90),
      longitude: coord(body, 'longitude', 'kinh độ vùng nguyên liệu', 180),
      areaGeoJson: normalizeArea(body.areaGeoJson),
      sourceProductBatchId: optionalInt(body, 'sourceProductBatchId', 'batch nguyên liệu nguồn'),
    },
  );
  await auth.writeAudit(
    c.env.DB,
    me,
    'UPDATE_INGREDIENT',
    String(ingredientId),
  );
  return c.json(updated);
});

app.post('/api/admin/process-events', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageEvent');
  const body = await jsonBody(c.req.raw);
  // Một trong hai: công đoạn của nguyên liệu, hoặc công đoạn ở xưởng.
  const ingredientBatchId = optionalInt(body, 'ingredientBatchId', 'lô nguyên liệu');
  const productBatchId = optionalInt(body, 'productBatchId', 'lô sản phẩm');
  if (ingredientBatchId != null) {
    auth.assertFacility(
      me,
      await auth.facilityOfIngredient(c.env.DB, ingredientBatchId),
    );
  }
  if (productBatchId != null) {
    auth.assertFacility(me, await auth.facilityOfBatch(c.env.DB, productBatchId));
  }
  const created = await trace.createEvent(c.env.DB, {
    ingredientBatchId,
    productBatchId,
    title: str(body, 'title', 'tên công đoạn', { max: 200 }),
    description: str(body, 'description', 'ghi chú', { optional: true }),
    eventDate: str(body, 'eventDate', 'ngày thực hiện', { max: 40 }),
    // Người nhập là người đang đăng nhập. Đây là chỗ câu "mỗi người tự khai
    // báo" thành có thật: không ai khai hộ dưới tên người khác được.
    enteredBy: me.username,
    position: optionalIndex(body, 'position', 'thứ tự công đoạn'),
    operator: optionalText(body, 'operator', 'người thực hiện', 120),
    inputQuantity: optionalAmount(body, 'inputQuantity', 'khối lượng vào'),
    outputQuantity: optionalAmount(body, 'outputQuantity', 'khối lượng ra'),
    quantityUnit: optionalText(body, 'quantityUnit', 'đơn vị khối lượng', 16),
    params: optionalParams(body, 'params', 'tham số công đoạn'),
  });
  await auth.writeAudit(
    c.env.DB,
    me,
    'CREATE_EVENT',
    String(created?.id ?? ''),
    String(created?.title ?? ''),
  );
  return c.json(created, 201);
});

app.patch('/api/admin/process-events/:id', async (c) => {
  const me = c.get('auth');
  auth.requirePermission(me, 'manageEvent');
  const eventId = pathInt(c.req.param('id'), 'id công đoạn');
  auth.assertFacility(me, await auth.facilityOfEvent(c.env.DB, eventId));
  const body = await jsonBody(c.req.raw);
  const updated = await trace.updateEvent(
    c.env.DB,
    eventId,
    {
      title: str(body, 'title', 'tên công đoạn', { optional: true, max: 200 }),
      description: str(body, 'description', 'ghi chú', { optional: true }),
      eventDate: str(body, 'eventDate', 'ngày thực hiện', {
        optional: true,
        max: 40,
      }),
      position: optionalIndex(body, 'position', 'thứ tự công đoạn'),
      operator: optionalText(body, 'operator', 'người thực hiện', 120),
      inputQuantity: optionalAmount(body, 'inputQuantity', 'khối lượng vào'),
      outputQuantity: optionalAmount(body, 'outputQuantity', 'khối lượng ra'),
      quantityUnit: optionalText(body, 'quantityUnit', 'đơn vị khối lượng', 16),
      params: optionalParams(body, 'params', 'tham số công đoạn'),
    },
  );
  await auth.writeAudit(c.env.DB, me, 'UPDATE_EVENT', String(eventId));
  return c.json(updated);
});

app.delete('/api/admin/process-events/:id', async (c) => {
  const me = c.get('auth');
  // Nhân viên khai thêm và sửa được, nhưng xoá một công đoạn khỏi lịch sử là
  // việc của người phụ trách cơ sở.
  auth.requirePermission(me, 'manageBatch');
  const eventId = pathInt(c.req.param('id'), 'id công đoạn');
  auth.assertFacility(me, await auth.facilityOfEvent(c.env.DB, eventId));
  const result = await trace.deleteEvent(c.env.DB, eventId);
  await auth.writeAudit(c.env.DB, me, 'DELETE_EVENT', String(eventId));
  return c.json(result);
});

app.get('/api/admin/media/config', (c) =>
  c.json({
    maxBytes: maxUpload(c.env),
    contentTypes: allowedContentTypes,
    roles: mediaRoles,
    certTypes,
  }),
);

app.post('/api/admin/media', async (c) => {
  const form = await c.req.raw.formData().catch(() => {
    throw new ApiError(400, 'VALIDATION_FAILED', 'Body phải là multipart/form-data.');
  });
  const file = form.get('file');
  if (!(file instanceof File)) {
    throw new ApiError(400, 'VALIDATION_FAILED', 'Thiếu trường file.');
  }

  const ownerType = oneOf(
    form.get('ownerType'),
    trace.ownerTypesList,
    'ownerType',
  );
  const ownerId = Number(form.get('ownerId'));
  if (!Number.isInteger(ownerId) || ownerId <= 0) {
    throw new ApiError(400, 'VALIDATION_FAILED', 'Thiếu ownerId hợp lệ.');
  }
  const me = c.get('auth');
  auth.requirePermission(me, 'manageMedia');
  // facilityOfOwner cũng trả 404 khi không có đối tượng, nên không cần kiểm
  // tồn tại thêm một lần nữa.
  auth.assertFacility(me, await auth.facilityOfOwner(c.env.DB, ownerType, ownerId));

  const stored = await storeUpload(c.env.DB, c.env.MEDIA, {
    file,
    ownerType,
    ownerId,
    role: oneOf(form.get('role'), mediaRoles, 'role', 'gallery'),
    caption: String(form.get('caption') ?? '').slice(0, 300),
    maxBytes: maxUpload(c.env),
    certType: String(form.get('certType') ?? '').slice(0, 40) || null,
    certNumber: String(form.get('certNumber') ?? '').slice(0, 80) || null,
    validUntil: String(form.get('validUntil') ?? '').slice(0, 40) || null,
  });
  await auth.writeAudit(
    c.env.DB,
    me,
    'UPLOAD_MEDIA',
    `${ownerType}:${ownerId}`,
    String((stored as Record<string, unknown>)?.fileName ?? ''),
  );
  return c.json(stored, 201);
});

app.delete('/api/admin/media/:id', async (c) => {
  const me = c.get('auth');
  // Đính thêm ảnh là việc của nhân viên, nhưng gỡ một minh chứng khỏi hồ sơ
  // thì không: cùng lý do với xoá công đoạn.
  auth.requirePermission(me, 'manageBatch');
  const id = pathInt(c.req.param('id'), 'id media');
  const owner = await c.env.DB.prepare(
    'SELECT owner_type as ownerType, owner_id as ownerId FROM media_assets WHERE id = ?',
  )
    .bind(id)
    .first<{ ownerType: string; ownerId: number }>();
  if (!owner) throw new ApiError(404, 'NOT_FOUND', 'Không tìm thấy media.');
  auth.assertFacility(
    me,
    await auth.facilityOfOwner(c.env.DB, owner.ownerType, Number(owner.ownerId)),
  );
  const result = await deleteMedia(c.env.DB, c.env.MEDIA, id);
  await auth.writeAudit(c.env.DB, me, 'DELETE_MEDIA', String(id));
  return c.json(result);
});

// Mọi đường dẫn còn lại là của ứng dụng Flutter (SPA fallback do assets lo).
app.all('*', (c) => c.env.ASSETS.fetch(c.req.raw));

// ------------------------------------------------------------------ helpers

/** Hồ sơ người đang đăng nhập, kèm bảng quyền để giao diện khỏi đoán. */
function publicAuth(me: auth.Auth) {
  return {
    username: me.username,
    fullName: me.fullName,
    role: me.role,
    roleLabel: auth.roleLabel(me.role),
    facilityId: me.facilityId,
    facilityName: me.facilityName,
    viaToken: me.viaToken,
    permissions: auth.permissions[me.role],
  };
}

/**
 * Phạm vi dữ liệu của một người: null là mọi cơ sở, số là một cơ sở. Tài khoản
 * không phải quản trị mà chưa gán cơ sở thì không được thấy gì, chứ không phải
 * được thấy tất cả.
 */
function scopeOf(me: auth.Auth) {
  if (auth.can(me, 'allFacilities')) return null;
  if (me.facilityId === null) {
    throw new ApiError(
      403,
      'FORBIDDEN',
      'Tài khoản chưa được gán cơ sở, không truy cập được dữ liệu nào.',
    );
  }
  return me.facilityId;
}

async function assertBatchScope(
  c: { env: Env; get: (key: 'auth') => auth.Auth },
  code: string,
) {
  const me = c.get('auth');
  if (auth.can(me, 'allFacilities')) return;
  auth.assertFacility(me, await auth.facilityOfBatchCode(c.env.DB, code));
}

function maxUpload(env: Env) {
  const parsed = Number(env.MAX_UPLOAD_BYTES);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 30 * 1024 * 1024;
}

function optional(
  body: Record<string, unknown>,
  field: string,
  label: string,
  max: number,
) {
  return body[field] === undefined
    ? undefined
    : str(body, field, label, { optional: true, max });
}

/// Cron quét lại hàng chờ. Mạng có lúc chập, `waitUntil` lúc công bố có thể
/// trượt; cái này là lưới đỡ để không bản nào nằm lại mãi mà không ai biết.
export default {
  fetch: app.fetch,
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(
      trace.drainOutbox(env, 10).then((result) => {
        if (result.sent || result.failed) console.log('Hàng chờ chuỗi', result);
      }),
    );
  },
};
