# Tú Lệ Trace

Hệ thống truy xuất nguồn gốc cho bột ngũ cốc **Tú Lệ Smart Breakfast**. Khách
quét QR trên bao bì để xem lô thành phẩm, bốn nguyên liệu bản địa, ảnh từng
công đoạn, hồ sơ kiểm định, và kiểm chứng dữ liệu có bị sửa sau khi công bố hay
không.

Đang chạy thật tại **https://trace.smartbreakfast.store**.

Chạy hoàn toàn trên Cloudflare: một Worker giữ dữ liệu (D1), file (R2) và dựng
luôn trang tra cứu; một project Pages đứng ra nhận tên miền.

## Trang công khai không chạy Flutter

Trang tra cứu (`/` và `/t/:code`) là **HTML do Worker dựng sẵn**, không phải
ứng dụng Flutter. Màn quản trị `/admin` vẫn là Flutter Web.

Lý do là con số. Đo trên cùng một lô, cùng một máy:

| | Bản Flutter | Bản HTML |
| --- | --- | --- |
| Nội dung hiện ra, 4G yếu + CPU chậm gấp 4 | 18,3 giây | **1,0 giây** |
| Nội dung hiện ra, wifi | 1,3 giây | **0,7 giây** |
| Tải về tới lúc đó | 3,2 MB | 202 KB |

Người quét mã QR đứng giữa chợ, mở trang đúng một lần rồi đóng: họ trả cái giá
3,8 MB engine mà không nhận lại gì. Người vận hành mở màn quản trị mỗi ngày trên
cùng một máy, tải một lần rồi nằm trong cache — ở đó Flutter là lựa chọn đúng.

Trang mới dùng được cả khi tắt JavaScript: đổi mục bằng liên kết thật
(`?tab=nguon-goc`), chi tiết một công đoạn hiện bằng `:target`, tra cứu bằng
form GET. JavaScript chỉ thêm phần mượt: đổi mục không tải lại trang, chọn ô
trên sơ đồ thì panel đổi tại chỗ, phóng to sơ đồ, và quét QR bằng camera.

## Tài liệu

| Tài liệu | Cho ai |
| --- | --- |
| [tai-lieu/KIEN_TRUC.md](tai-lieu/KIEN_TRUC.md) | Kiến trúc, mô hình dữ liệu, sơ đồ luồng, API, ràng buộc thiết kế |
| [tai-lieu/HUONG_DAN_SU_DUNG.md](tai-lieu/HUONG_DAN_SU_DUNG.md) | Người vận hành: tạo lô, nhập liệu, công bố, in QR |
| Bộ slide trình bày | Không nằm trong repo vì file nặng và bản gửi khách được sửa tay. Sinh bản mới bằng `python tools/make_slides.py`, ra `tai-lieu/Tu-Le-Trace-Slides.pptx` |
| [tai-lieu/BAN_GHI_TRACE_domain_setup.md](tai-lieu/BAN_GHI_TRACE_domain_setup.md) | Gửi người quản lý tên miền: bản ghi CNAME cho trace.smartbreakfast.store |
| [DEPLOY.md](DEPLOY.md) | Dựng hạ tầng Cloudflare, deploy, vận hành, chi phí |
| [BLOCKCHAIN.md](BLOCKCHAIN.md) | Hợp đồng, mạng Besu, kế hoạch để từng nhà cung cấp tự ký |
| [QUY_TRINH.md](QUY_TRINH.md) | Đối chiếu quy trình sản xuất thật và các tiêu chuẩn truy xuất |
| [PROJECT_PLAN.md](PROJECT_PLAN.md) | Phạm vi và kiến trúc lúc khởi động dự án |
| [AUDIT.md](AUDIT.md) | Kết quả rà soát và việc còn lại |

## Chạy local

```bash
cd worker
npm install
cp .dev.vars.example .dev.vars
npm run db:local && npm run db:seed:local
# database đã có sẵn dữ liệu thì chạy thêm: npm run db:migrate:local

cd .. && flutter build web --pwa-strategy=none --no-web-resources-cdn
cd worker && npm run dev        # http://127.0.0.1:8787
npm run test:api                # smoke test API
npm run typecheck
```

Bản build Flutter vẫn cần cho `/admin`; trang tra cứu thì Worker tự dựng, nên
sửa `worker/src/page/` là thấy ngay mà không phải build lại Flutter.

Phía Flutter:

```bash
flutter test                    # 38 test
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8787/api
```

## Đường dẫn

