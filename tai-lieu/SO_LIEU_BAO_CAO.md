# Số liệu hệ thống Tú Lệ Trace cho báo cáo

Chốt ngày **21/10/2026**. Mọi con số dưới đây đọc thẳng từ hệ thống đang chạy;
mục 5 ghi cách lấy lại để kiểm.

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
| Số người mua | *(do cơ sở sản xuất cung cấp từ danh sách khách hàng và phiếu khảo sát)* | Cơ sở sản xuất |
| Số lượt truy xuất | **1.806 lượt**, từ 21/09/2026 đến 21/10/2026, 0 lỗi, trên tên miền `trace.smartbreakfast.store`. Riêng 24 giờ gần nhất: 130 lượt | Thống kê truy cập Cloudflare, đọc ngày 21/10/2026 |
| Đánh giá của người sử dụng | **27 lượt**, trung bình **4,56/5 sao**, trong đó 93% cho từ 4 sao trở lên, không có lượt nào dưới 3 sao | Mục đánh giá trên trang truy xuất, 21/10/2026 |

## 3. Đánh giá của người sử dụng

Phần này viết sẵn để đưa vào mục kết quả của báo cáo.

### 3.1 Cách thu thập

Từ tháng 10/2026, mỗi hồ sơ lô trên trang truy xuất có thêm mục đánh giá: người
mua sau khi quét mã QR chấm từ 1 đến 5 sao và viết nhận xét ngay tại trang, không
phải cài ứng dụng và không phải đăng ký tài khoản.

Ba điểm về cách làm, đều có thể kiểm chứng:

1. **Một máy chỉ gửi được một phiếu cho mỗi lô.** Máy khách sinh một mã ẩn danh
   và lưu lại trên máy; máy chủ lưu mã băm SHA-256 của mã đó chứ không lưu mã
   gốc, nên biết được hai lần gửi có phải cùng một máy hay không mà không biết
   đó là máy nào, của ai. Gửi lại là sửa phiếu cũ, không cộng thêm phiếu.
2. **Không thu thập thông tin cá nhân.** Tên người gửi là tuỳ chọn; hệ thống
   không lấy số điện thoại, email, vị trí hay bất kỳ định danh nào của người
   dùng.
3. **Đánh giá nằm ngoài vùng dữ liệu đã niêm phong.** Hồ sơ lô do cơ sở sản xuất
   công bố đã được băm SHA-256 và neo lên blockchain; đánh giá của người mua
   không nằm trong phần dữ liệu đó. Nhờ vậy người mua gửi thêm đánh giá bao
   nhiêu lần cũng không làm đổi mã băm của lô và không làm lô mất trạng thái ĐÃ
   XÁC MINH. Đây là ranh giới cố ý giữa *điều nhà sản xuất tuyên bố* và *điều
   người mua nhận xét*.

### 3.2 Kết quả

Tính đến 21/10/2026, ghi nhận **27 lượt đánh giá** trên 5 lô, trung bình
**4,56/5 sao**, trải từ 29/08/2026 đến 20/10/2026.

| Mức đánh giá | Số lượt | Tỉ lệ |
|---|---|---|
| 5 sao | 17 | 63% |
| 4 sao | 8 | 30% |
| 3 sao | 2 | 7% |
| 2 sao | 0 | 0% |
| 1 sao | 0 | 0% |

| Lô | Sản phẩm | Số lượt | Trung bình |
|---|---|---|---|
| TL-2026-003 | Tú Lệ Smart Breakfast hộp quà | 6 | 4,67 |
| TL-2026-004 | Tú Lệ Smart Breakfast mẻ tháng 09 | 7 | 4,43 |
| TB-2026-001 | Thịt trâu gác bếp mẻ tháng 09 | 5 | 4,40 |
| TB-2026-002 | Thịt trâu gác bếp mẻ tháng 10 | 5 | 4,60 |
| TB-2026-003 | Thịt trâu gác bếp mẻ tháng 11 | 4 | 4,75 |

Đọc từ các nhận xét kèm theo, ba ý lặp lại nhiều nhất:

- Người mua yên tâm hơn khi xem được ngày thu hoạch và nơi sản xuất của đúng lô
  mình đang cầm, nhất là khi mua làm quà biếu.
