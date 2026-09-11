import { sha256Of } from './canonical';
import { anchorBatch, chainConfig } from './chain';
import type { Env } from './env';
import { ApiError } from './errors';

export type Row = Record<string, unknown>;

export const ownerTypesList = [
  'product_batch',
  'ingredient_batch',
  'process_event',
] as const;

export type OwnerType = (typeof ownerTypesList)[number];

const nowIso = () => new Date().toISOString();

async function all(db: D1Database, sql: string, ...binds: unknown[]) {
  const result = await db
    .prepare(sql)
    .bind(...binds)
    .all<Row>();
  return result.results ?? [];
}

async function first(db: D1Database, sql: string, ...binds: unknown[]) {
  return db
    .prepare(sql)
    .bind(...binds)
    .first<Row>();
}

async function count(db: D1Database, sql: string, ...binds: unknown[]) {
  const row = await first(db, sql, ...binds);
  return Number(row?.count ?? 0);
}

export async function findProduct(db: D1Database, code: string) {
  const product = await first(
    db,
    'SELECT * FROM product_batches WHERE code = ?',
    code,
  );
  if (!product) {
    throw new ApiError(404, 'TRACE_NOT_FOUND', 'Không tìm thấy mã truy xuất.');
  }
  return product;
}

/** Media gắn vào một chủ thể, dùng chung cho trang công khai và snapshot. */
export async function mediaFor(
  db: D1Database,
  ownerType: OwnerType,
  ownerIds: number[],
) {
  if (ownerIds.length === 0) return new Map<number, Row[]>();
  const placeholders = ownerIds.map(() => '?').join(',');
  const rows = await all(
    db,
    `SELECT * FROM media_assets WHERE owner_type = ? AND owner_id IN (${placeholders}) ORDER BY id`,
    ownerType,
    ...ownerIds,
  );
  const grouped = new Map<number, Row[]>();
  for (const row of rows) {
    const key = Number(row.owner_id);
    const list = grouped.get(key) ?? [];
    list.push(row);
    grouped.set(key, list);
  }
  return grouped;
}

function publicMedia(row: Row) {
  return {
    id: row.id,
    role: row.role,
    kind: row.kind,
    url: `/api/media/${row.r2_key}`,
    fileName: row.file_name,
    contentType: row.content_type,
    size: row.size,
    sha256: row.sha256,
    caption: row.caption,
    ...certFields(row),
  };
}

/**
 * Bỏ khoá khi không có dữ liệu.
 *
 * Đây là quy tắc RB-03 viết thành hàm: thêm một khoá rỗng vào payload là đổi
 * mã băm của mọi lô đã công bố trước đó, kể cả lô không ai đụng vào.
 */
function present(key: string, value: unknown) {
  if (value === null || value === undefined || value === '') return {};
  return { [key]: value };
}

/// Thông tin giấy chứng nhận, chỉ có ở media role = certificate.
function certFields(row: Row) {
  return {
    ...present('certType', row.cert_type),
    ...present('certNumber', row.cert_number),
    ...present('validUntil', row.valid_until),
  };
}

/// Chi tiết một công đoạn: phần chung cộng những trường đã khai.
function eventFields(row: Row) {
  const params = typeof row.params === 'string' && row.params ? row.params : null;
  return {
    title: row.title,
    description: row.description,
    eventDate: row.event_date,
    enteredBy: row.entered_by,
    ...present('operator', row.operator),
    ...present('inputQuantity', row.input_quantity),
    ...present('outputQuantity', row.output_quantity),
    ...present('quantityUnit', row.quantity_unit),
    ...(params ? { params: JSON.parse(params) as Record<string, string> } : {}),
  };
}

/** Phần media đưa vào snapshot: chỉ những trường xác định nội dung. */
function snapshotMedia(rows: Row[] = []) {
  return rows.map((row) => ({
    role: row.role,
    kind: row.kind,
    key: row.r2_key,
    fileName: row.file_name,
    contentType: row.content_type,
    size: row.size,
    sha256: row.sha256,
    caption: row.caption,
    ...certFields(row),
  }));
}

async function loadTree(db: D1Database, productId: number) {
  const product = await first(
    db,
    'SELECT * FROM product_batches WHERE id = ?',
    productId,
  );
  const ingredients = await all(
    db,
    'SELECT * FROM ingredient_batches WHERE product_batch_id = ? ORDER BY id',
    productId,
  );
  const ingredientIds = ingredients.map((item) => Number(item.id));
  const events =
    ingredientIds.length === 0
      ? []
      : await all(
          db,
          `SELECT * FROM process_events WHERE ingredient_batch_id IN (${ingredientIds
            .map(() => '?')
            .join(',')}) ORDER BY position, id`,
          ...ingredientIds,
        );

  // Công đoạn ở xưởng: phối trộn, đóng gói. Chúng thuộc về cả lô chứ không
  // thuộc nguyên liệu nào, nên đi thành một danh sách riêng.
  const batchEvents = await all(
    db,
    'SELECT * FROM process_events WHERE product_batch_id = ? ORDER BY position, id',
    productId,
  );

  const [productMedia, ingredientMedia, eventMedia] = await Promise.all([
    mediaFor(db, 'product_batch', [productId]),
    mediaFor(db, 'ingredient_batch', ingredientIds),
    mediaFor(db, 'process_event', [
      ...events.map((event) => Number(event.id)),
      ...batchEvents.map((event) => Number(event.id)),
    ]),
  ]);

  return {
    product,
    ingredients,
    events,
    batchEvents,
    productMedia,
    ingredientMedia,
    eventMedia,
  };
}

