-- Cho phép mỗi nguyên liệu có product/batch và QR truy xuất riêng.
ALTER TABLE products ADD COLUMN product_kind TEXT NOT NULL DEFAULT 'finished';
ALTER TABLE ingredient_batches ADD COLUMN source_product_batch_id INTEGER REFERENCES product_batches(id);

CREATE INDEX IF NOT EXISTS idx_ingredient_source_batch
  ON ingredient_batches(source_product_batch_id);
