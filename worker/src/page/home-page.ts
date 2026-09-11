/// Trang chủ khi chưa tra cứu, và trang báo không tìm thấy mã.

import { esc, eyebrow, heading } from './html';
import { shell } from './shell';
import type { BatchRef } from './types';

function sampleList(samples: BatchRef[]): string {
  if (samples.length === 0) return '';
  return (
    '<div class="hr"></div>' +
    eyebrow('Lô đã công bố') +
    '<div class="samples">' +
    samples
      .map(
        (item) =>
          `<a href="/t/${encodeURIComponent(String(item.code))}">` +
          `<span><span class="c">${esc(item.code)}</span>` +
          `<span class="s">${esc(item.name)}${item.productionDate ? `  ·  SX ${esc(item.productionDate)}` : ''}</span></span>` +
          '<span aria-hidden="true">›</span></a>',
      )
      .join('') +
    '</div>'
  );
}

export function renderHome(samples: BatchRef[], origin: string, error = ''): string {
  const body =
    '<main class="wrap"><div class="home">' +
    '<div class="hero"><img src="/f/tule-box.webp" alt="Hộp Tú Lệ Smart Breakfast" fetchpriority="high" decoding="async"></div>' +
    '<div class="side">' +
    '<div class="cover"><img src="/f/tule-products.webp" alt="Sản phẩm Tú Lệ Smart Breakfast" loading="lazy" decoding="async"></div>' +
    '<h1 class="title" style="font-size:24px;margin:0">Tra cứu một lô sản phẩm</h1>' +
    '<p style="color:#5A6560;margin:8px 0 0">Quét mã QR trên bao bì, hoặc nhập mã lô.</p>' +
    sampleList(samples) +
    '</div></div></main>';

  return shell({
    title: 'Tú Lệ Trace | Truy xuất nguồn gốc',
    description:
      'Truy xuất nguồn gốc bột ngũ cốc Tú Lệ Smart Breakfast: bốn nguyên liệu bản địa, từng công đoạn và mã băm kiểm chứng dữ liệu.',
    canonical: `${origin}/`,
    body,
    error,
  });
}

export function renderNotFound(code: string, samples: BatchRef[], origin: string): string {
  const suggestion = samples[0];
  const body =
    '<main class="wrap">' +
    '<div class="notice">' +
    `<h2>Không tìm thấy mã ${esc(code)}</h2>` +
    '<p>Mã thường có dạng TL-2026-001. Kiểm tra lại mã in trên bao bì.</p>' +
    (suggestion
      ? `<a href="/t/${encodeURIComponent(String(suggestion.code))}">Xem một lô đã công bố</a>`
      : '') +
    '</div>' +
    (samples.length
      ? `<div style="margin-top:26px;max-width:560px">${heading('Lô đã công bố')}` +
        '<div class="samples" style="margin-top:12px">' +
        samples
          .map(
            (item) =>
              `<a href="/t/${encodeURIComponent(String(item.code))}">` +
              `<span><span class="c">${esc(item.code)}</span>` +
              `<span class="s">${esc(item.name)}</span></span><span aria-hidden="true">›</span></a>`,
          )
          .join('') +
        '</div></div>'
      : '') +
    '</main>';

  return shell({
    title: `Không tìm thấy mã ${code} | Tú Lệ Trace`,
    description: 'Mã truy xuất không có trong hệ thống Tú Lệ Trace.',
    canonical: `${origin}/`,
    code,
    body,
  });
}
