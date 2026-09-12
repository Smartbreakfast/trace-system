// Dựng ảnh code: mỗi đoạn một thẻ nền tối, có tên file và số dòng.
// Chạy: npm i puppeteer-core && node tools/ppt_code_cards.js [thư-mục-ra]
const puppeteer = require('puppeteer-core');
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const path = require('node:path');
const OUT = process.argv[2] || path.join(__dirname, '..', 'docs', 'ppt-ky-thuat');

const cards = [
  {
    id: 'schema',
    file: 'worker/schema.sql',
    lang: 'sql',
    code: `CREATE TABLE product_batches (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  name            TEXT NOT NULL,
  code            TEXT NOT NULL UNIQUE,   -- TL-2026-002
  production_date TEXT NOT NULL,
  expiry_date     TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'DRAFT',
  facility_name   TEXT NOT NULL DEFAULT '',
  created_at      TEXT NOT NULL
);`,
  },
  {
    id: 'api',
    file: 'worker/src/index.ts',
    lang: 'ts',
    code: `// Người mua hỏi hồ sơ của một lô
app.get('/api/public/traces/:code', async (c) =>
  c.json(await trace.publicTrace(c.env.DB, c.req.param('code'), c.env)),
);

// Người vận hành bấm "Hoàn thành lô"
app.post('/api/admin/product-batches/:code/publish', async (c) => {
  const result = await trace.publish(c.env.DB, c.req.param('code'));
  c.executionCtx.waitUntil(trace.drainOutbox(c.env));  // gửi lên chuỗi
  return c.json(result);
});`,
  },
  {
    id: 'hash',
    file: 'worker/src/canonical.ts',
    lang: 'ts',
    code: `// Sắp khoá theo thứ tự chữ cái trước khi băm, để cùng một hồ sơ
// luôn ra cùng một mã, dù lấy dữ liệu ra theo thứ tự nào.
const entries = Object.entries(value)
  .filter(([, item]) => item !== undefined)
  .sort(([a], [b]) => (a < b ? -1 : 1));

export async function sha256Hex(data) {
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}`,
  },
  {
    id: 'chain',
    file: 'worker/src/chain.ts',
    lang: 'ts',
    code: `// Gửi mã băm lên blockchain. Không gửi hồ sơ, chỉ gửi dấu vân tay.
const txHash = await wallet.writeContract({
  address: config.contract,        // 0xcd6811f9...d3ca
  abi: traceAbi,
  functionName: 'anchorBatch',
  args: [toBytes32(input.hash), input.code, input.version, []],
  gasPrice,
});

const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });`,
  },
  {
    id: 'tree',
    file: 'worker/src/page/tree.ts',
    lang: 'ts',
    code: `// Xếp chỗ cho sơ đồ: thành phẩm ở trên, mỗi nguyên liệu một cột,
// công đoạn của nhánh đi xuống theo hàng.
ingredients.forEach((item, column) => {
  const left = column * COL_STEP;
  const steps = [...item.processEvents].reverse();

  steps.forEach((event, index) => {
    nodes.push({ id: \`s\${column}-\${index}\`, label: event.title,
      x: left, y: (branchTop + index) * ROW_STEP });
    edges.push({ from: parent, to: node, colour });
  });
});`,
  },
  {
    id: 'anh',
    file: 'web/image-shrink.js',
    lang: 'js',
    code: `// Nén ảnh ngay trên máy người dùng trước khi gửi lên.
const bitmap = await createImageBitmap(new Blob([bytes]));
const scale = longest > maxEdge ? maxEdge / longest : 1;

const canvas = new OffscreenCanvas(width, height);
canvas.getContext('2d').drawImage(bitmap, 0, 0, width, height);

const blob = await canvas.convertToBlob({ type: 'image/webp', quality });
return out.length < bytes.length ? out : null;  // to hơn thì giữ bản gốc`,
  },
];

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const html = `<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/atom-one-dark.min.css">
<style>
 body{margin:0;background:#fff;font-family:"Segoe UI",sans-serif}
 .card{width:1180px;margin:24px;border-radius:16px;overflow:hidden;background:#282c34;
   box-shadow:0 10px 30px rgba(0,0,0,.18)}
 .bar{display:flex;align-items:center;gap:10px;padding:12px 18px;background:#21252b;color:#9aa4b2;font-size:15px}
 .dot{width:12px;height:12px;border-radius:50%}
 pre{margin:0;padding:20px 22px 26px}
 code{font-family:"Cascadia Mono","Consolas",monospace;font-size:18px;line-height:1.65}
 .ln{color:#4b5363;user-select:none;padding-right:18px}
</style></head><body>
${cards.map((c) => `<div class="card" id="${c.id}">
  <div class="bar"><span class="dot" style="background:#ff5f57"></span>
  <span class="dot" style="background:#febc2e"></span>
  <span class="dot" style="background:#28c840"></span>
  <span style="margin-left:8px">${c.file}</span></div>
  <pre><code class="language-${c.lang}">${esc(c.code)}</code></pre></div>`).join('')}
<script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
<script>hljs.highlightAll();</script>
</body></html>`;

(async () => {
  require('node:fs').writeFileSync('code-cards.html', html);
  const b = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox'] });
  const p = await b.newPage();
  await p.setViewport({ width: 1280, height: 900, deviceScaleFactor: 2 });
  await p.goto('file://' + process.cwd().replace(/\\/g, '/') + '/code-cards.html', { waitUntil: 'networkidle2' });
  await sleep(1500);
  for (const c of cards) {
    const el = await p.$('#' + c.id);
    await el.screenshot({ path: path.join(OUT, `code-${c.id}.png`) });
  }
  console.log('xong', cards.length, 'the code');
  await b.close();
})();
