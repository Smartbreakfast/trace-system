// Chép một lô từ máy này lên môi trường khác, kèm ảnh.
//
//   node scripts/copy-batch.mjs TL-2026-002 \
//     --to https://tule-trace.sontm.workers.dev \
//     --to-token-file .admin-token.txt
//
// Dùng khi lô được nhập ở máy dev rồi mới quyết định đưa lên production. Không
// đụng vào database trực tiếp: đi qua đúng API quản trị, nên mọi kiểm tra đầu
// vào vẫn chạy và lô mới trên đích cũng có mã băm của riêng nó.
//
// Chạy lại với lô đã tồn tại ở đích thì dừng, không ghi đè.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : fallback;
}

const CODE = process.argv[2];
const FROM = (arg('from', 'http://127.0.0.1:8787')).replace(/\/$/, '');
const TO = (arg('to') ?? '').replace(/\/$/, '');
const FROM_TOKEN = arg('from-token', 'dev-token-tule');
const TO_TOKEN_FILE = arg('to-token-file', path.resolve(here, '..', '.admin-token.txt'));

if (!CODE || !TO) {
  console.error('Cách dùng: node scripts/copy-batch.mjs <MÃ LÔ> --to <địa chỉ đích>');
  process.exit(1);
}

const TO_TOKEN = (arg('to-token') ?? fs.readFileSync(TO_TOKEN_FILE, 'utf8')).trim();

async function call(base, token, method, url, body) {
  const res = await fetch(`${base}${url}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body ? { 'Content-Type': 'application/json; charset=utf-8' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${url} -> ${res.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : null;
}

/// Tải file từ nguồn rồi đẩy sang đích. Khoá R2 đặt theo nội dung nên file
/// giống nhau vẫn nằm chung một object ở đích, không nhân bản dung lượng.
async function copyMedia(asset, ownerType, ownerId) {
  const res = await fetch(`${FROM}${asset.url}`);
  if (!res.ok) throw new Error(`không tải được ${asset.url}: ${res.status}`);
  const blob = await res.blob();

  const form = new FormData();
  form.append('file', blob, asset.fileName || 'file');
  form.append('ownerType', ownerType);
  form.append('ownerId', String(ownerId));
  form.append('role', asset.role || 'gallery');
  if (asset.caption) form.append('caption', asset.caption);

  const upload = await fetch(`${TO}/api/admin/media`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${TO_TOKEN}` },
    body: form,
  });
  if (!upload.ok) {
    throw new Error(`tải ảnh lên đích hỏng: ${upload.status} ${(await upload.text()).slice(0, 200)}`);
  }
}

const source = await call(FROM, FROM_TOKEN, 'GET', `/api/admin/product-batches/${CODE}/trace`);

const existing = await fetch(`${TO}/api/public/traces/${CODE}`);
if (existing.ok) {
  console.error(`Đích đã có lô ${CODE}. Dừng để không ghi đè.`);
  process.exit(1);
}

console.log(`Chép ${CODE}: ${source.ingredients.length} nguyên liệu, ` +
  `${source.ingredients.reduce((n, i) => n + i.processEvents.length, 0)} công đoạn nguyên liệu, ` +
  `${(source.batchEvents ?? []).length} công đoạn xưởng`);

const created = await call(TO, TO_TOKEN, 'POST', '/api/admin/product-batches', {
  name: source.name,
  code: source.code,
  productionDate: source.production_date,
  expiryDate: source.expiry_date,
  description: source.description,
  facilityName: source.facility_name,
  latitude: source.latitude,
  longitude: source.longitude,
});
console.log('  đã tạo lô, id', created.id);

for (const asset of source.media ?? []) {
  await copyMedia(asset, 'product_batch', created.id);
}
if ((source.media ?? []).length) console.log(`  ${source.media.length} ảnh của lô`);

for (const item of source.ingredients) {
  const ingredient = await call(TO, TO_TOKEN, 'POST', '/api/admin/ingredient-batches', {
    productBatchId: created.id,
    name: item.name,
    origin: item.origin,
    supplier: item.supplier,
    harvestDate: item.harvest_date,
    receivedDate: item.received_date,
    summary: item.summary,
    latitude: item.latitude,
    longitude: item.longitude,
    areaRadiusKm: item.area_radius_km,
    areaGeoJson: item.area_geojson,
  });

  for (const asset of item.media ?? []) {
    await copyMedia(asset, 'ingredient_batch', ingredient.id);
  }

  for (const event of item.processEvents ?? []) {
    const madeEvent = await call(TO, TO_TOKEN, 'POST', '/api/admin/process-events', {
      ingredientBatchId: ingredient.id,
      title: event.title,
      description: event.description,
      eventDate: event.event_date,
      enteredBy: event.entered_by,
    });
    for (const asset of event.media ?? []) {
      await copyMedia(asset, 'process_event', madeEvent.id);
    }
  }
  console.log(`  ${item.name}: ${(item.processEvents ?? []).length} công đoạn, ` +
    `${(item.media ?? []).length + (item.processEvents ?? []).reduce((n, e) => n + (e.media?.length ?? 0), 0)} ảnh`);
}

for (const event of source.batchEvents ?? []) {
  const madeEvent = await call(TO, TO_TOKEN, 'POST', '/api/admin/process-events', {
    productBatchId: created.id,
    title: event.title,
    description: event.description,
    eventDate: event.event_date,
    enteredBy: event.entered_by,
  });
  for (const asset of event.media ?? []) {
    await copyMedia(asset, 'process_event', madeEvent.id);
  }
}

// Công bố để lô có mã băm và giao dịch của riêng nó ở môi trường đích. Mã băm
// sẽ khác bản ở nguồn nếu dữ liệu có sai khác dù nhỏ — đó là điều đúng.
const published = await call(TO, TO_TOKEN, 'POST', `/api/admin/product-batches/${CODE}/publish`, {
  enteredBy: 'copy-batch',
});
console.log(`Xong. Bản v${published.version}, mã băm ${published.sha256.slice(0, 16)}…`);
console.log(`${TO}/t/${CODE}`);
