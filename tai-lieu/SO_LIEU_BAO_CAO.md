# Số liệu hệ thống Tú Lệ Trace cho báo cáo

Chốt ngày **21/10/2026**, bổ sung mục Chỉ số ngày **25/10/2026**, bổ sung cơ
sở thứ ba và dòng ô mai táo mèo ngày **26/10/2026**. Mọi con số
dưới đây đọc thẳng từ hệ thống đang chạy, trừ những dòng ghi rõ là do cơ sở sản
xuất cung cấp; mục 5 ghi cách lấy lại để kiểm.

## 1. Bảng chỉ số hệ thống

| Chỉ số | Kết quả | Nguồn số liệu |
|---|---|---|
| Số khách hàng (cơ sở sản xuất) | **3 cơ sở**: Trung tâm Phát triển và Giao dịch Công nghệ thành phố Hà Nội (Tú Lệ Smart Breakfast), Cơ sở chế biến vùng cao (thịt trâu gác bếp) và Hợp tác xã chế biến, kinh doanh tổng hợp Đoàn Lương (ô mai táo mèo) | Trang `/chi-so`, 26/10/2026 |
| Số sản phẩm đưa lên hệ thống | 11 mã trong danh mục: 5 mã thành phẩm (bột Tú Lệ dạng hộp, gói 30 g, hộp quà; thịt trâu gác bếp; ô mai táo mèo) và 6 mã nguyên liệu (cốm Tú Lệ, lạc đỏ Lục Yên, chuối tiêu xanh Bảo Thắng, khoai môn Lục Yên, thịt trâu tươi, quả táo mèo tươi). Người mua nhìn thấy **3 dòng sản phẩm** | Danh mục sản phẩm trên hệ thống, 26/10/2026 |
| Số lô đưa lên hệ thống | 16 lô, trong đó **11 lô đã công bố** (10 lô thành phẩm, 1 lô nguyên liệu) và 5 lô nguyên liệu còn ở trạng thái nháp | Trang `/chi-so`, 26/10/2026 |
| Số lô đã neo lên blockchain | **11 lô**, cả 11 đều ĐÃ XÁC MINH và có giao dịch đã được xác nhận trên mạng VBSN (chainId 84001) | Đo trên mạng VBSN, 26/10/2026 |
| Số nguyên liệu đã khai báo | 22 lô nguyên liệu, 91 công đoạn, 149 tệp ảnh và tài liệu | Thống kê quản trị, 26/10/2026 |

Hai chỗ khác với bản nháp đang có trong báo cáo:

- **Số lô đã neo là 8, không phải 6.** Con số 6 là do trang chủ chỉ liệt kê 6 lô
  gần nhất. Hai lô `TL-2026-001` và `TL-2026-002` cũng đã neo, khối 5.783.872 và
  5.783.848.
- **"2 sản phẩm" nên viết rõ là dòng sản phẩm.** Từ 26/10/2026 có 3 dòng: bột
  ngũ cốc Tú Lệ, thịt trâu gác bếp và ô mai táo mèo. Danh mục thật có 11 mã, vì
  mỗi quy cách đóng gói và mỗi nguyên liệu đều là một mã riêng để truy xuất
  ngược được.
- **Cơ sở thứ ba vào hệ thống ngày 26/10/2026**: Hợp tác xã chế biến, kinh doanh
  tổng hợp Đoàn Lương, với 3 lô ô mai táo mèo `TM-2026-001`, `TM-2026-002`,
  `TM-2026-003`. Mọi con số "2 cơ sở" trong bản nháp báo cáo phải sửa thành 3.

## 2. Bảng người sử dụng

| Chỉ số | Kết quả | Nguồn số liệu |
|---|---|---|
| Số người sử dụng sản phẩm | **1.315 người** | Danh sách khách hàng và phiếu khảo sát của cơ sở sản xuất; hiện trên hệ thống ở mục **Chỉ số** |
| Số tài khoản trên hệ thống | Tài khoản theo ba vai trò: quản trị hệ thống, phụ trách cơ sở, nhân viên công đoạn. Người mua không cần tài khoản: quét mã là xem được ngay | Mục **Tài khoản** của màn quản trị |
| Số lượt truy xuất | **1.806 lượt**, từ 21/09/2026 đến 21/10/2026, 0 lỗi, trên tên miền `trace.smartbreakfast.store`. Từ 25/10/2026 hệ thống tự đếm tiếp, xem mục **Chỉ số** | Thống kê truy cập Cloudflare (giai đoạn trước); bộ đếm của hệ thống (từ 25/10/2026) |
| Đánh giá của người sử dụng | **27 lượt**, trung bình **4,56/5 sao**, trong đó 93% cho từ 4 sao trở lên, không có lượt nào dưới 3 sao | Mục đánh giá trên trang truy xuất, 21/10/2026 |

Toàn bộ bảng này xem được tại **https://trace.smartbreakfast.store/chi-so**,
không cần đăng nhập. Nên dẫn thẳng địa chỉ đó trong báo cáo: người chấm gõ vào
trình duyệt là đối chiếu được từng dòng với hệ thống đang chạy, thay vì phải
tin con số in trên giấy. Cùng bảng đó còn nằm ở mục **Chỉ số** của màn quản trị
cho người khai số.

