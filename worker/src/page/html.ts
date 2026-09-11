/// Tiện ích dựng HTML. Mọi chuỗi đi vào trang đều qua `esc`, trừ những mảnh
/// do chính các hàm ở đây sinh ra.

/** Thoát ký tự để chuỗi bất kỳ nằm an toàn trong thân HTML hoặc thuộc tính. */
export function esc(value: unknown): string {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** Nối các mảnh, bỏ qua mảnh rỗng. Dùng thay cho `if` rải khắp template. */
export function join(...parts: (string | false | null | undefined)[]): string {
  return parts.filter(Boolean).join('');
}

/** Một ô nhãn - giá trị, bản HTML của `InfoPill`. */
export function pill(label: string, value: string): string {
  if (!value) return '';
  return `<div class="pill"><span class="pill-l">${esc(label)}</span><span class="pill-v">${esc(value)}</span></div>`;
}

export function eyebrow(text: string): string {
  return `<p class="eyebrow">${esc(text)}</p>`;
}

export function heading(text: string): string {
  return `<h3 class="sec-head"><span class="sec-bar"></span>${esc(text)}</h3>`;
}
