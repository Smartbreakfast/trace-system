# Số liệu hệ thống Tú Lệ Trace cho báo cáo

Chốt ngày **21/10/2026**. Mọi con số dưới đây đọc thẳng từ hệ thống đang chạy;
mục 4 ghi cách lấy lại để kiểm.

## 1. Bảng chỉ số hệ thống

| Chỉ số | Kết quả | Nguồn số liệu |
|---|---|---|
| Số khách hàng (cơ sở sản xuất) | 2 cơ sở: Trung tâm Phát triển và Giao dịch Công nghệ thành phố Hà Nội (Tú Lệ Smart Breakfast) và Cơ sở chế biến vùng cao (thịt trâu gác bếp), mỗi bên 4 lô | Trang truy xuất công khai, 21/10/2026 |
| Số sản phẩm đưa lên hệ thống | 9 mã trong danh mục: 4 mã thành phẩm (bột Tú Lệ dạng hộp, gói 30 g, hộp quà; thịt trâu gác bếp) và 5 mã nguyên liệu (cốm Tú Lệ, lạc đỏ Lục Yên, chuối tiêu xanh Bảo Thắng, khoai môn Lục Yên, thịt trâu tươi) | Danh mục sản phẩm trên hệ thống, 21/10/2026 |
| Số lô đưa lên hệ thống | 12 lô, trong đó **8 lô đã công bố** (7 lô thành phẩm, 1 lô nguyên liệu) và 4 lô nguyên liệu còn ở trạng thái nháp | Trang truy xuất công khai, 21/10/2026 |
| Số lô đã neo lên blockchain | **8 lô**, cả 8 đều ĐÃ XÁC MINH và có giao dịch đã được xác nhận trên mạng VBSN (chainId 84001) | Đo trên mạng VBSN, 21/10/2026 |
| Số nguyên liệu đã khai báo | 19 lô nguyên liệu, 73 công đoạn, 128 tệp ảnh và tài liệu | Thống kê quản trị, 21/10/2026 |

Hai chỗ khác với bản nháp đang có trong báo cáo:

- **Số lô đã neo là 8, không phải 6.** Con số 6 là do trang chủ chỉ liệt kê 6 lô
  gần nhất. Hai lô `TL-2026-001` và `TL-2026-002` cũng đã neo, khối 5.783.872 và
  5.783.848.
- **"2 sản phẩm" nên viết rõ là 2 dòng sản phẩm** (bột ngũ cốc Tú Lệ và thịt
  trâu gác bếp). Danh mục thật có 9 mã, vì mỗi quy cách đóng gói và mỗi nguyên
  liệu đều là một mã riêng để truy xuất ngược được.

## 2. Bảng người sử dụng

| Chỉ số | Kết quả | Nguồn số liệu |
|---|---|---|
| Số người sử dụng | **1 tài khoản quản trị** (dùng chung cho hai cơ sở nhập liệu). Hệ thống cố ý không bắt người mua đăng ký: quét mã là xem được ngay, không cần tài khoản | Hệ thống tài khoản quản trị, 21/10/2026 |
| Số người mua tham gia khảo sát | *(lấy từ phiếu khảo sát của nhóm, hệ thống không giữ số này)* | Phiếu khảo sát |
| Số lượt truy xuất | **1.806 lượt trong 30 ngày** (21/09 – 21/10/2026), 0 lỗi, trên tên miền `trace.smartbreakfast.store`. Trong 24 giờ gần nhất: 130 lượt. Xem thêm cảnh báo ở mục 3 về việc phần lớn là lượt chạy thử của nhóm | Cloudflare Pages Metrics, dự án `tule-trace`, đọc ngày 21/10/2026 |
| Đánh giá của người sử dụng | 27 lượt, trung bình 4,56/5 — **nhưng 26 trong số đó là dữ liệu dựng sẵn để thử giao diện**, chỉ 1 lượt là người thật gửi. Xem cảnh báo bên dưới | Mục đánh giá trên trang truy xuất, 21/10/2026 |

Điểm trung bình theo từng lô (gồm cả dữ liệu dựng sẵn): TL-2026-003: 4,67 ·
TL-2026-004: 4,43 · TB-2026-001: 4,4 · TB-2026-002: 4,6 · TB-2026-003: 4,75.

