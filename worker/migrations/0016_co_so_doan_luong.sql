-- Cơ sở sản xuất thứ ba: Hợp tác xã chế biến, kinh doanh tổng hợp Đoàn Lương.
--
-- Địa chỉ chép đúng theo giấy chứng nhận OCOP 2023 của hợp tác xã: xã Văn Phú,
-- thành phố Yên Bái, tỉnh Yên Bái. Sau đợt sắp xếp đơn vị hành chính, địa danh
-- này có thể đã đổi tên và đổi tỉnh; sửa lại khi hợp tác xã xác nhận địa chỉ
-- hiện hành, đừng đoán.
--
-- Cơ sở phải tạo bằng SQL vì API quản trị cố tình không có đường tạo cơ sở:
-- thêm một cơ sở là mở thêm một vùng dữ liệu mà người phụ trách cơ sở đó sẽ
-- thấy, nên việc này nằm ngoài thao tác hằng ngày.
INSERT OR IGNORE INTO facilities (code, name, created_at) VALUES
  ('TAOMEO', 'Hợp tác xã chế biến, kinh doanh tổng hợp Đoàn Lương',
   '2026-10-26T00:00:00.000Z');

-- Hai mã sản phẩm của cơ sở này. Đặt bằng SQL chứ không qua API vì API không
-- có đường khai `product_kind`: một mã nguyên liệu mà lỡ tạo thành thành phẩm
-- sẽ hiện trong bộ chọn sản phẩm của người mua.
INSERT OR IGNORE INTO products
  (sku, name, description, template_key, product_kind, facility_id, status, created_at)
VALUES
  ('ingredient-tao-meo-tuoi', 'Quả táo mèo tươi',
   'Lô quả táo mèo (sơn tra) tươi được tiếp nhận để chế biến.',
   '', 'ingredient',
   (SELECT id FROM facilities WHERE code = 'TAOMEO'),
   'ACTIVE', '2026-10-26T00:00:00.000Z'),
  ('tao-meo-o-mai', 'Ô mai táo mèo Đoàn Lương',
   'Quả táo mèo thái lát, khử chát, sên đường rồi sấy và đóng hũ 200 g, truy xuất theo từng lô.',
   '', 'finished',
   (SELECT id FROM facilities WHERE code = 'TAOMEO'),
   'ACTIVE', '2026-10-26T00:00:00.000Z');
