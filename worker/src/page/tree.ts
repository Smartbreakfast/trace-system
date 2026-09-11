/// Sơ đồ quy trình dựng thành SVG ngay trên máy chủ.
///
/// Cách xếp chỗ giữ đúng bản Flutter: thành phẩm trên cùng, các công đoạn ở
/// xưởng đi xuống, rồi rẽ thành từng nhánh nguyên liệu, dưới cùng là dải vùng
/// nguyên liệu. Ai đọc quen sơ đồ cũ thì nhìn cái này không phải học lại.

import { esc } from './html';
import { ingredientGlyph } from './icons';
import type { PublicTrace } from './types';

const NODE_W = 200;
const STEP_H = 42;
const PRODUCT_H = 66;
const ORIGIN_H = 64;
const H_GAP = 24;
const V_GAP = 22;
const COL_STEP = NODE_W + H_GAP;
const ROW_STEP = STEP_H + V_GAP;

/// Cùng bảng màu nhánh với giao diện cũ.
export const accents = ['#6BA56D', '#B65C45', '#E2A545', '#876B9E'];

export interface TreeNode {
  id: string;
  parent?: string;
  /** Thứ tự nhánh nguyên liệu, để lấy đúng hình và đúng màu. */
  index?: number;
  kind: 'product' | 'batchStep' | 'ingredientStep' | 'ingredient';
  label: string;
  sub: string;
  colour: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

interface Edge {
  from: TreeNode;
  to: TreeNode;
  colour: string;
  id: string;
}

/** Cắt nhãn thành tối đa hai dòng vừa bề ngang ô. */
function wrap(text: string, perLine: number, maxLines: number): string[] {
  const words = String(text ?? '').split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let line = '';
  for (const word of words) {
    const next = line ? `${line} ${word}` : word;
    if (next.length <= perLine) {
      line = next;
      continue;
    }
    if (line) lines.push(line);
    line = word;
    if (lines.length === maxLines) break;
  }
  if (line && lines.length < maxLines) lines.push(line);
  if (lines.length === 0) return [''];
  const last = lines.length - 1;
  if (lines.length === maxLines && words.join(' ').length > lines.join(' ').length) {
    lines[last] = `${lines[last].slice(0, perLine - 1)}…`;
  }
  return lines;
}

export function buildTree(record: PublicTrace) {
  const nodes: TreeNode[] = [];
  const edges: Edge[] = [];
  const ingredients = record.ingredients ?? [];
  const columns = Math.max(ingredients.length, 1);
  const width = columns * COL_STEP - H_GAP;

  // Công đoạn ở xưởng đọc ngược: đóng gói sát thành phẩm, phối trộn ở dưới.
  const batchSteps = [...(record.batchEvents ?? [])].reverse();
  const branchTop = 1 + batchSteps.length;
  const deepest = ingredients.reduce(
    (top, item) => Math.max(top, (item.processEvents ?? []).length),
    0,
  );
  const bottomRow = branchTop + deepest;
  const height = bottomRow * ROW_STEP + ORIGIN_H;
  const centre = (width - NODE_W) / 2;

  const product: TreeNode = {
    id: 'p',
    kind: 'product',
    label: record.name || 'Thành phẩm',
    sub: '',
    colour: '#17352A',
    x: centre,
    y: 0,
    w: NODE_W,
    h: PRODUCT_H,
  };
  nodes.push(product);

  let previous = product;
  batchSteps.forEach((event, index) => {
    // Giữ chỉ số theo mảng gốc để phía trình duyệt tra đúng phần tử.
    const original = (record.batchEvents ?? []).length - 1 - index;
    const node: TreeNode = {
      id: `b${original}`,
      parent: previous.id,
      kind: 'batchStep',
      label: event.title ?? '',
      sub: '',
      colour: '#17352A',
      x: centre,
      y: (1 + index) * ROW_STEP,
      w: NODE_W,
      h: STEP_H,
    };
    nodes.push(node);
    edges.push({ from: previous, to: node, colour: '#17352A', id: node.id });
    previous = node;
  });

  ingredients.forEach((item, column) => {
    const colour = accents[column % accents.length];
    const left = column * COL_STEP;
    const steps = [...(item.processEvents ?? [])].reverse();
    let parent = previous;
    steps.forEach((event, index) => {
      const original = (item.processEvents ?? []).length - 1 - index;
      const node: TreeNode = {
        id: `s${column}-${original}`,
        parent: parent.id,
        kind: 'ingredientStep',
        label: event.title ?? '',
        sub: '',
        colour,
        x: left,
        y: (branchTop + index) * ROW_STEP,
        w: NODE_W,
        h: STEP_H,
      };
      nodes.push(node);
      edges.push({ from: parent, to: node, colour, id: node.id });
      parent = node;
    });
    const origin: TreeNode = {
      id: `i${column}`,
      parent: parent.id,
      index: column,
      kind: 'ingredient',
      label: item.name ?? '',
      sub: item.origin ?? '',
      colour,
      x: left,
      y: bottomRow * ROW_STEP,
      w: NODE_W,
      h: ORIGIN_H,
    };
    nodes.push(origin);
    edges.push({ from: parent, to: origin, colour, id: origin.id });
  });

  return { nodes, edges, width, height, bottomRow };
}

function edgePath(edge: Edge): string {
  const x1 = edge.from.x + edge.from.w / 2;
  const y1 = edge.from.y + edge.from.h;
  const x2 = edge.to.x + edge.to.w / 2;
  const y2 = edge.to.y;
  const mid = (y2 - y1) / 2;
  return `M${x1} ${y1}C${x1} ${y1 + mid} ${x2} ${y2 - mid} ${x2} ${y2}`;
}

function nodeSvg(node: TreeNode): string {
  const radius = node.kind === 'product' ? 14 : 10;
  const classes = `node ${node.kind}`;
  const label =
    node.kind === 'ingredient'
      ? wrap(node.label, 22, 1)
      : wrap(node.label, node.kind === 'product' ? 24 : 26, 2);

  const centreY =
    node.kind === 'ingredient'
      ? node.y + 24
      : node.y + node.h / 2 - (label.length - 1) * 7;

  const lines = label
    .map(
      (line, index) =>
        `<tspan x="${node.x + (node.kind === 'ingredient' ? 34 : node.w / 2)}" y="${centreY + index * 14 + 4}">${esc(line)}</tspan>`,
    )
    .join('');

  const anchor = node.kind === 'ingredient' ? 'start' : 'middle';
  const sub =
    node.kind === 'ingredient' && node.sub
      ? `<text class="sub" x="${node.x + 34}" y="${node.y + 46}" text-anchor="start" font-size="11" fill="#5A6560">${esc(wrap(node.sub, 24, 1)[0])}</text>`
      : '';
  // Ô vùng nguyên liệu mang đúng hình của bản cũ; ô công đoạn chỉ cần một
  // vạch màu bên trái để biết thuộc nhánh nào.
  const dot =
    node.kind === 'ingredient'
      ? ingredientGlyph(node.index ?? 0, node.x + 12, node.y + 18, node.colour)
      : node.kind === 'ingredientStep'
        ? `<rect x="${node.x}" y="${node.y}" width="4" height="${node.h}" rx="2" fill="${node.colour}"/>`
        : '';

  // Dùng thẻ <a>: không có JS thì bấm vẫn mở được chi tiết bằng :target, có
  // JS thì đoạn script chặn lại và đổi panel tại chỗ.
  return (
    `<a class="${classes}" href="#n-${esc(node.id)}" data-id="${esc(node.id)}"` +
    (node.parent ? ` data-parent="${esc(node.parent)}"` : '') +
    ` style="--c:${node.colour}" aria-label="${esc(node.label)}">` +
    `<rect x="${node.x}" y="${node.y}" width="${node.w}" height="${node.h}" rx="${radius}"/>` +
    dot +
    `<text text-anchor="${anchor}">${lines}</text>` +
    sub +
    '</a>'
  );
}

/** SVG hoàn chỉnh của sơ đồ, kèm dải nền nhóm vùng nguyên liệu. */
export function treeSvg(record: PublicTrace): string {
  const tree = buildTree(record);
  const pad = 16;
  const band =
    (record.ingredients ?? []).length > 0
      ? `<rect class="origin-band" x="${-14}" y="${tree.bottomRow * ROW_STEP - 16}" width="${tree.width + 28}" height="${ORIGIN_H + 30}" rx="16"/>`
      : '';

  const edges = tree.edges
    .map(
      (edge) =>
        `<path class="edge" data-for="${esc(edge.id)}" d="${edgePath(edge)}" stroke="${edge.colour}"/>`,
    )
    .join('');

  return (
    `<svg viewBox="${-pad} ${-pad} ${tree.width + pad * 2} ${tree.height + pad * 2}" ` +
    `preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg">` +
    // Lưới chấm rất mờ, đúng như nền của sơ đồ bản cũ: đủ để thấy mặt phẳng
    // này kéo được, không đủ để tranh chú ý với các ô.
    '<defs><pattern id="dots" width="22" height="22" patternUnits="userSpaceOnUse">' +
    '<circle cx="1.5" cy="1.5" r="1.1" fill="rgba(23,53,41,.07)"/></pattern></defs>' +
    `<rect x="${-pad - 400}" y="${-pad - 400}" width="${tree.width + 800}" height="${tree.height + 800}" fill="url(#dots)"/>` +
    `<g id="tree-root">${band}${edges}${tree.nodes.map(nodeSvg).join('')}</g></svg>`
  );
}
