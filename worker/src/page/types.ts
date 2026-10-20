/// Hình dạng dữ liệu công khai của một lô, đúng thứ `trace.publicTrace` trả về.
/// Khai báo lại ở đây để phần dựng trang không phải đoán tên trường.

export interface MediaItem {
  role: string;
  kind: string;
  url: string;
  fileName?: string;
  contentType?: string;
  caption?: string;
  certType?: string;
  certNumber?: string;
  validUntil?: string;
}

export interface ProcessEventItem {
  title?: string;
  description?: string;
  eventDate?: string;
  enteredBy?: string;
  operator?: string;
  inputQuantity?: number | null;
  outputQuantity?: number | null;
  quantityUnit?: string;
  params?: Record<string, string> | string | null;
  media?: MediaItem[];
}

export interface IngredientItem {
  name?: string;
  origin?: string;
  supplier?: string;
  harvestDate?: string;
  receivedDate?: string;
  summary?: string;
  media?: MediaItem[];
  processEvents?: ProcessEventItem[];
}

export interface ChainInfo {
  status?: string;
  txHash?: string;
  blockNumber?: string;
  chainId?: number | null;
  contract?: string;
  explorer?: string;
}

export interface IntegrityInfo {
  status?: string;
  version?: number;
  snapshotHash?: string;
  currentHash?: string;
  publishedBy?: string;
  publishedAt?: string;
  chain?: ChainInfo;
}

export interface RatingComment {
  stars: number;
  comment: string;
  displayName?: string;
  createdAt?: string;
}

export interface RatingInfo {
  count: number;
  average: number;
  distribution?: Record<string, number>;
  comments?: RatingComment[];
}

export interface PublicTrace {
  code: string;
  name: string;
  productionDate?: string;
  expiryDate?: string;
  description?: string;
  facilityName?: string;
  media?: MediaItem[];
  ingredients?: IngredientItem[];
  batchEvents?: ProcessEventItem[];
  status?: string;
  integrity?: IntegrityInfo;
  /// Đánh giá của người mua, nằm ngoài snapshot nên không ảnh hưởng mã băm.
  ratings?: RatingInfo;
}

export interface BatchRef {
  code: unknown;
  name: unknown;
  productionDate?: unknown;
  status?: unknown;
}

export interface PublicProduct {
  sku: string;
  name: string;
  description?: string;
  templateKey?: string;
  batches: BatchRef[];
}
