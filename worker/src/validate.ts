import { ApiError, badRequest } from './errors';

/**
 * Bộ kiểm tra nhỏ thay cho class-validator (decorator không chạy gọn trên
 * Workers). Mục tiêu giống nhau: body sai phải dừng ở 400 với câu tiếng Việt,
 * không rơi xuống tầng database rồi thành 500.
 */
export function str(
  body: Record<string, unknown>,
  field: string,
  label: string,
  { min = 1, max = 2000, optional = false } = {},
): string {
  const raw = body[field];
  if (raw === undefined || raw === null || raw === '') {
    if (optional) return '';
    throw badRequest(`Thiếu ${label}.`);
  }
  if (typeof raw !== 'string') throw badRequest(`${label} phải là chuỗi.`);
  const value = raw.trim();
  if (!optional && value.length < min) {
    throw badRequest(`${label} quá ngắn (tối thiểu ${min} ký tự).`);
  }
  if (value.length > max) {
    throw badRequest(`${label} quá dài (tối đa ${max} ký tự).`);
  }
  return value;
}

/// Thứ tự trong danh sách: tuỳ chọn, và 0 là hợp lệ vì đó là vị trí đầu tiên.
export function optionalIndex(
  body: Record<string, unknown>,
  field: string,
  label: string,
): number | undefined {
  const raw = body[field];
  if (raw == null) return undefined;
  const value = typeof raw === 'string' ? Number(raw) : raw;
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
    throw badRequest(`${label} phải là số nguyên không âm.`);
  }
  return value;
}

/// Số nguyên tuỳ chọn: không khai thì trả undefined, khai sai vẫn báo lỗi.
export function optionalInt(
  body: Record<string, unknown>,
  field: string,
  label: string,
): number | undefined {
  if (body[field] == null) return undefined;
  return int(body, field, label);
}

/**
 * Chuỗi tuỳ chọn phân biệt ba trạng thái: không gửi khoá (undefined, giữ
 * nguyên giá trị cũ), gửi rỗng hoặc null (xoá), gửi nội dung (đặt giá trị).
 * `str(..., optional)` không phân biệt được hai trạng thái đầu nên không dùng
 * cho những trường mà người vận hành cần gỡ ra được.
 */
export function optionalText(
  body: Record<string, unknown>,
  field: string,
  label: string,
  max = 200,
): string | null | undefined {
  if (!(field in body)) return undefined;
  const raw = body[field];
  if (raw === null || raw === '') return null;
  if (typeof raw !== 'string') throw badRequest(`${label} phải là chuỗi.`);
  const value = raw.trim();
  if (!value) return null;
  if (value.length > max) {
    throw badRequest(`${label} quá dài (tối đa ${max} ký tự).`);
  }
  return value;
}

/**
 * Số thực không âm, tuỳ chọn. Dùng cho khối lượng vào/ra của công đoạn.
 * `null` là cách xoá giá trị đã nhập, khác với không khai (undefined).
 */
export function optionalAmount(
  body: Record<string, unknown>,
  field: string,
  label: string,
): number | null | undefined {
  const raw = body[field];
  if (raw === undefined) return undefined;
  if (raw === null || raw === '') return null;
  const value = typeof raw === 'string' ? Number(raw.replace(',', '.')) : raw;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) {
    throw badRequest(`${label} phải là số không âm.`);
  }
  if (value > 1e9) throw badRequest(`${label} vượt quá giới hạn cho phép.`);
  return value;
}

/**
 * Tham số công đoạn: một object phẳng nhãn → giá trị, ví dụ
 * `{"Nhiệt độ": "80-90°C", "Thời gian": "60 phút"}`. Giữ dạng tự do vì mỗi
 * công đoạn có bộ tham số khác nhau, nhưng chặn cấu trúc lồng nhau để payload
 * công bố còn đọc được và còn băm ổn định.
 */
export function optionalParams(
  body: Record<string, unknown>,
  field: string,
  label: string,
): Record<string, string> | null | undefined {
  const raw = body[field];
  if (raw === undefined) return undefined;
  if (raw === null) return null;
  if (typeof raw !== 'object' || Array.isArray(raw)) {
    throw badRequest(`${label} phải là một object nhãn và giá trị.`);
  }
  const entries = Object.entries(raw as Record<string, unknown>);
  if (entries.length > 12) throw badRequest(`${label} tối đa 12 dòng.`);
  const out: Record<string, string> = {};
  for (const [key, value] of entries) {
    const name = key.trim();
    if (!name) continue;
    if (name.length > 60) throw badRequest(`Nhãn tham số quá dài: ${name}.`);
    if (typeof value !== 'string' && typeof value !== 'number') {
      throw badRequest(`Giá trị của tham số ${name} phải là chuỗi hoặc số.`);
    }
    const text = String(value).trim();
    if (!text) continue;
    if (text.length > 200) throw badRequest(`Giá trị của tham số ${name} quá dài.`);
    out[name] = text;
  }
  return Object.keys(out).length === 0 ? null : out;
}

export function int(
  body: Record<string, unknown>,
  field: string,
  label: string,
): number {
  const raw = body[field];
  const value = typeof raw === 'string' ? Number(raw) : raw;
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
    throw badRequest(`Thiếu ${label} hợp lệ.`);
  }
  return value;
}

/// Toạ độ tuỳ chọn: chấp nhận null để xoá, chặn giá trị ngoài phạm vi thật.
export function coord(
  body: Record<string, unknown>,
  field: string,
  label: string,
  limit: number,
): number | null | undefined {
  const raw = body[field];
  if (raw === undefined) return undefined;
  if (raw === null || raw === '') return null;
  const value = typeof raw === 'string' ? Number(raw) : raw;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw badRequest(`${label} phải là số.`);
  }
  if (Math.abs(value) > limit) {
    throw badRequest(`${label} nằm ngoài phạm vi hợp lệ.`);
  }
  return value;
}

export function pathInt(raw: string | undefined, label: string): number {
  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) {
    throw badRequest(`${label} không hợp lệ.`);
  }
  return value;
}

export function oneOf<T extends string>(
  raw: unknown,
  allowed: readonly T[],
  label: string,
  fallback?: T,
): T {
  if ((raw === undefined || raw === '') && fallback !== undefined) {
    return fallback;
  }
  if (typeof raw === 'string' && (allowed as readonly string[]).includes(raw)) {
    return raw as T;
  }
  throw badRequest(`${label} phải là một trong: ${allowed.join(', ')}.`);
}

export async function jsonBody(
  request: Request,
): Promise<Record<string, unknown>> {
  try {
    const parsed = await request.json();
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw badRequest('Body phải là một object JSON.');
    }
    return parsed as Record<string, unknown>;
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw badRequest('Body không phải JSON hợp lệ.');
  }
}
