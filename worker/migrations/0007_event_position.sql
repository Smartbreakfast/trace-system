-- Thứ tự công đoạn phải là dữ liệu, không phải suy từ ngày.
--
-- Bảy bước của khoai môn diễn ra trong cùng một ngày, nên sắp theo ngày thì
-- thứ tự rơi về id — đúng lúc mới nhập, sai ngay khi bổ sung một bước còn
-- thiếu vào giữa quy trình.

ALTER TABLE process_events ADD COLUMN position INTEGER NOT NULL DEFAULT 0;

-- Dữ liệu cũ giữ nguyên thứ tự đang hiển thị.
UPDATE process_events
   SET position = (
     SELECT COUNT(*)
       FROM process_events older
      WHERE older.id < process_events.id
        AND (
          (process_events.ingredient_batch_id IS NOT NULL
           AND older.ingredient_batch_id = process_events.ingredient_batch_id)
          OR (process_events.product_batch_id IS NOT NULL
              AND older.product_batch_id = process_events.product_batch_id)
        )
   );

CREATE INDEX IF NOT EXISTS idx_events_position ON process_events(ingredient_batch_id, position);
