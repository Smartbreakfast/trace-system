# Bảng 3 — bản sửa bằng số đo thật

Chuyên gia nhận xét Bảng 3 còn định tính (“vài giây”, “gần bằng 0”). Dưới đây là
bản thay thế: mỗi chỗ định tính được đổi thành một con số đo được, kèm cách đo
lại ở mục 3 để ban giám khảo tự kiểm.

Mọi con số đo ngày **23/10/2026** trên hệ thống đang chạy thật.

## 1. Bảng 3. Kiến trúc và công nghệ sử dụng

| Khối | Chức năng | Công nghệ đang sử dụng | Số đo thật (23/10/2026) |
|---|---|---|---|
| Giao diện | Trang người mua và màn quản trị | Flutter Web 3.44, go_router; trang truy xuất dựng sẵn thành HTML tại máy chủ | Trang truy xuất nặng 16,9 KB sau nén (85,4 KB chưa nén), byte đầu tiên về sau 0,29 giây, tải xong trang trong 0,34 giây. Người mua không cài ứng dụng, không cần ví điện tử |
| Xử lý nghiệp vụ | Định tuyến, xác thực, kiểm tra đầu vào, điều phối | Cloudflare Worker, Hono 4 | Một Worker phục vụ cả trang và API, không có máy chủ thường trực. 30 ngày gần nhất: 6.490 lượt chạy, 0 lỗi |
| Dữ liệu | Lưu lô, nguyên liệu, công đoạn, phiên bản công bố và hàng chờ neo chuỗi | Cloudflare D1 (SQLite), 8 bảng | Đang lưu 9 mã sản phẩm, 12 lô (8 lô đã công bố), 19 lô nguyên liệu, 73 công đoạn |
| Tệp minh chứng | Lưu ảnh, video, hồ sơ kiểm nghiệm | Cloudflare R2, khoá tệp bằng mã băm nội dung | Đang lưu 128 tệp, giới hạn 30 MB mỗi tệp. Hai tệp cùng nội dung cho cùng một khoá, nên không lưu trùng |
| Tạo mã băm | Chuẩn hoá hồ sơ lô rồi băm | JSON chuẩn hoá, SHA-256 | Mỗi lô ra một mã dài 64 ký tự hexa (256 bit). Sửa một ký tự trong hồ sơ là mã băm khác, hệ thống chuyển lô sang trạng thái SAI LỆCH |
| Hạ tầng blockchain | Neo mã băm và mốc thời gian, kiểm chứng giao dịch | Hạ tầng VBSN (Vietnam Blockchain Solution Network), mạng Besu, chainId 84001 | Khối ra đều 2,00 giây/khối. Mỗi lần neo tốn 29.293 gas, phí 0,00000366 VNX; 8 lô đã neo hết 0,0000293 VNX. Từ lúc bấm công bố tới lúc giao dịch được xác nhận: 1–5 giây. Chỉ ghi mã băm và mốc thời gian, không ghi hồ sơ hay dữ liệu cá nhân |
| Bản đồ | Hiển thị vùng nguyên liệu | MapLibre GL JS, OpenFreeMap | Hiển thị vùng nguyên liệu của từng lô nguyên liệu ngay trên trang truy xuất |

## 2. Hai chỗ phải sửa trong bản báo cáo hiện tại

| Chỗ đang viết | Sửa thành |
|---|---|
| “Chi phí sử dụng gần như bằng 0” | “Phí mỗi lần neo là 0,00000366 VNX, tương ứng 29.293 gas ở giá gas 0,1 gwei; tổng phí của 8 lô đã neo là 0,0000293 VNX” |
| “vài giây” | “1–5 giây từ lúc công bố tới lúc giao dịch được xác nhận trên chuỗi, trong đó thời gian ra khối của mạng là 2,00 giây” |
| “Cloudflare D1 (SQLite), 6 bảng” | “Cloudflare D1 (SQLite), 8 bảng” (đã thêm bảng liên kết nguyên liệu và bảng đánh giá) |

Con số 1–5 giây tính cả thời gian hồ sơ nằm trong hàng chờ neo chuỗi, không chỉ
thời gian của riêng blockchain. Ghi như vậy là nói đúng cái người dùng chờ.

## 3. Cách đo lại

| Số đo | Cách lấy lại |
|---|---|
| Thời gian khối, gas, phí, độ trễ công bố → chuỗi | `node worker/scripts/do-chi-so-chuoi.mjs` (chỉ đọc, không gửi giao dịch nào) |
| Dung lượng và thời gian tải trang truy xuất | `curl -s -o /dev/null -w "%{size_download} %{time_starttransfer}\n" https://trace.smartbreakfast.store/t/TL-2026-004` |
| Số sản phẩm, lô, nguyên liệu, công đoạn, tệp | `GET /api/admin/summary` (cần token quản trị) |
| Số lượt chạy Worker và số lỗi | dash.cloudflare.com → Workers & Pages → `tule-trace` → Metrics → Last 30 days |
| Mã băm và mã giao dịch của một lô | `https://trace.smartbreakfast.store/api/public/traces/TL-2026-004/verify` |
