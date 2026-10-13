# Xoá hẳn khỏi R2 bốn tấm ảnh bao bì của dự án riêng đã từng dùng cho lô demo
# thịt trâu. Bản ghi media đã xoá và bản công bố mới (phiên bản 3) không còn trỏ
# tới chúng, nhưng file vẫn nằm lại trong R2 vì hai bản công bố cũ còn nhắc tên
# khoá, nên worker không tự xoá.
#
# Chạy bằng tay vì wrangler cần đăng nhập: trong phiên Claude không có TTY để
# mở trình duyệt xác thực.
#
#     cd C:\Users\sontm\coded\com-tule\worker
#     ..\tools\xoa-anh-bao-bi-cu.ps1
#
# Sau khi xoá: ảnh của hai bản công bố cũ (phiên bản 1 và 2 của TB-2026-001/002/
# 003) không hiện được nữa trong màn xem lại bản cũ. Mã băm vẫn đúng và kiểm
# chứng chuỗi vẫn chạy bình thường, chỉ là không dựng lại được ảnh của bản cũ.

$keys = @(
  '1bf5f603db5c1eb3112acf5fcb631701ce44b68a94fddcca3f553c9538d0b479',
  '316510edabbced3b3974d16b58473bc958215086b7143128a903b29dd2b0b3ca',
  '932d6177618d42df97bcb759b4ba04d3b9b4fbb5f4118b27120c10978597a724',
  '95218fd1388186e7397eb6f5dd7d05890ad7a638aed022f84530001e9c5b5661'
)

foreach ($k in $keys) {
  npx wrangler r2 object delete "tule-trace-media/media/$k.jpg" --remote
}
