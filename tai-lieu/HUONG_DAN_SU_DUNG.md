# Hướng dẫn sử dụng Tú Lệ Trace

Dành cho người vận hành: tạo lô, nhập nguyên liệu và công đoạn, tải ảnh, công bố
và in mã QR lên bao bì.

- Trang khách: <https://tule-trace.sontm.workers.dev>
- Màn quản trị: <https://tule-trace.sontm.workers.dev/admin>

> **Ảnh minh hoạ**: mỗi mục có một dòng `![...](anh/...)`. Chụp màn hình rồi lưu
> vào thư mục `tai-lieu/anh/` đúng tên file ghi trong ngoặc là ảnh tự hiện ra.
> Xem [anh/README.md](anh/README.md) để biết cỡ ảnh nên chụp.

---

## 1. Trang khách thấy gì khi quét mã

Quét mã QR trên bao bì bằng camera điện thoại là mở thẳng hồ sơ lô. Không tiện
quét thì gõ mã in dưới mã QR vào ô tra cứu.

![Trang tra cứu khi chưa nhập mã](anh/01-trang-chu.png)

Sau khi có mã, trang chia hai phần:

- **Bên trái** là bản đồ vùng nguyên liệu, mỗi vùng một nhãn ảnh, đường nét đứt
  chạy từ các vùng về nơi phối trộn và đóng gói.
- **Bên phải** là hồ sơ lô: tên sản phẩm, thẻ **ĐÃ XÁC MINH**, mã lô, ngày sản
  xuất, hạn dùng, rồi danh sách hành trình đánh số.

![Hồ sơ một lô](anh/02-ho-so-lo.png)

Bấm vào một thành phần để xem hồ sơ riêng: nhà cung cấp, ngày thu hoạch, ngày
nhập kho, vùng nguyên liệu, và toàn bộ công đoạn kèm ảnh.

![Hồ sơ một nguyên liệu](anh/03-nguyen-lieu.png)

Dải dưới cùng là phần kiểm chứng: phiên bản, thời điểm công bố, mã giao dịch
trên blockchain và nút mở giao dịch đó trên explorer.

![Dải kiểm chứng](anh/04-kiem-chung.png)

---

## 2. Đăng nhập quản trị

Mở `/admin`, dán **token quản trị** vào ô rồi bấm **Vào Management**. Trình duyệt
nhớ token nên chỉ phải nhập một lần trên mỗi máy.

![Màn đăng nhập](anh/05-dang-nhap.png)

Token production nằm ở `worker/.admin-token.txt` trên máy quản trị. Đổi token
bằng một lệnh:

```bash
cd worker
npx wrangler secret put ADMIN_TOKEN
```

Đây là thứ duy nhất chặn người lạ tạo lô giả và công bố dưới tên thương hiệu,
nên trước khi in QR lên bao bì thật hãy đặt một chuỗi dài và khó đoán.

---

## 3. Tổng quan

Sau khi vào, màn **Tổng quan** cho biết đang có bao nhiêu lô, nguyên liệu, công
đoạn và bao nhiêu mã băm còn chờ ghi lên chuỗi.

![Màn tổng quan](anh/06-tong-quan.png)

---

## 4. Danh sách lô

Mục **Lô sản phẩm** liệt kê tất cả lô, mỗi dòng có mã lô, ngày tạo, ngày sản
xuất, số nguyên liệu, số công đoạn và phiên bản đã công bố.

- Ô tìm kiếm: gõ mã lô hoặc tên, kết quả lọc ngay.
- Thứ tự: mới tạo trước, cũ nhất trước, tên A→Z, hoặc theo mã lô.
- Mỗi trang 10 lô.

Nhãn trạng thái: **ĐANG TẠO** là chưa công bố bản nào, **ĐÃ XONG** là đã có bản
công bố.

![Danh sách lô](anh/07-danh-sach-lo.png)

---

## 5. Tạo một lô mới

