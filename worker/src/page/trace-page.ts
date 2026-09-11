/// Trang hồ sơ một lô, dựng sẵn thành HTML.
///
/// Ba mục giữ nguyên như bản Flutter: thông tin chung, nguồn gốc, kiểm định
/// chất lượng. Khác một điều: mọi thứ có mặt ngay trong HTML, nên người quét
/// mã đọc được trước khi trình duyệt kịp chạy dòng script nào.

import { esc, join, pill, eyebrow, heading } from './html';
import { shell } from './shell';
import { treeSvg, accents } from './tree';
import {
  iconAward,
  iconBack,
  iconBox,
  iconCalendar,
  iconClock,
  iconFlask,
  iconOpen,
  iconPerson,
  iconShield,
  iconStep,
  iconTag,
  iconTree,
  iconVerified,
  ingredientIcon,
} from './icons';
import type { MediaItem, ProcessEventItem, PublicTrace } from './types';

export type TabName = 'general' | 'origin' | 'quality';

const TABS: {
  name: TabName;
  slug: string;
  label: string;
  short: string;
  icon: (size?: number) => string;
}[] = [
  { name: 'general', slug: '', label: 'Thông tin chung', short: 'Thông tin', icon: iconBox },
  { name: 'origin', slug: 'nguon-goc', label: 'Nguồn gốc', short: 'Nguồn gốc', icon: iconTree },
  {
    name: 'quality',
    slug: 'kiem-dinh',
    label: 'Kiểm định chất lượng',
    short: 'Kiểm định',
    icon: iconVerified,
  },
];

export function tabFromSlug(slug: string | null | undefined): TabName {
  const found = TABS.find((tab) => tab.slug === (slug ?? '').trim());
  return found?.name ?? 'general';
}

/** Nhóm học sinh thực hiện đề tài, cũng là người ghi nhận công đoạn. */
const TEAM: { name: string; role: string; asset: string }[] = [
  { name: 'Trịnh Gia Nhi', role: '12 Chuyên Sinh', asset: 'trinh-gia-nhi.png' },
  { name: 'Phạm Hà Giang', role: '11D2 NH', asset: 'pham-ha-giang.png' },
  { name: 'Phạm Vũ Dũng', role: '10 Chuyên Anh1', asset: 'pham-vu-dung.png' },
  { name: 'Vũ Sơn Hải', role: '10 Chuyên Tin', asset: 'vu-son-hai.png' },
  { name: 'Nguyễn Tuấn Vũ', role: '10T1 NH', asset: 'nguyen-tuan-vu.png' },
];

