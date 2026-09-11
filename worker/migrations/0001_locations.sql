-- Thêm toạ độ để vẽ bản đồ vùng nguyên liệu.
-- Chạy cho database đã có dữ liệu:
--   wrangler d1 execute tule-trace --local  --file=./migrations/0001_locations.sql
--   wrangler d1 execute tule-trace --remote --file=./migrations/0001_locations.sql
-- Database mới thì schema.sql đã có sẵn các cột này.

ALTER TABLE product_batches ADD COLUMN facility_name TEXT NOT NULL DEFAULT '';
ALTER TABLE product_batches ADD COLUMN latitude REAL;
ALTER TABLE product_batches ADD COLUMN longitude REAL;

ALTER TABLE ingredient_batches ADD COLUMN latitude REAL;
ALTER TABLE ingredient_batches ADD COLUMN longitude REAL;
