/**
 * Lỗi có mã HTTP và thông báo tiếng Việt đọc được.
 *
 * Bản NestJS trước đây để lỗi SQLite lọt thẳng ra client dưới dạng 500, còn mã
 * truy xuất sai lại trả 200 kèm `{error}`. Client và cả công cụ giám sát đều
 * không phân biệt được "người dùng gõ sai" với "hệ thống hỏng".
 */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }

  toResponse() {
    return Response.json(
      { error: this.code, message: this.message },
      { status: this.status },
    );
  }
}

export function badRequest(message: string) {
  return new ApiError(400, 'VALIDATION_FAILED', message);
}
