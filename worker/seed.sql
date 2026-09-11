-- Dữ liệu khởi tạo cho lô đầu tiên của Tú Lệ Smart Breakfast.
-- Chạy sau schema.sql. Lô được tạo ở trạng thái DRAFT; bấm công bố trong
-- Management (hoặc gọi API publish) để sinh snapshot và hash đầu tiên.

DELETE FROM blockchain_outbox;
DELETE FROM published_snapshots;
DELETE FROM media_assets;
DELETE FROM process_events;
DELETE FROM ingredient_batches;
DELETE FROM product_batches;

-- Toạ độ dưới đây là vị trí thật của các xã vùng nguyên liệu. Riêng xưởng sản
-- xuất là giá trị demo, đặt tách khỏi bốn vùng nguyên liệu để bản đồ đọc được
-- hướng hội tụ. Thay bằng địa chỉ xưởng thật trước khi chạy production.
INSERT INTO product_batches (id, name, code, production_date, expiry_date, description, status, facility_name, latitude, longitude, created_at)
VALUES (
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

-- Toạ độ là tâm xã theo danh mục địa danh, dùng để định vị vùng nguyên liệu.
INSERT INTO ingredient_batches (id, product_batch_id, name, origin, supplier, harvest_date, received_date, summary, latitude, longitude) VALUES
  (1, 1, 'Cốm Tú Lệ', 'Tú Lệ, Yên Bái', 'Hợp tác xã Tú Lệ', '10.08.2026', '11.08.2026', 'Hạt nếp nương xanh, dẻo thơm và là linh hồn của công thức.', 21.7167, 104.2333),
  (2, 1, 'Lạc đỏ Lục Yên', 'Lục Yên, Yên Bái', 'Tổ hợp tác Lục Yên', '08.08.2026', '10.08.2026', 'Hạt lạc bản địa giàu đạm thực vật, tạo vị bùi tự nhiên.', 22.1000, 104.7167),
  (3, 1, 'Chuối tiêu xanh', 'Bảo Thắng, Lào Cai', 'Vùng trồng VietGAP Bảo Thắng', '09.08.2026', '10.08.2026', 'Chuối tiêu khoảng 9 tuần, dùng lúc còn xanh để giữ tinh bột kháng.', 22.3667, 104.1833),
  (4, 1, 'Khoai môn Lục Yên', 'Lâm Thượng, Lục Yên, Yên Bái', 'Hộ sản xuất Lâm Thượng', '09.08.2026', '11.08.2026', 'Khoai môn bản địa cho kết cấu dẻo mịn và hương thơm đặc trưng.', 22.1667, 104.7500);

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
