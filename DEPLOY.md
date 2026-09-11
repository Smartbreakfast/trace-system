# Đưa Tú Lệ Trace lên Cloudflare

Toàn bộ hệ thống chạy trên một Worker duy nhất: API, database D1, kho file R2
và cả bản build Flutter Web. Một origin, một lệnh deploy, không có server nào
phải tự quản.

```text
người quét QR
      │
      ▼
tule-trace.workers.dev  (hoặc trace.tule.vn)
      │
      ├── /                → Flutter Web (Workers Static Assets)
      ├── /t/TL-2026-001   → cùng bản Flutter, SPA fallback
      ├── /api/*           → Worker (Hono)
      │                       ├── D1  : dữ liệu lô, nguyên liệu, công đoạn, snapshot
      │                       └── R2  : ảnh, video, hồ sơ kiểm nghiệm
      └── /api/media/<hash>.<ext> → đọc thẳng từ R2, cache vĩnh viễn
```

## 1. Chuẩn bị một lần

```bash
cd worker
npm install
npx wrangler login
```

Tạo database và bucket:

```bash
npx wrangler d1 create tule-trace
npx wrangler r2 bucket create tule-trace-media
```

Lệnh `d1 create` in ra `database_id`. Dán vào `worker/wrangler.jsonc`, thay chỗ
`REPLACE_WITH_D1_DATABASE_ID`.

Đặt token quản trị (chuỗi ngẫu nhiên dài, đây là thứ duy nhất chặn người lạ
tạo lô giả và đổ file vào R2 của bạn):

```bash
npx wrangler secret put ADMIN_TOKEN
```

Đặt khoá ký giao dịch cho VBSN Besu. Đây là khoá của ví thương hiệu, mọi bản
ghi lên chuỗi mang chữ ký của nó, nên đừng dùng chung với ví giữ tiền:

```bash
npx wrangler secret put PRIVATE_KEY
```

Tạo bảng và nạp lô mẫu:

```bash
npm run db:remote
npm run db:seed:remote     # tuỳ chọn, bỏ qua nếu muốn bắt đầu trắng
```

Nếu database đã tạo từ trước khi có bản đồ, chạy thêm migration để bổ sung cột
toạ độ (chạy nhiều lần sẽ báo lỗi cột đã tồn tại, đó là bình thường):

```bash
npm run db:migrate:remote
```

## 2. Deploy

```bash
cd ..
flutter build web --release --pwa-strategy=none --no-web-resources-cdn
cd worker
npm run deploy
```

`--pwa-strategy=none` là bắt buộc: service worker của Flutter đã deprecated và
nó khiến trình duyệt phục vụ lại bản build cũ sau khi deploy.

`--no-web-resources-cdn` cũng vậy: không có nó, CanvasKit 5,6MB được tải từ
`gstatic.com` thay vì từ Worker của mình.

`wrangler.jsonc` trỏ `assets.directory` sang `../build/web`, nên phải build
Flutter trước rồi mới deploy. Không cần `--dart-define` nào: Worker phục vụ cả
web lẫn API nên client tự gọi `/api` cùng origin, và mã QR lấy origin đang chạy.

Nếu tách domain riêng cho API hoặc cho trang web thì mới cần:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.tule.vn/api \
  --dart-define=PUBLIC_BASE_URL=https://trace.tule.vn
