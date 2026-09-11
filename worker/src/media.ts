import { sha256Hex } from './canonical';
import { ApiError, badRequest } from './errors';
import type { OwnerType, Row } from './trace';

export type MediaKind = 'image' | 'video' | 'document';
export type MediaRole =
  | 'cover'
  | 'gallery'
  | 'lab_report'
  | 'certificate'
  | 'area_map';

export const mediaRoles = [
  'cover',
  'gallery',
  'lab_report',
  // Giấy chứng nhận (OCOP, VietGAP, ATTP...). Tách khỏi lab_report vì
  // phiếu kiểm nghiệm là kết quả của một mẻ, còn chứng nhận là của cơ sở
  // và có hạn hiệu lực riêng.
  'certificate',
  // Ảnh chụp vùng nguyên liệu. Thay cho bản đồ chạy tile: hồ sơ chỉ cần
  // chứng minh vùng ở đâu, không cần một bản đồ tương tác nặng 300KB.
  'area_map',
] as const;

/// Loại giấy chứng nhận được chấp nhận; 'Khác' cho trường hợp ngoài danh sách.
export const certTypes = [
  'OCOP',
  'VietGAP',
  'ATTP',
  'HACCP',
  'ISO 22000',
  'Hữu cơ',
  'Khác',
] as const;

/**
 * Danh sách trắng thay vì tin vào content-type do trình duyệt gửi lên.
 * Đuôi file suy ra từ đây, không lấy từ tên file người dùng đặt.
 */
const allowedTypes: Record<string, { kind: MediaKind; ext: string }> = {
  'image/jpeg': { kind: 'image', ext: 'jpg' },
  'image/png': { kind: 'image', ext: 'png' },
  'image/webp': { kind: 'image', ext: 'webp' },
  'image/avif': { kind: 'image', ext: 'avif' },
  'image/gif': { kind: 'image', ext: 'gif' },
  'video/mp4': { kind: 'video', ext: 'mp4' },
  'video/webm': { kind: 'video', ext: 'webm' },
  'video/quicktime': { kind: 'video', ext: 'mov' },
  'application/pdf': { kind: 'document', ext: 'pdf' },
};

export const allowedContentTypes = Object.keys(allowedTypes);

/**
 * Chữ ký nhị phân của vài định dạng phổ biến. Trình duyệt có thể khai sai
 * content-type, nên đọc thêm vài byte đầu để chắc file đúng như nó nói.
 */
function sniff(bytes: Uint8Array): string | null {
  const startsWith = (...signature: number[]) =>
    signature.every((byte, index) => bytes[index] === byte);

  if (startsWith(0xff, 0xd8, 0xff)) return 'image/jpeg';
  if (startsWith(0x89, 0x50, 0x4e, 0x47)) return 'image/png';
  if (startsWith(0x47, 0x49, 0x46, 0x38)) return 'image/gif';
  if (startsWith(0x25, 0x50, 0x44, 0x46)) return 'application/pdf';
  if (startsWith(0x1a, 0x45, 0xdf, 0xa3)) return 'video/webm';

  const ascii = (offset: number, text: string) =>
    [...text].every((char, index) => bytes[offset + index] === char.charCodeAt(0));

  if (ascii(0, 'RIFF') && ascii(8, 'WEBP')) return 'image/webp';
  if (ascii(4, 'ftyp')) {
    const brand = String.fromCharCode(...bytes.slice(8, 12));
    if (brand === 'qt  ') return 'video/quicktime';
    if (brand.startsWith('avif') || brand.startsWith('avis')) return 'image/avif';
    return 'video/mp4';
  }
  return null;
}

export interface UploadInput {
  file: File;
  ownerType: OwnerType;
  ownerId: number;
  role: MediaRole;
  caption: string;
  maxBytes: number;
  certType?: string | null;
  certNumber?: string | null;
  validUntil?: string | null;
}

export async function storeUpload(
  db: D1Database,
  bucket: R2Bucket,
  input: UploadInput,
) {
  const { file, maxBytes } = input;
  if (file.size === 0) throw badRequest('File rỗng.');
  if (file.size > maxBytes) {
    const mb = Math.round(maxBytes / (1024 * 1024));
    throw badRequest(`File vượt quá ${mb}MB.`);
  }

  const bytes = new Uint8Array(await file.arrayBuffer());
  const sniffed = sniff(bytes);
  const declared = (file.type || '').split(';')[0].trim().toLowerCase();
  const contentType = sniffed ?? declared;

  const meta = allowedTypes[contentType];
  if (!meta) {
    throw badRequest(
      'Định dạng không được hỗ trợ. Chấp nhận ảnh JPG/PNG/WebP/AVIF/GIF, video MP4/WebM/MOV và tài liệu PDF.',
    );
  }
  if (sniffed && declared && sniffed !== declared) {
    throw badRequest('Nội dung file không khớp với định dạng khai báo.');
  }
  if (input.role === 'lab_report' && meta.kind === 'video') {
    throw badRequest('Hồ sơ kiểm nghiệm nên là ảnh chụp hoặc file PDF.');
  }
  if (input.role === 'certificate' && meta.kind === 'video') {
    throw badRequest('Giấy chứng nhận nên là ảnh chụp hoặc file PDF.');
  }
  if (input.role === 'area_map' && meta.kind !== 'image') {
    throw badRequest('Ảnh vùng nguyên liệu phải là một file ảnh.');
  }

  // Khoá chứa hash nội dung: cùng một file tải lên hai lần dùng chung một object,
  // và đổi nội dung thì bắt buộc đổi khoá nên snapshot bắt được ngay.
  const digest = await sha256Hex(bytes);
  const key = `media/${digest}.${meta.ext}`;

  const existing = await bucket.head(key);
  if (!existing) {
    await bucket.put(key, bytes, {
      httpMetadata: {
        contentType,
        cacheControl: 'public, max-age=31536000, immutable',
      },
    });
  }

  const row = await db
    .prepare(
      `INSERT INTO media_assets
         (owner_type, owner_id, role, kind, r2_key, file_name, content_type,
          size, sha256, caption, created_at, cert_type, cert_number, valid_until)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       RETURNING id`,
    )
    .bind(
      input.ownerType,
      input.ownerId,
      input.role,
      meta.kind,
      key,
      safeFileName(file.name, meta.ext),
      contentType,
      file.size,
      digest,
      input.caption,
      new Date().toISOString(),
      // Chỉ giấy chứng nhận mới mang ba trường này; vai trò khác luôn để NULL
      // để chúng không lọt vào payload công bố.
      input.role === 'certificate' ? input.certType || null : null,
      input.role === 'certificate' ? input.certNumber || null : null,
      input.role === 'certificate' ? input.validUntil || null : null,
    )
    .first<Row>();

  return {
    id: row?.id,
    ownerType: input.ownerType,
    ownerId: input.ownerId,
    role: input.role,
    kind: meta.kind,
    url: `/api/media/${key}`,
    fileName: safeFileName(file.name, meta.ext),
    contentType,
    size: file.size,
    sha256: digest,
    caption: input.caption,
  };
}

