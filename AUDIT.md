# Audit Tú Lệ Trace

Rà soát toàn bộ source ngày 06.09.2026 cho sản phẩm cố định là bột ngũ cốc
**Tú Lệ Smart Breakfast**. Phần lớn ghi chú tập trung vào trải nghiệm sử dụng,
vì đó là chỗ hổng nặng nhất: giao diện trông đã xong nhưng phần lớn chưa nối
với dữ liệu thật.

Trạng thái: mục có `[đã sửa]` đã làm trong lần này, mục `[còn lại]` là việc
tiếp theo.

## Nhóm 1. Những chỗ khiến sản phẩm không dùng được thật

### 1.1 Không có QR, không có URL cho từng lô `[đã sửa]`

Toàn app điều hướng bằng một biến `bool management` trong `main.dart`. Hệ quả:
không có đường dẫn riêng cho mỗi lô, nên **không thể in QR** dù QR là toàn bộ
lý do sản phẩm tồn tại. Chia sẻ liên kết không được, nút back của trình duyệt
thoát thẳng khỏi ứng dụng.

Đã thay bằng `go_router` với `/`, `/t/:code`, `/admin`. Thêm `TraceQrCard` sinh
mã QR trỏ đúng liên kết lô, kèm nút sao chép, hiện ngay trong hộp thoại sau khi
công bố và trong mục Tính toàn vẹn.

### 1.2 Ô tra cứu là giả `[đã sửa]`

`TraceSearch.search()` chỉ so chuỗi với `'TL-2026-001'` rồi in một câu thông
báo. Nhập mã khác không gọi API, không đổi nội dung bên dưới.

Giờ ô tra cứu chuẩn hoá mã (bỏ khoảng trắng, viết hoa), kiểm tra độ dài, rồi
điều hướng sang `/t/:code` để tải hồ sơ thật.

### 1.3 Panel kiểm chứng in cứng một hash bịa `[đã sửa]`

`IntegrityPanel` hiển thị nguyên văn `'SHA-256  8d4a…f91c'` bất kể dữ liệu.
Phần quan trọng nhất của sản phẩm lại là phần duy nhất được bịa ra, trong khi
API đã trả `integrity.sha256` thật.

Bước 6 trong luồng hash của PROJECT_PLAN cũng chưa tồn tại: không có chỗ nào
tính lại hash để so sánh. Đã thêm `GET /api/public/traces/:code/verify`, backend
tính lại SHA-256 từ dữ liệu hiện tại rồi đối chiếu snapshot, trả
`VERIFIED | MISMATCH | NOT_PUBLISHED`. UI hiển thị đúng ba trạng thái này, kèm
hash rút gọn có nút copy, số phiên bản và thời điểm công bố.

### 1.4 Lỗi API bị nuốt và thay bằng dữ liệu mẫu `[đã sửa]`

```dart
} catch (_) {
  if (mounted) setState(() => connected = false);
}
```

Khi backend chết, khách quét QR vẫn thấy một hồ sơ đầy đủ, đẹp đẽ, hoàn toàn
bịa, chỉ khác một huy hiệu nhỏ ghi "MOCK DATA". Với sản phẩm bán bằng niềm tin
thì đây là lỗi nặng nhất trong cả repo.

Giờ có bốn trạng thái tách bạch: đang tải (skeleton), sẵn sàng, không tìm thấy
mã, và mất kết nối. Dữ liệu mẫu chỉ hiện khi URL có `?demo=1` và luôn kèm dải
cảnh báo màu cam. Có test chặn hồi quy chuyện này.

### 1.5 Form admin không lưu được thứ admin gõ `[đã sửa]`

Ba trường "Ngày sản xuất", "Hạn sử dụng", "Mô tả sản phẩm" là `const TextField`
không controller, giá trị gõ vào bị vứt đi. `saveAndPublish` gửi lên chuỗi cứng
`'12.08.2026'` và mô tả cứng. Nguyên liệu chỉ tick chọn từ `mock_data`, không
nhập được nhà cung cấp, ngày thu hoạch, ngày nhập kho, dù ba cột đó có sẵn
trong database.

Đã bind toàn bộ trường, thêm `Form` + validator, dùng date picker thay vì bắt
gõ đúng định dạng, và cho soạn nguyên liệu thành bản nháp sửa/xoá được kèm danh
sách công đoạn riêng.

