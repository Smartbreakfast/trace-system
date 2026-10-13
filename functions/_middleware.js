// Định tuyến cho bản chạy trên Cloudflare Pages.
//
// Ba nhóm đường dẫn, ba cách xử lý:
//
//   /api/*          → hàm chuyển tiếp về Worker (functions/api).
//   /  và  /t/*     → Flutter Web, để trang chủ và QR dùng cùng một catalog
//                     sản phẩm, bộ chọn sản phẩm và luồng hồ sơ.
//   /admin, /admin/*→ vẫn là ứng dụng Flutter: màn làm việc mỗi ngày, tải một
//                     lần rồi nằm trong cache, không ai quét QR vào đây.
//
// Không dùng file _redirects cho việc này: cùng thư mục build được deploy cho
// cả Worker lẫn Pages, mà Workers Static Assets từ chối mọi luật trỏ tới
// /index.html vì cho rằng sẽ lặp vô hạn.

export async function onRequest(context) {
  const url = new URL(context.request.url);
  if (url.pathname.startsWith('/api/')) return context.next();
  return context.env.ASSETS.fetch(new URL('/index.html', url));
}