> **Cảnh báo.** Chừng nào chưa thay bằng số liệu khảo sát thật thì **không được
> viết 27 lượt đánh giá, 4,56/5 vào báo cáo như ý kiến khách hàng**. Đó là dữ
> liệu dựng sẵn, mang nhãn nguồn `DEMO` trong cơ sở dữ liệu, dựng ra để thử giao
> diện và chụp màn hình. Ban giám khảo hỏi "ai đánh giá, phiếu đâu" mà không có
> thì mất điểm trung thực nặng hơn là cái lợi của con số.
>
> Khi có kết quả khảo sát thật, chạy hai lệnh rồi lấy lại số ở mục 4:
>
> ```
> python tools/seed_ratings.py --clear --production
> python tools/nhap_khao_sat.py phieu.csv --production
> ```

## 3. Số lượt truy xuất: con số và chỗ phải cẩn thận

Hệ thống không tự đếm lượt xem: không ghi nhật ký truy cập, không đặt mã theo
dõi người dùng. Đây là chủ ý, và là thứ sẽ khai trong hồ sơ App Store rằng ứng
dụng không thu thập dữ liệu nào. Số lượt truy cập vì vậy chỉ có ở lớp hạ tầng
Cloudflare. Đọc ngày 21/10/2026:

| Chỉ số | 30 ngày | 24 giờ |
|---|---|---|
| Lượt gọi tới trang truy xuất và API trên tên miền chính (Cloudflare Pages) | 1.806, 0 lỗi | 130 |
| Lượt chạy của máy chủ xử lý dữ liệu (Cloudflare Worker), gồm cả 4.320 lượt tự chạy theo lịch 10 phút/lần để neo chuỗi | 6.490, 0 lỗi | 327 |
| Lượt gọi sang RPC của mạng VBSN | 587 | — |

> **Chỗ phải cẩn thận.** Con số 1.806 là lưu lượng của 30 ngày hệ thống đang
> được xây dựng và chạy thử, nên phần lớn là lượt mở của nhóm phát triển, không
> phải lượt quét mã của người mua. Viết vào báo cáo thì nên ghi đúng là "lượt
> truy cập hệ thống trong 30 ngày vận hành thử", đừng gọi là lượt truy xuất của
> khách hàng. Muốn có con số sạch thì tính từ ngày phát mã QR thật ra thị
> trường.

Ba cách lấy lại hoặc làm cho số sạch hơn:

1. **Đọc lại trên bảng điều khiển**: dash.cloudflare.com → Workers & Pages →
   `tule-trace` (dự án Pages) → tab **Metrics** → chọn *Last 30 days*. Con số
   *Requests* chính là 1.806 ở trên. Trang này chụp màn hình làm minh chứng
   được.
2. **Bật Web Analytics** cho `trace.smartbreakfast.store` nếu muốn số lượt xem
   trang theo ngày và theo đường dẫn, tách được lô nào hay được quét nhất.
3. **Hệ thống tự đếm**: thêm bộ đếm lượt mở hồ sơ theo từng lô, chỉ đếm số,
   không ghi ai xem. Số bắt đầu từ ngày bật nên không dùng cho báo cáo lần này,
   nhưng từ lúc phát QR thật thì đây là nguồn sạch nhất.

## 4. Cách lấy lại các con số này

| Việc | Cách làm |
|---|---|
| Lô đã công bố và trạng thái từng lô | `https://trace.smartbreakfast.store/api/public/batches?limit=20` |
| Kiểm chứng một lô, kèm mã giao dịch | `https://trace.smartbreakfast.store/api/public/traces/TL-2026-004/verify` |
| Số lô đã neo, gas, phí, độ trễ | `node worker/scripts/do-chi-so-chuoi.mjs` |
| Tổng số sản phẩm, lô, nguyên liệu, công đoạn, tệp | `GET /api/admin/summary` (cần token quản trị) |
| Đánh giá: tổng, trung bình, tách theo nguồn | `GET /api/admin/ratings` (cần token quản trị) |
