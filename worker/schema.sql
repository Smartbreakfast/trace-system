-- Schema D1 cho Tú Lệ Trace. D1 chạy SQLite nên gần như giữ nguyên schema cũ,
-- phần thêm mới là bảng media_assets cho ảnh, video và hồ sơ kiểm nghiệm.

CREATE TABLE IF NOT EXISTS product_batches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  production_date TEXT NOT NULL,
  expiry_date TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'DRAFT',
  -- Nơi sản xuất: điểm hội tụ của mọi nguyên liệu trên bản đồ.
  facility_name TEXT NOT NULL DEFAULT '',
  latitude REAL,
  longitude REAL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ingredient_batches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_batch_id INTEGER NOT NULL REFERENCES product_batches(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  origin TEXT NOT NULL,
  supplier TEXT NOT NULL DEFAULT '',
  harvest_date TEXT NOT NULL DEFAULT '',
  received_date TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL DEFAULT '',
  -- Toạ độ chính xác của vùng trồng. Bỏ trống thì bản đồ rơi về tâm tỉnh suy
  -- từ `origin`, và giao diện phải nói rõ đó là vị trí tương đối.
  latitude REAL,
  longitude REAL,
  -- Bán kính vùng trồng tính bằng km. Có giá trị thì bản đồ tô một vòng tròn
  -- quanh toạ độ thay vì chấm một điểm.
  area_radius_km REAL,
  -- Vùng nguyên liệu do nhà sản xuất tự khoanh trên bản đồ, GeoJSON Polygon
  -- hoặc MultiPolygon. Có giá trị thì nó thắng bán kính, vì đây mới là hình
  -- thật của vùng thu mua chứ không phải một vòng tròn xấp xỉ.
  area_geojson TEXT
);

CREATE TABLE IF NOT EXISTS process_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ingredient_batch_id INTEGER NOT NULL REFERENCES ingredient_batches(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  event_date TEXT NOT NULL,
  entered_by TEXT NOT NULL DEFAULT 'admin',
  created_at TEXT NOT NULL,
  -- Chi tiết công đoạn. Để NULL khi không khai; trường rỗng không vào payload
  -- công bố nên mã băm của lô cũ không đổi khi thêm các cột này.
  input_quantity REAL,
  output_quantity REAL,
  quantity_unit TEXT,
  operator TEXT,                     -- người trực tiếp làm, khác entered_by
  params TEXT                        -- JSON: nhiệt độ, thời gian, tỷ lệ
);

-- Khoá R2 chứa luôn sha256 của nội dung file (content addressed). Nhờ vậy
-- thay ảnh khác thì khoá cũng khác, và khoá nằm trong snapshot nên việc tráo
-- ảnh sau khi công bố cũng bị bắt như tráo chữ.
CREATE TABLE IF NOT EXISTS media_assets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_type TEXT NOT NULL,          -- product_batch | ingredient_batch | process_event
  owner_id INTEGER NOT NULL,
  role TEXT NOT NULL DEFAULT 'gallery', -- cover | gallery | lab_report | certificate
  kind TEXT NOT NULL,                -- image | video | document
  r2_key TEXT NOT NULL,
  file_name TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size INTEGER NOT NULL,
  sha256 TEXT NOT NULL,
  caption TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  -- Chỉ dùng cho role = certificate: loại giấy, số hiệu và hạn hiệu lực.
  cert_type TEXT,                    -- OCOP | VietGAP | ATTP | ISO | HACCP | khác
  cert_number TEXT,
  valid_until TEXT
);

CREATE TABLE IF NOT EXISTS published_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_batch_id INTEGER NOT NULL REFERENCES product_batches(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  payload TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  published_by TEXT NOT NULL,
  published_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS blockchain_outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  snapshot_id INTEGER NOT NULL REFERENCES published_snapshots(id) ON DELETE CASCADE,
  batch_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING_NETWORK',
  tx_hash TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ingredients_product ON ingredient_batches(product_batch_id);
CREATE INDEX IF NOT EXISTS idx_events_ingredient ON process_events(ingredient_batch_id);
CREATE INDEX IF NOT EXISTS idx_media_owner ON media_assets(owner_type, owner_id);
CREATE INDEX IF NOT EXISTS idx_snapshots_product ON published_snapshots(product_batch_id, version DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_snapshots_version ON published_snapshots(product_batch_id, version);
CREATE INDEX IF NOT EXISTS idx_outbox_status ON blockchain_outbox(status);
