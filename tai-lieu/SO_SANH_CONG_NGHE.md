# So sánh và lựa chọn công nghệ cho hệ thống Tú Lệ Trace

Tài liệu này viết để chèn vào phần "Thiết kế và phương pháp nghiên cứu" của báo
cáo dự án khoa học kỹ thuật: nêu các phương án công nghệ đã xem xét, tiêu chí so
sánh, phương án được chọn và lý do, kèm số liệu đo được trên hệ thống thật.

## 1. Cách đọc các con số trong tài liệu

Số liệu trong tài liệu chia làm hai loại, luôn ghi rõ loại nào:

| Nhãn | Nghĩa |
|---|---|
| **(đo)** | Đo trực tiếp trên hệ thống Tú Lệ Trace đang chạy, ngày 21/10/2026. Mục 8 ghi đúng lệnh để đo lại. |
| **(nguồn)** | Lấy từ tài liệu công khai của nền tảng đó, có dẫn nguồn ở mục 9. Nhóm không tự đo. |
| **(tính)** | Suy ra bằng phép tính từ bảng giá gas công khai, có ghi phép tính. |

Không có con số nào trong tài liệu là ước lượng.

## 2. Ba khái niệm hay bị gọi lẫn: mã hoá, hàm băm, chữ ký số

Hệ thống truy xuất nguồn gốc dùng cả ba, mỗi thứ một việc. Gọi lẫn tên là mô tả
sai hệ thống, nên tách rõ ngay từ đầu:

| | Mã hoá (encryption) | Hàm băm (hash) | Chữ ký số (digital signature) |
|---|---|---|---|
| Để làm gì | Che nội dung, chỉ người có khoá đọc được | Tạo một "dấu niêm phong" ngắn, cố định cho một nội dung | Chứng minh bản ghi do ai gửi và không bị sửa trên đường |
| Giải ngược được không | Được, bằng khoá giải | **Không.** Một chiều, không có cách nào dựng lại nội dung từ mã băm | Không áp dụng |
| Đổi một ký tự trong nội dung | Bản mã đổi | Mã băm đổi hoàn toàn | Chữ ký không còn hợp lệ |
| Tú Lệ Trace dùng ở đâu | Chỉ ở tầng đường truyền: HTTPS/TLS 1.3 giữa điện thoại và máy chủ | SHA-256 cho bản công bố của mỗi lô và cho khoá lưu trữ tệp đính kèm | ECDSA trên đường cong secp256k1, khi gửi giao dịch neo mã băm lên blockchain |

**Hệ thống không mã hoá nội dung hồ sơ lô, và đó là chủ ý.** Hồ sơ truy xuất
sinh ra để người mua đọc được: mã hoá nó đi thì mục đích của sản phẩm mất. Thứ
cần bảo vệ không phải tính bí mật, mà là **tính không sửa được**, nên công cụ
đúng là hàm băm cộng blockchain, không phải mã hoá.

## 3. Chọn hàm băm: tại sao SHA-256

### 3.1 Yêu cầu đặt ra

Hàm băm ở đây đóng vai con dấu niêm phong của một bản công bố. Bốn yêu cầu:

1. **Chống đụng độ** (collision): không ai dựng được hai hồ sơ khác nhau mà
   cùng một mã băm. Nếu làm được, người bán có thể công bố một hồ sơ sạch rồi
   thay bằng hồ sơ khác mà mã băm vẫn khớp.
2. **Một chiều**: từ mã băm không suy ra được nội dung.
3. **Kết quả ngắn và cố định**: hồ sơ dài bao nhiêu thì mã băm vẫn 32 byte, để
   đưa lên blockchain với chi phí không đổi.
4. **Kiểm lại được bằng công cụ phổ thông**: ban giám khảo hoặc người mua phải
   tự tính lại được mã băm mà không cần cài gì của nhóm.

### 3.2 Các phương án đã xem xét

