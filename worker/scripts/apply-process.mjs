// Đưa công đoạn của một lô về đúng sơ đồ quy trình.
//
//   node scripts/apply-process.mjs TL-2026-002                     # máy dev
//   node scripts/apply-process.mjs TL-2026-002 --to <địa chỉ> --token-file ...
//
// Giữ lại công đoạn đã có nếu tên khớp — kèm ảnh đã tải lên — và chỉ bổ sung
// những bước còn thiếu. Xoá công đoạn để tạo lại là mất ảnh, nên script không
// làm thế.
//
// Chạy xong lô sẽ lệch với bản đã công bố; công bố lại bằng --publish.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { stepsForIngredient, BATCH_STEPS, STEP_ALIASES } from './process-steps.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : fallback;
}

const CODE = process.argv[2];
const BASE = (arg('to', 'http://127.0.0.1:8787')).replace(/\/$/, '');
const TOKEN_FILE = arg('token-file');
const TOKEN = (
  arg('token') ??
  (TOKEN_FILE ? fs.readFileSync(TOKEN_FILE, 'utf8') : 'dev-token-tule')
).trim();
const PUBLISH = process.argv.includes('--publish');

if (!CODE) {
  console.error('Cách dùng: node scripts/apply-process.mjs <MÃ LÔ> [--to <địa chỉ>] [--publish]');
  process.exit(1);
}

async function call(method, url, body) {
  const res = await fetch(`${BASE}${url}`, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      ...(body ? { 'Content-Type': 'application/json; charset=utf-8' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${url} -> ${res.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : null;
}

/// So tên công đoạn bỏ qua hoa thường và khoảng trắng thừa.
const key = (text) => (text ?? '').trim().toLowerCase();

/// Tìm công đoạn đã có ứng với một bước trong sơ đồ: khớp tên chuẩn, hoặc khớp
/// một trong những tên cũ từng dùng. Có thì đổi tên tại chỗ, giữ nguyên ảnh.
function findExisting(events, title, taken) {
  const names = [title, ...(STEP_ALIASES[title] ?? [])].map(key);
  return events.find(
    (event) => !taken.has(event.id) && names.includes(key(event.title)),
  );
}

async function syncSteps(existing, target, owner) {
  const taken = new Set();
  const plan = [];

  for (const [title, description] of target) {
    const match = findExisting(existing, title, taken);
    if (match) taken.add(match.id);
    plan.push({ title, description, match });
  }

  // Công đoạn đã ghi nhưng không có trong sơ đồ (ví dụ "Thu hoạch lúa nếp
  // nương") là dữ liệu thật của lô, không xoá. Xếp lên trước phần quy trình.
  const extras = existing.filter((event) => !taken.has(event.id));

  let added = 0;
  let renamed = 0;
  let position = 0;

  for (const event of extras) {
    if (event.position !== position) {
      await call('PATCH', `/api/admin/process-events/${event.id}`, { position });
    }
    position += 1;
  }

  for (const step of plan) {
    if (step.match) {
      const changed =
        key(step.match.title) !== key(step.title) ||
        key(step.match.description) !== key(step.description) ||
        step.match.position !== position;
      if (changed) {
        await call('PATCH', `/api/admin/process-events/${step.match.id}`, {
          title: step.title,
          description: step.description,
          position,
        });
        if (key(step.match.title) !== key(step.title)) renamed += 1;
      }
    } else {
      await call('POST', '/api/admin/process-events', {
        ...owner,
        title: step.title,
        description: step.description,
        eventDate: owner.eventDate,
        position,
      });
      added += 1;
    }
    position += 1;
  }

  return { added, renamed, kept: extras.length };
}

const trace = await call('GET', `/api/admin/product-batches/${CODE}/trace`);
const eventDate = trace.production_date || '';

for (const item of trace.ingredients) {
  const target = stepsForIngredient(item.name);
  if (!target) {
    console.log(`  ${item.name}: không có nhánh quy trình tương ứng, bỏ qua`);
    continue;
  }
  const result = await syncSteps(item.processEvents ?? [], target, {
    ingredientBatchId: item.id,
    eventDate: item.harvest_date || eventDate,
  });
  console.log(
    `  ${item.name}: ${target.length} bước sơ đồ (thêm ${result.added}, ` +
      `đổi tên ${result.renamed}, giữ ${result.kept} bước ngoài sơ đồ)`,
  );
}

const batch = await syncSteps(trace.batchEvents ?? [], BATCH_STEPS, {
  productBatchId: trace.id,
  eventDate,
});
console.log(
  `  Tại xưởng: ${BATCH_STEPS.length} bước (thêm ${batch.added}, ` +
    `đổi tên ${batch.renamed}, giữ ${batch.kept})`,
);

if (PUBLISH) {
  const published = await call('POST', `/api/admin/product-batches/${CODE}/publish`, {
    enteredBy: 'apply-process',
  });
  console.log(`Đã công bố bản v${published.version}.`);
} else {
  console.log('Chưa công bố. Thêm --publish nếu muốn chốt bản mới ngay.');
}
