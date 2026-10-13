-- Bộ dữ liệu trình diễn chuẩn cho catalog và các lô Smart Breakfast.
-- Chạy sau schema.sql. Lô được tạo ở trạng thái DRAFT; bấm công bố trong
-- Management (hoặc gọi API publish) để sinh snapshot và hash đầu tiên.

DELETE FROM blockchain_outbox;
DELETE FROM published_snapshots;
DELETE FROM media_assets;
DELETE FROM process_events;
DELETE FROM ingredient_batches;
DELETE FROM product_batches;

INSERT OR REPLACE INTO products (id, sku, name, description, template_key, status, created_at)
VALUES (1, 'tule-breakfast', 'Tú Lệ Smart Breakfast',
        'Bột ngũ cốc dinh dưỡng từ nông sản bản địa.', 'tule-breakfast', 'ACTIVE',
        '2026-08-12T02:00:00.000Z');

INSERT OR REPLACE INTO products (id, sku, name, description, template_key, status, created_at)
VALUES
  (2, 'tule-breakfast-sachet', 'Tú Lệ Smart Breakfast gói 30g',
   'Một khẩu phần bột dinh dưỡng pha nhanh từ bốn nông sản bản địa.', 'tule-breakfast', 'ACTIVE',
   '2026-08-12T02:00:00.000Z'),
  (3, 'tule-breakfast-gift', 'Tú Lệ Smart Breakfast hộp quà',
   'Hộp quà gồm các khẩu phần bột dinh dưỡng Tú Lệ Smart Breakfast.', 'tule-breakfast', 'ACTIVE',
   '2026-08-12T02:00:00.000Z');

-- Các SKU quy cách cũ vẫn giữ để không làm mất catalog vận hành, nhưng menu
-- khách chỉ coi Tú Lệ Smart Breakfast là một thành phẩm duy nhất.
UPDATE products SET product_kind = 'internal' WHERE id IN (2, 3);

INSERT OR REPLACE INTO products (id, sku, name, description, template_key, product_kind, status, created_at)
VALUES
  (4, 'ingredient-com-tu-le', 'Cốm Tú Lệ', 'Lô nguyên liệu cốm nếp nương dùng cho Smart Breakfast.', '', 'ingredient', 'ACTIVE', '2026-08-12T02:00:00.000Z'),
  (5, 'ingredient-lac-do-luc-yen', 'Lạc đỏ Lục Yên', 'Lô nguyên liệu lạc đỏ dùng cho Smart Breakfast.', '', 'ingredient', 'ACTIVE', '2026-08-12T02:00:00.000Z'),
  (6, 'ingredient-chuoi-tieu-bao-thang', 'Chuối tiêu xanh Bảo Thắng', 'Lô nguyên liệu chuối tiêu xanh dùng cho Smart Breakfast.', '', 'ingredient', 'ACTIVE', '2026-08-12T02:00:00.000Z'),
  (7, 'ingredient-khoai-mon-luc-yen', 'Khoai môn Lục Yên', 'Lô nguyên liệu khoai môn dùng cho Smart Breakfast.', '', 'ingredient', 'ACTIVE', '2026-08-12T02:00:00.000Z'),
  (8, 'ingredient-thit-trau-tuoi', 'Thịt trâu tươi', 'Lô thịt trâu nguyên liệu cho sản phẩm thịt trâu gác bếp.', '', 'ingredient', 'ACTIVE', '2026-09-01T02:00:00.000Z'),
  (9, 'buffalo-dried', 'Thịt trâu gác bếp', 'Thịt trâu tẩm ướp và hong khói, đóng gói truy xuất theo từng lô.', 'buffalo-dried', 'finished', 'ACTIVE', '2026-09-01T02:00:00.000Z');

