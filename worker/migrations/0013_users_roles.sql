-- Tài khoản và phân quyền theo vai trò.
--
-- Trước migration này toàn bộ /api/admin/* mở bằng MỘT token dùng chung, nên
-- không thể nói "ai khai báo công đoạn nào": mọi thao tác đều là "admin". Báo
-- cáo lại mô tả nhân viên từng công đoạn có tài khoản riêng. Bảng dưới đây là
-- phần làm thật của câu đó.
--
-- Ba vai trò, đặt theo đúng việc có thật ở hai cơ sở:
--   ADMIN    quản trị hệ thống: thấy mọi cơ sở, quản lý tài khoản.
--   FACILITY người phụ trách một cơ sở: toàn quyền trên dữ liệu cơ sở mình,
--            kể cả công bố lô.
--   STAFF    nhân viên công đoạn: chỉ khai công đoạn và đính ảnh cho lô của cơ
--            sở mình, KHÔNG được tạo lô, KHÔNG được công bố.
--
-- Dữ liệu người khai báo nằm NGOÀI vùng được băm (bảng audit_log, cột
-- entered_by sẵn có). Thêm tên người vào payload công bố sẽ làm mã băm của 8
-- lô đã neo lệch đi và cả 8 lô lập tức chuyển sang SAI LỆCH; xem
-- worker/src/trace.ts, hàm verify().

CREATE TABLE IF NOT EXISTS facilities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);

INSERT OR IGNORE INTO facilities (code, name, created_at) VALUES
  ('TULE', 'Cơ sở Tú Lệ Smart Breakfast', '2026-10-23T00:00:00.000Z'),
  ('TRAU', 'Cơ sở chế biến thịt trâu gác bếp', '2026-10-23T00:00:00.000Z');

-- Cơ sở gắn ở catalog sản phẩm, không gắn ở từng lô: một mã sản phẩm chỉ do
-- một cơ sở làm, còn lô thì sinh ra liên tục. Lô suy ra cơ sở qua product_id.
ALTER TABLE products ADD COLUMN facility_id INTEGER REFERENCES facilities(id);

UPDATE products
   SET facility_id = (SELECT id FROM facilities WHERE code = 'TRAU')
 WHERE sku IN ('buffalo-dried', 'ingredient-thit-trau-tuoi');

UPDATE products
   SET facility_id = (SELECT id FROM facilities WHERE code = 'TULE')
 WHERE facility_id IS NULL;

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL CHECK (role IN ('ADMIN', 'FACILITY', 'STAFF')),
  -- NULL chỉ hợp lệ với ADMIN; hai vai trò còn lại luôn thuộc một cơ sở.
  facility_id INTEGER REFERENCES facilities(id),
  -- Dạng pbkdf2$<số vòng>$<salt base64>$<hash base64>. Không lưu mật khẩu gốc,
  -- không có đường nào đọc lại được mật khẩu từ bảng này.
  password_hash TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  last_login_at TEXT
);

-- Lưu mã băm của token phiên, không lưu token. Rò bảng này cũng không ai đăng
-- nhập được bằng nội dung trong đó.
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);

-- Nhật ký thao tác: ai, vai trò gì, làm gì, trên lô nào, lúc nào. Đây là chỗ
-- trả lời câu "mỗi người tự khai báo" bằng bằng chứng.
CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER REFERENCES users(id),
  username TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT '',
  action TEXT NOT NULL,
  target TEXT NOT NULL DEFAULT '',
  detail TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_users_facility ON users(facility_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_target ON audit_log(target, created_at DESC);
