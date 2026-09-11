# Đối chiếu quy trình sản xuất với hệ thống truy xuất

Đọc `docs/quy trinh smart breakfast.docx` (sơ đồ + thuyết minh quy trình sản
xuất đồ uống Tú Lệ Smart) rồi soi lại xem phần số hoá đang làm đúng tới đâu.

Kết luận ngắn: **hướng đúng, nhưng mô hình dữ liệu đang thiếu ba thứ mà một hệ
truy xuất thật buộc phải có** — khối lượng, tham số công đoạn, và tầng bán thành
phẩm. Thiếu khối lượng thì không kiểm được cân bằng khối lượng, và đó chính là
chỗ mà truy xuất giả bị lộ.

## 1. Quy trình thật trong tài liệu

Bốn nhánh chạy song song, mỗi nhánh biến nguyên liệu tươi thành **bột**, rồi mới
phối trộn và đóng gói:

| Nhánh | Công đoạn | Tham số ghi trong tài liệu |
| --- | --- | --- |
| Khoai môn Lục Yên | làm sạch, bỏ vỏ → thái → nghiền → thuỷ phân → sấy phun | lát dày 0,5–1 cm; enzyme amylase; **80–90°C trong 60 phút**; bổ sung maltodextrin |
| Lạc đỏ Lục Yên | ngâm → nghiền mịn → lọc → thu sữa lạc → sấy phun | ngâm **2–3 giờ**; loại hạt lép, hạt hư |
| Chuối tiêu | bóc vỏ → nghiền mịn → lọc → sấy phun | chuối **khoảng 9 tuần**, không dùng quả dập, quá xanh hay đã chín |
| Cốm Tú Lệ | rang → nghiền mịn | rang **100°C** tới khi cốm nở, ngả màu, dậy mùi |

Sau đó: **phối trộn** bốn loại bột cộng phụ gia (bột kem sữa, bột vani) →
**đóng gói**.

Định mức trong bảng chi phí, tính cho một mẻ 1.000g thành phẩm:

| Nguyên liệu | Đầu vào | Bột thu được | Tỷ lệ thu hồi |
| --- | --- | --- | --- |
| Cốm Tú Lệ | 500 g | 135 g | 27% |
| Lạc đỏ Lục Yên | 1.000 g | 205 g | 20,5% |
| Khoai môn Lục Yên | 500 g | 320 g | 64% |
| Chuối tiêu xanh | 1.000 g | 210 g | 21% |
| Bột kem sữa | 130 g | 130 g | — |
| Bột vani | 0,02 g | 0,02 g | — |

Quy cách bán: gói 30 g, hộp 20 gói.

## 2. Hệ thống đang có gì

| Quy trình thật | Hệ thống hiện tại | Trạng thái |
| --- | --- | --- |
| 4 vùng nguyên liệu, có toạ độ | `ingredient_batches` có toạ độ, vùng khoanh, ảnh | đúng |
| Công đoạn theo từng nguyên liệu | `process_events` gắn `ingredient_batch_id` | đúng |
| Ảnh từng công đoạn | media R2 gắn `process_event` | đúng |
| Lô thành phẩm gộp 4 nhánh | `product_batches` + snapshot băm SHA-256 | đúng |
| Một mã QR cho một lô | `/t/:code` | đúng |
| **Khối lượng vào / ra mỗi công đoạn** | không có trường nào | **thiếu** |
| **Tham số công đoạn (nhiệt độ, thời gian)** | chỉ có tiêu đề + mô tả tự do | **thiếu** |
| **Phụ gia: maltodextrin, kem sữa, vani** | không có trong hồ sơ | **thiếu** |
| **Bán thành phẩm (bột khoai môn, bột lạc…)** | không mô hình hoá | **thiếu** |
| Công đoạn của cả lô: phối trộn, đóng gói | `process_events.product_batch_id` | **đã làm** |
| Vùng khoai môn | seed ghi "Lâm Thượng, **Lào Cai**" | **sai, đã sửa** |