| Hàm băm | Độ dài | Tình trạng an toàn | Có sẵn trên nền tảng đang chạy | Kết luận |
|---|---|---|---|---|
| MD5 | 128 bit | **Đã bị phá.** Tạo đụng độ được trong vài giây trên máy thường (nguồn) | Có | Loại |
| SHA-1 | 160 bit | **Đã bị phá.** Đụng độ thực tế được công bố năm 2017 (nguồn) | Có | Loại |
| **SHA-256** (họ SHA-2) | 256 bit | Chưa có đụng độ nào được công bố. Nằm trong chuẩn FIPS 180-4, NIST vẫn khuyến nghị dùng (nguồn) | **Có sẵn trong WebCrypto**, không cần thư viện ngoài | **Chọn** |
| SHA-3 / Keccak-256 | 256 bit | An toàn, chuẩn FIPS 202. Cấu trúc khác hẳn SHA-2 (nguồn) | Không có trong WebCrypto, phải nhúng thư viện | Không chọn |
| BLAKE3 | 256 bit | An toàn, nhanh hơn SHA-256 vài lần | Phải nhúng thư viện | Không chọn |

### 3.3 Vì sao SHA-256 thắng ba phương án còn an toàn

Ba hàm SHA-256, SHA-3 và BLAKE3 đều đủ an toàn cho bài toán này. Chọn SHA-256 vì
ba lý do thực tế, không phải vì nó mạnh hơn:

- **Có sẵn trong nền tảng.** Hệ thống chạy trên Cloudflare Workers, nơi WebCrypto
  cung cấp SHA-256 ở tầng nền. Không phải thêm thư viện nào: ít phụ thuộc, ít bề
  mặt lỗi, mã nguồn nhỏ hơn.
- **Ai cũng kiểm lại được.** Máy Windows có `certutil -hashfile <tệp> SHA256` và
  `Get-FileHash`; máy Linux, macOS có `sha256sum`. Người kiểm chứng không cần
  tin công cụ của nhóm. Với SHA-3 hay BLAKE3 thì phải cài thêm.
- **Cùng một hàm băm với lớp blockchain.** Hợp đồng lưu đúng 32 byte mã băm
  SHA-256; không phải chuyển đổi định dạng giữa hai hệ.

Tốc độ không phải tiêu chí quyết định: hệ thống băm một hồ sơ cỡ 17 KB mỗi lần
công bố, tức vài chục lần một vụ, nên chênh lệch vài micro giây giữa các hàm
không có ý nghĩa.

### 3.4 Hàm băm được dùng ở hai chỗ trong hệ thống

1. **Bản công bố của lô.** Toàn bộ hồ sơ được chuẩn hoá về JSON có khoá sắp xếp
   ổn định rồi băm. Ví dụ thật, lô `TL-2026-004` (đo):

   ```
   mã băm: 57cd034b98be0a7f43e9a8ae633d46ba2e7972ad11a9406a64fcbf7ddde1624a
   độ dài: 64 ký tự hexa = 256 bit = 32 byte
   ```

2. **Khoá lưu trữ của ảnh và video.** Mỗi tệp được lưu dưới tên chính là mã băm
   nội dung của nó (`media/<sha256>.<đuôi>`). Hệ quả: hai người tải cùng một ảnh
   lên thì chỉ tồn một bản, và **đổi một điểm ảnh là đổi tên tệp**, nên không
   thể âm thầm thay ảnh của một lô đã công bố.

## 4. Chọn nền tảng blockchain: tại sao VBSN Besu

### 4.1 Tiêu chí

Bảy tiêu chí, xếp theo mức quan trọng với một cơ sở sản xuất nhỏ:

1. Chi phí mỗi lần ghi, và chi phí đó có phụ thuộc giá tiền mã hoá hay không.
2. Thời gian từ lúc công bố đến lúc dữ liệu chốt trên chuỗi.
3. Người ngoài có tự kiểm chứng được hay không.
4. Ai được quyền ghi, ai vận hành hạ tầng.
5. Công sức dựng và duy trì hạ tầng.
6. Trả bằng gì (ngoại tệ hay tiền trong nước).
7. Nhóm học sinh có học và thao tác được trong thời gian làm dự án hay không.

### 4.2 Bốn phương án

