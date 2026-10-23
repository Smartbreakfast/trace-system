/**
 * Tài khoản, phiên đăng nhập và phân quyền theo vai trò.
 *
 * Trước đây cả `/api/admin/*` đóng bằng một bearer token dùng chung. Đủ an toàn
 * để chặn người ngoài, nhưng không trả lời được câu quan trọng nhất của một hệ
 * thống truy xuất: *ai* đã khai báo công đoạn này. Mọi thao tác đều ký tên
 * "admin", nên nhật ký không có giá trị làm bằng chứng.
 *
 * Ở đây mỗi người một tài khoản, mỗi tài khoản thuộc một cơ sở và một vai trò:
 *
 *   ADMIN     thấy mọi cơ sở, quản lý tài khoản, xem nhật ký.
 *   FACILITY  toàn quyền trên dữ liệu cơ sở mình, kể cả công bố lô.
 *   STAFF     chỉ khai công đoạn và đính ảnh cho lô của cơ sở mình.
 *
 * ADMIN_TOKEN vẫn dùng được, làm cửa dự phòng khi mất mật khẩu hoặc khi script
 * vận hành cần chạy không người trực. Nó mang vai trò ADMIN và ký tên
 * `token-quan-tri` trong nhật ký để phân biệt với người thật.
 */
import { sha256Hex } from './canonical';
import { ApiError, badRequest } from './errors';

export const roles = ['ADMIN', 'FACILITY', 'STAFF'] as const;
export type Role = (typeof roles)[number];

export interface Auth {
  userId: number | null;
  username: string;
  fullName: string;
  role: Role;
  /** null = thấy mọi cơ sở (chỉ ADMIN). */
  facilityId: number | null;
  facilityName: string;
  /** true khi vào bằng ADMIN_TOKEN thay vì tài khoản. */
  viaToken: boolean;
}

type Row = Record<string, unknown>;

const nowIso = () => new Date().toISOString();

/** Phiên sống 12 giờ: đủ một ngày làm việc, hết ngày là phải đăng nhập lại. */
const SESSION_HOURS = 12;
const PBKDF2_ROUNDS = 150_000;

/** Sai mật khẩu 5 lần liên tiếp thì khoá tạm 15 phút, rồi tự mở lại. */
const MAX_FAILED = 5;
const LOCK_MINUTES = 15;

/**
 * Băm giả dùng khi không có tài khoản nào mang tên đó.
 *
 * Không có nó thì đường "không tìm thấy" trả lời nhanh hơn hẳn đường "sai mật
 * khẩu", và người dò biết ngay tên đăng nhập nào có thật. Giá trị này là một
 * chuỗi pbkdf2 hợp lệ với mật khẩu không ai đoán ra, nên verifyPassword chạy
 * đúng một lần băm giống hệt đường thật.
 */
const DUMMY_HASH =
  'pbkdf2$150000$Y2hhbmctYmFvLWdpby1kdW5n$' +
  'n0Zq0h4Cm0Zq0h4Cm0Zq0h4Cm0Zq0h4Cm0Zq0h4Cm0E=';

const encoder = new TextEncoder();

function base64(bytes: Uint8Array) {
  let text = '';
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text);
}

function fromBase64(text: string) {
  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function pbkdf2(password: string, salt: Uint8Array, rounds: number) {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(password.normalize('NFC')),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      hash: 'SHA-256',
      salt: salt as BufferSource,
      iterations: rounds,
    },
    key,
    256,
  );
  return new Uint8Array(bits);
}

export async function hashPassword(password: string) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const derived = await pbkdf2(password, salt, PBKDF2_ROUNDS);
  return `pbkdf2$${PBKDF2_ROUNDS}$${base64(salt)}$${base64(derived)}`;
}

/** So sánh theo thời gian hằng số: độ trễ không được tiết lộ sai ở byte nào. */
function sameBytes(a: Uint8Array, b: Uint8Array) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) diff |= a[i] ^ b[i];
  return diff === 0;
}

export async function verifyPassword(password: string, stored: string) {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
  const rounds = Number(parts[1]);
  if (!Number.isInteger(rounds) || rounds < 1000) return false;
  try {
    const derived = await pbkdf2(password, fromBase64(parts[2]), rounds);
    return sameBytes(derived, fromBase64(parts[3]));
  } catch {
    return false;
  }
}