/** Bỏ dấu để so tên: dữ liệu nhập tay có thể thiếu dấu. */
function fold(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function personFor(name: string) {
  const folded = fold(name);
  if (!folded) return null;
  return TEAM.find((member) => fold(member.name) === folded) ?? null;
}

const byRole = (items: MediaItem[] | undefined, role: string) =>
  (items ?? []).filter((item) => item.role === role);

const first = (items: MediaItem[] | undefined, role: string) =>
  byRole(items, role)[0] ?? null;

/** 500 chứ không phải 500.0, nhưng 12.5 thì giữ nguyên. */
function amount(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(1);
}

function paramsOf(event: ProcessEventItem): [string, string][] {
  const raw = event.params;
  if (!raw) return [];
  let data: unknown = raw;
  if (typeof raw === 'string') {
    try {
      data = JSON.parse(raw);
    } catch {
      return [];
    }
  }
  if (!data || typeof data !== 'object') return [];
  return Object.entries(data as Record<string, unknown>)
    .filter(([, value]) => value !== null && value !== undefined && String(value) !== '')
    .map(([key, value]) => [key, String(value)]);
}

/** 2026-09-11T12:30:27Z -> 11.09.2026 19:30 theo giờ Việt Nam. */
function stamp(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '';
  const local = new Date(date.getTime() + 7 * 3600 * 1000);
  const two = (value: number) => String(value).padStart(2, '0');
  return `${two(local.getUTCDate())}.${two(local.getUTCMonth() + 1)}.${local.getUTCFullYear()} ${two(local.getUTCHours())}:${two(local.getUTCMinutes())}`;
}

function image(item: MediaItem, className: string, lazy = true): string {
  return (
    `<img src="${esc(item.url)}" alt="${esc(item.caption || item.fileName || '')}"` +
    (lazy ? ' loading="lazy" decoding="async"' : '') +
    (className ? ` class="${className}"` : '') +
    '>'
  );
}

function strip(items: MediaItem[]): string {
  if (items.length === 0) return '';
  return (
    '<div class="strip">' +
    items
      .map(
        (item) =>
          `<a href="${esc(item.url)}" target="_blank" rel="noopener">${image(item, '')}</a>`,
      )
      .join('') +
    '</div>'
  );
}

function verifyCard(record: PublicTrace): string {
  const status = record.integrity?.status ?? '';
  const map: Record<string, { cls: string; title: string; body: string }> = {
    VERIFIED: {
      cls: 'ok',
      title: 'Đã xác minh',
      body: 'Dữ liệu lô hàng khớp với bản ghi đã công bố.',
    },
    MISMATCH: {
      cls: 'bad',
      title: 'Dữ liệu sai lệch',
      body: 'Dữ liệu hiện tại không khớp bản đã công bố.',
    },
  };
  const info = map[status] ?? {
    cls: 'warn',
    title: 'Chưa công bố',
    body: 'Lô này chưa có bản ghi công bố nào.',
  };
  return (
    `<div class="verify ${info.cls}">` +
    '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="flex:none;margin-top:2px">' +
    '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9.5"/></svg>' +
    `<div><span class="t">${esc(info.title)}</span><p>${esc(info.body)}</p></div></div>`
  );
}

function factsRow(record: PublicTrace): string {
  return (
    '<div class="facts-row">' +
    `<div><span class="pill-l">${iconTag(13)}Mã lô</span>` +
    `<span class="pill-v">${esc(record.code)}</span></div>` +
    (record.productionDate
      ? `<div><span class="pill-l">${iconCalendar(13)}Sản xuất</span>` +
        `<span class="pill-v">${esc(record.productionDate)}</span></div>`
      : '') +
    (record.expiryDate
      ? `<div><span class="pill-l">${iconClock(13)}Hạn dùng</span>` +
        `<span class="pill-v">${esc(record.expiryDate)}</span></div>`
      : '') +
    '</div>'
  );
}

// --------------------------------------------------------------- mục 1

function generalPanel(record: PublicTrace): string {
  const cover = first(record.media, 'cover');
  const gallery = byRole(record.media, 'gallery');
  const shot = cover
    ? `<img src="${esc(cover.url)}" alt="${esc(record.name)}" fetchpriority="high" decoding="async">`
    : '<img src="/f/tule-products.webp" alt="Tú Lệ Smart Breakfast" decoding="async">';

  return (
    '<div class="general">' +
    `<div class="shot">${shot}</div>` +
    '<div class="scroll-wrap"><div class="card facts">' +
    eyebrow('Sản phẩm') +
    `<h1 class="title">${esc(record.name)}</h1>` +
    verifyCard(record) +
    factsRow(record) +
    (record.description ? `<p class="desc">${esc(record.description)}</p>` : '') +
    '<div class="pill-row" style="margin-top:18px">' +
    pill('Nơi sản xuất', record.facilityName ?? '') +
    pill('Thành phần', `${(record.ingredients ?? []).length} nguyên liệu`) +
    '</div>' +
    (gallery.length
      ? `<div style="margin-top:20px">${heading('Hình ảnh sản phẩm')}${strip(gallery)}</div>`
      : '') +
    '</div></div></div>'
  );
}

// --------------------------------------------------------------- mục 2

function stepDetail(
  id: string,
  event: ProcessEventItem,
  owner: string,
  colour: string,
  backId: string,
): string {
  const unit = event.quantityUnit || 'g';
  const ratio =
    event.inputQuantity && event.outputQuantity
      ? event.outputQuantity / event.inputQuantity
      : null;
  const facts = join(
    pill('Thời gian', event.eventDate ?? ''),
    event.inputQuantity != null
      ? pill('Khối lượng vào', `${amount(event.inputQuantity)} ${unit}`)
      : '',
    event.outputQuantity != null
      ? pill('Khối lượng ra', `${amount(event.outputQuantity)} ${unit}`)
      : '',
    ratio != null
      ? pill(
          'Tỷ lệ thu hồi',
          `${(ratio * 100).toFixed((ratio * 100) % 1 === 0 ? 0 : 1)}%`,
        )
      : '',
    ...paramsOf(event).map(([key, value]) => pill(key, value)),
  );
  const person = personFor(event.operator ?? '');
  const media = event.media ?? [];

  return (
    `<div class="detail" id="n-${esc(id)}">` +
    detailHeader(colour, event.title ?? '', owner, backId, iconStep(19)) +
    (event.operator
      ? '<div class="op">' +
        (person
          ? `<img src="/f/people/${esc(person.asset)}" alt="" loading="lazy">`
          : `<span class="badge-ic">${iconPerson(18)}</span>`) +
        `<div><div style="font-size:13.5px;font-weight:700">${esc(event.operator)}</div>` +
        (person ? `<div class="r">${esc(person.role)}</div>` : '<div class="r">Người thực hiện</div>') +
        '</div></div>'
      : '') +
    (facts ? `<div class="pill-row" style="margin-top:18px">${facts}</div>` : '') +
    (event.description
      ? `<p style="margin-top:18px;font-size:14px;line-height:1.55">${esc(event.description)}</p>`
      : '') +
    media
      .map(
        (item) =>
          `<div class="shotbox">${image(item, '')}</div>` +
          (item.caption ? `<p class="cap">${esc(item.caption)}</p>` : ''),
      )
      .join('') +
    (!facts && !event.description && media.length === 0
      ? '<p style="margin-top:18px;color:#5A6560">Chưa có chi tiết nào cho công đoạn này.</p>'
      : '') +
    '</div>'
  );
}

function detailHeader(
  colour: string,
  title: string,
  subtitle: string,
  backId: string,
  icon: string,
): string {
  return (
    `<a class="back" href="#n-${esc(backId)}" data-goto="${esc(backId)}">${iconBack(15)}Quay lại</a>` +
    '<div class="detail-head">' +
    `<span class="badge-ic" style="color:${esc(colour)};background:${esc(colour)}14">${icon}</span>` +
    `<div><div class="t">${esc(title)}</div>` +
    (subtitle ? `<div class="s">${esc(subtitle)}</div>` : '') +
    '</div></div>'
  );
}

function originPanel(record: PublicTrace): string {
  const ingredients = record.ingredients ?? [];
  const batchEvents = record.batchEvents ?? [];
  const gallery = byRole(record.media, 'gallery');
  const facility = record.facilityName || 'Nơi sản xuất';
  const steps =
    ingredients.reduce((total, item) => total + (item.processEvents ?? []).length, 0) +
    batchEvents.length;

  const details = join(
    ...batchEvents.map((event, index) =>
      stepDetail(`b${index}`, event, facility, '#17352A', 'p'),
    ),
    ...ingredients.flatMap((item, column) => {
      const colour = accents[column % accents.length];
      const area = first(item.media, 'area_map');
      const photos = (item.media ?? []).filter((media) => media.role !== 'area_map');
      const events = item.processEvents ?? [];
      const detail =
        `<div class="detail" id="n-i${column}">` +
        detailHeader(colour, item.name ?? '', item.origin ?? '', 'p', ingredientIcon(column, 19)) +
        (area ? `<div class="shotbox" style="max-height:200px">${image(area, '')}</div>` : '') +
        (item.summary
          ? `<p style="margin-top:14px;font-size:14px;line-height:1.5">${esc(item.summary)}</p>`
          : '') +
        '<div class="pill-row" style="margin-top:18px">' +
        pill('Nhà cung cấp', item.supplier ?? '') +
        pill('Thu hoạch', item.harvestDate ?? '') +
        pill('Nhập kho', item.receivedDate ?? '') +
        '</div>' +
        strip(photos) +
        `<div style="margin-top:20px">${heading('Công đoạn')}</div>` +
        (events.length === 0
          ? '<p style="color:#5A6560;margin-top:12px">Chưa có công đoạn nào.</p>'
          : events
              .map(
                (event, index) =>
                  `<a class="step-row" href="#n-s${column}-${index}" data-goto="s${column}-${index}">` +
                  `<span class="n">${String(index + 1).padStart(2, '0')}</span>` +
                  `<span><span class="t">${esc(event.title ?? '')}</span>` +
                  (event.eventDate ? `<br><span class="s">${esc(event.eventDate)}</span>` : '') +
                  '</span></a>',
              )
              .join('')) +
        '</div>';
      return [
        detail,
        ...events.map((event, index) =>
          stepDetail(`s${column}-${index}`, event, item.name ?? '', colour, `i${column}`),
        ),
      ];
    }),
  );

  const base =
    '<div class="dfl" id="n-p">' +
    eyebrow('Sản phẩm') +
    `<h2 class="title" style="font-size:25px">${esc(record.name)}</h2>` +
    (record.description
      ? `<p style="margin-top:8px;font-size:13.5px;color:#5A6560;line-height:1.5">${esc(record.description)}</p>`
      : '') +
    verifyCard(record) +
    factsRow(record) +
    '<div class="pill-row" style="margin-top:18px">' +
    pill('Nơi sản xuất', record.facilityName ?? '') +
    pill('Thành phần', `${ingredients.length} nguyên liệu`) +
    pill('Công đoạn', `${steps} bước`) +
    '</div>' +
    strip(gallery) +
    '</div>';

  const canvas =
    ingredients.length === 0
      ? '<div class="canvas"><img src="/f/tule-box.webp" alt="" style="width:100%;height:100%;object-fit:contain" loading="lazy"></div>'
      : '<div class="canvas">' +
        treeSvg(record) +
        '<div class="zoom">' +
        '<button type="button" id="zoom-out" aria-label="Thu nhỏ">−</button>' +
        '<button type="button" id="zoom-fit" aria-label="Vừa khung">⤢</button>' +
        '<button type="button" id="zoom-in" aria-label="Phóng to">+</button>' +
        '</div></div>';

  return (
    `<div class="origin">${canvas}` +
    `<div class="scroll-wrap"><div class="panel" id="panel">${details}${base}</div></div></div>`
  );
}

// --------------------------------------------------------------- mục 3

function docCard(item: MediaItem): string {
  const isCert = item.role === 'certificate';
  const title = isCert
    ? item.certType || 'Giấy chứng nhận'
    : item.caption || 'Phiếu kiểm nghiệm';
  const meta = [
    isCert && item.certNumber ? `Số ${item.certNumber}` : '',
    item.validUntil ? `Hiệu lực đến ${item.validUntil}` : '',
    isCert && item.caption ? item.caption : '',
  ]
    .filter(Boolean)
    .join('  ·  ');

  const picture =
    item.kind === 'image'
      ? image(item, '')
      : '<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#5A6560" stroke-width="1.6">' +
        '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/></svg>';

  return (
    `<a class="doc" href="${esc(item.url)}" target="_blank" rel="noopener">` +
    `<div class="pic">${picture}</div>` +
    '<div class="meta">' +
    `<div class="n">${isCert ? iconAward(17) : iconFlask(17)}${esc(title)}</div>` +
    (meta ? `<p class="m">${esc(meta)}</p>` : '') +
    `<p class="open">Xem cỡ đầy đủ${iconOpen(14)}</p>` +
    '</div></a>'
  );
}

function qualityPanel(record: PublicTrace): string {
  const certificates = byRole(record.media, 'certificate');
  const reports = byRole(record.media, 'lab_report');
  if (certificates.length === 0 && reports.length === 0) {
    return '<div class="empty">Chưa có giấy chứng nhận hay phiếu kiểm nghiệm.</div>';
  }
  return join(
    certificates.length
      ? `<div>${heading('Giấy chứng nhận')}<div class="docs">${certificates.map(docCard).join('')}</div></div>`
      : '',
    reports.length
      ? `<div style="margin-top:28px">${heading('Phiếu kiểm nghiệm')}<div class="docs">${reports.map(docCard).join('')}</div></div>`
      : '',
  );
}

// ------------------------------------------------------------ dải cuối

function integrityBar(record: PublicTrace): string {
  const integrity = record.integrity ?? {};
  const chain = integrity.chain ?? {};
  const verified = integrity.status === 'VERIFIED';
  const txShort = chain.txHash
    ? `${chain.txHash.slice(0, 10)}…${chain.txHash.slice(-6)}`
    : '';
  const link =
    chain.explorer && chain.txHash
      ? `<a class="link" href="${esc(chain.explorer)}/tx/${esc(chain.txHash)}" target="_blank" rel="noopener">` +
        `Xem giao dịch trên blockchain${iconOpen(14)}</a>`
      : '';

  return (
    '<div class="integrity">' +
    `<span class="ico">${iconShield(18)}</span>` +
    '<div class="lead">' +
    `<b>${verified ? 'Dữ liệu khớp với bản đã công bố' : 'Chưa xác minh được dữ liệu'}</b>` +
    `<span>${verified ? 'Mã băm tính lại trùng với bản ghi lúc công bố.' : 'Bản ghi công bố chưa sẵn sàng.'}</span>` +
    '</div>' +
    (integrity.version
      ? `<div class="f">Phiên bản<b>v${esc(integrity.version)}</b></div>`
      : '') +
    (integrity.publishedAt
      ? `<div class="f">Công bố lúc<b>${esc(stamp(integrity.publishedAt))}</b></div>`
      : '') +
    (txShort ? `<div class="f">Hash giao dịch<b class="tx">${esc(txShort)}</b></div>` : '') +
    link +
    '</div>'
  );
}

// ----------------------------------------------------------------- trang

export function renderTrace(record: PublicTrace, tab: TabName, origin: string): string {
  const cover = first(record.media, 'cover');
  const tabs =
    '<nav class="tabs">' +
    TABS.map((item) => {
      const href = item.slug ? `?tab=${item.slug}` : '?';
      const badge =
        item.name === 'quality'
          ? byRole(record.media, 'certificate').length + byRole(record.media, 'lab_report').length
          : 0;
      return (
        `<a href="${href}" data-tab="${item.name}"${item.name === tab ? ' aria-current="page"' : ''}>` +
        item.icon(16) +
        `<span class="full">${esc(item.label)}</span><span class="short">${esc(item.short)}</span>` +
        (badge ? `<span class="badge">${badge}</span>` : '') +
        '</a>'
      );
    }).join('') +
    '</nav>';

  const panel = (name: TabName, content: string) =>
    `<section data-panel="${name}"${name === tab ? '' : ' hidden'}>${content}</section>`;

  const body =
    '<main class="wrap">' +
    tabs +
    panel('general', generalPanel(record)) +
    panel('origin', originPanel(record)) +
    panel('quality', qualityPanel(record)) +
    integrityBar(record) +
    '</main>';

  return shell({
    title: `${record.name} · Lô ${record.code} | Tú Lệ Trace`,
    description:
      record.description?.slice(0, 180) ||
      `Hồ sơ truy xuất nguồn gốc lô ${record.code} của Tú Lệ Smart Breakfast.`,
    image: cover ? `${origin}${cover.url}` : undefined,
    canonical: `${origin}/t/${encodeURIComponent(record.code)}`,
    code: record.code,
    body,
    preload: cover ? [cover.url] : [],
  });
}
