-- Đánh giá của người mua sau khi quét mã.
--
-- Cố ý nằm NGOÀI snapshot và ngoài mã băm. Snapshot là tuyên bố của nhà sản
-- xuất tại thời điểm công bố, đã neo lên blockchain; đánh giá do người mua gửi
-- sau đó và còn thêm tiếp. Nếu nhét vào payload thì mỗi đánh giá mới làm hash
-- lệch, lô hoá MISMATCH, và phải neo lại một giao dịch cho mỗi ngôi sao.
--
-- device_hash là SHA-256 của mã thiết bị do máy khách sinh ra, không phải mã
-- gốc: database không cần biết thiết bị nào, chỉ cần biết hai lần gửi có phải
-- cùng một máy hay không.
CREATE TABLE IF NOT EXISTS batch_ratings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_batch_id INTEGER NOT NULL REFERENCES product_batches(id) ON DELETE CASCADE,
  stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment TEXT NOT NULL DEFAULT '',
  display_name TEXT NOT NULL DEFAULT '',
  device_hash TEXT NOT NULL,
  -- APP | WEB: người dùng tự gửi. SURVEY: nhập từ phiếu khảo sát giấy.
  -- DEMO: dữ liệu dựng sẵn để thử giao diện, phải thay hết trước khi đưa cho
  -- người khác xem như số liệu thật.
  source TEXT NOT NULL DEFAULT 'APP',
  created_at TEXT NOT NULL
);

-- Một thiết bị đánh giá một lô một lần; gửi lại là sửa đánh giá cũ.
CREATE UNIQUE INDEX IF NOT EXISTS idx_ratings_once
  ON batch_ratings(product_batch_id, device_hash);

CREATE INDEX IF NOT EXISTS idx_ratings_batch
  ON batch_ratings(product_batch_id, created_at);
