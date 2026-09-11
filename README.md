# Tú Lệ Trace

**Hệ thống truy xuất nguồn gốc nông sản ứng dụng blockchain — thử nghiệm trên
sản phẩm Tú Lệ Smart Breakfast.**

Người mua quét mã QR trên bao bì để xem lô mình đang cầm: nguyên liệu lấy từ
vùng nào, đi qua những công đoạn nào, ai làm, ảnh chụp tại chỗ, hồ sơ kiểm
nghiệm — và tự kiểm chứng được rằng hồ sơ đó không bị sửa sau ngày công bố.

Đang chạy thật tại **https://trace.smartbreakfast.store**

---

## 1. Bài toán

Hàng giả và hàng không rõ nguồn gốc vẫn phổ biến, trong khi phần lớn giải pháp
truy xuất hiện nay chỉ dẫn người mua tới **một trang thông tin do chính người
bán quản lý**. Nếu toàn bộ dữ liệu nằm trong tay một chủ thể, người mua không
có cách nào biết thông tin đã công bố có bị thay đổi về sau hay không. Dữ liệu
lại nằm rải rác trên nhiều phần mềm, nên người mua không tiếp cận được đầy đủ
lịch sử của sản phẩm.

Nhóm thử nghiệm trên Tú Lệ Smart Breakfast vì trong quá trình bán thử, một bộ
phận lớn người tiêu dùng không mua do chưa có đủ thông tin rõ ràng về nguồn gốc.

## 2. Giải pháp

Mỗi lô sản phẩm có một hồ sơ gồm nguyên liệu, công đoạn, ảnh và hồ sơ kiểm
nghiệm. Khi người vận hành bấm **Hoàn thành lô**:

1. Toàn bộ hồ sơ được gom thành một JSON chuẩn hoá (canonical),
2. băm SHA-256,
3. lưu thành **một phiên bản mới, không ghi đè bản cũ**,
4. và mã băm được gửi lên blockchain qua hợp đồng `TuleTrace`.

Trang truy xuất tính lại mã băm từ nội dung đang hiển thị rồi so với bản đã ghi
lên chuỗi. Khớp thì hiện **ĐÃ XÁC MINH**; lệch thì hiện **DỮ LIỆU SAI LỆCH**,
không có đường nào giấu đi. Blockchain ở đây không lưu hồ sơ — nó chỉ giữ **bằng
chứng về thời điểm và nội dung**, nên dữ liệu cá nhân không bị đẩy lên chuỗi
vĩnh viễn và chi phí gần như bằng không.

## 3. Chức năng

### 3.1 Hệ thống quản lý (`/admin`, cần token)

- Tạo lô, khai nguyên liệu và từng công đoạn kèm khối lượng vào/ra, thời gian,
  người thực hiện, tham số kỹ thuật.
- Tải ảnh công đoạn, ảnh vùng nguyên liệu, giấy chứng nhận, phiếu kiểm nghiệm.
- Công bố lô, xem lịch sử các bản đã công bố kèm trạng thái giao dịch.
- Tải mã QR của lô dạng PNG để đưa thẳng sang bản in bao bì.

### 3.2 Trang truy xuất (công khai)

| Mục | Nội dung |
| --- | --- |
| Thông tin chung | Ảnh bìa, tên lô, mã lô, ngày sản xuất, hạn dùng, nơi sản xuất, mô tả |
| Nguồn gốc | Sơ đồ quy trình bấm được: thành phẩm ở trên, truy ngược xuống bốn nhánh nguyên liệu; chạm một ô để xem chi tiết công đoạn hoặc hồ sơ vùng nguyên liệu |
| Kiểm định chất lượng | Giấy chứng nhận và phiếu kiểm nghiệm, mở được ảnh cỡ đầy đủ |
| Dải kiểm chứng | Trạng thái toàn vẹn, phiên bản, thời điểm công bố, mã giao dịch và liên kết mở giao dịch trên explorer |