```

## 3. Địa chỉ: chạy thử trên workers.dev trước

Chưa cần mua tên miền. Lần deploy đầu tiên Cloudflare cấp sẵn địa chỉ miễn phí:

```text
https://tule-trace.<subdomain>.workers.dev
https://tule-trace.<subdomain>.workers.dev/t/TL-2026-001
https://tule-trace.<subdomain>.workers.dev/admin
```

`<subdomain>` là tên workers.dev của tài khoản, wrangler in ra ngay sau khi
deploy xong. Mọi thứ chạy đủ trên địa chỉ này: HTTPS, mã QR, upload ảnh, kiểm
chứng hash. Không phải sửa gì trong code, vì ứng dụng lấy origin đang chạy làm
gốc cho cả lời gọi API lẫn nội dung mã QR.

### Một điều cần cẩn thận

Mã QR đã in lên bao bì là **cố định vĩnh viễn**. Gói hàng in theo địa chỉ
workers.dev sẽ mãi trỏ về đó, kể cả sau khi bạn mua `trace.tule.vn`.

Nên trong giai đoạn thử, chỉ in QR ra giấy để test, đừng in lên bao bì thật cho
tới khi chốt tên miền. `workers_dev` trong `wrangler.jsonc` đang để `true` và
nên giữ nguyên kể cả sau này: nếu lỡ có gói nào đã in theo workers.dev thì địa
chỉ đó vẫn mở được, cả hai cùng trỏ về một Worker và một database.

### Chuyển sang tên miền riêng

Khi đã mua và trỏ tên miền về Cloudflare: mở dashboard, vào Workers & Pages,
chọn `tule-trace`, tab Settings, mục Domains & Routes, thêm `trace.tule.vn`.

Không cần build lại, không cần sửa code, không cần đụng tới dữ liệu. Từ lúc đó
mã QR sinh ra ở Management sẽ tự dùng địa chỉ mới, vì nó lấy theo domain bạn
đang mở trang. Muốn chắc chắn QR luôn dùng domain chính dù mở từ đâu thì build
kèm:

```bash
flutter build web --release --pwa-strategy=none \n  --dart-define=PUBLIC_BASE_URL=https://trace.tule.vn
```

Đường dẫn sạch không có dấu `#` trên cả hai địa chỉ, vì Worker bật SPA fallback
cho mọi đường dẫn không phải `/api/*`.

## 3b. Tên miền trace.smartbreakfast.store

Tên miền `smartbreakfast.store` nằm ở một tài khoản Cloudflare khác (bên quản lý
landing page). Điều đó loại hai cách gắn tên miền thông thường:

| Cách | Vì sao không dùng được |
| --- | --- |
| Workers Custom Domain | Cloudflare đòi zone phải thuộc chính tài khoản tạo custom domain |
| Uỷ quyền subdomain bằng bản ghi NS | Cloudflare chỉ mở subdomain zone setup cho gói Enterprise; zone đang ở gói Free |

Cách đang dùng: **một project Cloudflare Pages đứng ra nhận tên miền**, vì với
subdomain thì Pages không đòi zone cùng tài khoản. Pages phục vụ thẳng toàn bộ
file tĩnh, còn `/api/*` được chuyển tiếp về Worker qua
`functions/api/[[path]].js`. Nhờ vậy D1, R2, secret và cron trigger vẫn nằm
nguyên ở Worker, không phải nhân đôi.

```bash
flutter build web --pwa-strategy=none --no-web-resources-cdn   --dart-define=PUBLIC_BASE_URL=https://trace.smartbreakfast.store
npx wrangler pages deploy build/web --project-name tule-trace --branch main
cd worker && npx wrangler deploy    # Worker vẫn giữ dữ liệu và cron
```

`PUBLIC_BASE_URL` quyết định nội dung mã QR. Ghim nó vào tên miền chính thức để
mã QR luôn trỏ đúng, dù người vận hành mở màn quản trị ở địa chỉ nào.

**Bản ghi bên quản lý tên miền phải tạo**, trong zone `smartbreakfast.store`:

| Trường | Giá trị |
| --- | --- |
| Type | CNAME |
| Name | `trace` |
| Target | `tule-trace.pages.dev` |
| Proxy status | **DNS only**, mây xám |
| TTL | Auto |

Bật proxy (mây vàng) sẽ ra `Error 1014 CNAME Cross-User Banned`, vì Cloudflare
chặn CNAME có proxy trỏ sang tài khoản khác. Custom domain phải được thêm vào
project Pages **trước** khi tạo bản ghi; ngược lại Pages có thể từ chối nhận
hostname đó.

Kiểm tra sau khi bản ghi đã tạo:

```bash
curl -sS -o /dev/null -w "%{http_code}
" https://trace.smartbreakfast.store/
curl -s https://trace.smartbreakfast.store/api/health
```

Chi tiết bàn giao giữa hai bên: `tai-lieu/Ket-noi-trace.smartbreakfast.store.pdf`.

## 4. Chạy local

Cần hai cửa sổ terminal:

