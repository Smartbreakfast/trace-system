# Tú Lệ Trace

## Mục tiêu

Web/PWA cho khách hàng truy xuất lô bột ngũ cốc Tú Lệ Smart Breakfast bằng QR. Admin nhập thông tin sản phẩm, bốn nguyên liệu và các công đoạn; hệ thống ghi nhận snapshot, hash và lịch sử phiên bản.

## Phạm vi MVP

- Public Trace Explorer: QR, thông tin lô thành phẩm, bốn thành phần, timeline, media, kiểm chứng hash và kênh mua hàng.
- Admin Studio: nhập sản phẩm, lô nguyên liệu, công đoạn, media, kiểm nghiệm, ngày sản xuất/hạn sử dụng và công bố.
- Integrity Service: canonical snapshot, SHA-256, lịch sử phiên bản và blockchain outbox.
- Flutter Web/PWA trước; chưa làm native mobile app.

## Giới hạn

Hệ thống không xác thực thông tin admin nhập có đúng ngoài thực tế hay không. Hệ thống chỉ xác minh dữ liệu hiện tại có bị thay đổi so với bản đã ghi nhận hay không. Không xử lý phát hiện QR thật bị sao chép trong MVP.

## Dữ liệu chính

`Product`, `ProductBatch`, `IngredientBatch`, `ProcessEvent`, `MediaAsset`, `TraceCode`, `PublishedSnapshot`, `IntegrityRecord`, `AuditLog`.

Chuỗi liên kết:

```text
QR -> ProductBatch -> 4 IngredientBatch -> ProcessEvent + MediaAsset
```

## Kiến trúc

```text
Flutter Web/PWA  ─┐
                  ├─ Cloudflare Worker (Hono)  ─┬─ D1 (SQLite)  dữ liệu lô
Workers Assets   ─┘                             ├─ R2           ảnh, video, hồ sơ
                                                └─ Hash Service ─ Blockchain Adapter
```

Một Worker phục vụ cả bản build Flutter lẫn `/api/*`, nên trang web và API cùng
một origin: không CORS, và mã QR có đường dẫn sạch `/t/TL-2026-001`.

Blockchain chỉ lưu batch hash/Merkle Root, không lưu ảnh, video hay toàn bộ dữ
liệu. Mạng blockchain sẽ tích hợp sau khi có thông tin từ nhóm.

## Bản đồ và biểu đồ

- **Bản đồ vùng nguyên liệu**: MapLibre GL với vector tile OpenFreeMap, thư viện
  tự host trong `web/vendor/maplibre/`. Vùng nguyên liệu, đường nối và điểm cắm
  là các lớp GeoJSON chồng lên nền bản đồ.
- **Chủ quyền**: nhãn mặt nước và tên nước ép về `name:vi` (Biển Đông, Việt
  Nam), thêm nhãn Quần đảo Hoàng Sa (Đà Nẵng) và Quần đảo Trường Sa (Khánh
  Hòa). Khung nhìn toàn quốc và giới hạn kéo đều phải ôm trọn hai quần đảo.
- **Bản đồ dự phòng**: khi không phải web hoặc tile không tải nổi, dùng bản vẽ
  bằng `CustomPainter` từ dữ liệu Natural Earth nhúng sẵn, phóng kéo được và có
  bản đồ nhỏ ở góc bám theo khung nhìn.
  Vùng nguyên liệu tô theo bán kính nhà sản xuất khai, hoặc theo nguyên ranh
  giới tỉnh khi hồ sơ mới chỉ biết tới cấp tỉnh.
- **Panel kết quả**: bản đồ bên trái, kết quả tra cứu bên phải. Mặc định là hồ
  sơ lô kèm danh sách thành phần; chạm một thành phần thì bản đồ bay tới vùng
  đó và panel đổi sang hồ sơ thành phần, gồm nhà cung cấp, mốc thời gian, ảnh
  và từng công đoạn.

Toạ độ nằm trong snapshot đem đi băm, nên dời điểm sau khi công bố bị bắt như
sửa chữ.

## Media

