# Ảnh minh hoạ cho hướng dẫn sử dụng

Chụp màn hình rồi lưu vào chính thư mục này, **đúng tên file** dưới đây là ảnh
tự hiện trong [../HUONG_DAN_SU_DUNG.md](../HUONG_DAN_SU_DUNG.md).

## Danh sách cần chụp

| Tên file | Chụp ở đâu | Nên lấy khung nào |
| --- | --- | --- |
| `01-trang-chu.png` | `/` khi chưa nhập mã | Cả trang, thấy ô tra cứu và thẻ giới thiệu |
| `02-ho-so-lo.png` | `/t/TL-2026-002` | Cả trang: bản đồ trái, hồ sơ phải |
| `03-nguyen-lieu.png` | Bấm một nguyên liệu trong danh sách hành trình | Panel phải sau khi mở, thấy công đoạn và ảnh |
| `04-kiem-chung.png` | Cuộn xuống dải dưới cùng trang khách | Riêng dải kiểm chứng, thấy mã giao dịch |
| `05-dang-nhap.png` | `/admin` khi chưa đăng nhập | Thẻ đăng nhập ở giữa |
| `06-tong-quan.png` | Sau khi đăng nhập, mục Tổng quan | Cả màn, thấy bốn ô số liệu |
| `07-danh-sach-lo.png` | Mục Lô sản phẩm | Thấy ô tìm kiếm, bộ sắp xếp và vài dòng lô |
| `08-tao-lo.png` | Bấm Tạo lô mới | Riêng hộp thoại |
| `09-man-lam-viec.png` | Mở một lô | Cả màn, thấy các khối xếp dọc |
| `10-thong-tin-lo.png` | Khối Thông tin lô | Riêng khối đó |
| `11-anh-lo.png` | Khối Ảnh của lô | Thấy dải ảnh và ba nút |
| `12-nguyen-lieu-admin.png` | Mở một thẻ nguyên liệu | Thấy bốn ô thông tin, ảnh và danh sách công đoạn |
| `13-khoanh-vung.png` | Hộp thoại sửa nguyên liệu → khoanh vùng | Bản đồ đang khoanh dở |
| `14-cong-doan-xuong.png` | Khối Công đoạn tại xưởng | Thấy phối trộn và đóng gói |
| `15-hoan-thanh-lo.png` | Khối Hoàn thành lô | Thấy trạng thái, nút và mã QR |
| `16-lich-su-qr.png` | Cuộn trong khối đó | Thấy lịch sử các bản và thẻ QR |

Ảnh trong thư mục này dùng cho cả [../HUONG_DAN_SU_DUNG.md](../HUONG_DAN_SU_DUNG.md)
và bộ slide. Chụp xong chạy `python tools/make_slides.py` để ảnh vào đúng chỗ
trong file `../Tu-Le-Trace-Slides.pptx`.

## Cách chụp

- **Cỡ cửa sổ 1440×900** cho ảnh toàn trang, để bố cục giống tài liệu.
- **Chụp thêm bản điện thoại** (390×844) cho mục 1 và 2 nếu muốn, đặt tên
  `02-ho-so-lo-mobile.png` rồi thêm dòng ảnh vào tài liệu.
- Lưu **PNG**, nén nhẹ nếu file trên 500KB.
- Đừng để lộ token quản trị trong ảnh: khi chụp màn đăng nhập hãy để ô trống.
- Dùng lô thật đã công bố (`TL-2026-002`) để ảnh có mã giao dịch và ảnh công
  đoạn thật.