```bash
# lần đầu
cd worker
cp .dev.vars.example .dev.vars
npm run db:local
npm run db:seed:local

# mỗi lần chạy
flutter build web --pwa-strategy=none --no-web-resources-cdn
cd worker && npm run dev     # http://127.0.0.1:8787
npm run test:api             # smoke test toàn bộ API
```

`wrangler dev --local` dựng D1 và R2 giả lập trong `worker/.wrangler`, không
đụng tới dữ liệu thật.

Muốn hot reload khi sửa giao diện thì chạy `flutter run -d chrome
--dart-define=API_BASE_URL=http://127.0.0.1:8787/api` song song với
`npm run dev`.

## 5. Vận hành

Mở `https<domain>/admin`, nhập `ADMIN_TOKEN`. Token lưu trong trình duyệt của
người vận hành, đăng xuất bằng nút ở góc trên.

Luồng làm một lô mới:

1. Lô sản phẩm, bấm Tạo lô mới, nhập thông tin, nơi sản xuất và bốn nguyên
   liệu. Mỗi nguyên liệu nên có toạ độ vùng trồng; bỏ trống thì bản đồ đặt
   điểm theo tâm tỉnh và nói rõ với khách rằng đó là vị trí tương đối.
2. Mục Nguyên liệu: tải ảnh bìa, ảnh vùng nguyên liệu, video công đoạn, và
   phiếu kiểm nghiệm PDF.
3. Mục Hoàn thành lô: bấm Hoàn thành lô, tải mã QR về rồi in lên bao bì. Mã
   băm của bản vừa chốt được gửi lên VBSN Besu ngay sau đó; khi có giao dịch
   thì cả màn quản trị lẫn trang công khai hiện "Đã lưu lên blockchain" kèm
   liên kết tới explorer.

Mỗi lần sửa dữ liệu hoặc thêm/xoá file sau khi công bố, trang công khai sẽ báo
`DỮ LIỆU SAI LỆCH` cho tới khi bạn công bố lại. Đó là hành vi đúng: snapshot cũ
không bị ghi đè, mỗi lần công bố là một phiên bản mới.

## 5a. Trang công khai dựng sẵn thành HTML

Từ 11.09.2026, `/` và `/t/<mã lô>` **không còn chạy Flutter**. Worker dựng thẳng
HTML (xem `worker/src/page/`), nên nội dung có mặt ngay byte đầu tiên.

| | Bản Flutter | Bản HTML |
| --- | --- | --- |
| Nội dung hiện ra, 4G yếu + CPU chậm gấp 4 | 18,3 giây | **1,0 giây** |
| Nội dung hiện ra, wifi | 1,3 giây | **0,7 giây** |
| Tải về tới lúc đó | 3,2 MB | 202 KB |

Màn quản trị `/admin` vẫn là Flutter: nó chạy mỗi ngày trên máy quen, tải một
lần rồi nằm trong cache, nên cái giá engine 3,8MB ở đó không ai trả hai lần.

Trang mới dùng được cả khi tắt JavaScript: mục chuyển bằng liên kết thật
(`?tab=nguon-goc`), chi tiết một công đoạn hiện bằng `:target`, tra cứu bằng
form GET. JavaScript chỉ thêm: đổi mục không tải lại trang, chọn ô trên sơ đồ
đổi panel tại chỗ, phóng to sơ đồ, và quét QR bằng camera.

Font cắt gọn để ở `web/f/` (woff2, 13-20KB mỗi file); `tools/build_fonts.py`
dựng bản ttf gốc, đoạn chuyển sang woff2 nằm trong lịch sử commit.

## 5b. Blockchain

Mã băm của mỗi bản đã chốt được neo lên **VBSN Besu** (chainId 84001, RPC
`https://besu-rpc.vbsn.vn`) qua hợp đồng `TuleTrace`:

| Thành phần | Giá trị |
| --- | --- |
| Hợp đồng | `0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca` |
| Ví ký | đặt bằng secret `PRIVATE_KEY` |
| Explorer | https://besu-explorer.vbsn.vn |
| Neo tự động | biến `CHAIN_AUTO_ANCHOR` (`"true"` ở production) |
| Lưới đỡ | cron 10 phút một lần quét lại hàng chờ |