/**
 * Payload đem đi băm. Chỉ chứa nội dung hồ sơ công bố, không có id nội bộ hay
 * created_at, để hash không đổi khi database được migrate.
 */
export async function snapshotPayload(db: D1Database, productId: number) {
  const tree = await loadTree(db, productId);
  const product = tree.product as Row;
  return {
    code: product.code,
    name: product.name,
    productionDate: product.production_date,
    expiryDate: product.expiry_date,
    description: product.description,
    facilityName: product.facility_name,
    // Toạ độ nằm trong snapshot vì đó cũng là một tuyên bố về nguồn gốc:
    // dời điểm trên bản đồ sau khi công bố phải bị bắt như sửa chữ.
    latitude: product.latitude,
    longitude: product.longitude,
    media: snapshotMedia(tree.productMedia.get(productId)),
    ingredients: tree.ingredients.map((item) => ({
      name: item.name,
      origin: item.origin,
      supplier: item.supplier,
      harvestDate: item.harvest_date,
      receivedDate: item.received_date,
      summary: item.summary,
      latitude: item.latitude,
      longitude: item.longitude,
      areaGeoJson: item.area_geojson,
      media: snapshotMedia(tree.ingredientMedia.get(Number(item.id))),
      processEvents: tree.events
        .filter((event) => event.ingredient_batch_id === item.id)
        .map((event) => ({
          ...eventFields(event),
          media: snapshotMedia(tree.eventMedia.get(Number(event.id))),
        })),
    })),
    // Công đoạn ở xưởng cũng phải nằm trong phần đem đi băm: sửa "đóng gói"
    // sau khi công bố thì phải bị bắt như sửa bất cứ dòng nào khác.
    //
    // Chỉ thêm khoá khi thật sự có dữ liệu. Thêm một khoá rỗng vào payload là
    // đổi mã băm của mọi lô đã công bố trước đó, kể cả lô không ai đụng vào —
    // trang công khai lập tức báo sai lệch cho hàng loạt lô vì một thay đổi
    // trong code. Quy tắc chung cho payload: trường rỗng thì không ghi.
    ...(tree.batchEvents.length === 0
      ? {}
      : {
          batchEvents: tree.batchEvents.map((event) => ({
            ...eventFields(event),
            media: snapshotMedia(tree.eventMedia.get(Number(event.id))),
          })),
        }),
  };
}

/// Media trong snapshot chỉ giữ khoá R2; dựng lại đường dẫn để trang khách
/// hiện được ảnh của đúng bản đã công bố.
function snapshotMediaToPublic(list: unknown): unknown[] {
  if (!Array.isArray(list)) return [];
  return list.map((item) => {
    const media = item as Record<string, unknown>;
    return { ...media, url: `/api/media/${media.key}` };
  });
}

/**
 * Hồ sơ công khai của một lô.
 *
 * Đã công bố thì trả **đúng nội dung của bản công bố gần nhất**, không phải dữ
 * liệu đang nằm trong database. Người vận hành sửa dở một lô đã bán ngoài thị
 * trường thì khách quét mã vẫn thấy bản đã chốt, thay vì thấy nửa vời kèm
 * cảnh báo đỏ vì một việc nội bộ bình thường. Nội dung mới chỉ ra mắt khi bấm
 * lưu bản mới — đúng nghĩa "công bố".
 *
 * Lô chưa công bố lần nào thì trả dữ liệu hiện tại, kèm trạng thái ĐANG TẠO.
 */
export async function publicTrace(db: D1Database, code: string, env?: Env) {
  const product = await findProduct(db, code);
  const productId = Number(product.id);

  const snapshot = await first(
    db,
    'SELECT * FROM published_snapshots WHERE product_batch_id = ? ORDER BY version DESC LIMIT 1',
    productId,
  );

  if (snapshot) {
    const payload = JSON.parse(String(snapshot.payload)) as Record<string, unknown>;
    const ingredients = (payload.ingredients as Record<string, unknown>[]) ?? [];
    return {
      ...payload,
      status: product.status,
      media: snapshotMediaToPublic(payload.media),
      ingredients: ingredients.map((item) => ({
        ...item,
        media: snapshotMediaToPublic(item.media),
        processEvents: ((item.processEvents as Record<string, unknown>[]) ?? []).map(
          (event) => ({ ...event, media: snapshotMediaToPublic(event.media) }),
        ),
      })),
      batchEvents: ((payload.batchEvents as Record<string, unknown>[]) ?? []).map(
        (event) => ({ ...event, media: snapshotMediaToPublic(event.media) }),
      ),
      integrity: await publicVerify(db, code, env),
    };
  }

  return adminTrace(db, code, env);
}

