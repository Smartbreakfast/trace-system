import { Hono } from 'hono';

import { ApiError } from './errors';
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

const app = new Hono<{ Bindings: Env }>();

/** So sánh token theo thời gian hằng số để không lộ thông tin qua độ trễ. */
function tokenMatches(given: string, expected: string) {
  if (given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < given.length; i += 1) {
    diff |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return diff === 0;
}

/**
 * Trước đây toàn bộ /api/admin/* mở cho cả internet. Chấp nhận được khi chỉ
 * chạy localhost, nhưng lên Cloudflare thì bất kỳ ai cũng công bố lô giả và
 * đổ file vào R2 của bạn được.
 */
app.use('/api/admin/*', async (c, next) => {
  const expected = c.env.ADMIN_TOKEN;
  if (!expected) {
    throw new ApiError(
      503,
      'ADMIN_TOKEN_MISSING',
      'Chưa cấu hình ADMIN_TOKEN. Chạy: wrangler secret put ADMIN_TOKEN',
    );
  }
  const header = c.req.header('authorization') ?? '';
  const given = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!given || !tokenMatches(given, expected)) {
    throw new ApiError(401, 'UNAUTHORIZED', 'Token quản trị không đúng.');
  }
  await next();
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
  const origin = new URL(c.req.url).origin;
  return htmlResponse(
    renderHome(samples, origin, asked !== undefined ? 'Nhập mã in trên bao bì, ví dụ TL-2026-001.' : ''),
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
  return htmlResponse(renderTrace(record, tab, origin));
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

app.get('/api/public/batches', async (c) =>
  c.json(await trace.publicBatches(c.env.DB)),
);

app.get('/api/public/featured', async (c) => c.json(await trace.featured(c.env.DB)));

app.get('/api/public/traces/:code', async (c) =>
  c.json(await trace.publicTrace(c.env.DB, c.req.param('code'), c.env)),
);

app.get('/api/public/traces/:code/verify', async (c) =>
  c.json(await trace.publicVerify(c.env.DB, c.req.param('code'), c.env)),
);

app.get('/api/media/*', (c) => {
  const key = decodeURIComponent(
    new URL(c.req.url).pathname.replace('/api/media/', ''),
  );
  return serveMedia(c.env.MEDIA, key, c.req.raw);
});

// -------------------------------------------------------------------- admin

app.get('/api/admin/session', (c) => c.json({ ok: true, role: 'admin' }));

app.get('/api/admin/summary', async (c) => c.json(await trace.summary(c.env.DB)));

app.get('/api/admin/product-batches', async (c) => {
  const query = c.req.query();
  return c.json(
    await trace.listBatches(c.env.DB, {
      q: query.q,
      sort: query.sort,
      page: query.page ? Number(query.page) : undefined,
      limit: query.limit ? Number(query.limit) : undefined,
    }),
  );
});

app.get('/api/admin/product-batches/:code/snapshots', async (c) =>
  c.json(await trace.snapshots(c.env.DB, c.req.param('code'))),
);

app.post('/api/admin/product-batches', async (c) => {
  const body = await jsonBody(c.req.raw);
  const created = await trace.createProduct(c.env.DB, {
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
  return c.json(created, 201);
});

app.patch('/api/admin/product-batches/:code', async (c) => {
  const body = await jsonBody(c.req.raw);
  const updated = await trace.updateProduct(c.env.DB, c.req.param('code'), {
    name: optional(body, 'name', 'tên sản phẩm', 160),
    productionDate: optional(body, 'productionDate', 'ngày sản xuất', 40),
    expiryDate: optional(body, 'expiryDate', 'hạn sử dụng', 40),
    description: optional(body, 'description', 'mô tả', 2000),
    facilityName: optional(body, 'facilityName', 'nơi sản xuất', 200),
    latitude: coord(body, 'latitude', 'vĩ độ nơi sản xuất', 90),
    longitude: coord(body, 'longitude', 'kinh độ nơi sản xuất', 180),
  });
  return c.json(updated);
});

app.delete('/api/admin/ingredient-batches/:id', async (c) =>
  c.json(
    await trace.deleteIngredient(
      c.env.DB,
      pathInt(c.req.param('id'), 'id nguyên liệu'),
    ),
  ),
);

/// Hồ sơ đầy đủ theo dữ liệu đang có, dành cho màn quản trị. Trang khách đọc
/// bản đã công bố, nên người vận hành phải có đường riêng để thấy thứ mình vừa
/// sửa.
app.get('/api/admin/product-batches/:code/trace', async (c) =>
  c.json(await trace.adminTrace(c.env.DB, c.req.param('code'), c.env)),
);

app.get('/api/admin/product-batches/:code/snapshots/:version', async (c) =>
  c.json(
    await trace.snapshotContent(
      c.env.DB,
      c.req.param('code'),
      pathInt(c.req.param('version'), 'phiên bản'),
    ),
  ),
);

app.get('/api/admin/chain', async (c) =>
  c.json({
    ...(await chainStatus(c.env)),
    outbox: await trace.outboxSummary(c.env.DB),
  }),
);

/// Gửi ngay những bản còn nằm trong hàng chờ. Dùng khi mạng vừa sập lúc công
/// bố, hoặc khi vừa sửa xong cấu hình chuỗi.
app.post('/api/admin/chain/send', async (c) =>
  c.json(await trace.drainOutbox(c.env, 10, true)),
);

app.post('/api/admin/chain/retry', async (c) =>
  c.json(await trace.retryOutbox(c.env.DB)),
);

app.post('/api/admin/product-batches/:code/publish', async (c) => {
  const body = await safeJson(c.req.raw);
  const result = await trace.publish(
    c.env.DB,
    c.req.param('code'),
    str(body, 'enteredBy', 'người công bố', { optional: true, max: 80 }) ||
      'admin',
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
  const body = await jsonBody(c.req.raw);
  const created = await trace.createIngredient(c.env.DB, {
    productBatchId: int(body, 'productBatchId', 'lô thành phẩm'),
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
    latitude: coord(body, 'latitude', 'vĩ độ vùng nguyên liệu', 90),
    longitude: coord(body, 'longitude', 'kinh độ vùng nguyên liệu', 180),
    areaGeoJson: normalizeArea(body.areaGeoJson),
  });
  return c.json(created, 201);
});

app.patch('/api/admin/ingredient-batches/:id', async (c) => {
  const body = await jsonBody(c.req.raw);
  const updated = await trace.updateIngredient(
    c.env.DB,
    pathInt(c.req.param('id'), 'id nguyên liệu'),
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
    },
  );
  return c.json(updated);
});

app.post('/api/admin/process-events', async (c) => {
  const body = await jsonBody(c.req.raw);
  const created = await trace.createEvent(c.env.DB, {
    // Một trong hai: công đoạn của nguyên liệu, hoặc công đoạn ở xưởng.
    ingredientBatchId: optionalInt(body, 'ingredientBatchId', 'lô nguyên liệu'),
    productBatchId: optionalInt(body, 'productBatchId', 'lô sản phẩm'),
    title: str(body, 'title', 'tên công đoạn', { max: 200 }),
    description: str(body, 'description', 'ghi chú', { optional: true }),
    eventDate: str(body, 'eventDate', 'ngày thực hiện', { max: 40 }),
    enteredBy: str(body, 'enteredBy', 'người nhập', { optional: true, max: 80 }),
    position: optionalIndex(body, 'position', 'thứ tự công đoạn'),
    operator: optionalText(body, 'operator', 'người thực hiện', 120),
    inputQuantity: optionalAmount(body, 'inputQuantity', 'khối lượng vào'),
    outputQuantity: optionalAmount(body, 'outputQuantity', 'khối lượng ra'),
    quantityUnit: optionalText(body, 'quantityUnit', 'đơn vị khối lượng', 16),
    params: optionalParams(body, 'params', 'tham số công đoạn'),
  });
  return c.json(created, 201);
});

app.patch('/api/admin/process-events/:id', async (c) => {
  const body = await jsonBody(c.req.raw);
  const updated = await trace.updateEvent(
    c.env.DB,
    pathInt(c.req.param('id'), 'id công đoạn'),
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
  return c.json(updated);
});

app.delete('/api/admin/process-events/:id', async (c) =>
  c.json(
    await trace.deleteEvent(c.env.DB, pathInt(c.req.param('id'), 'id công đoạn')),
  ),
);

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
  await assertOwnerExists(c.env.DB, ownerType, ownerId);

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
  return c.json(stored, 201);
});

app.delete('/api/admin/media/:id', async (c) =>
  c.json(
    await deleteMedia(
      c.env.DB,
      c.env.MEDIA,
      pathInt(c.req.param('id'), 'id media'),
    ),
  ),
);

// Mọi đường dẫn còn lại là của ứng dụng Flutter (SPA fallback do assets lo).
app.all('*', (c) => c.env.ASSETS.fetch(c.req.raw));

// ------------------------------------------------------------------ helpers

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

/** Publish có thể được gọi không kèm body, không nên vì thế mà thành 400. */
async function safeJson(request: Request): Promise<Record<string, unknown>> {
  try {
    const parsed = await request.json();
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? (parsed as Record<string, unknown>)
      : {};
  } catch {
    return {};
  }
}

const ownerTables: Record<string, string> = {
  product_batch: 'product_batches',
  ingredient_batch: 'ingredient_batches',
  process_event: 'process_events',
};

async function assertOwnerExists(
  db: D1Database,
  ownerType: string,
  ownerId: number,
) {
  const table = ownerTables[ownerType];
  const row = await db
    .prepare(`SELECT id FROM ${table} WHERE id = ?`)
    .bind(ownerId)
    .first();
  if (!row) {
    throw new ApiError(
      404,
      'OWNER_NOT_FOUND',
      'Không tìm thấy đối tượng để gắn media.',
    );
  }
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