-- Toạ độ và hồ sơ dưới đây bám theo nội dung giới thiệu và quy trình Smart
-- Breakfast, dùng để trình diễn đầy đủ luồng truy xuất nguồn gốc.
INSERT INTO product_batches (id, product_id, name, code, production_date, expiry_date, description, status, facility_name, latitude, longitude, created_at)
VALUES (
  1,
  1,
  'Tú Lệ Smart Breakfast',
  'TL-2026-001',
  '12.08.2026',
  '12.08.2027',
  'Bột ngũ cốc dinh dưỡng từ nông sản bản địa. Hồ sơ được ghi nhận theo từng công đoạn.',
  'DRAFT',
  'Trung tâm Phát triển và Giao dịch Công nghệ thành phố Hà Nội',
  21.0278,
  105.8342,
  '2026-08-12T02:00:00.000Z'
);

INSERT INTO product_batches (id, product_id, name, code, production_date, expiry_date, description, status, facility_name, latitude, longitude, created_at)
VALUES
  (2, 2, 'Tú Lệ Smart Breakfast gói 30g', 'TL-2026-002', '15.08.2026', '15.08.2027',
   'Một khẩu phần 30g bột dinh dưỡng pha nhanh, đóng gói riêng để sử dụng tiện lợi.', 'DRAFT',
   'Trung tâm Phát triển và Giao dịch Công nghệ thành phố Hà Nội', 21.0278, 105.8342,
   '2026-08-15T02:00:00.000Z'),
  (3, 3, 'Tú Lệ Smart Breakfast hộp quà', 'TL-2026-003', '18.08.2026', '18.08.2027',
   'Hộp quà gồm các khẩu phần bột dinh dưỡng từ nông sản Tây Bắc.', 'DRAFT',
    'Trung tâm Phát triển và Giao dịch Công nghệ thành phố Hà Nội', 21.0278, 105.8342,
    '2026-08-18T02:00:00.000Z');

UPDATE product_batches SET product_id = 1 WHERE id IN (2, 3);

INSERT INTO product_batches (id, product_id, name, code, production_date, expiry_date, description, status, facility_name, latitude, longitude, created_at)
VALUES
  (4, 4, 'Cốm Tú Lệ - lô nguyên liệu', 'NL-COM-2026-001', '10.08.2026', '10.08.2027', 'Lô cốm nếp nương được tiếp nhận để chế biến.', 'DRAFT', 'Hợp tác xã Tú Lệ', 21.7167, 104.2333, '2026-08-12T02:00:00.000Z'),
  (5, 5, 'Lạc đỏ Lục Yên - lô nguyên liệu', 'NL-LAC-2026-001', '08.08.2026', '08.08.2027', 'Lô lạc đỏ được tiếp nhận để chế biến.', 'DRAFT', 'Tổ hợp tác Lục Yên', 22.1000, 104.7167, '2026-08-12T02:00:00.000Z'),
  (6, 6, 'Chuối tiêu xanh Bảo Thắng - lô nguyên liệu', 'NL-CHUOI-2026-001', '09.08.2026', '09.08.2027', 'Lô chuối tiêu xanh được tiếp nhận để chế biến.', 'DRAFT', 'Vùng trồng Bảo Thắng', 22.3667, 104.1833, '2026-08-12T02:00:00.000Z'),
  (7, 7, 'Khoai môn Lục Yên - lô nguyên liệu', 'NL-KHOAI-2026-001', '09.08.2026', '09.08.2027', 'Lô khoai môn được tiếp nhận để chế biến.', 'DRAFT', 'Hộ sản xuất Lâm Thượng', 22.1667, 104.7500, '2026-08-12T02:00:00.000Z'),
  (8, 8, 'Thịt trâu tươi - lô nguyên liệu', 'NL-TRAU-2026-001', '28.08.2026', '05.09.2026', 'Lô thịt trâu nguyên liệu trước khi tẩm ướp và sấy.', 'DRAFT', 'Cơ sở chế biến vùng cao', 22.3364, 103.8438, '2026-09-01T02:00:00.000Z'),
  (9, 9, 'Thịt trâu gác bếp - mẻ tháng 09/2026', 'TB-2026-001', '01.09.2026', '01.03.2027', 'Thịt trâu thái dải, tẩm ướp, hong khói và đóng gói.', 'DRAFT', 'Cơ sở chế biến vùng cao', 22.3364, 103.8438, '2026-09-01T02:00:00.000Z');