/// Hồ sơ theo dữ liệu đang có trong database, dành cho màn quản trị và cho lô
/// chưa công bố lần nào.
export async function adminTrace(db: D1Database, code: string, env?: Env) {
  const product = await findProduct(db, code);
  const productId = Number(product.id);
  const tree = await loadTree(db, productId);

  return {
    ...product,
    media: (tree.productMedia.get(productId) ?? []).map(publicMedia),
    ingredients: tree.ingredients.map((item) => ({
      ...item,
      media: (tree.ingredientMedia.get(Number(item.id)) ?? []).map(publicMedia),
      processEvents: tree.events
        .filter((event) => event.ingredient_batch_id === item.id)
        .map((event) => ({
          // Cột thô đi trước để giữ id và position; eventFields ghi đè bằng
          // dạng đã chuẩn hoá, trong đó params là object chứ không phải chuỗi.
          ...event,
          ...eventFields(event),
          media: (tree.eventMedia.get(Number(event.id)) ?? []).map(publicMedia),
        })),
    })),
    batchEvents: tree.batchEvents.map((event) => ({
      ...event,
      ...eventFields(event),
      media: (tree.eventMedia.get(Number(event.id)) ?? []).map(publicMedia),
    })),
    integrity: await verify(db, code, env),
  };
}

/**
 * Vài lô đã công bố gần nhất, chỉ mã và tên.
 *
 * Trang chủ cần thứ gì đó để người chưa cầm bao bì trên tay vẫn xem thử được.
 * Chỉ trả mã và tên: mã lô vốn đã in trên bao bì nên không phải bí mật, còn
 * nội dung hồ sơ vẫn phải hỏi từng mã một như cũ.
 */
export async function publicBatches(db: D1Database, limit = 6) {
  const rows = await all(
    db,
    `SELECT p.code, p.name, p.production_date, MAX(s.published_at) AS at
       FROM product_batches p
       JOIN published_snapshots s ON s.product_batch_id = p.id
      WHERE p.status = 'PUBLISHED'
      GROUP BY p.id
      -- Xếp theo lô mới nhất chứ không theo lần công bố gần nhất: sửa chính
      -- tả cho một lô cũ không nên đẩy nó lên đầu danh sách.
      ORDER BY p.id DESC
      LIMIT ?`,
    Math.min(Math.max(limit, 1), 20),
  );
  return rows.map((row) => ({
    code: row.code,
    name: row.name,
    productionDate: row.production_date,
  }));
}

export async function featured(db: D1Database) {
  const row = await first(
    db,
    `SELECT p.code FROM product_batches p
       JOIN published_snapshots s ON s.product_batch_id = p.id
      WHERE p.status = 'PUBLISHED'
      ORDER BY s.published_at DESC, s.id DESC
      LIMIT 1`,
  );
  if (!row) {
    throw new ApiError(
      404,
      'NO_PUBLISHED_BATCH',
      'Chưa có lô nào được công bố.',
    );
  }
  return publicTrace(db, String(row.code));
}

/**
 * Kiểm chứng cho khách: bản đang hiển thị có đúng là bản đã công bố không.
 *
 * Băm lại chính payload đang được phục vụ rồi so với mã băm đã lưu và đã neo
 * lên chuỗi. Đây mới là câu hỏi của người quét mã. Việc người vận hành đang
 * sửa dở một bản mới là chuyện nội bộ, không phải cảnh báo dành cho họ.
 */
export async function publicVerify(db: D1Database, code: string, env?: Env) {
  const product = await findProduct(db, code);
  const snapshot = await first(
    db,
    'SELECT * FROM published_snapshots WHERE product_batch_id = ? ORDER BY version DESC LIMIT 1',
    product.id,
  );
  if (!snapshot) return { status: 'NOT_PUBLISHED', version: 0 };

  const servedHash = await sha256Of(JSON.parse(String(snapshot.payload)));
  const outbox = await first(
    db,
    'SELECT status, tx_hash, block_number, chain_id, contract FROM blockchain_outbox WHERE snapshot_id = ? ORDER BY id DESC LIMIT 1',
    snapshot.id,
  );

  return {
    status: servedHash === snapshot.sha256 ? 'VERIFIED' : 'MISMATCH',
    version: snapshot.version,
    snapshotHash: snapshot.sha256,
    currentHash: servedHash,
    publishedBy: snapshot.published_by,
    publishedAt: snapshot.published_at,
    chain: {
      status: outbox?.status ?? 'PENDING_NETWORK',
      txHash: outbox?.tx_hash ?? '',
      blockNumber: outbox?.block_number ?? '',
      chainId: outbox?.chain_id ?? null,
      contract: outbox?.contract ?? '',
      explorer: (env?.CHAIN_EXPLORER ?? '').replace(/\/$/, ''),
    },
  };
}