Bấm **Tạo lô mới**. Hộp thoại chỉ hỏi những gì bắt buộc:

| Trường | Ghi chú |
| --- | --- |
| Tên lô | Khách nhìn thấy đầu tiên khi quét QR |
| Mã truy xuất | In lên bao bì và nằm trong đường dẫn QR. Chữ in hoa, số, dấu gạch ngang. Trùng mã là bị chặn |
| Ngày sản xuất, hạn sử dụng | Chọn bằng lịch |
| Nơi sản xuất | Mặc định là Trung tâm Phát triển và Giao dịch Công nghệ thành phố Hà Nội |
| Tạo sẵn bốn nguyên liệu Tú Lệ | **Nên tick.** Hệ thống tạo luôn cốm, lạc, chuối, khoai môn kèm **toàn bộ 22 công đoạn theo sơ đồ quy trình** và mô tả lấy từ tài liệu, cộng hai công đoạn phối trộn và đóng gói ở xưởng |

![Hộp thoại tạo lô](anh/08-tao-lo.png)

Tick ô cuối thì việc còn lại của bạn gần như chỉ là **tải ảnh lên**.

---

## 6. Màn làm việc của một lô

Bấm vào một lô trong danh sách để mở. Mọi việc của lô nằm trong một màn, theo
đúng thứ tự làm:

![Màn làm việc của lô](anh/09-man-lam-viec.png)

### 6.1 Thông tin lô

Tên, ngày sản xuất, hạn dùng, nơi sản xuất, toạ độ và mô tả ngắn. Nút **Lưu
thông tin** chỉ sáng khi có thay đổi thật.

![Thông tin lô](anh/10-thong-tin-lo.png)

### 6.2 Ảnh của lô

- **Thêm ảnh / video**: ảnh giới thiệu lô.
- **Đặt ảnh bìa**: ảnh hiện ở đầu trang khách.
- **Thêm hồ sơ kiểm nghiệm**: file PDF hoặc ảnh phiếu kiểm nghiệm. Hồ sơ này
  dành cho landing page, trang quét QR không dựng nó.

Giới hạn mỗi file 30MB. Nén video xuống 720p trước khi tải.

![Ảnh của lô](anh/11-anh-lo.png)

### 6.3 Nguyên liệu

Mỗi nguyên liệu là một thẻ mở ra được. Bên trong có:

- Bốn thông tin mà trang khách hiện: nhà cung cấp, ngày thu hoạch, ngày nhập
  kho, vùng nguyên liệu. Bấm **Sửa thông tin nguyên liệu** để nhập.
- Ảnh vùng nguyên liệu.
- Toàn bộ công đoạn, mỗi công đoạn có dải ảnh riêng.

![Thẻ nguyên liệu mở ra](anh/12-nguyen-lieu-admin.png)

**Ảnh vùng nguyên liệu**: chụp màn hình bản đồ hành chính của xã (Google Maps
hoặc openstreetmap.org, nhớ giữ nguyên phần ghi nguồn trong ảnh), rồi tải lên
với vai trò **Vùng nguyên liệu**. Trang khách hiện ảnh này ngay đầu hồ sơ
nguyên liệu. Mỗi nguyên liệu chỉ nên có một ảnh vai trò này; ảnh ruộng, ảnh thu
hoạch thì để vai trò ảnh thường.

![Khoanh vùng nguyên liệu](anh/13-khoanh-vung.png)

### 6.4 Công đoạn tại xưởng

Phối trộn và đóng gói thuộc cả lô, không thuộc nguyên liệu nào, nên nằm ở khối
riêng. Mỗi công đoạn cũng tải ảnh được.

![Công đoạn tại xưởng](anh/14-cong-doan-xuong.png)

---

## 7. Hoàn thành lô

Bấm **Hoàn thành lô** (lần sau nút đổi thành **Lưu bản mới**). Một lần bấm làm
bốn việc:

