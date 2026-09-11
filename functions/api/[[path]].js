// Chuyển tiếp mọi lời gọi /api/* về Worker đang giữ dữ liệu.
//
// Vì sao không bê cả hệ thống sang Pages: tên miền nằm ở một tài khoản
// Cloudflare khác, mà Workers Custom Domain đòi zone phải cùng tài khoản.
// Pages thì cho phép gắn subdomain của zone thuộc tài khoản khác, nên Pages
// đứng ra nhận tên miền, còn D1, R2, secret và cron trigger vẫn ở nguyên chỗ
// cũ trong Worker. Chỉ lời gọi API đi thêm một chặng; toàn bộ file tĩnh do
// Pages phục vụ thẳng.
const ORIGIN = 'https://tule-trace.sontm.workers.dev';

export async function onRequest({ request }) {
  const url = new URL(request.url);
  const target = new URL(url.pathname + url.search, ORIGIN);
  // Dựng lại Request từ bản gốc để giữ nguyên method, header và body, kể cả
  // multipart lúc tải ảnh và header Range lúc tua video.
  return fetch(new Request(target, request));
}
