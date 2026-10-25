-- Hai bảng chỉ số cho báo cáo: một bảng hệ thống tự đếm, một bảng do cơ sở
-- sản xuất khai.
--
-- Cả hai nằm NGOÀI snapshot và ngoài mã băm, cùng lý do với batch_ratings ở
-- 0012: snapshot là tuyên bố của nhà sản xuất tại thời điểm công bố và đã neo
-- lên blockchain. Thêm một trường vào payload là 8 lô đang ĐÃ XÁC MINH hoá
-- SAI LỆCH ngay.

-- Lượt mở hồ sơ của từng lô. Chỉ một con số: không ghi IP, không ghi thiết bị,
-- không ghi thời điểm từng lượt. Đây là điều kiện để còn khai được "ứng dụng
-- không thu thập dữ liệu" trong hồ sơ App Store.
CREATE TABLE IF NOT EXISTS batch_views (
  product_batch_id INTEGER PRIMARY KEY REFERENCES product_batches(id) ON DELETE CASCADE,
  views INTEGER NOT NULL DEFAULT 0,
  first_at TEXT NOT NULL,
  last_at TEXT NOT NULL
);

-- Chỉ số do cơ sở sản xuất cung cấp, hệ thống không tự đo được: số khách đã
-- mua, số phiếu khảo sát, lượt truy cập giai đoạn trước khi bật bộ đếm.
--
-- Cột `source` là bắt buộc và phải ghi rõ số này lấy ở đâu. Một con số không
-- nói được nguồn thì không đưa vào báo cáo được, nên không cho phép để trống.
CREATE TABLE IF NOT EXISTS reported_metrics (
  key TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  value TEXT NOT NULL,
  source TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL,
  updated_by TEXT NOT NULL DEFAULT ''
);