Người vận hành không phải xác nhận ví: khoá nằm trong secret của worker, bấm
"Hoàn thành lô" là xong. Đổi lại, chữ ký trên chuỗi là chữ ký của **thương
hiệu**, không phải của từng nhà cung cấp — muốn từng bên tự ký thì xem
[BLOCKCHAIN.md](BLOCKCHAIN.md).

Ba việc cần nhớ khi vận hành:

- **Giữ ví có tiền.** Mỗi lần neo tốn khoảng 0,0000002 VNX, rất rẻ, nhưng hết
  sạch thì hàng chờ đứng lại. Màn quản trị hiện số dư ngay dưới nút.
- **Máy dev đừng bắn lên chuỗi.** `worker/.dev.vars` đặt `CHAIN_AUTO_ANCHOR=false`
  nên chạy thử và smoke test không tạo giao dịch thật; nút "Gửi lên chuỗi" vẫn
  dùng được khi cố ý.
- **Kiểm chứng độc lập.** Bất kỳ ai cũng đọc lại được từ chuỗi:

  ```bash
  node scripts/chain-verify.mjs 0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca <sha256>
  ```

Triển khai lại hợp đồng (chỉ khi đổi mã nguồn hợp đồng):

```bash
npm run chain:deploy       # biên dịch và deploy, in ra địa chỉ mới
npm run chain:status       # xem ví, số dư, khối hiện tại
```

## 5c. Đưa một lô từ máy dev lên production

Hai môi trường là hai database khác nhau: lô nhập ở máy dev **không** tự có
trên production. Chép sang bằng:

```bash
cd worker
node scripts/copy-batch.mjs TL-2026-002 --to https://tule-trace.sontm.workers.dev
```

Script đi qua đúng API quản trị chứ không đụng database, nên mọi kiểm tra đầu
vào vẫn chạy: tạo lô, từng nguyên liệu, từng công đoạn, tải lại toàn bộ ảnh, rồi
công bố. Lô ở đích có mã băm và giao dịch của riêng nó — hai môi trường không
dùng chung bản công bố, và đó là điều đúng.

Đích đã có mã lô đó thì script dừng, không ghi đè.

## 6. Chi phí

Ở quy mô một thương hiệu nông sản, mọi thứ nằm gọn trong free tier: Workers
100.000 request/ngày, D1 5GB dung lượng, R2 10GB lưu trữ và không tính phí
egress. Khoản dễ vượt trước nhất là dung lượng R2 nếu tải nhiều video, nên nén
video xuống 720p trước khi tải.

## 7. Bản đồ

Bản đồ nền dùng vector tile của OpenFreeMap qua MapLibre GL. Không cần API key,
không đăng ký, không giới hạn lượt xem, và được phép dùng thương mại. Ghi nguồn
OpenFreeMap, OpenMapTiles và OpenStreetMap là bắt buộc, đã có sẵn trong giao
diện.

Hai điều nên biết trước khi phụ thuộc hẳn vào nó:

- OpenFreeMap sống bằng quyên góp và **không cam kết SLA**. Nếu lượng truy cập
  lớn hoặc bạn cần đảm bảo, hãy cân nhắc gói hỗ trợ của họ, hoặc tự host tile
  bằng Protomaps hay MapTiler. Đổi nhà cung cấp chỉ là đổi `TileMap.styleUrl`.
- Người xem cần có mạng để tải tile. Mất mạng hoặc tile hỏng thì sau 8 giây ứng
  dụng tự chuyển sang bản đồ vector tự vẽ nhúng sẵn, kèm ghi chú cho người xem.

Thư viện `maplibre-gl-js` nằm trong `web/vendor/maplibre/` và được Worker phục
vụ cùng origin, không gọi ra CDN nào lúc chạy.

## 8. Giới hạn cần biết

- File tải lên tối đa 30MB, chỉnh bằng `MAX_UPLOAD_BYTES` trong `wrangler.jsonc`.
  Workers không nhận request lớn hơn 100MB nên đừng đặt quá con số đó.
- `ADMIN_TOKEN` là bí mật dùng chung cho mọi người vận hành. Khi cần phân quyền
  từng người thì thay bằng tài khoản riêng.
- Ghi vào blockchain vẫn dừng ở bảng `blockchain_outbox` với trạng thái
  `PENDING_NETWORK`, chờ thông tin mạng.