INSERT INTO product_batches (id, product_id, name, code, production_date, expiry_date, description, status, facility_name, latitude, longitude, created_at)
VALUES
  (10, 1, 'Tú Lệ Smart Breakfast - mẻ tháng 09', 'TL-2026-004', '22.08.2026', '22.08.2027', 'Bột ngũ cốc dinh dưỡng từ nông sản bản địa, mẻ tháng 09.', 'DRAFT', 'Trung tâm Phát triển và Giao dịch Công nghệ thành phố Hà Nội', 21.0278, 105.8342, '2026-08-22T02:00:00.000Z'),
  (11, 9, 'Thịt trâu gác bếp - mẻ tháng 10', 'TB-2026-002', '01.10.2026', '01.04.2027', 'Thịt trâu thái dải, tẩm ướp, hong khói và đóng gói.', 'DRAFT', 'Cơ sở chế biến vùng cao', 22.3364, 103.8438, '2026-10-01T02:00:00.000Z'),
  (12, 9, 'Thịt trâu gác bếp - mẻ tháng 11', 'TB-2026-003', '01.11.2026', '01.05.2027', 'Thịt trâu thái dải, tẩm ướp, hong khói và đóng gói.', 'DRAFT', 'Cơ sở chế biến vùng cao', 22.3364, 103.8438, '2026-11-01T02:00:00.000Z');

-- Toạ độ là tâm xã theo danh mục địa danh, dùng để định vị vùng nguyên liệu.
INSERT INTO ingredient_batches (id, product_batch_id, name, origin, supplier, harvest_date, received_date, summary, latitude, longitude) VALUES
  (1, 1, 'Cốm Tú Lệ', 'Tú Lệ, Yên Bái', 'Hợp tác xã Tú Lệ', '10.08.2026', '11.08.2026', 'Hạt nếp nương xanh, dẻo thơm và là linh hồn của công thức.', 21.7167, 104.2333),
  (2, 1, 'Lạc đỏ Lục Yên', 'Lục Yên, Yên Bái', 'Tổ hợp tác Lục Yên', '08.08.2026', '10.08.2026', 'Hạt lạc bản địa giàu đạm thực vật, tạo vị bùi tự nhiên.', 22.1000, 104.7167),
  (3, 1, 'Chuối tiêu xanh', 'Bảo Thắng, Lào Cai', 'Vùng trồng VietGAP Bảo Thắng', '09.08.2026', '10.08.2026', 'Chuối tiêu khoảng 9 tuần, dùng lúc còn xanh để giữ tinh bột kháng.', 22.3667, 104.1833),
  (4, 1, 'Khoai môn Lục Yên', 'Lâm Thượng, Lục Yên, Yên Bái', 'Hộ sản xuất Lâm Thượng', '09.08.2026', '11.08.2026', 'Khoai môn bản địa cho kết cấu dẻo mịn và hương thơm đặc trưng.', 22.1667, 104.7500);

UPDATE ingredient_batches SET source_product_batch_id = CASE id
  WHEN 1 THEN 4 WHEN 2 THEN 5 WHEN 3 THEN 6 WHEN 4 THEN 7
  WHEN 5 THEN 4 WHEN 6 THEN 5 WHEN 7 THEN 6 WHEN 8 THEN 7
  WHEN 9 THEN 4 WHEN 10 THEN 5 WHEN 11 THEN 6 WHEN 12 THEN 7
END
WHERE id BETWEEN 1 AND 12;

INSERT INTO ingredient_batches (id, product_batch_id, name, origin, supplier, harvest_date, received_date, summary, latitude, longitude, source_product_batch_id) VALUES
  (13, 9, 'Thịt trâu tươi', 'Lai Châu, vùng Tây Bắc', 'Cơ sở chăn nuôi địa phương', '28.08.2026', '28.08.2026', 'Thịt trâu được sơ chế trong ngày, sau đó chuyển sang công đoạn tẩm ướp.', 22.3364, 103.8438, 8);