/**
 * Kiểm chứng cho người vận hành: dữ liệu đang nằm trong database có khác bản
 * đã lưu gần nhất không. Khác thì cần bấm lưu bản mới; tới lúc đó khách vẫn
 * đang xem bản cũ.
 */
export async function verify(db: D1Database, code: string, env?: Env) {
  const product = await findProduct(db, code);
  const productId = Number(product.id);
  const snapshot = await first(
    db,
    'SELECT * FROM published_snapshots WHERE product_batch_id = ? ORDER BY version DESC LIMIT 1',
    productId,
  );
  const currentHash = await sha256Of(await snapshotPayload(db, productId));

  if (!snapshot) return { status: 'NOT_PUBLISHED', currentHash, version: 0 };

  const outbox = await first(
    db,
    'SELECT status, tx_hash, block_number, chain_id, contract FROM blockchain_outbox WHERE snapshot_id = ? ORDER BY id DESC LIMIT 1',
    snapshot.id,
  );

  return {
    status: snapshot.sha256 === currentHash ? 'VERIFIED' : 'MISMATCH',
    version: snapshot.version,
    snapshotHash: snapshot.sha256,
    currentHash,
    publishedBy: snapshot.published_by,
    publishedAt: snapshot.published_at,
    chain: {
      status: outbox?.status ?? 'PENDING_NETWORK',
      txHash: outbox?.tx_hash ?? '',
      blockNumber: outbox?.block_number ?? '',
      chainId: outbox?.chain_id ?? null,
      contract: outbox?.contract ?? '',
      // Địa chỉ explorer để client dựng liên kết mà không phải cấu hình lại.
      explorer: (env?.CHAIN_EXPLORER ?? '').replace(/\/$/, ''),
    },
  };
}

/**
 * Lấy các bản đã chốt nhưng chưa lên chuỗi rồi gửi từng cái một.
 *
 * Gửi tuần tự chứ không song song: các giao dịch cùng đi từ một ví, nonce phải
 * tăng theo thứ tự, bắn song song là chắc chắn đụng nhau.
 */
export async function drainOutbox(env: Env, limit = 5, manual = false) {
  const config = chainConfig(env);
  if (!config) return { sent: 0, failed: 0, skipped: 'CHAIN_NOT_CONFIGURED' };

  // Neo tự động phải tắt được. Máy dev và smoke test dùng chung ví với sản
  // xuất, mà mỗi lần chạy test lại bắn vài giao dịch thật lên chuỗi thì sổ cái
  // đầy dữ liệu rác. Nút "Gửi lên chuỗi" thì luôn chạy, vì đó là chủ ý.
  if (!manual && (env.CHAIN_AUTO_ANCHOR ?? 'true') !== 'true') {
    return { sent: 0, failed: 0, skipped: 'AUTO_ANCHOR_OFF' };
  }

  const rows = await all(
    env.DB,
    `SELECT o.id, o.snapshot_id, o.batch_hash, o.attempts,
            s.version, p.code
       FROM blockchain_outbox o
       JOIN published_snapshots s ON s.id = o.snapshot_id
       JOIN product_batches p ON p.id = s.product_batch_id
      WHERE o.status IN ('PENDING_NETWORK', 'FAILED') AND o.attempts < 5
      ORDER BY o.id ASC
      LIMIT ?`,
    limit,
  );

  let sent = 0;
  let failed = 0;
  for (const row of rows) {
    try {
      const result = await anchorBatch(config, {
        hash: String(row.batch_hash),
        code: String(row.code),
        version: Number(row.version),
      });
      await env.DB.prepare(
        `UPDATE blockchain_outbox
            SET status = 'CONFIRMED', tx_hash = ?, block_number = ?, chain_id = ?,
                contract = ?, sent_at = ?, attempts = attempts + 1, last_error = NULL
          WHERE id = ?`,
      )
        .bind(
          result.txHash,
          result.blockNumber,
          config.chainId,
          config.contract,
          nowIso(),
          row.id,
        )
        .run();
      sent += 1;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      await env.DB.prepare(
        `UPDATE blockchain_outbox
            SET status = 'FAILED', attempts = attempts + 1, last_error = ?
          WHERE id = ?`,
      )
        .bind(message.slice(0, 500), row.id)
        .run();
      failed += 1;
    }
  }
  return { sent, failed, considered: rows.length };
}

/**
 * Nội dung đầy đủ của một bản đã chốt.
 *
 * Snapshot lưu nguyên payload chứ không chỉ mã băm, nên sửa dữ liệu hôm nay
 * không xoá được bản hôm qua. Không có đường đọc lại thì cái "không ghi đè" ấy
 * chỉ đúng trên lý thuyết.
 */
