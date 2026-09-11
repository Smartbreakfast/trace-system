-- Vùng nguyên liệu do nhà sản xuất tự khoanh, lưu dạng GeoJSON Polygon.
--   wrangler d1 execute tule-trace --local  --file=./migrations/0003_area_polygon.sql
--   wrangler d1 execute tule-trace --remote --file=./migrations/0003_area_polygon.sql

ALTER TABLE ingredient_batches ADD COLUMN area_geojson TEXT;
