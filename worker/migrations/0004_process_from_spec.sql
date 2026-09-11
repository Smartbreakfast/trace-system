-- Sửa dữ liệu lô mẫu cho khớp thuyết minh quy trình sản xuất
-- (docs/quy trinh smart breakfast.docx).
--
-- Hai việc: một là sửa lỗi vùng nguyên liệu — Lâm Thượng là xã của Lục Yên,
-- Yên Bái chứ không phải Lào Cai; hai là thay công đoạn chung chung bằng đúng
-- công đoạn trong tài liệu, giữ nguyên id để ảnh đã tải lên không bị mồ côi.
--
-- Chạy xong thì lô đã công bố sẽ chuyển sang DỮ LIỆU SAI LỆCH cho tới khi bấm
-- "Lưu bản mới" — đúng như thiết kế, vì dữ liệu đã đổi sau lần chốt gần nhất.

UPDATE ingredient_batches
   SET name = 'Khoai môn Lục Yên',
       origin = 'Lâm Thượng, Lục Yên, Yên Bái'
 WHERE origin = 'Lâm Thượng, Lào Cai';

UPDATE ingredient_batches
   SET name = 'Chuối tiêu xanh',
       summary = 'Chuối tiêu khoảng 9 tuần, dùng lúc còn xanh để giữ tinh bột kháng.'
 WHERE name = 'Chuối tiêu hồng';

-- Cốm: rang 100°C rồi nghiền.
UPDATE process_events
   SET title = 'Rang cốm',
       description = 'Rang chảo ở 100°C tới khi cốm nở, ngả màu và dậy mùi. Đảo đều tay để cốm không cháy.'
 WHERE title = 'Nổ bỏng và làm sạch';

UPDATE process_events
   SET title = 'Nghiền mịn thành bột cốm',
       description = 'Nghiền hai lần, rây qua lưới 120 mesh. Thu 135g bột từ 500g cốm.'
 WHERE title = 'Nghiền thành bột mịn';

-- Lạc: ngâm 2-3 giờ, nghiền, lọc lấy sữa, sấy phun.
UPDATE process_events
   SET title = 'Tiếp nhận và chọn lạc',
       description = 'Cân nhận, loại hạt lép và hạt hư.'
 WHERE title = 'Tiếp nhận lô lạc đỏ';

UPDATE process_events
   SET title = 'Ngâm lạc',
       description = 'Ngâm 2-3 giờ trong nước sạch cho mềm hạt và giảm mùi hăng.'
 WHERE title = 'Tách vỏ và làm sạch';

UPDATE process_events
   SET title = 'Nghiền mịn và lọc lấy sữa lạc',
       description = 'Xay cùng nước rồi lọc tách bã, tránh xay lâu làm nóng hỗn hợp.'
 WHERE title = 'Xay với nước'
   AND ingredient_batch_id IN (SELECT id FROM ingredient_batches WHERE name LIKE 'Lạc%');

INSERT INTO process_events (ingredient_batch_id, title, description, event_date, entered_by, created_at)
SELECT id,
       'Sấy phun thành bột lạc',
       'Bổ sung maltodextrin rồi sấy phun. Thu 205g bột từ 1000g lạc.',
       '12.08.2026',
       'admin',
       '2026-08-12T02:00:00.000Z'
  FROM ingredient_batches
 WHERE name LIKE 'Lạc%'
   AND NOT EXISTS (
     SELECT 1 FROM process_events e
      WHERE e.ingredient_batch_id = ingredient_batches.id
        AND e.title = 'Sấy phun thành bột lạc'
   );

-- Chuối: bóc vỏ, nghiền, lọc, sấy phun.
UPDATE process_events
   SET title = 'Chọn và bóc vỏ chuối',
       description = 'Chuối tiêu khoảng 9 tuần, bỏ quả dập, quả quá xanh hoặc đã chín.'
 WHERE title = 'Chọn chuối xanh VietGAP';

UPDATE process_events
   SET title = 'Nghiền mịn và lọc',
       description = 'Xay cùng nước theo tỷ lệ, lọc tách bã bằng rây sạch.'
 WHERE title = 'Bóc vỏ và thái mỏng'
   AND ingredient_batch_id IN (SELECT id FROM ingredient_batches WHERE name LIKE 'Chuối%');

UPDATE process_events
   SET title = 'Sấy phun thành bột chuối',
       description = 'Bổ sung maltodextrin rồi sấy phun. Thu 210g bột từ 1000g chuối.'
 WHERE title = 'Xay với nước'
   AND ingredient_batch_id IN (SELECT id FROM ingredient_batches WHERE name LIKE 'Chuối%');

-- Khoai môn: thái 0,5-1cm, thuỷ phân 80-90°C trong 60 phút, sấy phun.
UPDATE process_events
   SET title = 'Làm sạch, gọt vỏ và thái',
       description = 'Rửa nhiều lần, gọt hết vỏ, thái lát dày 0,5-1cm rồi chế biến ngay để không thâm.'
 WHERE title = 'Thu hoạch tại vùng trồng';

UPDATE process_events
   SET title = 'Nghiền và thuỷ phân',
       description = 'Nghiền cùng nước, bổ sung enzyme amylase, giữ 80-90°C trong 60 phút.'
 WHERE title = 'Bóc vỏ và thái mỏng'
   AND ingredient_batch_id IN (SELECT id FROM ingredient_batches WHERE name LIKE 'Khoai%');

UPDATE process_events
   SET title = 'Sấy phun thành bột khoai môn',
       description = 'Lọc cặn, bổ sung maltodextrin rồi sấy phun. Thu 320g bột từ 500g khoai.'
 WHERE title = 'Xay với nước'
   AND ingredient_batch_id IN (SELECT id FROM ingredient_batches WHERE name LIKE 'Khoai%');