export async function snapshotContent(
  db: D1Database,
  code: string,
  version: number,
) {
  const product = await findProduct(db, code);
  const row = await first(
    db,
    'SELECT * FROM published_snapshots WHERE product_batch_id = ? AND version = ?',
    product.id,
    version,
  );
  if (!row) {
    throw new ApiError(404, 'SNAPSHOT_NOT_FOUND', 'Không có bản này.');
  }
  const outbox = await first(
    db,
    'SELECT status, tx_hash, block_number, chain_id, contract FROM blockchain_outbox WHERE snapshot_id = ? ORDER BY id DESC LIMIT 1',
    row.id,
  );
  return {
    version: row.version,
    sha256: row.sha256,
    publishedBy: row.published_by,
    publishedAt: row.published_at,
    chain: {
      status: outbox?.status ?? 'PENDING_NETWORK',
      txHash: outbox?.tx_hash ?? '',
      blockNumber: outbox?.block_number ?? '',
      chainId: outbox?.chain_id ?? null,
      contract: outbox?.contract ?? '',
    },
    payload: JSON.parse(String(row.payload)),
  };
}

/** Đặt lại các bản đã bỏ cuộc để người vận hành thử lại sau khi sửa cấu hình. */
export async function retryOutbox(db: D1Database) {
  const result = await db
    .prepare(
      "UPDATE blockchain_outbox SET status = 'PENDING_NETWORK', attempts = 0, last_error = NULL WHERE status = 'FAILED'",
    )
    .run();
  return { reset: result.meta?.changes ?? 0 };
}

/** Hàng chờ hiện có gì, cho màn quản trị. */
export async function outboxSummary(db: D1Database) {
  const rows = await all(
    db,
    'SELECT status, COUNT(*) as count FROM blockchain_outbox GROUP BY status',
  );
  const byStatus: Record<string, number> = {};
  for (const row of rows) byStatus[String(row.status)] = Number(row.count);
  const lastFailed = await first(
    db,
    "SELECT last_error FROM blockchain_outbox WHERE status = 'FAILED' ORDER BY id DESC LIMIT 1",
  );
  return { byStatus, lastError: lastFailed?.last_error ?? '' };
}

export async function summary(db: D1Database) {
  const [products, published, ingredients, events, media, pending] =
    await Promise.all([
      count(db, 'SELECT COUNT(*) as count FROM product_batches'),
      count(
        db,
        "SELECT COUNT(*) as count FROM product_batches WHERE status = 'PUBLISHED'",
      ),
      count(db, 'SELECT COUNT(*) as count FROM ingredient_batches'),
      count(db, 'SELECT COUNT(*) as count FROM process_events'),
      count(db, 'SELECT COUNT(*) as count FROM media_assets'),
      count(
        db,
        "SELECT COUNT(*) as count FROM blockchain_outbox WHERE status = 'PENDING_NETWORK'",
      ),
    ]);
  return {
    products,
    published,
    ingredients,
    events,
    media,
    pendingBlockchain: pending,
  };
}

/// Cách sắp xếp danh sách lô. Nhận từ query string nên phải là danh sách
/// đóng: ghép thẳng chuỗi của client vào ORDER BY là mở cửa cho SQL injection.
const BATCH_ORDER: Record<string, string> = {
  newest: 'p.created_at DESC, p.id DESC',
  oldest: 'p.created_at ASC, p.id ASC',
  name: 'p.name COLLATE NOCASE ASC',
  code: 'p.code ASC',
};

export async function listBatches(
  db: D1Database,
  options: { q?: string; sort?: string; page?: number; limit?: number } = {},
) {
  const order = BATCH_ORDER[options.sort ?? 'newest'] ?? BATCH_ORDER.newest;
  const limit = Math.min(Math.max(options.limit ?? 10, 1), 100);
  const page = Math.max(options.page ?? 1, 1);

  const term = (options.q ?? '').trim().toLowerCase();
  const where = term ? 'WHERE lower(p.code) LIKE ?1 OR lower(p.name) LIKE ?1' : '';
  const args = term ? [`%${term}%`] : [];

  const counted = await first(
    db,
    `SELECT COUNT(*) as total FROM product_batches p ${where}`,
    ...args,
  );
  const total = Number(counted?.total ?? 0);

  // Trang vượt quá số lô hiện có thì kéo về trang cuối, để lọc xong không rơi
  // vào một trang trống rồi tưởng mất dữ liệu.
  const pages = Math.max(Math.ceil(total / limit), 1);
  const current = Math.min(page, pages);

  const items = await all(
    db,
    `SELECT p.*,
        (SELECT COUNT(*) FROM ingredient_batches i WHERE i.product_batch_id = p.id) AS ingredientCount,
        (SELECT COUNT(*) FROM process_events e
           JOIN ingredient_batches i ON i.id = e.ingredient_batch_id
          WHERE i.product_batch_id = p.id) AS eventCount,
        (SELECT MAX(version) FROM published_snapshots s WHERE s.product_batch_id = p.id) AS version
       FROM product_batches p
       ${where}
      ORDER BY ${order}
      LIMIT ? OFFSET ?`,
    ...args,
    limit,
    (current - 1) * limit,
  );

  return { items, total, page: current, pages, limit };
}