| Đường dẫn | Ai dựng | Nội dung |
| --- | --- | --- |
| `/` | Worker | Ô tra cứu và danh sách lô đã công bố |
| `/t/:code` | Worker | Hồ sơ một lô, chính là địa chỉ mã QR trỏ tới |
| `/t/:code?tab=nguon-goc` | Worker | Mở thẳng mục Nguồn gốc (`kiem-dinh` cho mục kiểm định) |
| `/admin` | Flutter | Màn quản trị, cần token |
| `/api/*` | Worker | API |
| `/f/*` | tĩnh | Font woff2, logo, ảnh của trang |

Trên tên miền thật, Pages nhận tất cả rồi chuyển `/`, `/t/*` và `/api/*` về
Worker; `/admin` lấy bản build Flutter từ Pages. Xem `functions/_middleware.js`.

## API

Công khai:

- `GET /api/health`
- `GET /api/public/batches` (vài lô đã công bố, cho trang chủ)
- `GET /api/public/featured` (lô công bố gần nhất, cho landing page)
- `GET /api/public/traces/:code`
- `GET /api/public/traces/:code/verify`
- `GET /api/media/media/<sha256>.<ext>`

Quản trị, cần `Authorization: Bearer <ADMIN_TOKEN>`:

- `GET /api/admin/session`, `GET /api/admin/summary`
- `GET /api/admin/product-batches?q=&sort=newest|oldest|name|code&page=&limit=`
- `GET /api/admin/product-batches/:code/trace` (dữ liệu sống)
- `GET /api/admin/product-batches/:code/snapshots`, `.../snapshots/:version`
- `POST /api/admin/product-batches`, `PATCH /api/admin/product-batches/:code`
- `POST /api/admin/product-batches/:code/publish`
- `POST|PATCH|DELETE /api/admin/ingredient-batches[/:id]`
- `POST|PATCH|DELETE /api/admin/process-events[/:id]`
- `GET /api/admin/media/config`, `POST /api/admin/media`, `DELETE /api/admin/media/:id`
- `GET /api/admin/chain`, `POST /api/admin/chain/send`, `POST /api/admin/chain/retry`

## Trang tra cứu

Ba mục, đúng cách khách hàng mô tả sản phẩm:

1. **Thông tin chung** — ảnh bìa, tên lô, trạng thái kiểm chứng, mã lô, ngày
   sản xuất, hạn dùng, mô tả, nơi sản xuất, dải ảnh sản phẩm.
2. **Nguồn gốc** — sơ đồ quy trình bên trái, panel chi tiết bên phải.
3. **Kiểm định chất lượng** — giấy chứng nhận và phiếu kiểm nghiệm, mở được ảnh
   cỡ đầy đủ.

Dưới ba mục là dải kiểm chứng: trạng thái, phiên bản, thời điểm công bố, mã giao
dịch và liên kết mở giao dịch trên explorer của chuỗi.

**Sơ đồ quy trình** vẽ bằng SVG sinh tại máy chủ (`worker/src/page/tree.ts`):
thành phẩm trên cùng, các công đoạn ở xưởng đi xuống, rồi rẽ thành từng nhánh
nguyên liệu, dưới cùng là dải vùng nguyên liệu. Chạm một ô thì panel bên phải mở
đúng hồ sơ của ô đó — công đoạn thì có khối lượng vào/ra, tỷ lệ thu hồi, thời
gian, người thực hiện, tham số và ảnh; nguyên liệu thì có ảnh vùng, nhà cung
cấp, ngày thu hoạch, ngày nhập kho và danh sách công đoạn. Chỉ ô đang chọn được
tô viền; đường đi từ thành phẩm xuống ô đó sáng lên.

Phần kể chuyện thương hiệu thuộc về landing page riêng, không lặp ở đây.

## Vùng nguyên liệu

Bản đồ tile (MapLibre) đã gỡ khỏi dự án. Vùng nguyên liệu giờ là **một ảnh bản
đồ hành chính của xã**, do người vận hành chụp và tải lên với vai trò
`area_map`; trang khách hiện ảnh đó ngay đầu hồ sơ nguyên liệu.

Trường `area_radius_km` đã bị bỏ (migration `0009_drop_area_radius.sql`). Giá
trị trong đó là ước lượng lúc seed demo chứ không đo đạc, mà một con số không
kiểm chứng được nằm cạnh dữ liệu đã neo lên chuỗi thì sớm muộn cũng có người đọc
nó như số thật. Muốn nói chính xác hơn cấp xã thì phải có số từ nhà cung cấp,
lúc đó dùng cột `area_geojson` để lưu đúng ranh giới.

Toạ độ nằm trong snapshot đem đi băm, nên dời điểm sau khi công bố cũng làm
trạng thái chuyển sang `DỮ LIỆU SAI LỆCH`.

