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
| Số lượt truy xuất | *(chưa có — xem mục 3)* | Thống kê truy cập Cloudflare |
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

## 3. Số lượt truy xuất lấy ở đâu

Hệ thống không tự đếm lượt xem: không ghi nhật ký truy cập, không đặt mã theo
dõi người dùng. Đây là chủ ý, và là thứ sẽ khai trong hồ sơ App Store rằng ứng
dụng không thu thập dữ liệu nào. Vì vậy số lượt truy cập chỉ có ở lớp hạ tầng
Cloudflare, lấy theo một trong ba cách:

1. **Đọc trên bảng điều khiển** (nhanh nhất, không cần làm gì thêm):
   dash.cloudflare.com → Workers & Pages → `tule-trace` → tab **Metrics**. Chọn
   khoảng 30 ngày, lấy con số *Requests*. Lưu ý số đó gồm cả ảnh và tệp tĩnh,
   nên lớn hơn số lượt xem hồ sơ; muốn sát hơn thì đọc dòng của đường dẫn
   `/t/*`.
2. **Mở Web Analytics** cho tên miền `trace.smartbreakfast.store` nếu muốn có số
   lượt xem trang theo ngày, chuẩn hơn để trích vào báo cáo.
3. **Tạo API token** (quyền *Account Analytics: Read*) rồi đưa cho tôi, tôi lấy
   số theo ngày bằng API và ghi kèm cách kiểm lại như các chỉ số khác. Token
   đăng nhập sẵn của công cụ dòng lệnh không có quyền đọc phần thống kê.

Nếu muốn **hệ thống tự đếm** từ nay về sau thì làm được: thêm một bộ đếm lượt mở
hồ sơ theo từng lô, chỉ đếm số, không ghi ai xem. Nhưng số sẽ bắt đầu từ ngày
bật, nên không dùng cho báo cáo lần này được.

## 4. Cách lấy lại các con số này

| Việc | Cách làm |
|---|---|
| Lô đã công bố và trạng thái từng lô | `https://trace.smartbreakfast.store/api/public/batches?limit=20` |
| Kiểm chứng một lô, kèm mã giao dịch | `https://trace.smartbreakfast.store/api/public/traces/TL-2026-004/verify` |
| Số lô đã neo, gas, phí, độ trễ | `node worker/scripts/do-chi-so-chuoi.mjs` |
| Tổng số sản phẩm, lô, nguyên liệu, công đoạn, tệp | `GET /api/admin/summary` (cần token quản trị) |
| Đánh giá: tổng, trung bình, tách theo nguồn | `GET /api/admin/ratings` (cần token quản trị) |
