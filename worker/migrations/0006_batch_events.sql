-- Công đoạn của cả lô: phối trộn và đóng gói.
--
-- Tài liệu quy trình có hai công đoạn diễn ra ở xưởng chứ không thuộc riêng
-- nguyên liệu nào. Trước đây process_events buộc phải gắn vào một lô nguyên
-- liệu, nên muốn ghi "phối trộn" thì phải gắn nhờ vào cốm hoặc lạc — sai chỗ,
-- và trang công khai hiện nó nằm trong hồ sơ của nguyên liệu đó.
--
-- SQLite không bỏ được ràng buộc NOT NULL bằng ALTER, nên phải dựng lại bảng.
-- Giữ nguyên id khi chép sang: media của công đoạn trỏ vào id này, đổi id là
-- toàn bộ ảnh công đoạn thành mồ côi.

PRAGMA foreign_keys=OFF;

CREATE TABLE process_events_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ingredient_batch_id INTEGER REFERENCES ingredient_batches(id) ON DELETE CASCADE,
  product_batch_id INTEGER REFERENCES product_batches(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  event_date TEXT NOT NULL,
  entered_by TEXT NOT NULL DEFAULT 'admin',
  created_at TEXT NOT NULL,
  -- Một công đoạn thuộc về đúng một chỗ: hoặc một nguyên liệu, hoặc cả lô.
  CHECK (
    (ingredient_batch_id IS NOT NULL AND product_batch_id IS NULL)
    OR (ingredient_batch_id IS NULL AND product_batch_id IS NOT NULL)
  )
);

INSERT INTO process_events_new
  (id, ingredient_batch_id, product_batch_id, title, description, event_date, entered_by, created_at)
SELECT id, ingredient_batch_id, NULL, title, description, event_date, entered_by, created_at
  FROM process_events;

DROP TABLE process_events;
ALTER TABLE process_events_new RENAME TO process_events;

CREATE INDEX IF NOT EXISTS idx_events_ingredient ON process_events(ingredient_batch_id);
CREATE INDEX IF NOT EXISTS idx_events_product ON process_events(product_batch_id);

PRAGMA foreign_keys=ON;