| | A. Ethereum công khai | B. Hyperledger Fabric | C. Chuỗi riêng bằng Cosmos SDK | D. VBSN Besu (chọn) |
|---|---|---|---|---|
| Kiểu mạng | Công khai, không xin phép | Riêng tư, có cấp phép | Chuỗi riêng tự dựng | Riêng tư có cấp phép, do đơn vị trong nước vận hành |
| Thời gian khối | 12 giây/khối, 32 khối một epoch (nguồn); chốt chắc sau khoảng hai epoch, cỡ 13 phút (tính) | Tuỳ cấu hình dịch vụ sắp khối | Tuỳ cấu hình; đồng thuận BFT nên khối đã commit là chốt (nguồn) | **2,00 giây/khối** (đo) |
| Phí mỗi lần ghi | Trả bằng ETH, giá thay đổi theo thị trường | Không có phí giao dịch, nhưng phải tự chịu chi phí máy chủ | Không có phí nếu tự vận hành, phải tự chịu chi phí máy chủ | **0,00000366 VNX** (đo) |
| Ai được ghi | Bất kỳ ai có ETH | Chỉ thành viên được cấp chứng thư | Chỉ nhóm vận hành | Chỉ ví đã được cấp quyền |
| Người ngoài kiểm chứng | Được, bằng mọi explorer công khai | Khó: phải được cấp quyền vào mạng | Được nếu nhóm tự mở explorer | Được, qua explorer công khai của mạng |
| Hạ tầng nhóm phải dựng | Không | Phải dựng peer, orderer, CA | Phải dựng và duy trì validator | Không |
| Phù hợp cơ sở nhỏ | Kém: phí bằng ngoại tệ, biến động | Kém: nặng về vận hành | Kém: tốn người duy trì | **Phù hợp** |

### 4.3 Số liệu đo được trên phương án đã chọn

Đo ngày 21/10/2026 bằng `node worker/scripts/do-chi-so-chuoi.mjs`, đọc trực
tiếp từ RPC của mạng, không qua lớp trung gian nào (đo):

| Chỉ số | Giá trị |
|---|---|
| Mạng | VBSN Besu, chainId 84001 |
| Hợp đồng lưu mã băm | `0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca` |
| Thời gian ra khối | 2,00 giây/khối (trung bình 200 khối gần nhất) |
| Giá gas | 0,1 gwei |
| Gas mỗi giao dịch neo | 29.285 – 29.345 đơn vị, trung bình 29.293 |
| Phí mỗi giao dịch neo | 0,00000366 VNX |
| Độ trễ công bố → có trên chuỗi | 1 – 5 giây |
| Số lô đã neo | 8 lô, cả 8 đều ở trạng thái ĐÃ XÁC MINH và đã có giao dịch được xác nhận |

Danh sách giao dịch thật của từng lô (đo):

| Lô | Khối | Gas | Trạng thái |
|---|---|---|---|
| TL-2026-001 | 5.783.872 | 29.285 | ĐÃ XÁC MINH |
| TL-2026-002 | 5.783.848 | 29.285 | ĐÃ XÁC MINH |
| TL-2026-003 | 5.783.886 | 29.285 | ĐÃ XÁC MINH |
| TL-2026-004 | 5.783.899 | 29.285 | ĐÃ XÁC MINH |
| NL-TRAU-2026-001 | 5.785.027 | 29.345 | ĐÃ XÁC MINH |
| TB-2026-001 | 5.786.972 | 29.285 | ĐÃ XÁC MINH |
| TB-2026-002 | 5.786.975 | 29.285 | ĐÃ XÁC MINH |
| TB-2026-003 | 5.786.977 | 29.285 | ĐÃ XÁC MINH |

Giao dịch của lô `TL-2026-004`:
`0xcf5ac3f9a848406f028b79b3b62508f1fc49bab8a93a732d80f3ab9e0944dcf9`, khối
5.783.899. Xem được tại explorer công khai của mạng VBSN.

### 4.4 Hạn chế của phương án đã chọn

Nói thẳng, vì đây là điểm ban giám khảo sẽ hỏi: mạng VBSN là mạng có cấp phép do
một đơn vị trong nước vận hành, nên **không phi tập trung như Ethereum công
khai**. Nếu đơn vị vận hành dừng mạng, các giao dịch cũ không tra cứu được qua
explorer của họ nữa.

Thiết kế của hệ thống đã tính đến chuyện đó: bản công bố và mã băm được giữ
trong cơ sở dữ liệu của hệ thống, nên vẫn kiểm lại được bằng cách băm lại hồ sơ,
và có thể neo lại cùng mã băm đó lên một mạng khác mà không phải sửa dữ liệu.
Mã băm không gắn với một mạng cụ thể nào.

