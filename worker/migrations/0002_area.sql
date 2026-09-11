-- Bán kính vùng nguyên liệu, để bản đồ vẽ được một vùng thay vì một chấm.
--   wrangler d1 execute tule-trace --local  --file=./migrations/0002_area.sql
--   wrangler d1 execute tule-trace --remote --file=./migrations/0002_area.sql

ALTER TABLE ingredient_batches ADD COLUMN area_radius_km REAL;
