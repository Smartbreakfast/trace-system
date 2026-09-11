/// Khung chung của trang tra cứu: thẻ head, thanh điều hướng, ô tra cứu,
/// chân trang. Bản Flutter cũ dựng những thứ này bằng widget; ở đây chúng là
/// HTML sinh sẵn, nên nội dung có mặt ngay ở byte đầu tiên.

import { esc, join } from './html';
import { pageCss } from './theme';
import { clientJs } from './client';

const LANDING = 'https://smartbreakfast.store';

const MENU: { label: string; path: string }[] = [
  { label: 'Trang chủ', path: '/' },
  { label: 'Sản phẩm', path: '/san-pham' },
  { label: 'Quy trình', path: '/quy-trinh' },
  { label: 'Công nghệ', path: '/cong-nghe' },
  { label: 'Truy xuất nguồn gốc', path: '' },
  { label: 'Thành tựu', path: '/thanh-tuu' },
  { label: 'Liên hệ', path: '/lien-he' },
];

function header(): string {
  const links = MENU.map((item) =>
    item.path === ''
      ? `<a href="/" aria-current="page">${esc(item.label)}</a>`
      : `<a href="${LANDING}${item.path}">${esc(item.label)}</a>`,
  );
  return (
    '<header class="hdr" id="hdr">' +
    '<div class="hdr-in">' +
    `<a class="brand" href="/"><img src="/f/logo-mark.png" width="40" height="40" alt="">` +
    '<span><b>Tú Lệ</b><span>SMART BREAKFAST</span></span></a>' +
    `<nav class="nav">${links.join('')}</nav>` +
    `<a class="cta" href="${LANDING}/lien-he#dat-hang">Đặt hàng</a>` +
    '<button class="menu-btn" id="menu-btn" aria-expanded="false" aria-controls="m-nav">Menu</button>' +
    '</div>' +
    `<nav class="m-nav" id="m-nav">${links.join('')}</nav>` +
    '</header>'
  );
}

/** Ô tra cứu. Gửi bằng form thật nên không có JS vẫn tra được. */
export function searchBand(code = '', error = ''): string {
  return (
    '<div class="search-band"><div class="search">' +
    '<form action="/" method="get" id="search-form">' +
    '<button class="qr" type="button" id="qr-btn" hidden aria-label="Quét mã QR trên bao bì">' +
    '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">' +
    '<path d="M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3"/>' +
    '<rect x="8" y="8" width="8" height="8" rx="1"/></svg></button>' +
    '<span class="qr" id="qr-icon" aria-hidden="true">' +
    '<svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">' +
    '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/>' +
    '<rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM20 14v3M14 20h6"/></svg></span>' +
    `<input name="code" id="code" value="${esc(code)}" placeholder="Nhập mã lô, ví dụ TL-2026-001" ` +
    'autocapitalize="characters" autocomplete="off" spellcheck="false" aria-label="Mã lô">' +
    '<button type="submit" aria-label="Tra cứu"><span class="t">Tra cứu</span><span class="i" aria-hidden="true">' +
    '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">' +
    '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg></span></button>' +
    '</form>' +
    (error ? `<p class="err">${esc(error)}</p>` : '') +
    '</div></div>'
  );
}

function footer(): string {
  return (
    '<footer class="ft">' +
    '<span><b>TÚ LỆ TRACE</b></span><span>Truy xuất nguồn gốc</span><span>·</span>' +
    '<span>Minh bạch</span><span>·</span><span>Vì nông sản Việt</span>' +
    '<span style="margin-left:auto">Kết nối giá trị từ những vùng đất lành</span>' +
    '</footer>'
  );
}

export interface ShellOptions {
  title: string;
  description: string;
  body: string;
  /** Ảnh cho thẻ chia sẻ mạng xã hội. */
  image?: string;
  canonical?: string;
  code?: string;
  error?: string;
  /** Ảnh cần tải sớm, thường là ảnh bìa của lô. */
  preload?: string[];
}

export function shell(options: ShellOptions): string {
  const preload = join(
    ...(options.preload ?? []).map(
      (url, index) =>
        `<link rel="preload" as="image" href="${esc(url)}"${index === 0 ? ' fetchpriority="high"' : ''}>`,
    ),
  );
  return (
    '<!doctype html><html lang="vi"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">' +
    `<title>${esc(options.title)}</title>` +
    `<meta name="description" content="${esc(options.description)}">` +
    '<meta name="theme-color" content="#19362B">' +
    `<meta property="og:title" content="${esc(options.title)}">` +
    `<meta property="og:description" content="${esc(options.description)}">` +
    '<meta property="og:type" content="website">' +
    (options.image ? `<meta property="og:image" content="${esc(options.image)}">` : '') +
    (options.canonical ? `<link rel="canonical" href="${esc(options.canonical)}">` : '') +
    '<link rel="icon" href="/favicon.png">' +
    '<link rel="preload" as="font" type="font/woff2" href="/f/BeVietnamPro-Regular.woff2" crossorigin>' +
    '<link rel="preload" as="font" type="font/woff2" href="/f/BeVietnamPro-Bold.woff2" crossorigin>' +
    preload +
    `<style>${pageCss}</style>` +
    '</head><body>' +
    header() +
    searchBand(options.code ?? '', options.error ?? '') +
    options.body +
    footer() +
    `<script>${clientJs}</script>` +
    '</body></html>'
  );
}
