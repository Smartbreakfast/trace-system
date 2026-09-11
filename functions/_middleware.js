// Định tuyến cho bản chạy trên Cloudflare Pages.
//
// Ba nhóm đường dẫn, ba cách xử lý:
//
//   /api/*          → hàm chuyển tiếp về Worker (functions/api).
//   /  và  /t/*     → trang tra cứu do Worker dựng sẵn thành HTML. Trước đây
//                     chỗ này trả index.html của Flutter, và người quét mã
//                     phải tải 3,8MB engine trước khi thấy chữ nào.
//   /admin, /admin/*→ vẫn là ứng dụng Flutter: màn làm việc mỗi ngày, tải một
//                     lần rồi nằm trong cache, không ai quét QR vào đây.
//
// Không dùng file _redirects cho việc này: cùng thư mục build được deploy cho
// cả Worker lẫn Pages, mà Workers Static Assets từ chối mọi luật trỏ tới
// /index.html vì cho rằng sẽ lặp vô hạn.
const ORIGIN = 'https://tule-trace.sontm.workers.dev';

/** Trang do Worker dựng: trang chủ và hồ sơ từng lô. */
function isRendered(pathname) {
  return pathname === '/' || pathname.startsWith('/t/');
}

export async function onRequest(context) {
  const url = new URL(context.request.url);
  if (url.pathname.startsWith('/api/')) return context.next();
  if (isRendered(url.pathname)) {
    const target = new URL(url.pathname + url.search, ORIGIN);
    return fetch(new Request(target, context.request));
  }
  return context.env.ASSETS.fetch(new URL('/index.html', url));
}
