// Kiểm tra phân quyền theo vai trò trên một worker ĐANG CHẠY LOCAL.
//
//   npx wrangler dev --port 8799      (cửa sổ khác)
//   node scripts/test-phan-quyen.mjs  [http://127.0.0.1:8799]
//
// Script tạo ba tài khoản thử, dựng một lô của cơ sở TULE rồi kiểm từng ô
// trong bảng quyền: ai làm được gì, và quan trọng hơn, ai KHÔNG làm được gì.
// Ẩn nút trên giao diện không phải bảo vệ; chỗ phải chặn là API, nên chỗ phải
// kiểm cũng là API.
//
// Chỉ chạy local: nó tạo tài khoản và lô thật, không được chạm vào bản production.

import { readFileSync } from 'node:fs';

const BASE = (process.argv[2] ?? 'http://127.0.0.1:8799').replace(/\/$/, '');

if (!/^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/.test(BASE)) {
  console.error(
    'Script này chỉ chạy với worker local. Nó tạo tài khoản và lô thật.',
  );
  process.exit(2);
}

/** Token quản trị của bản local, đọc từ worker/.dev.vars (không in ra). */
function adminToken() {
  if (process.env.ADMIN_TOKEN) return process.env.ADMIN_TOKEN;
  const text = readFileSync(new URL('../.dev.vars', import.meta.url), 'utf8');
  const line = text
    .split(/\r?\n/)
    .find((row) => row.trim().startsWith('ADMIN_TOKEN'));
  if (!line) throw new Error('Không thấy ADMIN_TOKEN trong worker/.dev.vars');
  return line.slice(line.indexOf('=') + 1).trim().replace(/^["']|["']$/g, '');
}

const TOKEN = adminToken();
const stamp = Date.now().toString(36).slice(-5);
/// Worker in hoa mã lô khi lưu, nên test phải gọi lại bằng đúng mã đã in hoa.
const CODE = `PQ-${stamp}`.toUpperCase();

let passed = 0;
const failures = [];

function check(name, condition, detail = '') {
  if (condition) {
    passed += 1;
    console.log(`  ok   ${name}`);
  } else {
    failures.push(`${name}${detail ? ` — ${detail}` : ''}`);
    console.log(`  LỖI  ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

async function call(auth, method, path, body) {
  const response = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      ...(auth ? { authorization: `Bearer ${auth}` } : {}),
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try {
    data = await response.json();
  } catch {
    data = null;
  }
  return { status: response.status, data };
}

async function login(username, password) {
  const result = await call(null, 'POST', '/api/auth/login', {
    username,
    password,
  });
  if (result.status !== 200) {
    throw new Error(
      `Đăng nhập ${username} thất bại: ${result.status} ${JSON.stringify(result.data)}`,
    );
  }
  return result.data.token;
}

// --------------------------------------------------------------- dựng dữ liệu

console.log(`Kiểm phân quyền trên ${BASE}`);

const facilities = await call(TOKEN, 'GET', '/api/admin/facilities');
if (facilities.status !== 200 || !Array.isArray(facilities.data)) {
  console.error(
    'Không đọc được danh sách cơ sở. Đã chạy migration 0013 chưa?',
    facilities.status,
    facilities.data,
  );
  process.exit(2);
}
const tule = facilities.data.find((row) => row.code === 'TULE');
const trau = facilities.data.find((row) => row.code === 'TRAU');
if (!tule || !trau) {
  console.error('Thiếu cơ sở TULE hoặc TRAU trong bảng facilities.');
  process.exit(2);
}

const accounts = {
  phuTrachTule: {
    username: `pt-tule-${stamp}`,
    password: 'thuquyen2026',
    fullName: 'Phụ trách Tú Lệ (thử)',
    role: 'FACILITY',
    facilityId: tule.id,
  },
  nhanVienTule: {
    username: `nv-tule-${stamp}`,
    password: 'thuquyen2026',
    fullName: 'Nhân viên Tú Lệ (thử)',
    role: 'STAFF',
    facilityId: tule.id,
  },
  phuTrachTrau: {
    username: `pt-trau-${stamp}`,
    password: 'thuquyen2026',
    fullName: 'Phụ trách thịt trâu (thử)',
    role: 'FACILITY',
    facilityId: trau.id,
  },
};

for (const account of Object.values(accounts)) {
  const created = await call(TOKEN, 'POST', '/api/admin/users', account);
  if (created.status !== 201) {
    console.error('Không tạo được tài khoản thử:', created.status, created.data);
    process.exit(2);
  }
}

const sessions = {
  tuleFacility: await login(
    accounts.phuTrachTule.username,
    accounts.phuTrachTule.password,
  ),
  tuleStaff: await login(
    accounts.nhanVienTule.username,
    accounts.nhanVienTule.password,
  ),
  trauFacility: await login(
    accounts.phuTrachTrau.username,
    accounts.phuTrachTrau.password,
  ),
};

// Một sản phẩm của mỗi cơ sở, để có lô mà thử.
const tuleProduct = await call(TOKEN, 'POST', '/api/admin/products', {
  sku: `thu-tule-${stamp}`,
  name: 'Sản phẩm thử Tú Lệ',
  facilityId: tule.id,
});
const trauProduct = await call(TOKEN, 'POST', '/api/admin/products', {
  sku: `thu-trau-${stamp}`,
  name: 'Sản phẩm thử thịt trâu',
  facilityId: trau.id,
});
if (tuleProduct.status !== 201 || trauProduct.status !== 201) {
  console.error('Không tạo được sản phẩm thử.', tuleProduct, trauProduct);
  process.exit(2);
}

console.log('\n1. Mật khẩu và phiên');

const badLogin = await call(null, 'POST', '/api/auth/login', {
  username: accounts.nhanVienTule.username,
  password: 'sai-mat-khau-1',
});
check('mật khẩu sai bị từ chối', badLogin.status === 401, `status ${badLogin.status}`);

const noToken = await call(null, 'GET', '/api/admin/summary');
check('không token thì không vào được', noToken.status === 401);

const fakeToken = await call('khong-phai-token', 'GET', '/api/admin/summary');
check('token bừa thì không vào được', fakeToken.status === 401);

const me = await call(sessions.tuleStaff, 'GET', '/api/admin/session');
check(
  'phiên trả về đúng vai trò và cơ sở',
  me.status === 200 &&
    me.data?.user?.role === 'STAFF' &&
    me.data?.user?.facilityId === tule.id,
  JSON.stringify(me.data?.user),
);

console.log('\n2. Nhân viên công đoạn');

const staffBatch = await call(
  sessions.tuleStaff,
  'POST',
  '/api/admin/product-batches',
  {
    productId: tuleProduct.data.id,
    name: 'Lô do nhân viên tạo',
    code: `NV-${stamp}`,
    productionDate: '23.10.2026',
    expiryDate: '23.04.2027',
  },
);
check('nhân viên KHÔNG tạo được lô', staffBatch.status === 403, `status ${staffBatch.status}`);

const staffUsers = await call(sessions.tuleStaff, 'GET', '/api/admin/users');
check('nhân viên KHÔNG xem được tài khoản', staffUsers.status === 403);

const staffAudit = await call(sessions.tuleStaff, 'GET', '/api/admin/audit');
check('nhân viên KHÔNG xem được nhật ký', staffAudit.status === 403);

const staffRatings = await call(sessions.tuleStaff, 'GET', '/api/admin/ratings');
check('nhân viên KHÔNG xem được báo cáo đánh giá', staffRatings.status === 403);

const staffChain = await call(sessions.tuleStaff, 'POST', '/api/admin/chain/send');
check('nhân viên KHÔNG gửi tay lên chuỗi', staffChain.status === 403);

console.log('\n3. Phụ trách cơ sở');

const batch = await call(
  sessions.tuleFacility,
  'POST',
  '/api/admin/product-batches',
  {
    productId: tuleProduct.data.id,
    name: 'Lô thử phân quyền',
    code: CODE,
    productionDate: '23.10.2026',
    expiryDate: '23.04.2027',
    facilityName: 'Xưởng thử',
  },
);
check('phụ trách tạo được lô của cơ sở mình', batch.status === 201, JSON.stringify(batch.data));

const crossBatch = await call(
  sessions.tuleFacility,
  'POST',
  '/api/admin/product-batches',
  {
    productId: trauProduct.data.id,
    name: 'Lô của cơ sở khác',
    code: `CHEO-${stamp}`,
    productionDate: '23.10.2026',
    expiryDate: '23.04.2027',
  },
);
check(
  'phụ trách KHÔNG tạo được lô cho cơ sở khác',
  crossBatch.status === 403,
  `status ${crossBatch.status}`,
);

const batchId = batch.data?.id;
const ingredient = await call(
  sessions.tuleFacility,
  'POST',
  '/api/admin/ingredient-batches',
  {
    productBatchId: batchId,
    name: 'Nguyên liệu thử',
    origin: 'Tú Lệ, Yên Bái',
  },
);
check('phụ trách thêm được nguyên liệu', ingredient.status === 201);

const facilityUsers = await call(sessions.tuleFacility, 'GET', '/api/admin/users');
check('phụ trách KHÔNG quản lý được tài khoản', facilityUsers.status === 403);

console.log('\n4. Ranh giới giữa hai cơ sở');

const trauList = await call(
  sessions.trauFacility,
  'GET',
  '/api/admin/product-batches?limit=100',
);
const trauCodes = (trauList.data?.items ?? []).map((row) => row.code);
check(
  'cơ sở khác KHÔNG thấy lô vừa tạo trong danh sách',
  trauList.status === 200 && !trauCodes.includes(CODE),
  `thấy ${trauCodes.length} lô`,
);

const trauRead = await call(
  sessions.trauFacility,
  'GET',
  `/api/admin/product-batches/${CODE}/trace`,
);
check('cơ sở khác KHÔNG đọc được hồ sơ lô', trauRead.status === 403);

const trauPatch = await call(
  sessions.trauFacility,
  'PATCH',
  `/api/admin/product-batches/${CODE}`,
  { name: 'Đổi tên lô người khác' },
);
check('cơ sở khác KHÔNG sửa được lô', trauPatch.status === 403);

const trauEvent = await call(
  sessions.trauFacility,
  'POST',
  '/api/admin/process-events',
  {
    ingredientBatchId: ingredient.data?.id,
    title: 'Công đoạn chen ngang',
    eventDate: '23.10.2026',
  },
);
check('cơ sở khác KHÔNG khai được công đoạn', trauEvent.status === 403);

const trauPublish = await call(
  sessions.trauFacility,
  'POST',
  `/api/admin/product-batches/${CODE}/publish`,
);
check('cơ sở khác KHÔNG công bố được lô', trauPublish.status === 403);

console.log('\n5. Việc của nhân viên thì vẫn làm được, và ghi đúng tên');

const staffEvent = await call(
  sessions.tuleStaff,
  'POST',
  '/api/admin/process-events',
  {
    ingredientBatchId: ingredient.data?.id,
    title: 'Sấy thử',
    eventDate: '23.10.2026',
    // Cố tình khai tên người khác: worker phải bỏ qua và ghi tên người đăng nhập.
    enteredBy: 'giam-doc',
  },
);
check('nhân viên khai được công đoạn', staffEvent.status === 201, JSON.stringify(staffEvent.data));

const trace = await call(
  sessions.tuleFacility,
  'GET',
  `/api/admin/product-batches/${CODE}/trace`,
);
const events = (trace.data?.ingredients ?? []).flatMap(
  (row) => row.processEvents ?? [],
);
const sayEvent = events.find((row) => row.title === 'Sấy thử');
check(
  'người nhập là người đăng nhập, không phải tên client tự khai',
  sayEvent?.enteredBy === accounts.nhanVienTule.username,
  `enteredBy = ${sayEvent?.enteredBy}`,
);

const staffPublish = await call(
  sessions.tuleStaff,
  'POST',
  `/api/admin/product-batches/${CODE}/publish`,
);
check('nhân viên KHÔNG công bố được lô', staffPublish.status === 403);

const publish = await call(
  sessions.tuleFacility,
  'POST',
  `/api/admin/product-batches/${CODE}/publish`,
);
check('phụ trách công bố được lô', publish.status === 201, JSON.stringify(publish.data));

console.log('\n6. Nhật ký ghi lại ai làm gì');

const audit = await call(TOKEN, 'GET', '/api/admin/audit?limit=200');
const rows = Array.isArray(audit.data) ? audit.data : [];
check(
  'nhật ký có dòng nhân viên khai công đoạn, ghi tên người đó',
  rows.some(
    (row) =>
      row.action === 'CREATE_EVENT' &&
      row.username === accounts.nhanVienTule.username,
  ),
);
check(
  'nhật ký có dòng công bố, ghi tên người phụ trách',
  rows.some(
    (row) =>
      row.action === 'PUBLISH' &&
      row.username === accounts.phuTrachTule.username &&
      row.target === CODE,
  ),
);
check(
  'nhật ký ghi cả lần đăng nhập',
  rows.some(
    (row) =>
      row.action === 'LOGIN' && row.username === accounts.nhanVienTule.username,
  ),
);

console.log('\n7. Khoá tài khoản là đóng luôn phiên đang mở');

const staffRow = (await call(TOKEN, 'GET', '/api/admin/users')).data.find(
  (row) => row.username === accounts.nhanVienTule.username,
);
const locked = await call(TOKEN, 'PATCH', `/api/admin/users/${staffRow.id}`, {
  active: false,
});
check('khoá được tài khoản', locked.status === 200);

const afterLock = await call(sessions.tuleStaff, 'GET', '/api/admin/session');
check(
  'phiên của tài khoản bị khoá hết hiệu lực ngay',
  afterLock.status === 401,
  `status ${afterLock.status}`,
);

console.log('');
console.log('8. Hãm số lần thử mật khẩu');

// Tài khoản phụ trách Tú Lệ không còn phiên nào cần giữ, dùng nó làm chuột bạch.
let lastWrong = { status: 0 };
for (let attempt = 0; attempt < 5; attempt += 1) {
  lastWrong = await call(null, 'POST', '/api/auth/login', {
    username: accounts.phuTrachTule.username,
    password: `sai-mat-khau-${attempt}`,
  });
}
check(
  'sai 5 lần liên tiếp thì khoá tạm',
  lastWrong.status === 429,
  `status ${lastWrong.status}`,
);

const rightButLocked = await call(null, 'POST', '/api/auth/login', {
  username: accounts.phuTrachTule.username,
  password: accounts.phuTrachTule.password,
});
check(
  'đang khoá tạm thì mật khẩu đúng cũng chưa vào được',
  rightButLocked.status === 429,
  `status ${rightButLocked.status}`,
);

const lockedRow = (await call(TOKEN, 'GET', '/api/admin/users')).data.find(
  (row) => row.username === accounts.phuTrachTule.username,
);
await call(TOKEN, 'PATCH', `/api/admin/users/${lockedRow.id}`, {
  active: true,
  password: 'matkhaumoi2026',
});
const afterReset = await call(null, 'POST', '/api/auth/login', {
  username: accounts.phuTrachTule.username,
  password: 'matkhaumoi2026',
});
check(
  'quản trị đặt lại mật khẩu thì mở khoá luôn',
  afterReset.status === 200,
  `status ${afterReset.status}`,
);

console.log('');
console.log('9. Danh mục sản phẩm phải thuộc một cơ sở');

const orphan = await call(TOKEN, 'POST', '/api/admin/products', {
  sku: `thu-khong-co-so-${stamp}`,
  name: 'Sản phẩm không cơ sở',
});
check(
  'không tạo được sản phẩm thiếu cơ sở',
  orphan.status === 400,
  `status ${orphan.status}`,
);

const badFacility = await call(TOKEN, 'POST', '/api/admin/products', {
  sku: `thu-co-so-la-${stamp}`,
  name: 'Sản phẩm cơ sở lạ',
  facilityId: 99999,
});
check('không tạo được sản phẩm với cơ sở không có thật', badFacility.status === 400);

console.log('');
console.log('10. Nhật ký không rò sang cơ sở khác');

const trauAudit = await call(
  sessions.trauFacility,
  'GET',
  '/api/admin/audit?limit=200',
);
const trauRows = Array.isArray(trauAudit.data) ? trauAudit.data : [];
check(
  'phụ trách cơ sở này không thấy dòng nhật ký của cơ sở kia',
  trauAudit.status === 200 &&
    !trauRows.some(
      (row) => row.target === CODE || row.username.startsWith('nv-tule'),
    ),
  `${trauRows.length} dòng`,
);

console.log('');
console.log('11. Chỉ số báo cáo');

const metricKey = `thu-chi-so-${stamp}`;
// Đến đây hai phiên của cơ sở Tú Lệ đã chết (mục 7 khoá tài khoản, mục 8 đổi
// mật khẩu), nên dùng phiên của cơ sở trâu làm đại diện cho vai trò phụ trách.
const facilityMetric = await call(
  sessions.trauFacility,
  'PUT',
  `/api/admin/metrics/${metricKey}`,
  { label: 'Thử', value: '1', source: 'thử' },
);
check(
  'phụ trách cơ sở không khai được chỉ số',
  facilityMetric.status === 403,
  `status ${facilityMetric.status}`,
);

const noSource = await call(TOKEN, 'PUT', `/api/admin/metrics/${metricKey}`, {
  label: 'Thiếu nguồn',
  value: '1315',
  source: '',
});
check(
  'không lưu được chỉ số không ghi nguồn',
  noSource.status === 400,
  `status ${noSource.status}`,
);

const saved = await call(TOKEN, 'PUT', `/api/admin/metrics/${metricKey}`, {
  label: 'Chỉ số thử',
  value: '1315',
  source: 'Phiếu khảo sát thử',
});
check('quản trị khai được chỉ số có nguồn', saved.status === 200);

const listed = await call(TOKEN, 'GET', '/api/admin/metrics');
const metricRows = listed.data?.reported ?? [];
check(
  'chỉ số hiện ra kèm đúng nguồn đã ghi',
  metricRows.some((row) => row.key === metricKey && row.source === 'Phiếu khảo sát thử'),
);

// Lượt mở hồ sơ: đếm tăng đúng một, và endpoint công khai không cần đăng nhập.
const before = (await call(TOKEN, 'GET', '/api/admin/metrics')).data.views.total;
await call(null, 'POST', `/api/public/traces/${CODE}/view`);
const after = (await call(TOKEN, 'GET', '/api/admin/metrics')).data.views.total;
check(
  'mở hồ sơ cộng đúng một lượt, không cần đăng nhập',
  after === before + 1,
  `${before} -> ${after}`,
);

const trauViews = await call(sessions.trauFacility, 'GET', '/api/admin/metrics');
check(
  'phụ trách cơ sở này không thấy lượt xem lô của cơ sở kia',
  trauViews.status === 200 &&
    !(trauViews.data.views.byBatch ?? []).some((row) => row.code === CODE),
);

await call(TOKEN, 'DELETE', `/api/admin/metrics/${metricKey}`);

console.log('');
// Dọn: khoá hai tài khoản thử còn lại để bản local không còn cửa mở.
for (const account of Object.values(accounts)) {
  const row = (await call(TOKEN, 'GET', '/api/admin/users')).data.find(
    (item) => item.username === account.username,
  );
  if (row) {
    await call(TOKEN, 'PATCH', `/api/admin/users/${row.id}`, { active: false });
  }
}

console.log(`\n${passed} mục đúng, ${failures.length} mục sai.`);
if (failures.length) {
  for (const failure of failures) console.log(`  - ${failure}`);
  process.exit(1);
}