/// Lịch sử niêm phong của một lô, kèm tình trạng ghi lên chuỗi của từng bản.
///
/// Màn quản trị cần nói rõ mã băm đang nằm ở đâu: mới chỉ trong D1, hay đã có
/// giao dịch trên chuỗi. Nói chung chung là "đã công bố" thì người vận hành
/// tưởng dữ liệu đã lên blockchain trong khi mạng còn chưa được cấu hình.
export async function snapshots(db: D1Database, code: string) {
  const product = await findProduct(db, code);
  return all(
    db,
    `SELECT s.id, s.version, s.sha256, s.published_by as publishedBy,
            s.published_at as publishedAt,
            o.status as chainStatus, o.tx_hash as txHash
       FROM published_snapshots s
       LEFT JOIN blockchain_outbox o ON o.snapshot_id = s.id
      WHERE s.product_batch_id = ? ORDER BY s.version DESC`,
    product.id,
  );
}

export async function createProduct(
  db: D1Database,
  body: {
    name: string;
    code: string;
    productionDate: string;
    expiryDate: string;
    description?: string;
    facilityName?: string;
    latitude?: number | null;
    longitude?: number | null;
  },
) {
  const code = body.code.trim().toUpperCase();
  const duplicate = await first(
    db,
    'SELECT id FROM product_batches WHERE code = ?',
    code,
  );
  if (duplicate) {
    throw new ApiError(
      409,
      'CODE_TAKEN',
      `Mã lô ${code} đã tồn tại. Chọn mã khác.`,
    );
  }
  const result = await db
    .prepare(
      'INSERT INTO product_batches (name, code, production_date, expiry_date, description, status, facility_name, latitude, longitude, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id',
    )
    .bind(
      body.name.trim(),
      code,
      body.productionDate,
      body.expiryDate,
      body.description ?? '',
      'DRAFT',
      body.facilityName ?? '',
      body.latitude ?? null,
      body.longitude ?? null,
      nowIso(),
    )
    .first<Row>();
  return { id: result?.id, ...body, code, status: 'DRAFT' };
}

export async function updateProduct(
  db: D1Database,
  code: string,
  body: {
    name?: string;
    productionDate?: string;
    expiryDate?: string;
    description?: string;
    facilityName?: string;
    latitude?: number | null;
    longitude?: number | null;
  },
) {
  const product = await findProduct(db, code);
  await db
    .prepare(
      'UPDATE product_batches SET name = ?, production_date = ?, expiry_date = ?, description = ?, facility_name = ?, latitude = ?, longitude = ? WHERE id = ?',
    )
    .bind(
      body.name ?? product.name,
      body.productionDate ?? product.production_date,
      body.expiryDate ?? product.expiry_date,
      body.description ?? product.description,
      body.facilityName ?? product.facility_name,
      body.latitude === undefined ? product.latitude : body.latitude,
      body.longitude === undefined ? product.longitude : body.longitude,
      product.id,
    )
    .run();
  return first(db, 'SELECT * FROM product_batches WHERE id = ?', product.id);
}

export async function createIngredient(
  db: D1Database,
  body: {
    productBatchId: number;
    name: string;
    origin: string;
    supplier?: string;
    harvestDate?: string;
    receivedDate?: string;
    summary?: string;
    latitude?: number | null;
    longitude?: number | null;
    areaGeoJson?: string | null;
  },
) {
  const parent = await first(
    db,
    'SELECT id FROM product_batches WHERE id = ?',
    body.productBatchId,
  );
  if (!parent) {
    throw new ApiError(404, 'BATCH_NOT_FOUND', 'Lô thành phẩm không tồn tại.');
  }
  const result = await db
    .prepare(
      'INSERT INTO ingredient_batches (product_batch_id, name, origin, supplier, harvest_date, received_date, summary, latitude, longitude, area_geojson) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id',
    )
    .bind(
      body.productBatchId,
      body.name.trim(),
      body.origin.trim(),
      body.supplier ?? '',
      body.harvestDate ?? '',
      body.receivedDate ?? '',
      body.summary ?? '',
      body.latitude ?? null,
      body.longitude ?? null,
      body.areaGeoJson ?? null,
    )
    .first<Row>();
  return { id: result?.id, ...body };
}

