/**
 * Canonical JSON: khoá sắp xếp ổn định, chuẩn hoá unicode NFC.
 *
 * Hash phải độc lập với chi tiết lưu trữ. Nếu băm thẳng JSON.stringify của row
 * database thì thứ tự khoá phụ thuộc thứ tự cột, chỉ cần một lần đổi schema là
 * mọi snapshot cũ hoá MISMATCH dù dữ liệu không đổi.
 */
export function canonicalize(value: unknown): string {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'string') return JSON.stringify(value.normalize('NFC'));
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) return 'null';
    return JSON.stringify(value);
  }
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (Array.isArray(value)) return `[${value.map(canonicalize).join(',')}]`;
  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([, item]) => item !== undefined)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
    return `{${entries
      .map(([key, item]) => `${JSON.stringify(key)}:${canonicalize(item)}`)
      .join(',')}}`;
  }
  return 'null';
}

/** Workers không có node:crypto sync, dùng WebCrypto nên mọi hàm hash là async. */
export async function sha256Hex(data: ArrayBuffer | Uint8Array): Promise<string> {
  const buffer = data instanceof Uint8Array ? bufferOf(data) : data;
  const digest = await crypto.subtle.digest('SHA-256', buffer);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function bufferOf(view: Uint8Array): ArrayBuffer {
  return view.byteOffset === 0 && view.byteLength === view.buffer.byteLength
    ? (view.buffer as ArrayBuffer)
    : (view.slice().buffer as ArrayBuffer);
}

export function sha256Of(value: unknown): Promise<string> {
  return sha256Hex(new TextEncoder().encode(canonicalize(value)));
}