## 5. Vì sao chỉ neo mã băm, không đẩy cả hồ sơ lên blockchain

Ba cách đã cân:

| | Ghi toàn bộ hồ sơ lên chuỗi | **Chỉ neo mã băm (chọn)** | Không dùng blockchain |
|---|---|---|---|
| Dung lượng mỗi lô | Hồ sơ `TL-2026-004` nặng 17 KB (đo) | Đúng 32 byte, không đổi theo độ dài hồ sơ | 0 |
| Gas nếu lưu vào bộ nhớ hợp đồng | 17.000 byte ÷ 32 = 532 ô × 20.000 gas = **10.640.000 gas** (tính) | 29.285 gas (đo) | — |
| Sửa dữ liệu sau khi công bố | Không sửa được, kể cả khi ghi sai hoặc cần xoá thông tin cá nhân | Sửa được trong cơ sở dữ liệu, nhưng mã băm lệch ngay nên **bị phát hiện** | Sửa được, không ai biết |
| Ảnh và video | Không khả thi, dung lượng hàng megabyte | Ảnh lưu ngoài, tên tệp là mã băm nội dung nên cũng không thay được | — |

Tỉ lệ chênh lệch: 10.640.000 so với 29.285 gas, tức **gấp khoảng 363 lần** cho
cùng một lô. Và đó mới là một lô; chi phí tăng tuyến tính theo độ dài hồ sơ,
trong khi cách neo mã băm thì cố định.

Cách neo mã băm còn một điểm quan trọng hơn chi phí: dữ liệu trên blockchain
không xoá được. Hồ sơ lô có tên và địa chỉ hộ nông dân, số điện thoại cơ sở thu
mua; ghi thẳng lên chuỗi công khai là đẩy những thông tin đó ra nơi không thể
thu hồi. Neo mã băm thì chuỗi chỉ giữ 32 byte vô nghĩa với người ngoài, còn dữ
liệu thật nằm trong hệ thống và sửa được khi người dân yêu cầu.

## 6. Đánh giá của người mua: vì sao để ngoài mã băm

Hệ thống có mục đánh giá sao và nhận xét của người mua ngay trong hồ sơ lô.
Phần này **cố ý không nằm trong bản công bố và không vào mã băm**, vì:

- Bản công bố là tuyên bố của nhà sản xuất tại một thời điểm, đã neo lên chuỗi.
  Đánh giá là ý kiến người mua, còn gửi thêm mãi về sau.
- Nếu nhét đánh giá vào bản công bố thì mỗi ngôi sao mới làm mã băm lệch, lô
  chuyển sang trạng thái "dữ liệu đã thay đổi", và phải neo một giao dịch mới
  cho mỗi lần ai đó bấm sao.

Kiểm chứng điều này (đo): sau khi 27 đánh giá được ghi vào hệ thống, trạng thái
toàn vẹn của cả 8 lô đã công bố vẫn là ĐÃ XÁC MINH và mã băm không đổi (kiểm
lại ngày 21/10/2026). Đây chính là cách phân tách hai dòng dữ liệu: thứ đã niêm phong và thứ còn
thay đổi.

Chống gửi trùng: máy khách sinh một mã ẩn danh và lưu lại; máy chủ lưu **mã băm
SHA-256 của mã đó**, không lưu mã gốc, nên biết được hai lần gửi có cùng một máy
hay không mà không biết đó là máy nào. Một máy gửi lại là sửa đánh giá cũ chứ
không cộng thêm phiếu.

## 7. Bảng tổng hợp lựa chọn

| Vấn đề | Phương án chọn | Lý do một dòng |
|---|---|---|
| Niêm phong hồ sơ | SHA-256 | An toàn, có sẵn trong nền tảng, ai cũng kiểm lại được bằng công cụ có sẵn trên máy |
| Lưu dấu niêm phong | Neo mã băm lên VBSN Besu | 2 giây mỗi khối, phí 0,00000366 VNX, trả bằng tiền trong nước, không phải dựng hạ tầng |
| Lượng dữ liệu lên chuỗi | Chỉ 32 byte mã băm | Rẻ hơn khoảng 363 lần, và không đẩy thông tin cá nhân lên chỗ không xoá được |
| Chữ ký giao dịch | ECDSA secp256k1 | Chuẩn của mọi mạng tương thích Ethereum, dùng được ví và công cụ sẵn có |
| Lưu ảnh, video | Khoá theo nội dung (`media/<sha256>`) | Đổi một điểm ảnh là đổi tên tệp, không thay ảnh âm thầm được |
| Đánh giá người mua | Lưu ngoài bản công bố | Không làm lệch mã băm, không phải neo giao dịch cho mỗi ngôi sao |

