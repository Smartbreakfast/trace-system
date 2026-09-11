/// Bộ biểu tượng dùng lại đúng những hình của bản Flutter (Material
/// Outlined), vẽ thành SVG nét mảnh để không phải tải một bộ font icon 16KB
/// chỉ để hiện chục cái hình.

function svg(body: string, size = 18): string {
  return (
    `<svg class="ic" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" ` +
    'stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" ' +
    `aria-hidden="true">${body}</svg>`
  );
}

/** Thùng hàng: mục Thông tin chung. */
export const iconBox = (size?: number) =>
  svg('<path d="M3 8.5l9-5 9 5v7l-9 5-9-5z"/><path d="M3 8.5l9 5 9-5"/><path d="M12 13.5V20"/>', size);

/** Sơ đồ nhánh: mục Nguồn gốc. */
export const iconTree = (size?: number) =>
  svg(
    '<rect x="9" y="3" width="6" height="4.5" rx="1"/><rect x="3" y="16.5" width="6" height="4.5" rx="1"/>' +
      '<rect x="15" y="16.5" width="6" height="4.5" rx="1"/><path d="M12 7.5v4M6 16.5v-2.5h12v2.5"/>',
    size,
  );

/** Huy hiệu kiểm định: mục Kiểm định chất lượng. */
export const iconVerified = (size?: number) =>
  svg('<circle cx="12" cy="12" r="9"/><path d="M8 12.4l2.6 2.6L16 9.6"/>', size);

export const iconCalendar = (size?: number) =>
  svg('<rect x="3.5" y="5" width="17" height="16" rx="2"/><path d="M8 3v4M16 3v4M3.5 10h17"/>', size);

export const iconTag = (size?: number) =>
  svg('<path d="M3.5 11.5V4.5A1 1 0 0 1 4.5 3.5h7l9 9-8 8z"/><circle cx="8" cy="8" r="1.4"/>', size);

/** Giấy chứng nhận. */
export const iconAward = (size?: number) =>
  svg('<circle cx="12" cy="9" r="5.5"/><path d="M8.5 13.5L7 21l5-2.5L17 21l-1.5-7.5"/>', size);

/** Phiếu kiểm nghiệm. */
export const iconFlask = (size?: number) =>
  svg('<path d="M10 3v6.2L4.8 18a2 2 0 0 0 1.7 3h11a2 2 0 0 0 1.7-3L14 9.2V3"/><path d="M8.5 3h7M7.5 15h9"/>', size);

export const iconClock = (size?: number) =>
  svg('<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/>', size);

export const iconStep = (size?: number) =>
  svg('<path d="M4 7h10M4 12h16M4 17h7"/><circle cx="18" cy="7" r="2"/><circle cx="13" cy="17" r="2"/>', size);

export const iconShield = (size?: number) =>
  svg('<path d="M12 3l7.5 3v5.5c0 4.3-3.2 7.6-7.5 9.5-4.3-1.9-7.5-5.2-7.5-9.5V6z"/><path d="M9 12.4l2.2 2.2 4-4"/>', size);

export const iconOpen = (size?: number) =>
  svg('<path d="M14 4h6v6"/><path d="M20 4l-8.5 8.5"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>', size);

export const iconBack = (size?: number) =>
  svg('<path d="M15 5l-7 7 7 7"/>', size);

export const iconPerson = (size?: number) =>
  svg('<circle cx="12" cy="8.5" r="3.8"/><path d="M4.5 20a7.5 7.5 0 0 1 15 0"/>', size);

/// Bốn hình nguyên liệu, đúng bộ của bản Flutter: cỏ lúa, lá kép, mầm, hoa.
/// Dùng trong ô vùng nguyên liệu trên sơ đồ và ở đầu hồ sơ nguyên liệu.
const INGREDIENT_PATHS = [
  // grass
  '<path d="M4 20c0-5 3-8 5-9M12 20c0-7 3-11 6-13M8 20c0-4 1.5-7 3-9"/>',
  // spa
  '<path d="M12 20c-4-2-6-5-6-8 3 0 5 1 6 3 1-2 3-3 6-3 0 3-2 6-6 8z"/><path d="M12 15c0-4 2-7 5-9-3-1-7 1-8 4"/>',
  // eco
  '<path d="M5 19c0-8 6-13 14-13 0 8-5 13-13 13"/><path d="M8 16c2-4 5-6 8-7"/>',
  // local_florist
  '<circle cx="12" cy="12" r="2.5"/><path d="M12 9.5c0-3 1.5-4.5 3.5-4.5S18 7 16 9M12 14.5c0 3-1.5 4.5-3.5 4.5S6 17 8 15M9.5 12c-3 0-4.5-1.5-4.5-3.5S7 6 9 8M14.5 12c3 0 4.5 1.5 4.5 3.5S17 18 15 16"/>',
];

export function ingredientIcon(index: number, size = 18): string {
  return svg(INGREDIENT_PATHS[index % INGREDIENT_PATHS.length], size);
}

/** Bản dùng trong SVG sơ đồ: không có thẻ svg lồng, chỉ là nhóm đường nét. */
export function ingredientGlyph(index: number, x: number, y: number, colour: string): string {
  const scale = 0.75;
  return (
    `<g transform="translate(${x} ${y}) scale(${scale})" fill="none" stroke="${colour}" ` +
    'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">' +
    INGREDIENT_PATHS[index % INGREDIENT_PATHS.length] +
    '</g>'
  );
}