export async function updateIngredient(
  db: D1Database,
  id: number,
  body: Record<string, string | number | null | undefined>,
) {
  const existing = await first(
    db,
    'SELECT * FROM ingredient_batches WHERE id = ?',
    id,
  );
  if (!existing) {
    throw new ApiError(
      404,
      'INGREDIENT_NOT_FOUND',
      'Không tìm thấy lô nguyên liệu.',
    );
  }
  await db
    .prepare(
      'UPDATE ingredient_batches SET name = ?, origin = ?, supplier = ?, harvest_date = ?, received_date = ?, summary = ?, latitude = ?, longitude = ?, area_geojson = ? WHERE id = ?',
    )
    .bind(
      body.name ?? existing.name,
      body.origin ?? existing.origin,
      body.supplier ?? existing.supplier,
      body.harvestDate ?? existing.harvest_date,
      body.receivedDate ?? existing.received_date,
      body.summary ?? existing.summary,
      body.latitude === undefined ? existing.latitude : body.latitude,
      body.longitude === undefined ? existing.longitude : body.longitude,
      body.areaGeoJson === undefined
        ? existing.area_geojson
        : body.areaGeoJson,
      id,
    )
    .run();
  return first(db, 'SELECT * FROM ingredient_batches WHERE id = ?', id);
}

/// Xoá một lô nguyên liệu cùng mọi công đoạn và media của nó.
export async function deleteIngredient(db: D1Database, id: number) {
  const existing = await first(
    db,
    'SELECT id FROM ingredient_batches WHERE id = ?',
    id,
  );
  if (!existing) {
    throw new ApiError(
      404,
      'INGREDIENT_NOT_FOUND',
      'Không tìm thấy lô nguyên liệu.',
    );
  }

  const events = await all(
    db,
    'SELECT id FROM process_events WHERE ingredient_batch_id = ?',
    id,
  );
  const eventIds = events.map((event) => Number(event.id));

  // Media của công đoạn phải đi cùng, nếu không sẽ thành bản ghi mồ côi trỏ
  // vào những công đoạn đã biến mất.
  const statements = [
    ...(eventIds.length > 0
      ? [
          db
            .prepare(
              `DELETE FROM media_assets WHERE owner_type = 'process_event' AND owner_id IN (${eventIds
                .map(() => '?')
                .join(',')})`,
            )
            .bind(...eventIds),
        ]
      : []),
    db
      .prepare(
        "DELETE FROM media_assets WHERE owner_type = 'ingredient_batch' AND owner_id = ?",
      )
      .bind(id),
    db.prepare('DELETE FROM process_events WHERE ingredient_batch_id = ?').bind(id),
    db.prepare('DELETE FROM ingredient_batches WHERE id = ?').bind(id),
  ];
  await db.batch(statements);
  return { deleted: id };
}

/**
 * Ghi một công đoạn.
 *
 * Gắn vào một nguyên liệu (thu hoạch, sấy phun...) hoặc vào cả lô (phối trộn,
 * đóng gói ở xưởng). Đúng một trong hai, vì một công đoạn không thể vừa thuộc
 * riêng cốm vừa thuộc cả mẻ.
 */
export async function createEvent(
  db: D1Database,
  body: {
    ingredientBatchId?: number;
    productBatchId?: number;
    title: string;
    description?: string;
    eventDate: string;
    enteredBy?: string;
    position?: number;
    operator?: string | null;
    inputQuantity?: number | null;
    outputQuantity?: number | null;
    quantityUnit?: string | null;
    params?: Record<string, string> | null;
  },
) {
  const hasIngredient = body.ingredientBatchId != null;
  const hasProduct = body.productBatchId != null;
  if (hasIngredient === hasProduct) {
    throw new ApiError(
      400,
      'EVENT_OWNER_REQUIRED',
      'Công đoạn phải thuộc một nguyên liệu hoặc thuộc cả lô, không thể cả hai.',
    );
  }

  if (hasIngredient) {
    const parent = await first(
      db,
      'SELECT id FROM ingredient_batches WHERE id = ?',
      body.ingredientBatchId,
    );
    if (!parent) {
      throw new ApiError(
        404,
        'INGREDIENT_NOT_FOUND',
        'Lô nguyên liệu không tồn tại.',
      );
    }
  } else {
    const parent = await first(
      db,
      'SELECT id FROM product_batches WHERE id = ?',
      body.productBatchId,
    );
    if (!parent) {
      throw new ApiError(404, 'PRODUCT_NOT_FOUND', 'Lô sản phẩm không tồn tại.');
    }
  }

  // Vị trí mặc định là nối tiếp công đoạn cuối của cùng chủ thể, để thứ tự
  // hiển thị đúng thứ tự người vận hành nhập vào.
  const last = hasIngredient
    ? await first(
        db,
        'SELECT MAX(position) as top FROM process_events WHERE ingredient_batch_id = ?',
        body.ingredientBatchId,
      )
    : await first(
        db,
        'SELECT MAX(position) as top FROM process_events WHERE product_batch_id = ?',
        body.productBatchId,
      );
  const position = body.position ?? Number(last?.top ?? -1) + 1;

  const result = await db
    .prepare(
      `INSERT INTO process_events
         (ingredient_batch_id, product_batch_id, title, description, event_date,
          entered_by, created_at, position,
          operator, input_quantity, output_quantity, quantity_unit, params)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id`,
    )
    .bind(
      body.ingredientBatchId ?? null,
      body.productBatchId ?? null,
      body.title.trim(),
      body.description ?? '',
      body.eventDate,
      body.enteredBy ?? 'admin',
      nowIso(),
      position,
      body.operator || null,
      body.inputQuantity ?? null,
      body.outputQuantity ?? null,
      body.quantityUnit || null,
      body.params ? JSON.stringify(body.params) : null,
    )
    .first<Row>();
  return { id: result?.id, position, ...body };
}

