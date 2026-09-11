/// Kiểu binding của worker, tách riêng để chain.ts và trace.ts dùng chung mà
/// không phải nhập ngược từ index.ts (vòng nhập).
export interface Env {
  DB: D1Database;
  MEDIA: R2Bucket;
  ASSETS: Fetcher;
  ADMIN_TOKEN?: string;
  MAX_UPLOAD_BYTES?: string;

  // Nối chuỗi. Thiếu bất kỳ giá trị nào thì mã băm nằm lại hàng chờ, hệ thống
  // vẫn chạy bình thường.
  CHAIN_RPC_URL?: string;
  CHAIN_ID?: string;
  CHAIN_EXPLORER?: string;
  TRACE_CONTRACT?: string;
  PRIVATE_KEY?: string;
  /// 'false' để tắt neo tự động; nút gửi tay vẫn chạy.
  CHAIN_AUTO_ANCHOR?: string;
}