INSERT INTO ingredient_batches (id, product_batch_id, name, origin, supplier, harvest_date, received_date, summary, latitude, longitude, source_product_batch_id) VALUES
  (14, 10, 'Cốm Tú Lệ', 'Tú Lệ, Yên Bái', 'Hợp tác xã Tú Lệ', '20.08.2026', '21.08.2026', 'Hạt nếp nương xanh, dẻo thơm và là linh hồn của công thức.', 21.7167, 104.2333, 4),
  (15, 10, 'Lạc đỏ Lục Yên', 'Lục Yên, Yên Bái', 'Tổ hợp tác Lục Yên', '20.08.2026', '21.08.2026', 'Hạt lạc bản địa giàu đạm thực vật, tạo vị bùi tự nhiên.', 22.1000, 104.7167, 5),
  (16, 10, 'Chuối tiêu xanh', 'Bảo Thắng, Lào Cai', 'Vùng trồng VietGAP Bảo Thắng', '20.08.2026', '21.08.2026', 'Chuối xanh thu hoạch khoảng 9 tuần để khai thác tinh bột kháng.', 22.3667, 104.1833, 6),
  (17, 10, 'Khoai môn Lục Yên', 'Lâm Thượng, Lục Yên, Yên Bái', 'Hộ sản xuất Lâm Thượng', '20.08.2026', '21.08.2026', 'Khoai môn bản địa cho kết cấu dẻo mịn và hương thơm đặc trưng.', 22.1667, 104.7500, 7),
  (18, 11, 'Thịt trâu tươi', 'Lai Châu, vùng Tây Bắc', 'Cơ sở chăn nuôi địa phương', '28.09.2026', '28.09.2026', 'Thịt trâu được sơ chế trong ngày, sau đó chuyển sang công đoạn tẩm ướp.', 22.3364, 103.8438, 8),
  (19, 12, 'Thịt trâu tươi', 'Lai Châu, vùng Tây Bắc', 'Cơ sở chăn nuôi địa phương', '29.10.2026', '29.10.2026', 'Thịt trâu được sơ chế trong ngày, sau đó chuyển sang công đoạn tẩm ướp.', 22.3364, 103.8438, 8);

INSERT INTO ingredient_batches (id, product_batch_id, name, origin, supplier, harvest_date, received_date, summary, latitude, longitude) VALUES
  (5, 2, 'Cốm Tú Lệ', 'Tú Lệ, Yên Bái', 'Hợp tác xã Tú Lệ', '13.08.2026', '14.08.2026', 'Hạt nếp nương xanh, dẻo thơm và là linh hồn của công thức.', 21.7167, 104.2333),
  (6, 2, 'Lạc đỏ Lục Yên', 'Lục Yên, Yên Bái', 'Tổ hợp tác Lục Yên', '13.08.2026', '14.08.2026', 'Hạt lạc bản địa giàu đạm thực vật, tạo vị bùi tự nhiên.', 22.1000, 104.7167),
  (7, 2, 'Chuối tiêu xanh', 'Bảo Thắng, Lào Cai', 'Vùng trồng VietGAP Bảo Thắng', '13.08.2026', '14.08.2026', 'Chuối xanh thu hoạch khoảng 9 tuần để khai thác tinh bột kháng.', 22.3667, 104.1833),
  (8, 2, 'Khoai môn Lục Yên', 'Lâm Thượng, Lục Yên, Yên Bái', 'Hộ sản xuất Lâm Thượng', '13.08.2026', '14.08.2026', 'Khoai môn bản địa cho kết cấu dẻo mịn và hương thơm đặc trưng.', 22.1667, 104.7500),
  (9, 3, 'Cốm Tú Lệ', 'Tú Lệ, Yên Bái', 'Hợp tác xã Tú Lệ', '16.08.2026', '17.08.2026', 'Hạt nếp nương xanh, dẻo thơm và là linh hồn của công thức.', 21.7167, 104.2333),
  (10, 3, 'Lạc đỏ Lục Yên', 'Lục Yên, Yên Bái', 'Tổ hợp tác Lục Yên', '16.08.2026', '17.08.2026', 'Hạt lạc bản địa giàu đạm thực vật, tạo vị bùi tự nhiên.', 22.1000, 104.7167),
  (11, 3, 'Chuối tiêu xanh', 'Bảo Thắng, Lào Cai', 'Vùng trồng VietGAP Bảo Thắng', '16.08.2026', '17.08.2026', 'Chuối xanh thu hoạch khoảng 9 tuần để khai thác tinh bột kháng.', 22.3667, 104.1833),
  (12, 3, 'Khoai môn Lục Yên', 'Lâm Thượng, Lục Yên, Yên Bái', 'Hộ sản xuất Lâm Thượng', '16.08.2026', '17.08.2026', 'Khoai môn bản địa cho kết cấu dẻo mịn và hương thơm đặc trưng.', 22.1667, 104.7500);