### 1.6 Rail bên trái của Management là hình trang trí `[đã sửa]`

Bốn mục "Tổng quan / Lô sản phẩm / Nguyên liệu / Tính toàn vẹn" đều là
`WorkspaceLink` không có `onTap`, mục đầu hardcode `active: true`. Không có
danh sách lô: admin chỉ tạo lô mới được, không mở lại lô cũ, không biết trong
hệ thống đang có gì.

Đã cho rail chuyển mục thật, thêm `GET /api/admin/product-batches` (kèm số
nguyên liệu, số công đoạn, phiên bản snapshot) và màn danh sách chọn lô để làm
việc. Nút "Chỉnh sửa" trước đây mở hộp thoại ghi "Mock form" nay gọi
`PATCH /api/admin/ingredient-batches/:id` thật, thêm và xoá công đoạn cũng thật.

### 1.7 Địa chỉ API hardcode localhost `[đã sửa]`

`const TraceApi({this.baseUrl = 'http://localhost:3000/api'})`: build production
sẽ gọi vào máy của chính khách hàng. Giờ đọc từ `--dart-define=API_BASE_URL`,
mặc định mới rơi về localhost khi dev.

## Nhóm 2. Lỗi kỹ thuật tìm thấy khi sửa

### 2.1 Tiếng Việt hỏng khi server không khai charset `[đã sửa]`

`package:http` giải mã `response.body` bằng **latin1** nếu header không có
`charset`. NestJS hiện có khai nên chưa lộ, nhưng chỉ cần đổi reverse proxy hay
CDN là "Cốm Tú Lệ" thành ký tự rác. Đã đọc `response.bodyBytes` rồi
`utf8.decode` tường minh.

### 2.2 Canonical JSON chưa canonical `[đã sửa]`

`publish()` hash thẳng `JSON.stringify` của row SQLite, nên thứ tự khoá phụ
thuộc thứ tự cột trong bảng và payload chứa cả `id`, `created_at`. Một lần
`ALTER TABLE` là mọi snapshot cũ hoá MISMATCH dù dữ liệu không đổi.

Đã tách `canonical.ts`: sắp khoá ổn định, chuẩn hoá unicode NFC, và chỉ đưa vào
snapshot những trường thuộc hồ sơ công bố.

### 2.3 Backend trả sai mã lỗi `[đã sửa]`

- Mã không tồn tại trả **200** kèm `{error: 'TRACE_NOT_FOUND'}`, giám sát không
  phân biệt được "sai mã" với "hỏng server". Nay là 404.
- `@Body() body: any` không validate, body rỗng rơi xuống SQLite thành 500
  NOT NULL. `class-validator` đã nằm trong `package.json` từ đầu mà không dùng.
  Nay có DTO và `ValidationPipe`, trả 400 kèm thông báo tiếng Việt.
- Trùng mã lô ném `SQLITE_CONSTRAINT` thành 500. Nay là 409 với câu gợi ý.

### 2.4 Publish không nằm trong transaction `[đã sửa]`

Ba lệnh ghi (`published_snapshots`, `UPDATE status`, `blockchain_outbox`) chạy
rời nhau; lỗi giữa chừng để lại snapshot không có bản ghi outbox. Đã gói vào
`db.transaction`.

### 2.5 Khoá ngoại không được bật `[đã sửa]`

SQLite mặc định tắt `foreign_keys`, nên các khai báo `FOREIGN KEY` trong schema
không có tác dụng. Đã bật pragma và thêm index cho ba đường truy vấn nóng.

## Nhóm 3. Giao diện và khả năng dùng

### 3.1 Vỡ layout trên điện thoại `[đã sửa]`

- `BatchSummary` dùng `Row` cứng với ảnh 175px, tràn ở màn 360px.
- `TraceSearch` khoá `SizedBox(width: 450)`, rộng hơn cả màn hình điện thoại.
- Tiêu đề hero cố định 42px.
- Rail Management tràn 0,75px đúng lúc mục dài nhất được chọn, vì chữ đậm rộng
  hơn chữ thường.

Đã xếp dọc khi hẹp, đổi sang `ConstrainedBox`, cho cỡ chữ hero co theo màn
hình, và thêm test quét ba khổ 360 / 768 / 1440 để chặn hồi quy.