## 4. Kiến trúc và công nghệ

| Khối | Chức năng | Công nghệ | Lý do kỹ thuật |
| --- | --- | --- | --- |
| Trang truy xuất | Hiển thị hồ sơ lô cho người quét QR | HTML dựng sẵn ở máy chủ (Cloudflare Worker) | Nội dung có mặt ngay byte đầu tiên; dùng được cả khi tắt JavaScript |
| Màn quản trị | Nhập liệu, công bố, in QR | Flutter Web, go_router | Một codebase dùng lại được khi làm app di động |
| Xử lý nghiệp vụ | Định tuyến, xác thực, kiểm tra đầu vào | Cloudflare Worker, Hono 4 | Không cần máy chủ thường trực |
| Dữ liệu | Lô, nguyên liệu, công đoạn, phiên bản, hàng chờ | Cloudflare D1 (SQLite), 6 bảng | Tách dữ liệu nghiệp vụ khỏi blockchain |
| Tệp minh chứng | Ảnh, video, hồ sơ kiểm nghiệm | Cloudflare R2, khoá tệp là mã băm nội dung | Tệp có tham chiếu ổn định theo nội dung, tráo ảnh là bị phát hiện |
| Mã hoá | Chuẩn hoá và tạo mã băm | JSON canonical + SHA-256 | Cùng nội dung cho cùng một mã; đổi một ký tự là đổi mã băm |
| Blockchain | Neo mã băm và mốc thời gian | Hạ tầng VBSN — mạng **Besu**, chainId 84001 | EBSI của châu Âu cũng dựng trên Besu, thuận cho định hướng xuất khẩu. Chỉ ghi bằng chứng, không ghi hồ sơ |
| Vùng nguyên liệu | Định vị vùng trồng | Ảnh bản đồ hành chính cấp xã do người vận hành tải lên | Nói đúng mức chính xác mà dữ liệu thật sự có |

```text
người quét QR ──► trace.smartbreakfast.store (Cloudflare Pages)
                         │
                         ├── /, /t/:code  ──► Worker dựng HTML ──► D1 + R2
                         ├── /api/*       ──► Worker
                         └── /admin       ──► bản build Flutter
                                                   │
                     mã băm mỗi bản công bố ───────┴──► VBSN Besu (TuleTrace)
```

Hợp đồng: `0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca`, triển khai từ khối
4.410.749.

## 5. Những ràng buộc tự đặt ra

Đây là phần quyết định hệ thống có đáng tin hay không, nhiều hơn cả phần công
nghệ.

- **Trang khách xem bản đã công bố, không xem dữ liệu đang sửa.** Người vận hành
  sửa dở một lô đã bán ngoài thị trường thì khách vẫn thấy bản đã chốt; nội dung
  mới chỉ ra mắt khi bấm công bố.
- **Trường rỗng không được ghi vào payload.** Thêm một khoá rỗng là đổi mã băm
  của mọi lô đã công bố trước đó, kể cả lô không ai đụng vào.
- **Không hiển thị chính xác hơn mức dữ liệu thật sự có.** Trường "bán kính vùng
  trồng" đã bị bỏ khỏi hệ thống vì con số trong đó là ước lượng chứ không đo đạc.
- **Không bịa dữ liệu để trang trông đầy đặn.** Ảnh minh hoạ do máy sinh đều
  được đóng dấu "ẢNH MINH HOẠ"; không có chứng nhận hay số liệu nào không lấy từ
  hồ sơ thật.
- **Không xoá tệp R2 khi còn một bản công bố tham chiếu tới nó.** Xoá file là làm
  hỏng chính bản đã ghi lên chuỗi.
- **Nén ảnh trước khi tải lên, không nén khi phục vụ.** Khoá tệp là mã băm nội
  dung, nên nén lại sau khi công bố là làm sai lệch bản đã neo.

## 6. Kết quả hiện tại

