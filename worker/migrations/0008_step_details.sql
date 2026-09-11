-- Chi tiết công đoạn và giấy chứng nhận.
--
-- Khách hàng yêu cầu bấm vào một công đoạn phải thấy khối lượng, thời gian,
-- người làm và tham số kỹ thuật; và cần một chỗ riêng cho giấy chứng nhận
-- (OCOP, VietGAP, ATTP) tách khỏi phiếu kiểm nghiệm.
--
-- Các cột đều cho phép NULL và trường rỗng không được ghi vào payload công bố
-- (RB-03), nên mã băm của những lô đã công bố trước đó không đổi.

ALTER TABLE process_events ADD COLUMN input_quantity REAL;
ALTER TABLE process_events ADD COLUMN output_quantity REAL;
ALTER TABLE process_events ADD COLUMN quantity_unit TEXT;
ALTER TABLE process_events ADD COLUMN operator TEXT;
ALTER TABLE process_events ADD COLUMN params TEXT;

ALTER TABLE media_assets ADD COLUMN cert_type TEXT;
ALTER TABLE media_assets ADD COLUMN cert_number TEXT;
ALTER TABLE media_assets ADD COLUMN valid_until TEXT;
