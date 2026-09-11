import assert from 'node:assert/strict';
import { Buffer } from 'node:buffer';

const BASE = process.env.API_BASE ?? 'http://127.0.0.1:8787';
const TOKEN = process.env.ADMIN_TOKEN ?? 'dev-token-tule';
const CODE = 'TL-2026-001';

async function call(method, path, { body, admin = false, headers = {} } = {}) {
  const init = { method, headers: { ...headers } };
  if (admin) init.headers.authorization = `Bearer ${TOKEN}`;
  if (body instanceof FormData) {
    init.body = body;
  } else if (body !== undefined) {
    init.headers['content-type'] = 'application/json';
    init.body = JSON.stringify(body);
  }
  const response = await fetch(`${BASE}${path}`, init);
  const text = await response.text();
  let parsed = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = text;
  }
  return { status: response.status, body: parsed, headers: response.headers };
}

async function get(path, admin = false) {
  const result = await call('GET', path, { admin });
  assert.equal(result.status, 200, `${path} trả ${result.status}`);
  return result.body;
}

/** PNG 1x1 hợp lệ, đủ để kiểm tra đường tải lên mà không cần file ngoài. */
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);

(async () => {
  const health = await get('/api/health');
  assert.equal(health.database, 'd1');
  assert.equal(health.storage, 'r2');

  // Quản trị phải đóng với người lạ.
  assert.equal((await call('GET', '/api/admin/summary')).status, 401);
  assert.equal(
    (
      await call('GET', '/api/admin/summary', {
        headers: { authorization: 'Bearer sai-token' },
      })
    ).status,
    401,
  );

  // Công bố lần đầu để có snapshot đối chiếu.
  const first = await call('POST', `/api/admin/product-batches/${CODE}/publish`, {
    admin: true,
  });
  assert.equal(first.status, 201);
  assert.equal(first.body.sha256.length, 64);

  // Hồ sơ công khai là bản đã công bố; hồ sơ quản trị là dữ liệu đang có. Mọi
  // thao tác cần id phải đi qua bản quản trị, vì bản công bố không mang id.
  /// Dữ liệu đang có khác bản đã lưu hay không — câu hỏi của người vận hành.
  const adminStatus = async () =>
    (await get(`/api/admin/product-batches/${CODE}/trace`, true)).integrity.status;

  const trace = await get(`/api/admin/product-batches/${CODE}/trace`, true);
  assert.equal(trace.ingredients.length, 4);

  const publicTrace = await get(`/api/public/traces/${CODE}`);
  assert.equal(publicTrace.ingredients.length, 4);
  assert.equal(publicTrace.id, undefined, 'bản công khai không mang id nội bộ');
  assert.equal(trace.integrity.status, 'VERIFIED');
  assert.ok(Array.isArray(trace.media), 'trace thiếu mảng media');

  const featured = await get('/api/public/featured');
  assert.equal(featured.code, CODE);

  const batches = await get(`/api/admin/product-batches?q=${CODE}`, true);
  assert.equal(batches.total, 1, 'tìm theo mã lô phải ra đúng một lô');
  assert.equal(batches.items[0].ingredientCount, 4);
  // Đủ 22 bước của sơ đồ cộng 2 bước ở xưởng; con số đổi khi quy trình đổi.
  assert.equal(batches.items[0].eventCount, 24);
  assert.ok(batches.items[0].created_at, 'danh sách phải kèm ngày tạo');

  // Phân trang: limit 1 thì mỗi trang đúng một lô, và trang vượt quá số trang
  // hiện có phải kéo về trang cuối thay vì trả danh sách rỗng.
  const firstPage = await get('/api/admin/product-batches?limit=1&sort=oldest', true);
  assert.equal(firstPage.items.length, 1);
  assert.equal(firstPage.page, 1);
  const beyond = await get('/api/admin/product-batches?limit=1&page=9999', true);
  assert.equal(beyond.page, beyond.pages);
  assert.equal(beyond.items.length, 1);
  assert.equal(
    (await get('/api/admin/product-batches?q=khong-co-ma-nay', true)).total,
    0,
  );

  assert.equal((await call('GET', '/api/public/traces/KHONG-CO')).status, 404);
  assert.equal(
    (await call('POST', '/api/admin/product-batches', { admin: true, body: {} }))
      .status,
    400,
  );
  assert.equal(
    (
      await call('POST', '/api/admin/product-batches', {
        admin: true,
        body: {
          name: 'Trùng mã',
          code: CODE,
          productionDate: '01.01.2026',
          expiryDate: '01.01.2027',
        },
      })
    ).status,
    409,
  );

  // Sửa thông tin lô và xoá nguyên liệu là hai việc mà màn quản trị cần.
  const renamed = await call('PATCH', `/api/admin/product-batches/${CODE}`, {
    admin: true,
    body: { description: 'Mô tả cập nhật từ smoke test.' },
  });
  assert.equal(renamed.status, 200);
  assert.equal(renamed.body.description, 'Mô tả cập nhật từ smoke test.');
  await call('PATCH', `/api/admin/product-batches/${CODE}`, {
    admin: true,
    body: { description: trace.description },
  });

  const newIngredient = await call('POST', '/api/admin/ingredient-batches', {
    admin: true,
    body: {
      productBatchId: trace.id,
      name: 'Nguyên liệu kiểm thử',
      origin: 'Tú Lệ, Yên Bái',
    },
  });
  assert.equal(newIngredient.status, 201);
  assert.equal(
    (
      await call('DELETE', `/api/admin/ingredient-batches/${newIngredient.body.id}`, {
        admin: true,
      })
    ).status,
    200,
  );
  assert.equal(
    (await get(`/api/public/traces/${CODE}`)).ingredients.length,
    4,
    'xoá nguyên liệu phải trả danh sách về như cũ',
  );

  // Tải ảnh bìa cho lô.
  const form = new FormData();
  form.set('file', new Blob([PNG], { type: 'image/png' }), 'anh-san-pham.png');
  form.set('ownerType', 'product_batch');
  form.set('ownerId', '1');
  form.set('role', 'cover');
  form.set('caption', 'Ảnh gói thành phẩm');
  const uploaded = await call('POST', '/api/admin/media', {
    admin: true,
    body: form,
  });
  assert.equal(uploaded.status, 201, JSON.stringify(uploaded.body));
  assert.equal(uploaded.body.kind, 'image');
  assert.equal(uploaded.body.sha256.length, 64);
  assert.ok(
    uploaded.body.url.includes(uploaded.body.sha256),
    'khoá R2 phải chứa hash nội dung',
  );

  // File phải tải về được, đúng content-type và có cache dài hạn.
  const fetched = await call('GET', uploaded.body.url);
  assert.equal(fetched.status, 200);
  assert.equal(fetched.headers.get('content-type'), 'image/png');
  assert.match(fetched.headers.get('cache-control') ?? '', /immutable/);
  assert.equal(fetched.headers.get('accept-ranges'), 'bytes');

  // Video cần Range để tua được; kiểm luôn trên file ảnh cho rẻ.
  const ranged = await call('GET', uploaded.body.url, {
    headers: { range: 'bytes=0-9' },
  });
  assert.equal(ranged.status, 206, 'thiếu hỗ trợ Range');
  assert.match(ranged.headers.get('content-range') ?? '', /^bytes 0-9\//);

  // Khoá bịa phải là 404 chứ không lộ lỗi nội bộ.
  assert.equal((await call('GET', '/api/media/media/khong-phai-hash.png')).status, 404);

  // File không nằm trong danh sách trắng bị chặn ở 400.
  const badForm = new FormData();
  badForm.set(
    'file',
    new Blob([Buffer.from('#!/bin/sh\necho hi')], { type: 'application/x-sh' }),
    'script.sh',
  );
  badForm.set('ownerType', 'product_batch');
  badForm.set('ownerId', '1');
  assert.equal(
    (await call('POST', '/api/admin/media', { admin: true, body: badForm }))
      .status,
    400,
  );

  // Thêm ảnh là đổi hồ sơ, nên phải lệch snapshot cũ.
  const afterUpload = { status: await adminStatus() };
  assert.equal(
    afterUpload.status,
    'MISMATCH',
    'thêm media phải làm snapshot lệch',
  );

  const republished = await call(
    'POST',
    `/api/admin/product-batches/${CODE}/publish`,
    { admin: true, body: { enteredBy: 'smoke-test' } },
  );
  assert.equal(republished.body.version, first.body.version + 1);
  assert.equal(await adminStatus(), 'VERIFIED');

  // Công đoạn ở xưởng: thuộc cả lô, không thuộc nguyên liệu nào.
  //
  // Đoạn này còn là chốt chặn cho quy tắc "trường rỗng thì không ghi vào
  // payload". Lô chưa có công đoạn xưởng phải băm ra đúng như trước khi tính
  // năng này tồn tại; thêm một khoá rỗng vào snapshot là làm mọi lô đã công bố
  // hoá sai lệch chỉ vì một thay đổi trong code.
  const batchEvent = await call('POST', '/api/admin/process-events', {
    admin: true,
    body: {
      productBatchId: trace.id,
      title: 'Kiểm thử phối trộn',
      eventDate: '12.08.2026',
    },
  });
  assert.equal(batchEvent.status, 201);
  const withBatchEvent = await get(`/api/public/traces/${CODE}`);
  assert.ok(
    withBatchEvent.batchEvents.some((e) => e.title === 'Kiểm thử phối trộn'),
    'công đoạn của lô phải ra ở batchEvents',
  );
  assert.ok(
    withBatchEvent.ingredients.every((item) =>
      item.processEvents.every((e) => e.title !== 'Kiểm thử phối trộn'),
    ),
    'công đoạn của lô không được lẫn vào nguyên liệu',
  );
  // Khai cả hai chỗ, hoặc không khai chỗ nào, đều phải bị từ chối.
  assert.equal(
    (
      await call('POST', '/api/admin/process-events', {
        admin: true,
        body: {
          productBatchId: trace.id,
          ingredientBatchId: trace.ingredients[0].id,
          title: 'Sai chỗ',
          eventDate: '12.08.2026',
        },
      })
    ).status,
    400,
  );
  assert.equal(
    (
      await call('POST', '/api/admin/process-events', {
        admin: true,
        body: { title: 'Không chủ', eventDate: '12.08.2026' },
      })
    ).status,
    400,
  );
  // Thêm công đoạn xưởng thì snapshot phải lệch...
  assert.equal(
    await adminStatus(),
    'MISMATCH',
    'thêm công đoạn xưởng phải làm snapshot lệch',
  );
  assert.equal(
    (await call('DELETE', `/api/admin/process-events/${batchEvent.body.id}`, {
      admin: true,
    })).status,
    200,
  );
  // ...và xoá đi thì khớp lại như cũ, không cần công bố lại.
  assert.equal(
    await adminStatus(),
    'VERIFIED',
    'lô không có công đoạn xưởng phải băm ra đúng như trước',
  );

  // Giấy chứng nhận: ba trường riêng, và chỉ giấy chứng nhận mới có chúng.
  const certForm = new FormData();
  certForm.set('file', new Blob([PNG], { type: 'image/png' }), 'ocop.png');
  certForm.set('ownerType', 'product_batch');
  certForm.set('ownerId', String(trace.id));
  certForm.set('role', 'certificate');
  certForm.set('caption', 'OCOP 4 sao');
  certForm.set('certType', 'OCOP');
  certForm.set('certNumber', '12/2026');
  certForm.set('validUntil', '31/12/2028');
  const cert = await call('POST', '/api/admin/media', {
    admin: true,
    body: certForm,
  });
  assert.equal(cert.status, 201, JSON.stringify(cert.body));

  const withCert = await get(`/api/admin/product-batches/${CODE}/trace`, true);
  const savedCert = withCert.media.find((item) => item.id === cert.body.id);
  assert.ok(savedCert, 'giấy chứng nhận phải nằm trong hồ sơ');
  assert.equal(savedCert.role, 'certificate');
  assert.equal(savedCert.certType, 'OCOP');
  assert.equal(savedCert.certNumber, '12/2026');
  assert.equal(savedCert.validUntil, '31/12/2028');
  assert.ok(
    withCert.media.every(
      (item) => item.role === 'certificate' || item.certType === undefined,
    ),
    'vai trò khác không được mang trường của giấy chứng nhận',
  );

  // Ảnh vùng nguyên liệu chỉ nhận file ảnh.
  const areaPdf = new FormData();
  areaPdf.set(
    'file',
    new Blob([Buffer.from('%PDF-1.4\n')], { type: 'application/pdf' }),
    'vung.pdf',
  );
  areaPdf.set('ownerType', 'product_batch');
  areaPdf.set('ownerId', String(trace.id));
  areaPdf.set('role', 'area_map');
  assert.equal(
    (await call('POST', '/api/admin/media', { admin: true, body: areaPdf }))
      .status,
    400,
    'ảnh vùng nguyên liệu phải từ chối file PDF',
  );

  const areaForm = new FormData();
  areaForm.set('file', new Blob([PNG], { type: 'image/png' }), 'vung.png');
  areaForm.set('ownerType', 'product_batch');
  areaForm.set('ownerId', String(trace.id));
  areaForm.set('role', 'area_map');
  areaForm.set('caption', 'Bốn vùng nguyên liệu');
  const area = await call('POST', '/api/admin/media', {
    admin: true,
    body: areaForm,
  });
  assert.equal(area.status, 201, JSON.stringify(area.body));

  // Dọn lại để lô trở về đúng bản đã công bố.
  await call('DELETE', `/api/admin/media/${cert.body.id}`, { admin: true });
  await call('DELETE', `/api/admin/media/${area.body.id}`, { admin: true });

  // Chi tiết công đoạn: khối lượng, người làm, tham số.
  //
  // Kiểm hai điều. Một, công đoạn không khai chi tiết thì payload không được
  // mọc thêm khoá rỗng — trạng thái phải còn VERIFIED sau khi tính năng này
  // tồn tại. Hai, PATCH chỉ đổi một trường không được xoá các trường khác.
  assert.equal(
    await adminStatus(),
    'VERIFIED',
    'thêm cột chi tiết công đoạn không được đổi mã băm của lô cũ',
  );

  const firstIngredient = trace.ingredients[0];
  const detailEvent = await call('POST', '/api/admin/process-events', {
    admin: true,
    body: {
      ingredientBatchId: firstIngredient.id,
      title: 'Kiểm thử sấy phun',
      eventDate: '12.08.2026',
      operator: 'Nguyễn Văn A',
      inputQuantity: 1000,
      outputQuantity: 210,
      quantityUnit: 'g',
      params: { 'Nhiệt độ': '180°C', 'Thời gian': '30 phút' },
    },
  });
  assert.equal(detailEvent.status, 201);
  const eventId = detailEvent.body.id;

  const withDetail = await get(`/api/admin/product-batches/${CODE}/trace`, true);
  const saved = withDetail.ingredients
    .flatMap((item) => item.processEvents)
    .find((item) => item.id === eventId);
  assert.ok(saved, 'công đoạn vừa tạo phải có trong hồ sơ quản trị');
  assert.equal(saved.operator, 'Nguyễn Văn A');
  assert.equal(saved.inputQuantity, 1000);
  assert.equal(saved.outputQuantity, 210);
  assert.equal(saved.params['Nhiệt độ'], '180°C');

  // PATCH mỗi khối lượng ra: người làm và tham số phải còn nguyên.
  assert.equal(
    (
      await call('PATCH', `/api/admin/process-events/${eventId}`, {
        admin: true,
        body: { outputQuantity: 205 },
      })
    ).status,
    200,
  );
  const afterPatch = (
    await get(`/api/admin/product-batches/${CODE}/trace`, true)
  ).ingredients
    .flatMap((item) => item.processEvents)
    .find((item) => item.id === eventId);
  assert.equal(afterPatch.outputQuantity, 205);
  assert.equal(
    afterPatch.operator,
    'Nguyễn Văn A',
    'PATCH một trường không được xoá các trường khác',
  );
  assert.equal(afterPatch.params['Thời gian'], '30 phút');
  assert.equal(afterPatch.title, 'Kiểm thử sấy phun');

  // Gửi null là xoá, khác với không gửi khoá.
  await call('PATCH', `/api/admin/process-events/${eventId}`, {
    admin: true,
    body: { operator: null, params: null },
  });
  const afterClear = (
    await get(`/api/admin/product-batches/${CODE}/trace`, true)
  ).ingredients
    .flatMap((item) => item.processEvents)
    .find((item) => item.id === eventId);
  assert.ok(!afterClear.operator, 'gửi null phải xoá người thực hiện');
  assert.ok(
    !afterClear.params || Object.keys(afterClear.params).length === 0,
    'gửi null phải xoá tham số',
  );
  assert.equal(afterClear.outputQuantity, 205, 'xoá trường này không đụng trường kia');

  // Khối lượng âm bị chặn ở 400 chứ không rơi xuống database.
  assert.equal(
    (
      await call('PATCH', `/api/admin/process-events/${eventId}`, {
        admin: true,
        body: { inputQuantity: -5 },
      })
    ).status,
    400,
  );

  assert.equal(
    (await call('DELETE', `/api/admin/process-events/${eventId}`, { admin: true }))
      .status,
    200,
  );
  assert.equal(
    await adminStatus(),
    'VERIFIED',
    'xoá công đoạn kiểm thử phải trả lô về đúng bản đã công bố',
  );

  // Trạng thái chuỗi: khai báo có cấu hình hay không, và hàng chờ ra sao.
  const chain = await get('/api/admin/chain', true);
  assert.equal(typeof chain.configured, 'boolean');
  assert.ok(chain.outbox && typeof chain.outbox.byStatus === 'object');
  if (chain.configured) {
    assert.match(chain.address, /^0x[0-9a-fA-F]{40}$/);
    assert.equal(typeof chain.chainId, 'number');
  }

  // Lịch sử niêm phong phải nói được mã băm đang nằm ở đâu.
  const history = await call('GET', `/api/admin/product-batches/${CODE}/snapshots`, {
    admin: true,
  });
  assert.equal(history.status, 200);
  assert.equal(history.body[0].version, republished.body.version);
  assert.equal(history.body[0].sha256, republished.body.sha256);
  assert.equal(
    history.body[0].chainStatus,
    'PENDING_NETWORK',
    'chưa nối mạng thì mọi bản niêm phong phải nằm ở hàng chờ',
  );
  assert.equal(history.body[0].txHash, null);

  // Bản công khai lấy media từ snapshot nên không mang id nội bộ; nhận diện
  // bằng mã băm nội dung, đúng như cách khoá R2 được đặt.
  const withMedia = await get(`/api/public/traces/${CODE}`);
  const cover = withMedia.media.find(
    (item) => item.sha256 === uploaded.body.sha256,
  );
  assert.ok(cover, 'ảnh vừa tải không xuất hiện trong trace công khai');
  assert.equal(cover.role, 'cover');
  assert.equal(cover.caption, 'Ảnh gói thành phẩm');
  assert.ok(cover.url.startsWith('/api/media/'), 'ảnh phải có đường dẫn tải về');

  // Sửa dữ liệu thì trang khách vẫn phải giữ nguyên bản đã công bố: người vận
  // hành nhập dở một lô đã bán ngoài thị trường không được làm khách thấy hồ sơ
  // nửa vời.
  const beforeEdit = await get(`/api/public/traces/${CODE}`);
  await call('PATCH', `/api/admin/product-batches/${CODE}`, {
    admin: true,
    body: { description: 'Sửa dở, khách không được thấy dòng này.' },
  });
  const duringEdit = await get(`/api/public/traces/${CODE}`);
  assert.equal(
    duringEdit.description,
    beforeEdit.description,
    'trang khách phải giữ nguyên bản đã công bố khi admin đang sửa',
  );
  assert.equal(
    duringEdit.integrity.status,
    'VERIFIED',
    'bản đang phục vụ vẫn khớp mã băm của chính nó',
  );
  assert.equal(await adminStatus(), 'MISMATCH', 'admin phải thấy có thay đổi chưa lưu');

  await call('POST', `/api/admin/product-batches/${CODE}/publish`, {
    admin: true,
    body: { enteredBy: 'smoke-test' },
  });
  assert.equal(
    (await get(`/api/public/traces/${CODE}`)).description,
    'Sửa dở, khách không được thấy dòng này.',
    'công bố xong thì nội dung mới ra mắt',
  );
  await call('PATCH', `/api/admin/product-batches/${CODE}`, {
    admin: true,
    body: { description: beforeEdit.description },
  });
  await call('POST', `/api/admin/product-batches/${CODE}/publish`, {
    admin: true,
    body: { enteredBy: 'smoke-test' },
  });

  // Bản cũ phải đọc lại được nguyên nội dung, không chỉ còn mã băm: đó là thứ
  // làm cho câu "sửa dữ liệu không xoá bản đã công bố" thành sự thật kiểm được.
  const old = await get(
    `/api/admin/product-batches/${CODE}/snapshots/${first.body.version}`,
    true,
  );
  assert.equal(old.version, first.body.version);
  assert.equal(old.sha256, first.body.sha256);
  assert.ok(old.payload && Array.isArray(old.payload.ingredients));
  assert.equal(old.payload.ingredients.length, 4);
  assert.equal(
    (await call('GET', `/api/admin/product-batches/${CODE}/snapshots/99999`, { admin: true }))
      .status,
    404,
  );

  // Xoá media khỏi lô không được xoá file mà bản đã công bố còn trỏ tới: khoá
  // R2 nằm trong snapshot đem đi băm, mất file là bản trên chuỗi không dựng
  // lại được nữa.
  const keptKey = uploaded.body.url.replace('/api/media/', '');
  const removal = await call('DELETE', `/api/admin/media/${uploaded.body.id}`, {
    admin: true,
  });
  assert.equal(removal.status, 200);
  assert.equal(removal.body.fileKept, true, 'file còn trong bản công bố thì phải giữ lại');
  assert.equal(
    (await call('GET', `/api/media/${keptKey}`)).status,
    200,
    'file của bản đã công bố phải còn tải được sau khi gỡ khỏi lô',
  );

  // Gỡ media xong thì snapshot lệch, công bố lại để trả database về sạch.
  assert.equal(
    await adminStatus(),
    'MISMATCH',
  );
  await call('POST', `/api/admin/product-batches/${CODE}/publish`, {
    admin: true,
  });
  assert.equal(await adminStatus(), 'VERIFIED');

  // Trang web tĩnh vẫn phải phục vụ được và SPA fallback phải hoạt động.
  const spa = await call('GET', `/t/${CODE}`);
  assert.equal(spa.status, 200, 'SPA fallback không hoạt động');

  console.log(
    'Worker smoke test passed: auth quản trị, mã lỗi HTTP, upload R2 content-addressed, Range, media vào snapshot, chi tiết công đoạn, giấy chứng nhận, SPA fallback',
  );
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