## Ảnh: nén lúc tải lên, không nén lúc phục vụ

Ảnh được thu nhỏ và mã hoá lại **ngay trên trình duyệt trước khi gửi lên**, ra
WebP (JPEG nếu trình duyệt không mã hoá được). Lý do phải làm ở đầu này: khoá R2
là mã băm của chính nội dung file, và khoá đó nằm trong bản công bố đem đi băm —
nén lại một tấm ảnh sau khi đã công bố là làm hỏng đúng bản đã ghi lên chuỗi.

Mức nén theo vai trò ảnh nằm ở `lib/ui/media_manager.dart`. Đo trên bộ ảnh thật
của lô TL-2026-002: 9,07 MB xuống 5,19 MB, riêng mấy tấm PNG giảm hơn 90%. Ảnh
nào nén lại không nhẹ được ít nhất 12% thì giữ nguyên, vì đổi thêm một lần mất
mát để lấy vài phần trăm dung lượng là lỗ.

Ảnh của lô đã có sẵn thì nén lại bằng `python tools/reencode_media.py <mã lô>`:
tải lên bản mới, xoá bản cũ, rồi công bố một phiên bản mới.

## Tải trước ảnh của lô

`web/index.html` hỏi hồ sơ lô ngay từ byte đầu của trang rồi chèn thẻ preload
cho ảnh bìa và dải ảnh. Trước đó phải đợi engine khởi động xong mới có ai đi hỏi
ảnh, đường mạng nằm không suốt quãng ấy. Đo trên máy thật: ảnh bắt đầu tải ở
344 ms thay vì 1793 ms, và lượt tải sau đó của ứng dụng ăn cache chứ không tải
lại.

Font cắt gọn còn Latin + tiếng Việt, chuyển sang woff2 để ở `web/f/`, mỗi file
13-20 KB. CSS nhúng thẳng trong HTML nên không tốn thêm vòng đi về nào.

## Màn quản trị

Rail trái chỉ còn hai mục: **Tổng quan** và **Lô sản phẩm**. Mọi việc của một lô
nằm trong một màn làm việc duy nhất, mở ra khi bấm vào lô trong danh sách:

1. **Thông tin lô** — tên, ngày sản xuất, hạn dùng, nơi sản xuất, toạ độ, mô tả.
   Nút lưu chỉ sáng khi có thay đổi thật.
2. **Ảnh và hồ sơ của lô** — ảnh bìa, ảnh sản phẩm, giấy chứng nhận, phiếu kiểm
   nghiệm.
3. **Nguyên liệu và công đoạn** — mỗi nguyên liệu là một thẻ mở ra được, bên
   trong là vùng trồng, ảnh vùng, và từng công đoạn kèm ảnh của riêng nó.