**Dữ liệu thật đang chạy**: 4 lô đã công bố, mỗi lô 4 vùng nguyên liệu và 26
công đoạn (24 công đoạn thuộc các nhánh nguyên liệu, cộng phối trộn và đóng
gói), 36 ảnh minh chứng. Cả 4 lô đều ở trạng thái ĐÃ XÁC MINH và có giao dịch
đã xác nhận trên Besu.

**Tốc độ mở trang** — trước đây trang truy xuất chạy bằng Flutter Web; đo lại
trên cùng một lô, cùng một máy sau khi chuyển sang HTML dựng sẵn:

| | Bản Flutter | Bản HTML |
| --- | --- | --- |
| Nội dung hiện ra, 4G yếu + CPU chậm gấp 4 | 18,3 giây | **1,0 giây** |
| Nội dung hiện ra, wifi | 1,3 giây | **0,7 giây** |
| Tải về tới lúc đó | 3,2 MB | 202 KB |

Người quét mã QR đứng giữa chợ, mở trang đúng một lần rồi đóng, nên 3,8 MB
engine là cái giá họ trả mà không nhận lại gì. Màn quản trị thì ngược lại: mở
mỗi ngày trên cùng một máy, tải một lần rồi nằm trong cache — ở đó Flutter vẫn
là lựa chọn đúng.

**Dung lượng ảnh**: nén sang WebP ngay trên trình duyệt lúc tải lên, đo trên bộ
ảnh thật của một lô: 9,07 MB xuống 5,19 MB, riêng ảnh PNG giảm hơn 90%.

## 7. Kiểm chứng độc lập

Không cần tin vào trang web. Lấy mã băm hiện trên trang rồi đọc ngược từ chuỗi:

```bash
cd worker
node scripts/chain-verify.mjs 0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca <sha256>
```

Script in ra mã lô, số phiên bản, ví đã ký, thời điểm và số khối — đọc thẳng từ
sự kiện trên blockchain, không qua API của hệ thống.

Chữ ký trên chuỗi hiện là chữ ký của **thương hiệu**: nó chứng minh dữ liệu
không bị sửa sau khi chốt, chứ chưa chứng minh hợp tác xã đã giao hàng. Bước cho
từng nhà cung cấp tự ký nằm ở [BLOCKCHAIN.md](BLOCKCHAIN.md).

## 8. Chạy ở máy local

```bash
cd worker
npm install
cp .dev.vars.example .dev.vars          # điền token và khoá ký của riêng bạn
npm run db:local && npm run db:seed:local
cd .. && flutter build web --pwa-strategy=none --no-web-resources-cdn
cd worker && npm run dev                # http://127.0.0.1:8787

npm run test:api                        # smoke test API
npm run typecheck
cd .. && flutter test                   # 38 test
```

Bản build Flutter chỉ cần cho `/admin`. Trang truy xuất do Worker dựng, nên sửa
`worker/src/page/` là thấy ngay mà không phải build lại Flutter.

Triển khai lên Cloudflare: xem [DEPLOY.md](DEPLOY.md).

## 9. Cấu trúc mã nguồn

```text
worker/
  src/
    index.ts      Hono routes: API và hai route dựng trang (/ và /t/:code)
    trace.ts      tầng D1, snapshot, hàng chờ neo chuỗi
    chain.ts      ký và gửi giao dịch, đọc trạng thái ví
    media.ts      tải lên R2, kiểm định dạng, xoá an toàn
    canonical.ts  JSON chuẩn hoá và SHA-256
    page/         dựng HTML trang truy xuất: khung, ba mục, sơ đồ SVG, CSS, JS
  migrations/     thay đổi lược đồ theo thời gian
  scripts/        smoke test, công cụ chuỗi, chép lô
contracts/        TuleTrace.sol và ABI đã biên dịch
lib/              Flutter: màn quản trị
functions/        Pages Functions: chuyển tiếp về Worker
web/              index.html, script nén ảnh và quét QR, font cùng ảnh tĩnh
tools/            công cụ Python: nhân lô, đồng bộ ảnh, nén ảnh, slide, font
tai-lieu/         tài liệu cho khách và người vận hành
```