1. Gom toàn bộ dữ liệu lô thành một bản snapshot.
2. Băm SHA-256 bản đó và lưu thành phiên bản mới, **không ghi đè bản cũ**.
3. Gửi mã băm lên VBSN Besu bằng ví của thương hiệu — bạn không phải xác nhận
   ví, không phải trả gas.
4. Từ lúc này khách quét QR mới thấy nội dung mới.

![Khối hoàn thành lô](anh/15-hoan-thanh-lo.png)

Sau khi xong, khối này hiện:

- Trạng thái **Dữ liệu khớp với bản đã công bố** kèm mã băm.
- Dòng **Đã lưu lên blockchain** kèm nút xem giao dịch.
- **Lịch sử** các bản đã lưu; bấm biểu tượng đồng hồ ở một dòng để **xem lại
  nội dung bản đó** đúng như lúc chốt.
- Mã QR của lô, có nút **Tải mã QR** ra file PNG nền trắng 1024px kèm mã lô bên
  dưới, đưa thẳng sang bản in bao bì được.

![Lịch sử và mã QR](anh/16-lich-su-qr.png)

---

## 8. Những trạng thái hay gặp

| Bạn thấy | Nghĩa là | Cần làm gì |
| --- | --- | --- |
| **Có thay đổi chưa lưu** (màn quản trị) | Bạn vừa sửa dữ liệu; khách vẫn đang xem bản cũ | Bấm **Lưu bản mới** khi đã nhập xong |
| **CHỜ LƯU CHUỖI** trong lịch sử | Mã băm đã vào hàng chờ, chưa có giao dịch | Đợi tối đa 10 phút, hoặc bấm **Gửi lên chuỗi** |
| **GỬI HỎNG** | Giao dịch thất bại, thường do mạng hoặc ví hết VNX | Kiểm số dư ví hiện dưới nút, rồi bấm gửi lại |
| **DỮ LIỆU SAI LỆCH** trên trang khách | Nội dung đang phục vụ không khớp mã băm của chính nó | Hiếm; báo kỹ thuật kiểm tra ngay |
| **ĐANG TẠO** | Lô chưa công bố bản nào | Nhập xong thì bấm **Hoàn thành lô** |

Sửa dữ liệu **không** xoá bản cũ: nội dung và giao dịch của bản trước vẫn còn
nguyên, xem lại được trong Lịch sử. Ảnh đã gỡ khỏi lô cũng được giữ trong kho
nếu còn bản công bố nào trỏ tới nó.

---

## 9. Việc định kỳ

**Xem tình trạng ví neo dữ liệu**

```bash
cd worker
npm run chain:status
```

**Kiểm chứng độc lập một mã băm** — đọc thẳng từ chuỗi, không cần tin trang web:

```bash
node scripts/chain-verify.mjs 0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca <sha256>
```

**Chép một lô từ máy thử lên production** — hai môi trường là hai database khác
nhau, lô nhập ở máy dev không tự có trên production:

```bash
node scripts/copy-batch.mjs TL-2026-003 --to https://tule-trace.sontm.workers.dev
```

**Đưa công đoạn của một lô về đúng sơ đồ quy trình** — giữ nguyên ảnh đã tải,
chỉ bổ sung bước còn thiếu:

```bash
node scripts/apply-process.mjs TL-2026-003 --publish
```

---

## 10. Cần biết trước khi in bao bì

- **Mã lô nằm trong đường dẫn QR.** In rồi thì không đổi mã được nữa; đổi mã là
  mọi gói đã in trỏ vào một trang không tồn tại.
- **Đổi token quản trị** sang chuỗi dài, khó đoán.
- **Kiểm tra bằng điện thoại thật** trước khi in hàng loạt: quét thử mã QR đã
  tải về, xem trang mở đúng lô và ảnh hiện đủ.
- **Ví neo dữ liệu phải còn VNX.** Hết thì hàng chờ đứng lại, dữ liệu vẫn an
  toàn nhưng không có giao dịch mới.