4. **Hoàn thành lô** — trạng thái toàn vẹn, nút hoàn thành (lần sau là "Lưu bản
   mới"), lịch sử các bản đã lưu kèm tình trạng blockchain, và mã QR tải về dạng
   PNG (nền trắng, 1024px, có mã lô ở dưới) để đưa thẳng sang bản in bao bì.

Sửa dữ liệu sau khi công bố không bị chặn, nhưng trạng thái toàn vẹn sẽ chuyển
sang `DỮ LIỆU SAI LỆCH` cho tới khi công bố phiên bản mới. Đó là cách duy nhất
trung thực: giấu thay đổi đi mới là nói dối người quét mã.

`Lô sản phẩm` có ô tìm theo mã hoặc tên, chọn thứ tự và phân trang 10 lô một
trang, cả ba chạy ở D1 chứ không tải hết về rồi lọc ở client.

Không có dòng chú thích nhỏ nào dưới tiêu đề khối hay dưới ô nhập. Người vận
hành dùng màn này mỗi ngày, chú thích chỉ đúng ở lần đầu rồi thành nhiễu. Trạng
thái lô nói bằng tiếng thường: `ĐANG TẠO` và `ĐÃ XONG`.

## Nút "Hoàn thành lô" và blockchain

Một lần bấm làm bốn việc: gom toàn bộ dữ liệu lô thành snapshot JSON canonical,
băm SHA-256, lưu thành một phiên bản mới (không ghi đè), rồi gửi mã băm lên
**VBSN Besu** qua hợp đồng `TuleTrace`
(`0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca`, chainId 84001).

Người vận hành không phải xác nhận ví: khoá của thương hiệu nằm trong secret
`PRIVATE_KEY` của worker, worker ký và trả gas. Giao dịch gửi trong `waitUntil`
nên không ai phải đứng chờ, và một cron 10 phút quét lại hàng chờ phòng khi mạng
chập. Máy dev đặt `CHAIN_AUTO_ANCHOR=false` để chạy thử không bắn giao dịch thật.

Hai điều kiện của mạng này, gặp lúc triển khai và đã xử lý trong mã:

- **Máy ảo trước Shanghai.** Bytecode mặc định của solc 0.8.24 có opcode PUSH0
  và node từ chối ngay ở bước ước lượng gas, nên `scripts/deploy-contract.mjs`
  biên dịch với `evmVersion: 'paris'`.
- **Giá gas phải hỏi node.** `baseFeePerGas` của mạng là 7 wei nhưng node chỉ
  nhận giao dịch từ 0,1 gwei; viem nhìn baseFee rồi đặt trần 8 wei và mọi giao
  dịch bị từ chối với một thông báo cụt lủn. `chain.ts` lấy thẳng `eth_gasPrice`
  rồi cộng biên 25%.

Kiểm chứng độc lập, không cần tin vào trang web:

```bash
cd worker
node scripts/chain-verify.mjs 0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca <sha256>
```

Chữ ký trên chuỗi hiện là chữ ký của **thương hiệu**. Nó chứng minh dữ liệu
không bị sửa sau khi chốt, chứ chưa chứng minh hợp tác xã đã giao hàng. Bước cho
từng nhà cung cấp tự ký nằm ở [BLOCKCHAIN.md](BLOCKCHAIN.md).

## Một luật của snapshot: trường rỗng thì không ghi

Mã băm được tính lại từ dữ liệu hiện tại rồi so với bản đã công bố. Nghĩa là
**đổi hình dạng payload trong code cũng làm mọi lô đã công bố hoá sai lệch**,
kể cả lô không ai đụng vào — trang công khai lập tức báo `DỮ LIỆU SAI LỆCH`
hàng loạt vì một lần sửa code, chứ không phải vì dữ liệu đổi.

Nên khi thêm một trường vào snapshot: chỉ ghi khoá đó khi thật sự có dữ liệu.
Lô chưa dùng tính năng mới vẫn băm ra đúng như cũ và giữ nguyên trạng thái.
Smoke test giữ luật này: thêm một công đoạn xưởng thì lô phải lệch, xoá đi thì
phải khớp lại mà không cần công bố lại.

Khi buộc phải đổi hình dạng payload cho mọi lô, đó là một quyết định có giá:
phải công bố lại toàn bộ và mỗi lô tốn một giao dịch mới trên chuỗi. Lần gần
nhất là lúc bỏ trường bán kính vùng nguyên liệu.

## Trang khách xem bản đã công bố, không xem dữ liệu đang sửa

`GET /api/public/traces/:code` trả **nội dung của bản công bố gần nhất**, dựng
lại từ payload đã lưu chứ không đọc dữ liệu sống. Người vận hành sửa dở một lô
đã bán ngoài thị trường thì khách quét mã vẫn thấy bản đã chốt; nội dung mới chỉ
ra mắt khi bấm "Lưu bản mới". Lô chưa công bố lần nào thì trả dữ liệu hiện tại
kèm trạng thái `ĐANG TẠO`.

Vì thế có hai câu hỏi kiểm chứng khác nhau, và hai đường trả lời:

| Ai hỏi | Câu hỏi | Đường |
| --- | --- | --- |
| Khách quét QR | Bản tôi đang xem có đúng là bản đã ghi lên chuỗi không? | `GET /api/public/traces/:code/verify` |
| Người vận hành | Dữ liệu tôi vừa sửa có khác bản đã lưu không? | `GET /api/admin/product-batches/:code/trace` |

Trước đây cả hai dùng chung một phép so, nên mỗi lần admin sửa một dòng là trang
khách hiện cảnh báo đỏ. Cảnh báo ấy phải để dành cho trường hợp thật sự đáng báo
động, nếu không thì chẳng ai còn tin nó.

## Sửa lô sau khi đã lên chuỗi

Sửa được, và bản cũ không mất. Ba việc xảy ra cùng lúc:

1. **Bản đã chốt còn nguyên.** `published_snapshots` giữ cả payload đầy đủ chứ
   không chỉ mã băm, nên nội dung lô lúc đó vẫn đọc lại được. Trong màn quản trị,
   mỗi dòng ở "Lịch sử" có nút mở lại nội dung bản ấy.
2. **Giao dịch cũ vẫn nằm trên chuỗi.** Không ai xoá được, kể cả người có khoá.
3. **Trang công khai không đổi gì cả**: khách vẫn xem bản đã công bố. Chỉ màn
   quản trị hiện "Có thay đổi chưa lưu" kèm số hiệu bản mà khách đang thấy.

Ảnh cũng vậy: gỡ một ảnh khỏi lô thì bản ghi biến mất khỏi lô, nhưng file trong
R2 được giữ lại nếu còn bản đã công bố nào trỏ tới nó. Khoá R2 nằm trong snapshot
đem đi băm, xoá file là làm hỏng chính bản đã ghi lên chuỗi.

**Cái chưa có**: nhật ký từng lần sửa giữa hai lần chốt. Hệ thống ghi lại các
**bản đã chốt**, không ghi "14:03 ai đó đổi ngày sản xuất". Với một token quản
trị dùng chung thì nhật ký ấy cũng chỉ ghi được "admin", nên nó chỉ đáng làm
cùng lúc với tài khoản riêng cho từng người vận hành.

## Media

Ảnh, video và hồ sơ kiểm nghiệm nằm trong R2, khoá lưu trữ là
`media/<sha256 của nội dung>.<ext>`. Ba hệ quả:

- Tải lại đúng file cũ thì dùng chung một object, không tốn thêm dung lượng.
- Nội dung không bao giờ đổi theo một khoá, nên cache được vĩnh viễn.
- Khoá nằm trong snapshot đem đi băm, nên tráo ảnh sau khi công bố cũng bị bắt
  như tráo chữ.

`role` quyết định chỗ hiển thị:

| role | Hiện ở đâu |
| --- | --- |
| `cover` | Ảnh lớn của mục Thông tin chung |
| `gallery` | Dải ảnh sản phẩm, ảnh của nguyên liệu, ảnh của công đoạn |
| `area_map` | Ảnh vùng nguyên liệu, ngay đầu hồ sơ nguyên liệu |
| `certificate` | Mục Kiểm định, kèm loại, số hiệu, hạn hiệu lực |
| `lab_report` | Mục Kiểm định |

## Công cụ

Tất cả đi qua API quản trị chứ không đụng thẳng database, nên mọi kiểm tra đầu
vào vẫn chạy và lô mới có mã băm cùng giao dịch của riêng nó.

| Lệnh | Việc |
| --- | --- |
| `python tools/clone_batch.py <nguồn> <đích> --shift <ngày>` | Nhân một lô đầy đủ dữ liệu thành lô khác, dời ngày tháng |
| `python tools/sync_ingredient_media.py <nguồn> <đích...>` | Đồng bộ ảnh của nguyên liệu giữa các lô |
| `python tools/reencode_media.py <mã lô>` | Nén lại ảnh của một lô sang WebP rồi công bố |
| `python tools/make_slides.py` | Sinh bộ slide trình bày |
| `python tools/build_fonts.py <thư mục ttf>` | Cắt gọn font còn Latin + tiếng Việt |
| `node worker/scripts/chain-status.mjs` | Ví, số dư, khối hiện tại |
| `node worker/scripts/chain-verify.mjs <contract> <sha256>` | Đọc ngược từ chuỗi xem mã băm có thật không |
| `node worker/scripts/deploy-contract.mjs` | Biên dịch và triển khai hợp đồng |

## Cấu trúc mã nguồn

```text
worker/
  src/
    index.ts      Hono routes: API, và hai route dựng trang (/ và /t/:code)
    trace.ts      tầng D1, snapshot, hàng chờ neo chuỗi
    chain.ts      ký và gửi giao dịch, đọc trạng thái ví
    media.ts      tải lên R2, kiểm định dạng, xoá an toàn
    canonical.ts  JSON chuẩn hoá và SHA-256
    page/         dựng HTML trang tra cứu: khung, ba mục, sơ đồ SVG, CSS, JS
  migrations/     thay đổi lược đồ theo thời gian
  scripts/        smoke test, công cụ chuỗi, chép lô
lib/              Flutter: màn quản trị (và bản explorer cũ, giữ cho app sau này)
functions/        Pages Functions: chuyển tiếp về Worker
web/              index.html, script nén ảnh và quét QR, font cùng ảnh tĩnh ở web/f
tools/            công cụ Python: seed, nhân lô, nén ảnh, slide, font
tai-lieu/         tài liệu cho khách và người vận hành
```

## Quan hệ với landing page

`smartbreakfast.store` là landing page (repo riêng), `trace.smartbreakfast.store`
là hệ thống này. Thanh điều hướng hai bên dùng chung bảng màu, cùng bộ mục và
cùng logo, để người quét mã không thấy mình vừa rơi sang một website khác. Màu
và số đo lấy đúng từ `assets/css/style.css` của landing, ghi lại trong
`worker/src/page/theme.ts` và `lib/ui/tule_theme.dart`.