### 3.2 Không có trạng thái tải, lỗi, rỗng `[đã sửa]`

Trước đây chỉ có đúng một trạng thái: nội dung. Đã thêm skeleton giữ đúng nhịp
bố cục (trang không nhảy khi dữ liệu về), màn lỗi có nút thử lại, màn không tìm
thấy có hướng dẫn tìm mã trên bao bì, và màn rỗng cho lô chưa khai nguyên liệu.

### 3.3 Dữ liệu thật bị vứt đi ở tầng model `[đã sửa]`

`Ingredient.fromApi` chỉ lấy `title` của công đoạn, bỏ ngày, mô tả và người
nhập. `supplier`, `harvest_date`, `received_date` có trong database nhưng không
bao giờ hiện ra. Sheet nguyên liệu in cứng `'12.08.2026 · Đã ghi nhận'` cho
bước đầu và `'13.08.2026'` cho mọi bước sau, tức là ngày tháng hiển thị cho
khách là bịa.

Đã dựng `ProcessEvent` đầy đủ, hiện nhà cung cấp, ngày thu hoạch, ngày nhập kho
và mốc thời gian thật. Thêm dòng thời gian gộp toàn lô, sắp theo ngày, để khách
không phải mở từng nguyên liệu mới thấy quy trình.

### 3.4 Sheet nguyên liệu tràn màn hình `[đã sửa]`

Là một `Container` cao cố định; lô nhiều công đoạn sẽ tràn và không cuộn được.
Đã đổi sang `DraggableScrollableSheet`. Avatar cũng đang hardcode `Icons.spa`
cho mọi nguyên liệu thay vì dùng `item.icon`.

### 3.5 Tương phản và trợ năng `[đã sửa]`