-- Công đoạn lấy từ thuyết minh quy trình sản xuất, giữ nguyên các mốc nhiệt độ
-- và thời gian vì đó là thứ đoàn kiểm tra sẽ hỏi. Chừng nào process_events chưa
-- có cột params thì tham số nằm trong phần mô tả.
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at) VALUES
  (1, 'Thu hoạch lúa nếp nương', 'Gặt tay tại ruộng bậc thang, chọn bông chín tới.', '10.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (1, 'Rang cốm', 'Rang chảo ở 100°C tới khi cốm nở, ngả màu và dậy mùi. Đảo đều tay để cốm không cháy.', '11.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (1, 'Nghiền mịn thành bột cốm', 'Nghiền hai lần, rây qua lưới 120 mesh. Thu 135g bột từ 500g cốm.', '12.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (2, 'Tiếp nhận và chọn lạc', 'Cân nhận, loại hạt lép và hạt hư.', '10.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (2, 'Ngâm lạc', 'Ngâm 2-3 giờ trong nước sạch cho mềm hạt và giảm mùi hăng.', '11.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (2, 'Nghiền mịn và lọc lấy sữa lạc', 'Xay cùng nước rồi lọc tách bã, tránh xay lâu làm nóng hỗn hợp.', '11.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (2, 'Sấy phun thành bột lạc', 'Bổ sung maltodextrin rồi sấy phun. Thu 205g bột từ 1000g lạc.', '12.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (3, 'Chọn và bóc vỏ chuối', 'Chuối tiêu khoảng 9 tuần, bỏ quả dập, quả quá xanh hoặc đã chín.', '09.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (3, 'Nghiền mịn và lọc', 'Xay cùng nước theo tỷ lệ, lọc tách bã bằng rây sạch.', '11.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (3, 'Sấy phun thành bột chuối', 'Bổ sung maltodextrin rồi sấy phun. Thu 210g bột từ 1000g chuối.', '12.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (4, 'Làm sạch, gọt vỏ và thái', 'Rửa nhiều lần, gọt hết vỏ, thái lát dày 0,5-1cm rồi chế biến ngay để không thâm.', '09.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (4, 'Nghiền và thuỷ phân', 'Nghiền cùng nước, bổ sung enzyme amylase, giữ 80-90°C trong 60 phút.', '11.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (4, 'Sấy phun thành bột khoai môn', 'Lọc cặn, bổ sung maltodextrin rồi sấy phun. Thu 320g bột từ 500g khoai.', '12.08.2026', 'admin', '2026-08-12T02:00:00.000Z');

-- Hai công đoạn ở xưởng, thuộc cả lô chứ không thuộc nguyên liệu nào.
INSERT INTO process_events (product_batch_id, title, description, event_date, entered_by, created_at) VALUES
  (1, 'Phối trộn', 'Trộn bột khoai môn, bột lạc, bột chuối, bột cốm cùng bột kem sữa và bột vani theo định mức.', '12.08.2026', 'admin', '2026-08-12T02:00:00.000Z'),
  (1, 'Đóng gói', 'Đóng gói 30g mỗi gói, 20 gói một hộp, hàn kín để bảo quản.', '12.08.2026', 'admin', '2026-08-12T02:00:00.000Z');

INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 5, title, description, event_date, entered_by, '2026-08-15T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 1;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 6, title, description, event_date, entered_by, '2026-08-15T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 2;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 7, title, description, event_date, entered_by, '2026-08-15T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 3;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 8, title, description, event_date, entered_by, '2026-08-15T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 4;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 9, title, description, event_date, entered_by, '2026-08-18T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 1;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 10, title, description, event_date, entered_by, '2026-08-18T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 2;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 11, title, description, event_date, entered_by, '2026-08-18T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 3;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 12, title, description, event_date, entered_by, '2026-08-18T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 4;

INSERT INTO process_events (product_batch_id, title, description, event_date, entered_by, created_at)
SELECT 2, title, description, '15.08.2026', entered_by, '2026-08-15T02:00:00.000Z'
  FROM process_events WHERE product_batch_id = 1;
INSERT INTO process_events (product_batch_id, title, description, event_date, entered_by, created_at)
SELECT 3, title, description, '18.08.2026', entered_by, '2026-08-18T02:00:00.000Z'
  FROM process_events WHERE product_batch_id = 1;

INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 14, title, description, event_date, entered_by, '2026-08-22T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 1;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 15, title, description, event_date, entered_by, '2026-08-22T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 2;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 16, title, description, event_date, entered_by, '2026-08-22T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 3;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 17, title, description, event_date, entered_by, '2026-08-22T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 4;
INSERT INTO process_events (product_batch_id, title, description, event_date, entered_by, created_at)
SELECT 10, title, description, '22.08.2026', entered_by, '2026-08-22T02:00:00.000Z'
  FROM process_events WHERE product_batch_id = 1;

INSERT INTO process_events (product_batch_id, title, description, event_date, entered_by, created_at) VALUES
  (8, 'Tiếp nhận và kiểm tra thịt', 'Kiểm tra nguồn gốc, màu sắc, mùi và nhiệt độ bảo quản trước khi sơ chế.', '28.08.2026', 'admin', '2026-09-01T02:00:00.000Z'),
  (9, 'Sơ chế và thái dải', 'Lọc phần gân không phù hợp, thái thịt theo thớ thành các dải đồng đều.', '28.08.2026', 'admin', '2026-09-01T02:00:00.000Z'),
  (9, 'Tẩm ướp', 'Ướp thịt với muối, mắc khén, hạt dổi, ớt và gia vị theo công thức của cơ sở.', '29.08.2026', 'admin', '2026-09-01T02:00:00.000Z'),
  (9, 'Hong khói và làm khô', 'Hong trên bếp củi, sau đó làm khô đến độ dai phù hợp trước khi đóng gói.', '30.08.2026', 'admin', '2026-09-01T02:00:00.000Z'),
  (9, 'Đóng gói và dán QR', 'Đóng túi kín, ghi mã lô TB-2026-001 và dán mã QR truy xuất.', '01.09.2026', 'admin', '2026-09-01T02:00:00.000Z');

INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 18, title, description, '28.09.2026', entered_by, '2026-10-01T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 13;
INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT 19, title, description, '29.10.2026', entered_by, '2026-11-01T02:00:00.000Z'
  FROM process_events WHERE ingredient_batch_id = 13;
INSERT INTO process_events (product_batch_id, title, description, event_date, entered_by, created_at)
SELECT 11, title, description, '01.10.2026', entered_by, '2026-10-01T02:00:00.000Z'
  FROM process_events WHERE product_batch_id = 9;
INSERT INTO process_events (product_batch_id, title, description, event_date, entered_by, created_at)
SELECT 12, title, description, '01.11.2026', entered_by, '2026-11-01T02:00:00.000Z'
  FROM process_events WHERE product_batch_id = 9;

-- Ảnh lấy từ website Smart Breakfast chính thức, đã lưu content-addressed trong R2.
INSERT INTO media_assets
  (owner_type, owner_id, role, kind, r2_key, file_name, content_type, size, sha256, caption, created_at)
VALUES
  ('product_batch', 1, 'cover', 'image', 'media/437b96b8d6e3bf089a499ecd700b535991a89e5927d637a6bc2635547d7d9e6f.jpg', 'hop-qua.jpg', 'image/jpeg', 620552, '437b96b8d6e3bf089a499ecd700b535991a89e5927d637a6bc2635547d7d9e6f', 'Hộp 600g Tú Lệ Smart Breakfast', '2026-08-12T02:00:00.000Z'),
  ('product_batch', 1, 'gallery', 'image', 'media/2c3f74181cfda39e4d9cf2ae59b1c8bde718e1853315bb26d83abea77f2866e5.jpg', 'nguyen-lieu.jpg', 'image/jpeg', 301556, '2c3f74181cfda39e4d9cf2ae59b1c8bde718e1853315bb26d83abea77f2866e5', 'Bốn nguyên liệu trước khi chế biến', '2026-08-12T02:00:00.000Z'),
  ('product_batch', 1, 'gallery', 'image', 'media/5cc2af52660cbe10f4b1d237c391bfba6d6b838add0a9042681e4c4c05d6a55c.jpg', 'quy-trinh-so-do.jpg', 'image/jpeg', 502337, '5cc2af52660cbe10f4b1d237c391bfba6d6b838add0a9042681e4c4c05d6a55c', 'Sơ đồ quy trình sản xuất', '2026-08-12T02:00:00.000Z'),
  ('product_batch', 2, 'cover', 'image', 'media/c375aaf447a112a20b1d841b440f3ef143d541a8d70aed647eee0625f4492407.jpg', 'goi-le.jpg', 'image/jpeg', 338835, 'c375aaf447a112a20b1d841b440f3ef143d541a8d70aed647eee0625f4492407', 'Gói khẩu phần 30g', '2026-08-15T02:00:00.000Z'),
  ('product_batch', 2, 'gallery', 'image', 'media/a49e7c04601473f2db8092a1fd309bfdd015919e5bcaba6eff2ea582af35ede6.jpg', 'huong-dan-su-dung.jpg', 'image/jpeg', 479178, 'a49e7c04601473f2db8092a1fd309bfdd015919e5bcaba6eff2ea582af35ede6', 'Hướng dẫn pha sản phẩm', '2026-08-15T02:00:00.000Z'),
  ('product_batch', 3, 'cover', 'image', 'media/437b96b8d6e3bf089a499ecd700b535991a89e5927d637a6bc2635547d7d9e6f.jpg', 'hop-qua.jpg', 'image/jpeg', 620552, '437b96b8d6e3bf089a499ecd700b535991a89e5927d637a6bc2635547d7d9e6f', 'Hộp quà Tú Lệ Smart Breakfast', '2026-08-18T02:00:00.000Z'),
  ('product_batch', 3, 'gallery', 'image', 'media/2c3f74181cfda39e4d9cf2ae59b1c8bde718e1853315bb26d83abea77f2866e5.jpg', 'nguyen-lieu.jpg', 'image/jpeg', 301556, '2c3f74181cfda39e4d9cf2ae59b1c8bde718e1853315bb26d83abea77f2866e5', 'Nguyên liệu Tây Bắc', '2026-08-18T02:00:00.000Z');

-- Sau khi mọi répertoire cũ được nạp, gom hai quy cách cũ vào cùng menu
-- Smart Breakfast để khách chỉ thấy hai thành phẩm: Smart Breakfast và trâu.
UPDATE products SET product_kind = 'internal' WHERE id IN (2, 3);
UPDATE product_batches SET product_id = 1 WHERE id IN (2, 3);