Điểm cuối là lỗi dữ liệu thật: Lâm Thượng là một xã của **Lục Yên, Yên Bái**,
tài liệu cũng ghi "Khoai môn Lục Yên". Đã sửa trong `seed.sql` và trong bộ bốn
nguyên liệu mẫu của màn quản trị, kèm công đoạn đúng theo tài liệu.

## 3. Đối chiếu chuẩn

### Thông tư 02/2024/TT-BKHCN (Bộ KH&CN, hiệu lực 01/6/2024)

Điều 6 khoản 3 liệt kê dữ liệu tối thiểu của hệ thống truy xuất nội bộ:

| Yêu cầu | Hệ thống | Ghi chú |
| --- | --- | --- |
| Tên sản phẩm, hàng hoá | có | |
| Hình ảnh sản phẩm | có | ảnh bìa + dải ảnh |
| Tên đơn vị sản xuất, kinh doanh | có | `facility_name` |
| Địa chỉ đơn vị | một phần | mới có tên xưởng và toạ độ, chưa có địa chỉ hành chính đầy đủ |
| Công đoạn: mã sản phẩm, mã địa điểm, thời gian sự kiện | một phần | có thời gian và toạ độ, **chưa có mã địa điểm chuẩn (GLN)** |
| Mã truy xuất nguồn gốc | có | `TL-2026-001`, nhưng **chưa theo TCVN 13274:2020** |
| Thương hiệu, số sê-ri | một phần | có tên lô, chưa có số sê-ri |
| Thời hạn sử dụng | có | `expiry_date` |
| Tiêu chuẩn, quy chuẩn áp dụng | **chưa có** | cần một trường khai TCVN/QCVN mà sản phẩm tuân theo |

Hai TCVN bị viện dẫn trực tiếp:

- **TCVN 13274:2020** — định dạng mã truy xuất. Mã `TL-2026-001` hiện là mã tự
  đặt. Nếu muốn kết nối Cổng truy xuất nguồn gốc quốc gia thì phải chuyển sang
  mã theo chuẩn (GTIN cho sản phẩm, GLN cho địa điểm, số lô theo AI 10).
- **TCVN 13275:2020** — định dạng vật mang dữ liệu. Mã QR hiện chứa một URL
  thuần. Chuẩn dùng **GS1 Digital Link**, dạng
  `https://ten-mien/01/{GTIN}/10/{số lô}`. Đây là thay đổi ở tầng URL, không phá
  kiến trúc hiện có: vẫn là một URL mở ra một trang.

### GS1 EPCIS

Quy trình này là ví dụ sách giáo khoa của **TransformationEvent**: nhiều đầu vào
biến mất, một đầu ra sinh ra, không còn quan hệ một-một. Bốn nhánh bột là bốn
transformation, phối trộn là transformation thứ năm, đóng gói là một
`AggregationEvent`.

Mô hình hiện tại chỉ có hai tầng phẳng (nguyên liệu → thành phẩm) nên không diễn
tả được "500g cốm tươi cho ra 135g bột cốm, và chính 135g đó đi vào mẻ này".

### ISO 22005 và HACCP

ISO 22005 đòi hỏi truy được **một bước tiến, một bước lùi** kèm khối lượng. Các
mốc nhiệt trong tài liệu (thuỷ phân 80–90°C/60 phút, rang 100°C, sấy phun) là
điểm kiểm soát: đó là những con số mà đoàn kiểm tra sẽ hỏi, và cũng là thứ đáng
đưa lên chuỗi vì không sửa lại được.

## 4. Đề xuất sửa mô hình dữ liệu

Ba thay đổi, xếp theo giá trị trên công sức.

**a. Khối lượng — quan trọng nhất.**

```sql
ALTER TABLE ingredient_batches ADD COLUMN input_quantity REAL;   -- 500
ALTER TABLE ingredient_batches ADD COLUMN output_quantity REAL;  -- 135
ALTER TABLE ingredient_batches ADD COLUMN unit TEXT DEFAULT 'g';
ALTER TABLE product_batches   ADD COLUMN output_quantity REAL;   -- 1000
ALTER TABLE product_batches   ADD COLUMN pack_size REAL;         -- 30 g/gói
ALTER TABLE product_batches   ADD COLUMN pack_count INTEGER;     -- 20 gói/hộp
```

