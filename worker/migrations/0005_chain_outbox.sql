-- Hàng chờ ghi chuỗi cần nhớ đã thử mấy lần và hỏng vì gì, nếu không thì một
-- giao dịch thất bại sẽ im lặng nằm đó mãi mà không ai biết.

ALTER TABLE blockchain_outbox ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE blockchain_outbox ADD COLUMN last_error TEXT;
ALTER TABLE blockchain_outbox ADD COLUMN sent_at TEXT;
ALTER TABLE blockchain_outbox ADD COLUMN chain_id INTEGER;
ALTER TABLE blockchain_outbox ADD COLUMN block_number TEXT;
ALTER TABLE blockchain_outbox ADD COLUMN contract TEXT;

CREATE INDEX IF NOT EXISTS idx_outbox_snapshot ON blockchain_outbox(snapshot_id);
