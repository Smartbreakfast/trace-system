-- Catalog sản phẩm tách khỏi các batch. product_id nullable để migration không
-- buộc phải rewrite các snapshot/hash đã công bố.
CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sku TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  template_key TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at TEXT NOT NULL
);

INSERT OR IGNORE INTO products (sku, name, description, template_key, status, created_at)
VALUES ('tule-breakfast', 'Tú Lệ Smart Breakfast',
        'Bột ngũ cốc dinh dưỡng từ nông sản bản địa.', 'tule-breakfast', 'ACTIVE',
        '2026-08-12T02:00:00.000Z');

ALTER TABLE product_batches ADD COLUMN product_id INTEGER REFERENCES products(id);

UPDATE product_batches
   SET product_id = (SELECT id FROM products WHERE sku = 'tule-breakfast')
 WHERE product_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_batches_product ON product_batches(product_id);