Ảnh, video và hồ sơ kiểm nghiệm gắn được vào ba cấp: lô thành phẩm, lô nguyên
liệu và từng công đoạn. File nằm trong R2 với khoá là sha256 của chính nội dung,
và khoá đó đi vào snapshot, nên tráo ảnh sau khi công bố cũng làm hash lệch
đúng như tráo chữ.

## Cấu trúc UI component

- `lib/ui/tule_theme.dart`: bảng màu, `ThemeData`, breakpoint và kiểu chữ dùng chung.
- `lib/ui/shared_components.dart`: `TuleWebFrame`, brand, huy hiệu toàn vẹn, tab, hash copy được.
- `lib/ui/async_states.dart`: skeleton lúc tải và màn thông báo lỗi/rỗng.
- `lib/ui/media_components.dart`: thumbnail, dải media, trình xem ảnh và video.
- `lib/ui/media_manager.dart`: khối tải lên và xoá media phía quản trị.
- `lib/ui/trace_components.dart`: navbar kèm ô tra cứu, thẻ nhập mã, bảng kiểm
  chứng, hồ sơ nguyên liệu và thẻ QR.
- `lib/ui/sourcing_section.dart`: khối bản đồ và panel kết quả.
- `lib/ui/management_components.dart`: rail, thẻ số liệu, dòng lô, ô chọn ngày,
  form thông tin lô, thẻ nguyên liệu mở được và các hộp thoại nhập liệu.
- `lib/ui/admin_login.dart`: cửa vào Management.
- `ExplorerPage`: trải nghiệm công khai theo đường dẫn `/t/:code`.
- `ManagementPage`: hai mục (tổng quan, lô sản phẩm); mở một lô là vào màn làm
  việc chứa toàn bộ việc của lô đó.

## Điều hướng

`go_router` với `/`, `/t/:code`, `/admin`, dùng đường dẫn thật thay vì hash.
Mỗi lô có một URL riêng vì đó chính là nội dung in vào mã QR trên bao bì.

`/` dừng ở thẻ nhập mã và không gọi API: hồ sơ chỉ hiện sau khi quét QR hoặc
nhập mã, không bày sẵn một lô mặc định.

## Bảo mật

`/api/admin/*` yêu cầu `Authorization: Bearer <ADMIN_TOKEN>`. Token là secret
của Worker, người vận hành nhập ở `/admin` và trình duyệt giữ lại giữa các phiên.

## Luồng hash

1. Admin công bố lô.
2. Worker dựng canonical JSON snapshot (khoá sắp xếp ổn định, unicode NFC),
   bao gồm cả khoá và hash của mọi file media.
3. Worker tính SHA-256 và lưu snapshot kèm số phiên bản.
4. Bản ghi vào blockchain outbox với trạng thái `PENDING_NETWORK`.
5. Worker sau này gom batch và gửi transaction.
6. `GET /api/public/traces/:code/verify` tính lại hash từ dữ liệu hiện tại và
   trả `VERIFIED`, `MISMATCH` hoặc `NOT_PUBLISHED`; explorer hiển thị đúng
   trạng thái đó.

## Trạng thái phát triển

- [x] Explorer công khai đọc dữ liệu thật từ API.
- [x] Định tuyến theo mã lô và sinh mã QR cho bao bì.
- [x] Trạng thái tải, lỗi và không tìm thấy tách bạch, không rơi ngầm về dữ liệu mẫu.
- [x] Management: một luồng duy nhất theo lô — thông tin, ảnh, nguyên liệu,
      công đoạn và công bố nằm chung một màn.
- [x] Kiểm chứng hash hai chiều (tính lại và đối chiếu snapshot).
- [x] Ảnh, video và hồ sơ kiểm nghiệm lưu trên R2, nằm trong phạm vi kiểm chứng.
- [x] Xác thực cho toàn bộ API quản trị.
- [x] Backend trên Cloudflare Workers + D1, deploy một lệnh.
- [x] Bản đồ vùng nguyên liệu và biểu đồ hành trình trên trang công khai.
- [ ] Tài khoản riêng cho từng người vận hành thay cho một token dùng chung.
- [ ] Smart contract và relayer sau khi nhận network.
- [ ] Trang Câu chuyện, trang Quy trình và kênh mua hàng.