- `componentOrange` (#D9743B) trên nền trắng chỉ đạt 3,2:1, dưới ngưỡng AA cho
  chữ nhỏ, mà lại đang dùng cho chữ 10-11px. Thêm `brandOrangeText` (#A84B1B,
  5,8:1) cho chữ, giữ màu cũ cho mảng nền và icon lớn.
- `Colors.black45` cho nhãn nhỏ chỉ đạt 3,4:1, đổi sang `brandMuted`.
- Thêm `Semantics` cho thẻ nguyên liệu, huy hiệu toàn vẹn, tab và rail; thêm
  tooltip cho mọi nút chỉ có icon.
- Skeleton tôn trọng `disableAnimations` của hệ điều hành.
- `fontFamily: 'Arial'` hardcode đã bỏ, chuyển sang một `ThemeData` tập trung.

### 3.6 Vỏ web vẫn là template Flutter `[đã sửa]`

`manifest.json` còn nguyên `"name": "com_tule"`, `"description": "A new Flutter
project."` và `theme_color` xanh `#0175C2`. Cài PWA từ QR sẽ ra một icon tên
`com_tule`. Trang cũng không có màn chờ nên vài giây đầu là trang trắng.

Đã đổi manifest sang thương hiệu Tú Lệ, thêm màn chờ HTML nhẹ tự biến mất khi
Flutter vẽ khung đầu tiên, thêm thẻ Open Graph vì liên kết lô hay được chia sẻ
lại.

## Nhóm 4. Đưa lên Cloudflare và hoàn thiện media

Làm sau vòng audit đầu, khi chốt hướng chạy toàn bộ trên Cloudflare.

### 4.1 Backend chuyển sang Workers + D1 + R2 `[đã sửa]`

NestJS + `better-sqlite3` chỉ chạy được trên một server tự quản. Đã port sang
Hono trên Cloudflare Workers, dữ liệu vào D1 (cũng là SQLite nên schema giữ gần
nguyên), file vào R2. Thư mục `backend/` cũ đã bỏ, thay bằng `worker/`.

Worker phục vụ luôn bản build Flutter qua Workers Static Assets, nên web và API
cùng origin. Hai cái được luôn: không còn CORS, và đường dẫn chuyển sang dạng
thật `/t/TL-2026-001` thay vì `/#/t/TL-2026-001`, mã QR nhờ đó gọn hơn.

### 4.2 Ảnh, video và hồ sơ kiểm nghiệm `[đã sửa]`

Trước đây hai nút "Thêm hồ sơ kiểm nghiệm" và "Thêm ảnh / video" chỉ hiện
snackbar, cột `media_url` trong database chưa bao giờ được ghi, và `MediaAsset`
trong PROJECT_PLAN chưa tồn tại.

Giờ có bảng `media_assets` gắn được vào ba cấp: lô, nguyên liệu và từng công
đoạn. Ba vai trò: `cover` (ảnh bìa lô), `lab_report` (hồ sơ kiểm nghiệm, mở
bằng tab mới vì trình duyệt đọc PDF tốt hơn mọi trình xem nhúng) và phần còn
lại vào dải ảnh/video. Explorer hiện ảnh bìa, dải ảnh, video phát tại chỗ, ảnh
theo từng công đoạn trong timeline, và danh sách hồ sơ kiểm nghiệm.

### 4.3 File cũng nằm trong phạm vi kiểm chứng `[đã sửa]`

Khoá R2 là `media/<sha256 của nội dung>.<ext>`, và khoá đó nằm trong snapshot
đem đi băm. Hệ quả: tráo ảnh sau khi công bố làm hash lệch đúng như tráo chữ,
tải lại đúng file cũ thì dùng chung object nên không tốn thêm dung lượng, và
nội dung ứng với một khoá không bao giờ đổi nên cache được vĩnh viễn.

Kiểm tra định dạng đọc chữ ký nhị phân của file chứ không tin content-type do
trình duyệt khai, đuôi file suy từ danh sách trắng chứ không lấy từ tên người
dùng đặt, và file phục vụ kèm `Content-Security-Policy: sandbox` để không chạy
được như tài liệu cùng origin.

### 4.4 Đóng API quản trị `[đã sửa]`

`/api/admin/*` từng mở cho cả internet. Chấp nhận được khi chỉ chạy localhost,
nhưng lên Cloudflare thì bất kỳ ai cũng tạo lô giả và đổ file vào R2 của bạn
được, tức là vừa hỏng dữ liệu vừa tốn tiền. Giờ cần
`Authorization: Bearer <ADMIN_TOKEN>`, so token theo thời gian hằng số, và
Management có màn đăng nhập riêng. Token bị thu hồi giữa chừng thì client tự
quay về màn đăng nhập thay vì để admin bấm mãi vào các nút đã hỏng.

## Nhóm 5. Việc còn lại

- **Tài khoản riêng cho từng người vận hành `[còn lại]`.** `ADMIN_TOKEN` hiện là
  một bí mật dùng chung, không truy được ai đã sửa gì. Cột `entered_by` đã có
  sẵn chỗ để ghi khi có tài khoản thật.
- **Blockchain adapter `[còn lại]`.** `blockchain_outbox` vẫn dừng ở
  `PENDING_NETWORK` đúng như kế hoạch, chờ thông tin mạng.
- **Nén ảnh và video phía client `[còn lại]`.** Hiện tải lên nguyên bản, giới
  hạn 30MB. Ảnh 12MP từ điện thoại nên được resize trước khi tải.
- **Trang "Câu chuyện" và "Quy trình" `[còn lại]`.** Hai mục trên navbar vẫn chỉ
  hiện snackbar.
- **Kênh mua hàng `[còn lại]`.** Nút vẫn là placeholder.
- **PostgreSQL `[không còn cần]`.** Kế hoạch ban đầu ghi PostgreSQL; D1 đã đáp
  ứng ở quy mô này và nằm luôn trong cùng nền tảng, nên bỏ khỏi đường đi.

## Chạy và kiểm thử

```bash
# Backend trên Cloudflare, chạy local bằng wrangler
cd worker && npm install
cp .dev.vars.example .dev.vars
npm run db:local && npm run db:seed:local
npm run dev
npm run test:api    # auth, mã lỗi HTTP, upload R2, Range, media vào snapshot, SPA fallback

# Frontend
flutter test
flutter build web --release
```

Xem `DEPLOY.md` cho các bước tạo D1, R2, đặt `ADMIN_TOKEN` và deploy thật.

Canonical JSON đã đổi so với bản NestJS đầu tiên nên hash cũ không còn khớp.
Database D1 là mới hoàn toàn, chạy `npm run db:local` rồi công bố lại từng lô.