## 8. Cách kiểm lại các số liệu trong tài liệu

Mọi số có nhãn (đo) đều kiểm lại được, không cần quyền quản trị:

| Việc cần kiểm | Cách làm |
|---|---|
| Mã băm và trạng thái toàn vẹn của một lô | Mở `https://trace.smartbreakfast.store/api/public/traces/TL-2026-004/verify` |
| Mã băm có đúng là tính từ hồ sơ hay không | Bấm "Kiểm lại" trong trang tra cứu: máy chủ băm lại hồ sơ hiện tại rồi so với bản đã công bố |
| Giao dịch trên blockchain | Tra mã giao dịch trong mục 4.3 trên explorer của mạng VBSN |
| Số liệu chuỗi trong mục 4.3 | `node worker/scripts/do-chi-so-chuoi.mjs` |
| Mã băm của một tệp bất kỳ, bằng công cụ của Windows | `certutil -hashfile <tệp> SHA256` |
| Đọc mã băm trực tiếp từ hợp đồng, không qua máy chủ của hệ thống | `node worker/scripts/chain-verify.mjs 0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca <mã băm>` |

## 9. Nguồn tham khảo

1. NIST, *FIPS 180-4: Secure Hash Standard* — chuẩn định nghĩa SHA-256.
2. NIST, *FIPS 202: SHA-3 Standard*.
3. Stevens M. và cộng sự, *The first collision for full SHA-1*, CWI Amsterdam và
   Google, 2017 — đụng độ SHA-1 thực tế đầu tiên.
4. Wang X., Yu H., *How to Break MD5 and Other Hash Functions*, 2005.
5. ethereum.org, *Proof-of-stake (PoS)* — thời gian khối 12 giây, 32 khối một
   epoch: https://ethereum.org/en/developers/docs/consensus-mechanisms/pos/
6. Cosmos, *CometBFT* — đồng thuận BFT State Machine Replication:
   https://docs.cosmos.network/cometbft
7. Hyperledger Fabric, *Introduction* — mạng có cấp phép, không dùng tiền mã
   hoá: https://hyperledger-fabric.readthedocs.io/
8. W3C, *Web Cryptography API* — SHA-256 có sẵn trong nền tảng chạy của hệ thống.
9. Bảng giá gas của Ethereum (20.000 gas cho mỗi ô lưu trữ 32 byte ghi mới) —
   dùng cho phép tính ở mục 5.

---

## Ghi chú cho người viết báo cáo (không chép vào báo cáo)

1. **Không viết "nhóm đã triển khai thử trên Ethereum, Cosmos và Besu".** Sự
   thật là hệ thống chỉ chạy thật trên VBSN Besu; ba phương án kia được so sánh
   theo tiêu chí dựa trên tài liệu công khai. Viết quá lên là không có minh
   chứng, mà phần so sánh theo tiêu chí đã đủ đáp yêu cầu "tìm tòi các giải pháp
   khác nhau để phân tích và lựa chọn giải pháp khả thi".
2. **Đừng gọi SHA-256 là "mã hoá"** ở bất kỳ chỗ nào trong báo cáo. Dùng "hàm
   băm" hoặc "băm". Mục 2 có bảng phân biệt, chép nguyên bảng đó vào là an toàn.
3. Phần đánh giá của người mua hiện đang dùng **dữ liệu dựng sẵn** để thử giao
   diện. Khi có kết quả khảo sát thật thì thay bằng số thật
   (`tools/seed_ratings.py --clear` rồi `tools/nhap_khao_sat.py <tệp.csv>`), và
   trong báo cáo phải ghi đúng nguồn số liệu là phiếu khảo sát nào, bao nhiêu
   người, khảo sát khi nào.
4. Số liệu đo trong tài liệu chốt ngày 21/10/2026. Nếu bảo vệ sau đó một thời
   gian dài thì chạy lại lệnh ở mục 8 để số khối và số lô khớp thực tế.