/** Tên file chỉ để hiển thị, nên cắt sạch đường dẫn và ký tự lạ. */
function safeFileName(raw: string, ext: string) {
  const base = (raw || 'file')
    .split(/[\\/]/)
    .pop()!
    .replace(/[^\p{L}\p{N}._-]+/gu, '-')
    .slice(0, 80);
  return base.includes('.') ? base : `${base}.${ext}`;
}

export async function deleteMedia(
  db: D1Database,
  bucket: R2Bucket,
  id: number,
) {
  const row = await db
    .prepare('SELECT * FROM media_assets WHERE id = ?')
    .bind(id)
    .first<Row>();
  if (!row) throw new ApiError(404, 'MEDIA_NOT_FOUND', 'Không tìm thấy media.');

  await db.prepare('DELETE FROM media_assets WHERE id = ?').bind(id).run();

  // Object trong R2 dùng chung theo hash, chỉ xoá khi không còn bản ghi nào trỏ tới.
  const remaining = await db
    .prepare('SELECT COUNT(*) as count FROM media_assets WHERE r2_key = ?')
    .bind(row.r2_key)
    .first<Row>();

  // Và cũng chỉ xoá khi không bản công bố nào còn trỏ tới file này. Khoá R2 nằm
  // trong snapshot đem đi băm, nên xoá file là làm hỏng chính bản đã ghi lên
  // chuỗi: mã băm vẫn đúng nhưng nội dung không dựng lại được nữa.
  // Dùng instr chứ không LIKE: SQLite từ chối mẫu LIKE ghép chuỗi kiểu này
  // ("LIKE or GLOB pattern too complex"), còn instr là tìm chuỗi con thẳng.
  const inSnapshot = await db
    .prepare(
      'SELECT COUNT(*) as count FROM published_snapshots WHERE instr(payload, ?) > 0',
    )
    .bind(row.r2_key)
    .first<Row>();

  const stillReferenced =
    Number(remaining?.count ?? 0) > 0 || Number(inSnapshot?.count ?? 0) > 0;
  if (!stillReferenced) {
    await bucket.delete(String(row.r2_key));
  }
  return {
    deleted: id,
    // Nói rõ file còn nằm lại vì bản công bố cũ, để người vận hành không tưởng
    // đã xoá sạch.
    fileKept: Number(inSnapshot?.count ?? 0) > 0,
  };
}

/**
 * Trả file từ R2, có hỗ trợ Range để video tua được và trình duyệt phát dần.
 */
export async function serveMedia(
  bucket: R2Bucket,
  key: string,
  request: Request,
): Promise<Response> {
  if (!/^media\/[0-9a-f]{64}\.[a-z0-9]{2,5}$/.test(key)) {
    return Response.json(
      { error: 'MEDIA_NOT_FOUND', message: 'Khoá media không hợp lệ.' },
      { status: 404 },
    );
  }

  // R2 nhận thẳng Headers để tự đọc `Range`, không cần tự parse chuỗi byte.
  const wantsRange = request.headers.has('range');
  const object = wantsRange
    ? await bucket.get(key, { range: request.headers })
    : await bucket.get(key);
  if (!object) {
    return Response.json(
      { error: 'MEDIA_NOT_FOUND', message: 'Không tìm thấy file.' },
      { status: 404 },
    );
  }

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);
  headers.set('accept-ranges', 'bytes');
  // Nội dung định danh bằng hash nên không bao giờ đổi: cache vĩnh viễn.
  headers.set('cache-control', 'public, max-age=31536000, immutable');
  headers.set('x-content-type-options', 'nosniff');
  // File do admin tải lên: không cho trình duyệt chạy như tài liệu cùng origin.
  headers.set('content-security-policy', "default-src 'none'; sandbox");

  // R2 vẫn đính `range` cho cả lần đọc trọn file, nên chỉ trả 206 khi client
  // thực sự hỏi Range.
  if (wantsRange && object.range && 'offset' in object.range) {
    const offset = object.range.offset ?? 0;
    const length = object.range.length ?? object.size - offset;
    headers.set(
      'content-range',
      `bytes ${offset}-${offset + length - 1}/${object.size}`,
    );
    return new Response(object.body, { status: 206, headers });
  }

  return new Response(object.body, { headers });
}
