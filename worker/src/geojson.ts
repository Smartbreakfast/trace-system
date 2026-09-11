import { badRequest } from './errors';

/** Số đỉnh tối đa của một vùng, đủ rộng cho một hình vẽ tay và đủ chặt để một
 * request không nhét được cả file bản đồ vào database. */
const MAX_POINTS = 2000;

/**
 * Kiểm tra một vùng nguyên liệu do người vận hành khoanh.
 *
 * Chỉ nhận Polygon hoặc MultiPolygon, toạ độ trong phạm vi hợp lệ, vòng khép
 * kín và đủ ba đỉnh. Trả về chuỗi đã chuẩn hoá để lưu, hoặc null khi xoá vùng.
 */
export function normalizeArea(raw: unknown): string | null | undefined {
  if (raw === undefined) return undefined;
  if (raw === null || raw === '') return null;
  if (typeof raw !== 'string') {
    throw badRequest('Vùng nguyên liệu phải là chuỗi GeoJSON.');
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw badRequest('Vùng nguyên liệu không phải JSON hợp lệ.');
  }

  const geometry = unwrap(parsed);
  const type = (geometry as { type?: unknown }).type;
  if (type !== 'Polygon' && type !== 'MultiPolygon') {
    throw badRequest('Vùng nguyên liệu phải là Polygon hoặc MultiPolygon.');
  }

  const polygons =
    type === 'Polygon'
      ? [(geometry as { coordinates?: unknown }).coordinates]
      : ((geometry as { coordinates?: unknown }).coordinates as unknown[]);

  if (!Array.isArray(polygons) || polygons.length === 0) {
    throw badRequest('Vùng nguyên liệu không có toạ độ.');
  }

  let total = 0;
  const cleaned = polygons.map((polygon) => {
    if (!Array.isArray(polygon) || polygon.length === 0) {
      throw badRequest('Vùng nguyên liệu thiếu vòng toạ độ.');
    }
    return polygon.map((ring) => {
      if (!Array.isArray(ring) || ring.length < 4) {
        throw badRequest('Mỗi vòng phải có ít nhất ba đỉnh và được khép kín.');
      }
      total += ring.length;
      if (total > MAX_POINTS) {
        throw badRequest(`Vùng nguyên liệu quá nhiều đỉnh (tối đa ${MAX_POINTS}).`);
      }
      const points = ring.map((point) => {
        if (
          !Array.isArray(point) ||
          point.length < 2 ||
          typeof point[0] !== 'number' ||
          typeof point[1] !== 'number' ||
          Math.abs(point[0]) > 180 ||
          Math.abs(point[1]) > 90 ||
          !Number.isFinite(point[0]) ||
          !Number.isFinite(point[1])
        ) {
          throw badRequest('Toạ độ trong vùng nguyên liệu không hợp lệ.');
        }
        // Làm tròn 6 chữ số: khoảng 10cm, mịn hơn mọi phép đo thực địa mà một
        // hợp tác xã làm được, và giữ cho hash ổn định.
        return [round(point[0]), round(point[1])];
      });
      const first = points[0];
      const last = points[points.length - 1];
      if (first[0] !== last[0] || first[1] !== last[1]) points.push([...first]);
      return points;
    });
  });

  return JSON.stringify(
    type === 'Polygon'
      ? { type: 'Polygon', coordinates: cleaned[0] }
      : { type: 'MultiPolygon', coordinates: cleaned },
  );
}

/** Chấp nhận cả Feature và FeatureCollection một phần tử, vì đó là thứ mà mọi
 * công cụ vẽ bản đồ xuất ra. */
function unwrap(value: unknown): unknown {
  const node = value as { type?: unknown; geometry?: unknown; features?: unknown };
  if (node?.type === 'Feature') return node.geometry;
  if (node?.type === 'FeatureCollection' && Array.isArray(node.features)) {
    if (node.features.length !== 1) {
      throw badRequest('Chỉ nhận đúng một vùng cho mỗi lô nguyên liệu.');
    }
    return (node.features[0] as { geometry?: unknown }).geometry;
  }
  return value;
}

const round = (value: number) => Math.round(value * 1e6) / 1e6;