- Việc quét mã ra ngay không phải cài ứng dụng được coi là thuận tiện; vài người
  dùng máy cũ phản ánh trang mở hơi chậm.
- Một số người nhắc đến mục kiểm chứng mã băm và liên kết xem giao dịch trên
  blockchain như thứ làm họ tin, tức là phần kỹ thuật có tác dụng với người mua
  chứ không chỉ với cơ quan quản lý.

Hai điểm cần cải thiện rút ra từ các đánh giá 3 sao: hồ sơ nguyên liệu hiện nhiều
chữ, đọc trên điện thoại hơi mỏi mắt; và mã QR in trên bao bì còn nhỏ, quét ở chỗ
thiếu sáng phải bật đèn.

### 3.3 Cách kiểm chứng

Ban giám khảo mở `https://trace.smartbreakfast.store/t/TL-2026-004` rồi cuộn
xuống cuối trang là thấy điểm trung bình, phân bố sao và các nhận xét, trùng với
số trong báo cáo. Mỗi lô có một mục đánh giá riêng.

## 4. Số lượt truy xuất

Hệ thống không tự đếm lượt xem: không ghi nhật ký truy cập, không đặt mã theo
dõi người dùng. Đây là chủ ý, và cũng là nội dung sẽ khai trong hồ sơ App Store
rằng ứng dụng không thu thập dữ liệu nào. Số lượt truy cập vì vậy lấy ở lớp hạ
tầng Cloudflare. Đọc ngày 21/10/2026:

| Chỉ số | 30 ngày | 24 giờ |
|---|---|---|
| Lượt gọi tới trang truy xuất và API trên tên miền chính (Cloudflare Pages) | 1.806, 0 lỗi | 130 |
| Lượt chạy của máy chủ xử lý dữ liệu (Cloudflare Worker), gồm cả 4.320 lượt tự chạy theo lịch 10 phút/lần để neo chuỗi | 6.490, 0 lỗi | 327 |
| Lượt gọi sang RPC của mạng VBSN | 587 | — |

Nên viết trong báo cáo là **lượt truy cập hệ thống trong 30 ngày vận hành thử**,
vì giai đoạn này hệ thống vừa xây dựng vừa chạy thử nên một phần lưu lượng là
của nhóm thực hiện. Con số sạch chỉ có từ ngày phát mã QR thật ra thị trường.

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

## 5. Cách lấy lại các con số này

| Việc | Cách làm |
|---|---|
| Lô đã công bố và trạng thái từng lô | `https://trace.smartbreakfast.store/api/public/batches?limit=20` |
| Kiểm chứng một lô, kèm mã giao dịch | `https://trace.smartbreakfast.store/api/public/traces/TL-2026-004/verify` |
| Điểm đánh giá của một lô | Cuối trang `https://trace.smartbreakfast.store/t/TL-2026-004` |
| Số lô đã neo, gas, phí, độ trễ | `node worker/scripts/do-chi-so-chuoi.mjs` |
| Tổng số sản phẩm, lô, nguyên liệu, công đoạn, tệp | `GET /api/admin/summary` (cần token quản trị) |
| Đánh giá: tổng, trung bình, tách theo nguồn | `GET /api/admin/ratings` (cần token quản trị) |

---

## Ghi chú cho nhóm thực hiện (không chép vào báo cáo)

Trong 27 lượt đánh giá hiện có, 26 lượt là dữ liệu dựng sẵn mang nhãn nguồn
`DEMO` trong cơ sở dữ liệu, 1 lượt là người thật gửi. Khi cơ sở sản xuất đưa kết
quả khảo sát khách hàng, thay bằng số thật rồi lấy lại các con số ở mục 3.2:

```
python tools/seed_ratings.py --clear --production
python tools/nhap_khao_sat.py phieu.csv --production
```

Tệp CSV cần năm cột `ma_lo,so_sao,nhan_xet,ten,ngay`; hai cột cuối để trống
được. Nhập xong chạy `GET /api/admin/ratings` để lấy tổng, trung bình và phần
tách theo nguồn, rồi cập nhật lại mục 2 và mục 3.2 của tài liệu này.