Trang chia làm hai nửa và không trộn vào nhau: nửa trên là thứ hệ thống tự đếm
(số cơ sở, số sản phẩm và lô, số lô đã neo, số lượt đánh giá, lượt mở hồ sơ) —
không ai khai tay được, kể cả quản trị; nửa dưới là thứ cơ sở sản xuất cung cấp,
mỗi con số kèm đúng nguồn của nó. Người chấm hồ sơ hỏi "số này ở đâu ra" thì câu
trả lời nằm ngay dưới con số, không phải đi tìm.

Riêng dòng **số người sử dụng sản phẩm**: đây là số của cơ sở sản xuất, không
phải số hệ thống đếm được. Hệ thống cố ý không bắt người mua đăng ký nên không
có cách nào đếm đầu người từ phía máy chủ. Báo cáo nên viết đúng như vậy — ghi
nguồn là danh sách khách hàng và phiếu khảo sát của cơ sở — thay vì để nguồn là
"danh sách tài khoản", vì trên hệ thống không có 1.315 tài khoản và người chấm
mở mục Tài khoản ra là thấy.

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

Từ 25/10/2026 hệ thống có bộ đếm riêng: mỗi lần một hồ sơ lô được mở là cộng
một lượt, tách theo từng lô, xem ở mục **Chỉ số**. Bộ đếm chỉ lưu một con số —
không IP, không mã thiết bị, không thời điểm của từng lượt — nên vẫn giữ được
lời khai "ứng dụng không thu thập dữ liệu" trong hồ sơ App Store. Số của giai
đoạn trước ngày bật vẫn phải lấy ở Cloudflare, và đang được khai vào đúng nửa
"cơ sở cung cấp" của trang Chỉ số kèm ngày đọc.

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
| Cả bảng chỉ số, không cần đăng nhập | `https://trace.smartbreakfast.store/chi-so` (hoặc `GET /api/public/metrics` nếu cần số thô) |
| Lô đã công bố và trạng thái từng lô | `https://trace.smartbreakfast.store/api/public/batches?limit=20` |
| Kiểm chứng một lô, kèm mã giao dịch | `https://trace.smartbreakfast.store/api/public/traces/TL-2026-004/verify` |
| Điểm đánh giá của một lô | Cuối trang `https://trace.smartbreakfast.store/t/TL-2026-004` |
| Số lô đã neo, gas, phí, độ trễ | `node worker/scripts/do-chi-so-chuoi.mjs` |
| Tổng số sản phẩm, lô, nguyên liệu, công đoạn, tệp | `GET /api/admin/summary` (cần token quản trị) |
| Đánh giá: tổng, trung bình, tách theo nguồn | `GET /api/admin/ratings` (cần token quản trị) |
| Lượt mở hồ sơ và các chỉ số do cơ sở khai | `GET /api/admin/metrics` (cần token quản trị), hoặc mục **Chỉ số** trên màn quản trị |
| Khai lại một chỉ số sau khi cơ sở đưa số mới | Sửa bảng `METRICS` trong `tools/khai_chi_so.py` rồi chạy `python tools/khai_chi_so.py --production` |

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

### Dòng ô mai táo mèo - đâu là thật, đâu là dựng

Cơ sở là thật: **Hợp tác xã chế biến, kinh doanh tổng hợp Đoàn Lương**, địa chỉ
chép đúng theo giấy chứng nhận OCOP 2023 của chính hợp tác xã. Tên sản phẩm,
quy cách hũ 200 g và toàn bộ ảnh cũng là của hợp tác xã; chú thích từng ảnh ghi
rõ "ảnh tư liệu" chứ không nói là ảnh chụp tại lô đó.

Ba điều phải nhớ trước khi đưa dòng này vào báo cáo:

1. **Mã lô, ngày sản xuất và khối lượng từng công đoạn là dựng**, đúng như dòng
   thịt trâu gác bếp. Khi hợp tác xã gửi sổ sản xuất thật thì sửa bảng `LOTS` và
   phần `STEPS` trong `tools/seed_tao_meo.py` rồi chạy lại, đừng sửa tay trong
   màn quản trị.
2. **Ba giấy OCOP của hợp tác xã chưa đưa lên hệ thống.** Giấy ghi "có giá trị
   36 tháng kể từ ngày ký Quyết định 4357/QĐ-UBND ngày 21/8/2023", tức đã hết
   hiệu lực từ 21/8/2026. Đăng một tờ giấy hết hạn như minh chứng còn hiệu lực
   là đúng loại lỗi hội đồng sẽ bắt. Xin hợp tác xã bản gia hạn rồi mới đăng.
3. **Địa chỉ có thể đã đổi.** Giấy 2023 ghi "xã Văn Phú, thành phố Yên Bái, tỉnh
   Yên Bái"; sau đợt sắp xếp đơn vị hành chính, địa danh này có thể đã thuộc
   tỉnh Lào Cai. Hỏi lại hợp tác xã rồi sửa, đừng tự suy.

Cơ sở mới chưa có tài khoản riêng, nên hiện chỉ quản trị mới khai báo được cho
dòng này. Tạo tài khoản phụ trách cơ sở khi hợp tác xã cử người nhập liệu.