Công cụ dòng lệnh hay dùng, tất cả đi qua API quản trị chứ không đụng thẳng
database:

| Lệnh | Việc |
| --- | --- |
| `python tools/clone_batch.py <nguồn> <đích> --shift <ngày>` | Nhân một lô đầy đủ dữ liệu thành lô khác |
| `python tools/sync_ingredient_media.py <nguồn> <đích...>` | Đồng bộ ảnh nguyên liệu giữa các lô |
| `python tools/reencode_media.py <mã lô>` | Nén lại ảnh của một lô sang WebP rồi công bố |
| `python tools/make_slides.py` | Sinh bộ slide trình bày |
| `node worker/scripts/chain-status.mjs` | Ví, số dư, khối hiện tại |
| `node worker/scripts/deploy-contract.mjs` | Biên dịch và triển khai hợp đồng |

## 10. Kế hoạch hoàn thiện

| Hạng mục | Việc | Ước lượng |
| --- | --- | --- |
| Phân quyền | Tài khoản riêng cho từng người vận hành, kèm nhật ký thao tác | 2 tuần |
| Ứng dụng di động | Bản app cho người vận hành nhập liệu tại xưởng | 3 tuần |
| Phi tập trung | Mỗi nhà cung cấp tự ký công đoạn của mình ([BLOCKCHAIN.md](BLOCKCHAIN.md)) | đang thiết kế |
| Quy mô | Mở rộng lên 100 lô | 1 tháng |
| Tiêu chuẩn | Bổ sung mã GS1 (GTIN, GLN) để liên thông hệ thống truy xuất quốc gia | 2 tuần |

Vì sao chưa dùng GS1 ngay: mã GTIN phải mua theo năm từ GS1 Việt Nam và phải in
lên bao bì, mà bao bì lô thử nghiệm đã in xong trước khi hệ thống chạy. Chi tiết
ở [tai-lieu/KIEN_TRUC.md](tai-lieu/KIEN_TRUC.md).

## Tài liệu

| Tài liệu | Cho ai |
| --- | --- |
| [tai-lieu/KIEN_TRUC.md](tai-lieu/KIEN_TRUC.md) | Kiến trúc, mô hình dữ liệu, sơ đồ luồng, API, ràng buộc thiết kế |
| [tai-lieu/HUONG_DAN_SU_DUNG.md](tai-lieu/HUONG_DAN_SU_DUNG.md) | Người vận hành: tạo lô, nhập liệu, công bố, in QR |
| [DEPLOY.md](DEPLOY.md) | Dựng hạ tầng Cloudflare, deploy, vận hành, chi phí |
| [BLOCKCHAIN.md](BLOCKCHAIN.md) | Hợp đồng, mạng Besu, kế hoạch để từng nhà cung cấp tự ký |
| [QUY_TRINH.md](QUY_TRINH.md) | Đối chiếu quy trình sản xuất thật và các tiêu chuẩn truy xuất |
| [tai-lieu/BAN_GHI_TRACE_domain_setup.md](tai-lieu/BAN_GHI_TRACE_domain_setup.md) | Người quản lý tên miền: bản ghi CNAME cần tạo |

Bộ slide trình bày không nằm trong repo vì file nặng và bản gửi khách được sửa
tay; sinh bản mới bằng `python tools/make_slides.py`.

## Bảo mật

Khoá ký giao dịch (`PRIVATE_KEY`) và token quản trị (`ADMIN_TOKEN`) **không nằm
trong repo**. Production đặt bằng `wrangler secret put`; máy local để ở
`worker/.dev.vars` (đã gitignore). File `worker/.dev.vars.example` chỉ chứa giá
trị mẫu.