/// Sửa một công đoạn đã ghi. Không có đường này thì muốn sửa một lỗi chính tả
/// phải xoá rồi tạo lại, mà xoá là mất luôn ảnh của công đoạn đó.
export async function updateEvent(
  db: D1Database,
  id: number,
  body: {
    title?: string;
    description?: string;
    eventDate?: string;
    position?: number;
    operator?: string | null;
    inputQuantity?: number | null;
    outputQuantity?: number | null;
    quantityUnit?: string | null;
    params?: Record<string, string> | null;
  },
) {
  const existing = await first(db, 'SELECT * FROM process_events WHERE id = ?', id);
  if (!existing) {
    throw new ApiError(404, 'EVENT_NOT_FOUND', 'Không tìm thấy công đoạn.');
  }
  // Trường tuỳ chọn không khai thì giữ nguyên. Tên rỗng cũng coi như không
  // khai: PATCH mỗi thứ tự mà xoá mất tên công đoạn thì hồ sơ hỏng lặng lẽ.
  //
  // Riêng nhóm chi tiết công đoạn phân biệt "không khai" (undefined, giữ
  // nguyên) với "xoá" (null), để sửa nhầm khối lượng còn gỡ ra được.
  const keep = <T>(next: T | null | undefined, current: unknown) =>
    next === undefined ? (current ?? null) : (next === null ? null : next);

  await db
    .prepare(
      `UPDATE process_events
         SET title = ?, description = ?, event_date = ?, position = ?,
             operator = ?, input_quantity = ?, output_quantity = ?,
             quantity_unit = ?, params = ?
       WHERE id = ?`,
    )
    .bind(
      body.title?.trim() ? body.title.trim() : existing.title,
      body.description ?? existing.description,
      body.eventDate?.trim() ? body.eventDate.trim() : existing.event_date,
      body.position ?? existing.position,
      keep(body.operator, existing.operator),
      keep(body.inputQuantity, existing.input_quantity),
      keep(body.outputQuantity, existing.output_quantity),
      keep(body.quantityUnit, existing.quantity_unit),
      keep(
        body.params === undefined
          ? undefined
          : body.params === null
            ? null
            : JSON.stringify(body.params),
        existing.params,
      ),
      id,
    )
    .run();
  return first(db, 'SELECT * FROM process_events WHERE id = ?', id);
}

export async function deleteEvent(db: D1Database, id: number) {
  const existing = await first(db, 'SELECT id FROM process_events WHERE id = ?', id);
  if (!existing) {
    throw new ApiError(404, 'EVENT_NOT_FOUND', 'Không tìm thấy công đoạn.');
  }
  // Media của công đoạn phải đi cùng, nếu không sẽ thành file mồ côi trong R2.
  await db.batch([
    db
      .prepare("DELETE FROM media_assets WHERE owner_type = 'process_event' AND owner_id = ?")
      .bind(id),
    db.prepare('DELETE FROM process_events WHERE id = ?').bind(id),
  ]);
  return { deleted: id };
}

export async function publish(db: D1Database, code: string, admin = 'admin') {
  const product = await findProduct(db, code);
  const productId = Number(product.id);
  const payload = await snapshotPayload(db, productId);
  const hash = await sha256Of(payload);
  const previous = await first(
    db,
    'SELECT MAX(version) as version FROM published_snapshots WHERE product_batch_id = ?',
    productId,
  );
  const version = Number(previous?.version ?? 0) + 1;
  const at = nowIso();

  const snapshot = await db
    .prepare(
      'INSERT INTO published_snapshots (product_batch_id, version, payload, sha256, published_by, published_at) VALUES (?, ?, ?, ?, ?, ?) RETURNING id',
    )
    .bind(productId, version, JSON.stringify(payload), hash, admin, at)
    .first<Row>();

  // D1 chạy batch trong một transaction, nên trạng thái lô và bản ghi outbox
  // không thể lệch nhau.
  await db.batch([
    db
      .prepare('UPDATE product_batches SET status = ? WHERE id = ?')
      .bind('PUBLISHED', productId),
    db
      .prepare(
        'INSERT INTO blockchain_outbox (snapshot_id, batch_hash, created_at) VALUES (?, ?, ?)',
      )
      .bind(snapshot?.id, hash, at),
  ]);

  return { code, version, sha256: hash, status: 'PENDING_NETWORK' };
}