export function tokenMatches(given: string, expected: string) {
  return sameBytes(encoder.encode(given), encoder.encode(expected));
}

/**
 * Mật khẩu yếu là cửa mở, nhưng quy tắc quá rắc rối thì người ta dán giấy lên
 * màn hình. Đủ dài, có chữ và số, hết.
 */
export function checkPasswordStrength(password: string) {
  if (password.length < 10) {
    throw badRequest('Mật khẩu phải dài từ 10 ký tự.');
  }
  if (!/[a-zA-Z]/.test(password) || !/[0-9]/.test(password)) {
    throw badRequest('Mật khẩu phải có cả chữ và số.');
  }
}

export function normalizeUsername(raw: string) {
  const username = raw.trim().toLowerCase();
  if (!/^[a-z0-9][a-z0-9._-]{2,39}$/.test(username)) {
    throw badRequest(
      'Tên đăng nhập 3-40 ký tự, chỉ gồm chữ không dấu, số và . _ -',
    );
  }
  return username;
}

// -------------------------------------------------------------------- phiên

function sessionKey(token: string) {
  return sha256Hex(encoder.encode(token));
}

/** Đang trong thời gian khoá tạm: nói rõ còn bao nhiêu phút. */
function lockedError(lockedUntil: string, now: string) {
  const minutes = Math.max(
    1,
    Math.ceil((Date.parse(lockedUntil) - Date.parse(now)) / 60000),
  );
  return new ApiError(
    429,
    'TOO_MANY_ATTEMPTS',
    `Nhập sai quá nhiều lần. Thử lại sau ${minutes} phút.`,
  );
}

const WRONG = new ApiError(
  401,
  'UNAUTHORIZED',
  'Tên đăng nhập hoặc mật khẩu không đúng.',
);

/**
 * Kiểm tên đăng nhập và mật khẩu, KHÔNG mở phiên.
 *
 * Tách khỏi `login` vì việc tự đổi mật khẩu cũng phải nhập mật khẩu cũ; gọi
 * thẳng `login` ở đó sẽ đẻ ra một phiên không ai dùng và ghi sai mốc "đăng
 * nhập lần cuối".
 */
export async function verifyCredentials(
  db: D1Database,
  username: string,
  password: string,
) {
  const row = await db
    .prepare(
      `SELECT u.*, f.name as facility_name, f.code as facility_code
         FROM users u LEFT JOIN facilities f ON f.id = u.facility_id
        WHERE u.username = ?`,
    )
    .bind(username.trim().toLowerCase())
    .first<Row>();

  const now = nowIso();
  const lockedUntil = String(row?.locked_until ?? '');
  if (row && lockedUntil && lockedUntil > now) throw lockedError(lockedUntil, now);

  const ok = await verifyPassword(
    password,
    String(row?.password_hash ?? '') || DUMMY_HASH,
  );

  if (!row || !ok || Number(row.active) !== 1) {
    if (row) {
      // Đếm số lần sai liên tiếp; đủ ngưỡng thì khoá tạm.
      const failed = Number(row.failed_attempts ?? 0) + 1;
      const lock =
        failed >= MAX_FAILED
          ? new Date(Date.now() + LOCK_MINUTES * 60000).toISOString()
          : null;
      await db
        .prepare('UPDATE users SET failed_attempts = ?, locked_until = ? WHERE id = ?')
        .bind(lock ? 0 : failed, lock, row.id)
        .run();
      // Nói thẳng ngay ở lần khoá, đừng để người gõ nhầm thử tiếp rồi mới biết.
      if (lock) throw lockedError(lock, now);
    }
    throw WRONG;
  }

  if (Number(row.failed_attempts ?? 0) !== 0 || lockedUntil) {
    await db
      .prepare('UPDATE users SET failed_attempts = 0, locked_until = NULL WHERE id = ?')
      .bind(row.id)
      .run();
  }
  return row;
}