Có ba cột này thì trang công khai hiện được câu đắt giá nhất của truy xuất:
*"mẻ 1.000g này được làm từ 500g cốm, 1.000g lạc, 500g khoai môn, 1.000g chuối"*
— và hệ thống tự cảnh báo khi tổng bột thành phần không khớp khối lượng thành
phẩm. Không có nó thì không ai chứng minh được lô 10 tấn không đến từ 1 tấn
nguyên liệu.

**b. Tham số công đoạn.**

```sql
ALTER TABLE process_events ADD COLUMN params TEXT;  -- JSON: {"nhiệt độ":"80-90°C","thời gian":"60 phút"}
```

Cột `product_batch_id` **đã có** (migration 0006): công đoạn phối trộn và đóng
gói giờ gắn thẳng vào lô, nhập ở khối "Công đoạn tại xưởng" trong màn quản trị
và hiện trong hồ sơ nơi sản xuất trên trang khách. Ràng buộc CHECK bắt một công
đoạn thuộc đúng một chỗ: hoặc một nguyên liệu, hoặc cả lô.

`params` là JSON tự do nhưng hiển thị thành các ô nhãn–giá trị, để nhiệt độ
thuỷ phân là **dữ liệu** chứ không phải một câu trong ô mô tả. Cột
`product_batch_id` cho phép phối trộn và đóng gói gắn thẳng vào lô, thay vì phải
gắn nhờ vào một nguyên liệu như hiện nay.

**c. Tầng bán thành phẩm.**

Cách nhẹ nhất mà không đập lại schema: coi mỗi nhánh bột là một `ingredient_batch`
có `kind = 'SEMI'` trỏ về nguyên liệu tươi qua `parent_id`. Nặng hơn nhưng đúng
chuẩn EPCIS: một bảng `transformations` riêng, mỗi dòng là (inputs[], output,
công đoạn). Chỉ nên làm khi bắt đầu bán cho khách hàng khác ngoài Tú Lệ.

## 5. Thứ tự đề xuất

1. **Khối lượng và định mức** (mục 4a). Rẻ, và mở ra kiểm tra cân bằng khối
   lượng — thứ phân biệt truy xuất thật với trang giới thiệu có mã QR.
2. **Tham số công đoạn + công đoạn của lô** (4b). Sau bước này mới ghi được
   đúng quy trình trong tài liệu, gồm phối trộn và đóng gói.
3. **Phụ gia**: khai maltodextrin, bột kem sữa, bột vani như nguyên liệu có
   nguồn mua. Ghi nhãn thực phẩm đòi hỏi liệt kê đủ, và người mua có quyền biết.
4. **Mã theo chuẩn**: xin GTIN/GLN của GS1 Việt Nam, đổi nội dung QR sang GS1
   Digital Link. Chỉ làm khi có ý định nối Cổng truy xuất quốc gia — trước đó thì
   mã tự đặt vẫn chạy tốt.
5. **Bán thành phẩm** (4c). Để sau cùng.

## 6. Hai điều phải giữ

**Bảng chi phí không được lên trang công khai.** Tài liệu có giá vốn từng nguyên
liệu, giá thành một gói và lãi dự kiến trên mỗi hộp. Những số này không được
nằm trong snapshot đem đi băm, vì snapshot là thứ công bố cho bất kỳ ai quét mã.
Nếu sau này nhập định mức vào hệ thống, chỉ nhập **khối lượng**, không nhập giá.

**Tên gọi đã chốt: "Tú Lệ Smart Breakfast".** Tài liệu quy trình gọi là "sản
phẩm đồ uống từ ngũ cốc Tú Lệ Smart"; tên dùng chính thức ở bao bì, nhãn và
trang truy xuất là **Tú Lệ Smart Breakfast**. Mọi chỗ trong hệ thống, kể cả tên
mặc định lúc tạo lô, đã dùng đúng tên này.