export async function login(
  db: D1Database,
  username: string,
  password: string,
) {
  const row = await verifyCredentials(db, username, password);

  const token = base64(crypto.getRandomValues(new Uint8Array(32)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
  const created = new Date();
  const expires = new Date(created.getTime() + SESSION_HOURS * 3600 * 1000);

  await db
    .prepare(
      `INSERT INTO sessions (token_hash, user_id, created_at, expires_at, last_seen_at)
       VALUES (?, ?, ?, ?, ?)`,
    )
    .bind(
      await sessionKey(token),
      row.id,
      created.toISOString(),
      expires.toISOString(),
      created.toISOString(),
    )
    .run();

  await db
    .prepare('UPDATE users SET last_login_at = ? WHERE id = ?')
    .bind(created.toISOString(), row.id)
    .run();

  // Dọn phiên hết hạn ở đây thay vì dựng một cron riêng: mỗi lần đăng nhập là
  // một dịp quét, bảng này không bao giờ to.
  await db
    .prepare('DELETE FROM sessions WHERE expires_at < ?')
    .bind(created.toISOString())
    .run();

  return { token, expiresAt: expires.toISOString(), auth: authOf(row) };
}

export async function logout(db: D1Database, token: string) {
  await db
    .prepare('DELETE FROM sessions WHERE token_hash = ?')
    .bind(await sessionKey(token))
    .run();
  return { ok: true };
}

function authOf(row: Row): Auth {
  return {
    userId: Number(row.id),
    username: String(row.username),
    fullName: String(row.full_name ?? ''),
    role: String(row.role) as Role,
    facilityId: row.facility_id === null ? null : Number(row.facility_id),
    facilityName: String(row.facility_name ?? ''),
    viaToken: false,
  };
}

export function tokenAuth(): Auth {
  return {
    userId: null,
    username: 'token-quan-tri',
    fullName: 'Token quản trị',
    role: 'ADMIN',
    facilityId: null,
    facilityName: '',
    viaToken: true,
  };
}

/** Phiên từ bearer token; trả null khi token không phải của phiên nào. */
export async function sessionAuth(
  db: D1Database,
  token: string,
): Promise<Auth | null> {
  const key = await sessionKey(token);
  const row = await db
    .prepare(
      `SELECT u.*, f.name as facility_name, f.code as facility_code, s.expires_at
         FROM sessions s
         JOIN users u ON u.id = s.user_id
         LEFT JOIN facilities f ON f.id = u.facility_id
        WHERE s.token_hash = ?`,
    )
    .bind(key)
    .first<Row>();
  if (!row) return null;

  const now = nowIso();
  if (String(row.expires_at) <= now || Number(row.active) !== 1) {
    await db.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(key).run();
    return null;
  }

  await db
    .prepare('UPDATE sessions SET last_seen_at = ? WHERE token_hash = ?')
    .bind(now, key)
    .run();
  return authOf(row);
}

// --------------------------------------------------------------- phân quyền

/**
 * Quyền của từng vai trò, viết thẳng ra một bảng thay vì rải `if role ===`
 * khắp router. Đọc bảng này là biết ai làm được gì, và thêm vai trò mới chỉ
 * phải sửa một chỗ.
 */
export const permissions = {
  ADMIN: {
    manageUsers: true,
    viewAudit: true,
    manageCatalog: true,
    manageBatch: true,
    publish: true,
    manageEvent: true,
    manageMedia: true,
    manageRatings: true,
    viewChain: true,
    manageChain: true,
    allFacilities: true,
  },
  FACILITY: {
    manageUsers: false,
    viewAudit: true,
    manageCatalog: false,
    manageBatch: true,
    publish: true,
    manageEvent: true,
    manageMedia: true,
    manageRatings: false,
    viewChain: true,
    manageChain: false,
    allFacilities: false,
  },
  STAFF: {
    manageUsers: false,
    viewAudit: false,
    manageCatalog: false,
    manageBatch: false,
    publish: false,
    manageEvent: true,
    manageMedia: true,
    manageRatings: false,
    viewChain: false,
    manageChain: false,
    allFacilities: false,
  },
} as const satisfies Record<Role, Record<string, boolean>>;

export type Permission = keyof (typeof permissions)['ADMIN'];

export function can(auth: Auth, permission: Permission) {
  return permissions[auth.role][permission];
}

export function requirePermission(auth: Auth, permission: Permission) {
  if (!can(auth, permission)) {
    throw new ApiError(
      403,
      'FORBIDDEN',
      `Vai trò ${roleLabel(auth.role)} không được làm việc này.`,
    );
  }
}

export function roleLabel(role: Role) {
  return role === 'ADMIN'
    ? 'quản trị hệ thống'
    : role === 'FACILITY'
      ? 'phụ trách cơ sở'
      : 'nhân viên công đoạn';
}

/**
 * Chặn ở tầng dữ liệu, không chỉ ẩn nút trên giao diện: người của cơ sở này gọi
 * thẳng API với id của cơ sở kia vẫn phải bị từ chối.
 */
export function assertFacility(auth: Auth, facilityId: number | null) {
  if (can(auth, 'allFacilities')) return;
  if (auth.facilityId === null) {
    throw new ApiError(
      403,
      'FORBIDDEN',
      'Tài khoản chưa được gán cơ sở, không truy cập được dữ liệu nào.',
    );
  }
  if (facilityId !== auth.facilityId) {
    throw new ApiError(403, 'FORBIDDEN', 'Dữ liệu này thuộc cơ sở khác.');
  }
}

async function facilityByQuery(
  db: D1Database,
  sql: string,
  value: unknown,
  missing: [string, string],
) {
  const row = await db.prepare(sql).bind(value).first<Row>();
  if (!row) throw new ApiError(404, missing[0], missing[1]);
  return row.facilityId === null ? null : Number(row.facilityId);
}

const BATCH_FACILITY = `SELECT c.facility_id as facilityId
     FROM product_batches p LEFT JOIN products c ON c.id = p.product_id`;

/** Cơ sở của một lô, suy qua catalog sản phẩm. */
export function facilityOfBatch(db: D1Database, batchId: number) {
  return facilityByQuery(db, `${BATCH_FACILITY} WHERE p.id = ?`, batchId, [
    'TRACE_NOT_FOUND',
    'Không tìm thấy lô.',
  ]);
}

export function facilityOfBatchCode(db: D1Database, code: string) {
  return facilityByQuery(db, `${BATCH_FACILITY} WHERE p.code = ?`, code, [
    'TRACE_NOT_FOUND',
    'Không tìm thấy mã truy xuất.',
  ]);
}

export function facilityOfIngredient(db: D1Database, ingredientId: number) {
  return facilityByQuery(
    db,
    `SELECT c.facility_id as facilityId
       FROM ingredient_batches i
       JOIN product_batches p ON p.id = i.product_batch_id
       LEFT JOIN products c ON c.id = p.product_id
      WHERE i.id = ?`,
    ingredientId,
    ['NOT_FOUND', 'Không tìm thấy lô nguyên liệu.'],
  );
}

/** Công đoạn treo ở nguyên liệu, hoặc treo thẳng ở lô thành phẩm. */
const EVENT_FACILITY = `SELECT c.facility_id as facilityId
     FROM process_events e
     LEFT JOIN ingredient_batches i ON i.id = e.ingredient_batch_id
     LEFT JOIN product_batches p
            ON p.id = COALESCE(i.product_batch_id, e.product_batch_id)
     LEFT JOIN products c ON c.id = p.product_id`;

export function facilityOfEvent(db: D1Database, eventId: number) {
  return facilityByQuery(db, `${EVENT_FACILITY} WHERE e.id = ?`, eventId, [
    'NOT_FOUND',
    'Không tìm thấy công đoạn.',
  ]);
}

const ownerFacilitySql: Record<string, string> = {
  product_batch: `${BATCH_FACILITY} WHERE p.id = ?`,
  ingredient_batch: `SELECT c.facility_id as facilityId
       FROM ingredient_batches i
       JOIN product_batches p ON p.id = i.product_batch_id
       LEFT JOIN products c ON c.id = p.product_id
      WHERE i.id = ?`,
  process_event: `${EVENT_FACILITY} WHERE e.id = ?`,
};

export function facilityOfOwner(
  db: D1Database,
  ownerType: string,
  ownerId: number,
) {
  const sql = ownerFacilitySql[ownerType];
  if (!sql) throw badRequest('ownerType không hợp lệ.');
  return facilityByQuery(db, sql, ownerId, [
    'OWNER_NOT_FOUND',
    'Không tìm thấy đối tượng để gắn media.',
  ]);
}

export function facilityOfProduct(db: D1Database, productId: number) {
  return facilityByQuery(
    db,
    'SELECT facility_id as facilityId FROM products WHERE id = ?',
    productId,
    ['NOT_FOUND', 'Không tìm thấy sản phẩm.'],
  );
}

// ------------------------------------------------------------------ nhật ký

export async function writeAudit(
  db: D1Database,
  auth: Auth,
  action: string,
  target: string,
  detail = '',
) {
  await db
    .prepare(
      `INSERT INTO audit_log (user_id, username, role, action, target, detail, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    )
    .bind(
      auth.userId,
      auth.username,
      auth.role,
      action,
      target.slice(0, 120),
      detail.slice(0, 400),
      nowIso(),
    )
    .run();
}

export async function auditLog(
  db: D1Database,
  options: { limit?: number; target?: string; facilityId?: number | null } = {},
) {
  const limit = Math.min(Math.max(options.limit ?? 50, 1), 500);
  const conditions: string[] = [];
  const args: unknown[] = [];
  if (options.target) {
    conditions.push('a.target = ?');
    args.push(options.target);
  }
  // Người phụ trách cơ sở chỉ xem nhật ký của người cùng cơ sở mình. Không
  // kèm các dòng do token quản trị ghi: chúng có thể nhắc mã lô của cơ sở kia.
  if (options.facilityId !== undefined && options.facilityId !== null) {
    conditions.push('u.facility_id = ?');
    args.push(options.facilityId);
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const result = await db
    .prepare(
      `SELECT a.id, a.username, a.role, a.action, a.target, a.detail,
              a.created_at as createdAt, u.full_name as fullName
         FROM audit_log a LEFT JOIN users u ON u.id = a.user_id
         ${where}
        ORDER BY a.id DESC LIMIT ?`,
    )
    .bind(...args, limit)
    .all<Row>();
  return result.results ?? [];
}

// ---------------------------------------------------------------- tài khoản

export async function listFacilities(db: D1Database) {
  const result = await db
    .prepare('SELECT id, code, name FROM facilities ORDER BY id')
    .all<Row>();
  return result.results ?? [];
}

/** Cơ sở phải có thật trước khi gắn tài khoản hay sản phẩm vào. */
export async function assertFacilityExists(db: D1Database, id: number) {
  const row = await db
    .prepare('SELECT id FROM facilities WHERE id = ?')
    .bind(id)
    .first<Row>();
  if (!row) throw badRequest('Không có cơ sở với mã này.');
}

export async function listUsers(db: D1Database) {
  const result = await db
    .prepare(
      `SELECT u.id, u.username, u.full_name as fullName, u.role, u.active,
              u.facility_id as facilityId, f.name as facilityName,
              u.created_at as createdAt, u.last_login_at as lastLoginAt
         FROM users u LEFT JOIN facilities f ON f.id = u.facility_id
        ORDER BY u.role, u.username`,
    )
    .all<Row>();
  return result.results ?? [];
}

export async function createUser(
  db: D1Database,
  input: {
    username: string;
    password: string;
    fullName: string;
    role: Role;
    facilityId: number | null;
  },
) {
  const username = normalizeUsername(input.username);
  checkPasswordStrength(input.password);
  // Quản trị hệ thống thấy mọi cơ sở, nên không gắn cơ sở nào: để lại một
  // facility_id ở đó chỉ làm người đọc dữ liệu hiểu nhầm là họ bị giới hạn.
  if (input.role === 'ADMIN') input.facilityId = null;
  if (input.role !== 'ADMIN' && input.facilityId === null) {
    throw badRequest('Vai trò này phải thuộc một cơ sở.');
  }
  if (input.facilityId !== null) {
    await assertFacilityExists(db, input.facilityId);
  }
  const existing = await db
    .prepare('SELECT id FROM users WHERE username = ?')
    .bind(username)
    .first<Row>();
  if (existing) throw badRequest('Tên đăng nhập đã có người dùng.');

  const created = await db
    .prepare(
      `INSERT INTO users (username, full_name, role, facility_id, password_hash, active, created_at)
       VALUES (?, ?, ?, ?, ?, 1, ?)
       RETURNING id, username, full_name as fullName, role,
                 facility_id as facilityId, active`,
    )
    .bind(
      username,
      input.fullName.trim().slice(0, 120),
      input.role,
      input.facilityId,
      await hashPassword(input.password),
      nowIso(),
    )
    .first<Row>();
  return created as Row;
}

export async function updateUser(
  db: D1Database,
  id: number,
  input: {
    fullName?: string;
    password?: string;
    active?: boolean;
    role?: Role;
    facilityId?: number | null;
  },
) {
  const user = await db
    .prepare('SELECT * FROM users WHERE id = ?')
    .bind(id)
    .first<Row>();
  if (!user) throw new ApiError(404, 'NOT_FOUND', 'Không tìm thấy tài khoản.');

  const role = input.role ?? (String(user.role) as Role);
  // Quản trị hệ thống không thuộc cơ sở nào (xem createUser).
  const facilityId =
    role === 'ADMIN'
      ? null
      : input.facilityId !== undefined
        ? input.facilityId
        : user.facility_id === null
          ? null
          : Number(user.facility_id);
  if (role !== 'ADMIN' && facilityId === null) {
    throw badRequest('Vai trò này phải thuộc một cơ sở.');
  }

  // Khoá hoặc hạ quyền người quản trị cuối cùng là tự khoá mình ra ngoài. Chỉ
  // kiểm khi đối tượng đang LÀ quản trị: kiểm cả lúc khoá nhân viên thì hệ
  // thống chưa có tài khoản ADMIN nào (chỉ vào bằng token) sẽ không khoá được ai.
  if (String(user.role) === 'ADMIN' && (input.active === false || role !== 'ADMIN')) {
    await assertAdminRemains(db, id);
  }

  // Giữ câu lệnh và tham số đi cùng nhau trong một danh sách: tách thành hai
  // mảng song song là kiểu lỗi chỉ lộ ra khi đã ghi nhầm cột.
  const changes: [string, unknown][] = [];
  if (input.fullName !== undefined) {
    changes.push(['full_name = ?', input.fullName.trim().slice(0, 120)]);
  }
  if (input.password !== undefined) {
    checkPasswordStrength(input.password);
    changes.push(['password_hash = ?', await hashPassword(input.password)]);
  }
  if (input.active !== undefined) {
    changes.push(['active = ?', input.active ? 1 : 0]);
  }
  if (input.role !== undefined) changes.push(['role = ?', role]);
  if (input.facilityId !== undefined || (role === 'ADMIN' && user.facility_id !== null)) {
    changes.push(['facility_id = ?', facilityId]);
  }
  if (!changes.length) throw badRequest('Không có trường nào để sửa.');

  // Đặt lại mật khẩu hoặc mở lại tài khoản thì xoá luôn phần khoá tạm do nhập
  // sai nhiều lần, không bắt người ta ngồi chờ hết 15 phút.
  const extra =
    input.password !== undefined || input.active === true
      ? ', failed_attempts = 0, locked_until = NULL'
      : '';

  await db
    .prepare(
      `UPDATE users SET ${changes.map(([sql]) => sql).join(', ')}${extra} WHERE id = ?`,
    )
    .bind(...changes.map(([, value]) => value), id)
    .run();

  // Đổi mật khẩu, khoá tài khoản, đổi vai trò hay đổi cơ sở đều phải đẩy người
  // đó ra khỏi mọi phiên đang mở; nếu không thì phiên cũ chạy tiếp như chưa có
  // gì xảy ra, với quyền cũ.
  if (
    input.password !== undefined ||
    input.active === false ||
    input.role !== undefined ||
    input.facilityId !== undefined
  ) {
    await db.prepare('DELETE FROM sessions WHERE user_id = ?').bind(id).run();
  }

  return { id, username: String(user.username), role, facilityId };
}

/** Hệ thống phải luôn còn ít nhất một quản trị đang hoạt động. */
export async function assertAdminRemains(db: D1Database, excludeId: number) {
  const row = await db
    .prepare(
      `SELECT COUNT(*) as count FROM users
        WHERE role = 'ADMIN' AND active = 1 AND id <> ?`,
    )
    .bind(excludeId)
    .first<Row>();
  if (Number(row?.count ?? 0) === 0) {
    throw badRequest(
      'Đây là tài khoản quản trị đang hoạt động duy nhất, không khoá hoặc hạ quyền được.',
    );
  }
}
