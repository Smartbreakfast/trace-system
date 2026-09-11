# Truy xuất phi tập trung: mỗi bên tự ký phần của mình

Bản thiết kế cho bước tiếp theo của Tú Lệ Trace: thay vì một admin gõ hộ toàn
bộ hồ sơ, mỗi bên tham gia tự đẩy công đoạn của mình lên chuỗi, rồi lô thành
phẩm tham chiếu ngược lại các bản ghi đó.

**Bước 1 đã chạy**: hợp đồng `TuleTrace` đã triển khai trên VBSN Besu
(`0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca`, chainId 84001) và worker tự neo
mã băm của mỗi lô sau khi hoàn thành. Phần còn lại của tài liệu này — cho từng
nhà cung cấp tự ký — vẫn là kế hoạch, vì phần khó nhất không phải hợp đồng thông
minh mà là **cách nhà cung cấp đăng nhập**.

## 1. Hiện trạng

Hệ thống đang chạy tập trung, nhưng đã có neo chuỗi:

- Admin nhập cả bốn nguyên liệu, cả công đoạn đóng gói.
- Bấm "Hoàn thành lô" thì tạo snapshot canonical, băm SHA-256, lưu vào D1, đẩy
  mã băm vào `blockchain_outbox`, rồi gửi lên VBSN Besu bằng ví của thương
  hiệu. Giao dịch xong thì trang công khai hiện liên kết tới explorer.

Điểm yếu không nằm ở kỹ thuật mà ở lời hứa: mã băm chỉ chứng minh **admin không
sửa dữ liệu sau khi chốt**. Nó không chứng minh hợp tác xã Tú Lệ có thật sự giao
lô cốm đó hay không, vì chính admin là người gõ dòng ấy vào.

Phi tập trung giải quyết đúng chỗ đó: chữ ký của hợp tác xã, không phải của
thương hiệu.

## 2. Mô hình hai tầng

**Tầng 1 — nhà cung cấp ký lô nguyên liệu của mình.**
Hợp tác xã Tú Lệ tạo lô cốm: tên, vùng trồng, ngày thu hoạch, ảnh, các công
đoạn. Bấm gửi thì client dựng snapshot canonical, băm SHA-256, ký bằng khoá của
hợp tác xã và ghi lên chuỗi một sự kiện:

```
IngredientAnchored(bytes32 hash, address supplier, string ref, uint64 at)
```

`ref` là mã lô nguyên liệu (ví dụ `COM-TL-2026-08`), đủ để tra ngược; dữ liệu
thật vẫn nằm ở D1 và R2, chuỗi chỉ giữ mã băm.

**Tầng 2 — thương hiệu ký lô thành phẩm.**
Admin lập lô `TL-2026-003` bằng cách **chọn** các lô nguyên liệu đã được ký, chứ
không gõ tay. Snapshot của lô thành phẩm nhúng đúng những mã băm đó, rồi ghi:

```
BatchAnchored(bytes32 hash, address brand, string code, bytes32[] inputs, uint64 at)
```

`inputs` là mảng mã băm của bốn nguyên liệu cộng công đoạn đóng gói. Khách quét
QR kiểm được hai việc tách bạch:

1. Dữ liệu đang xem khớp với mã băm đã ghi lên chuỗi (như hiện nay).
2. Từng nguyên liệu được ký bởi **địa chỉ của chính nhà cung cấp**, có tên trong
   sổ đăng ký, chứ không phải bởi thương hiệu.

Việc thứ hai mới là thứ mà một tờ giấy chứng nhận không làm được.

## 3. Ai là "một bên"

Với công thức hiện tại có sáu vai:

| Vai | Ai | Ký gì |
| --- | --- | --- |
| Nhà cung cấp cốm | Hợp tác xã Tú Lệ | lô cốm |
| Nhà cung cấp lạc | Tổ hợp tác Lục Yên | lô lạc đỏ |
| Nhà cung cấp chuối | Vùng trồng Bảo Thắng | lô chuối tiêu hồng |
| Nhà cung cấp khoai | Hộ sản xuất Lâm Thượng | lô khoai môn |
| Xưởng đóng gói | Xưởng chế biến Nghĩa Lộ | công đoạn phối trộn, đóng gói |
| Thương hiệu | Tú Lệ Lab | lô thành phẩm |

Xưởng đóng gói cũng là một bên ký, không phải một dòng do admin gõ. Nếu để admin
gõ hộ thì cả chuỗi vẫn phụ thuộc một người.

## 4. Đăng nhập: phần khó, và ba cách

Đây là chỗ bạn đang mắc. Ba cách, kèm cái giá của từng cách.

### A. Ví thật, nhà cung cấp tự giữ khoá (MetaMask hoặc ví riêng)

Phi tập trung đúng nghĩa. Nhưng người dùng thật của mình là hợp tác xã ở Yên
Bái, không phải dân crypto: phải giữ 12 từ khoá, phải có MATRIX để trả gas, mất
điện thoại là mất danh tính. Đây là cách gần như chắc chắn làm hỏng dự án ở bước
triển khai thực tế.

### B. Server giữ khoá hộ (custodial), đăng nhập bằng số điện thoại

Dễ dùng nhất: nhập số điện thoại, nhận OTP, xong. Server tạo ví cho mỗi nhà cung
cấp và ký hộ.

Nhưng lúc đó chữ ký "của hợp tác xã" thực chất do server tạo ra. Server có thể ký
thay bất kỳ ai, nên với bên thứ ba nó **không chứng minh được gì hơn hiện tại**.
Vẫn dùng được, miễn là giao diện công khai đừng ghi "nhà cung cấp đã xác nhận".

### C. Khoá nằm trên máy nhà cung cấp, server trả gas (khuyến nghị)

Cách này giữ được cái lợi của A mà tránh được cả ba cái khó của nó:

- Khoá sinh ngay trên điện thoại nhà cung cấp, mã hoá bằng mã PIN sáu số hoặc
  passkey của máy. Bản sao lưu đã mã hoá đẩy lên server — server giữ được bản
  sao nhưng không mở được.
- Nhà cung cấp ký một thông điệp EIP-712 (chuẩn ký có cấu trúc, hiện rõ nội dung
  đang ký), không phải ký một giao dịch.
- Server đóng vai relayer: nhận chữ ký, tự trả gas, gửi giao dịch lên VBSN. Nhà
  cung cấp không cần biết gas là gì, không cần có MATRIX.
- Verify vẫn ra đúng địa chỉ của nhà cung cấp, vì chữ ký là của họ. Relayer chỉ
  là người đưa thư.

Mất máy thì khôi phục bằng bản sao lưu đã mã hoá cộng OTP; hỏng hẳn thì admin
thu hồi địa chỉ cũ trong sổ đăng ký và cấp địa chỉ mới — lịch sử cũ vẫn còn
nguyên và vẫn đúng, chỉ là từ thời điểm đó nhà cung cấp ký bằng địa chỉ mới.

Chuẩn liên quan: EIP-712 (ký có cấu trúc), EIP-2771 (`trusted forwarder` để hợp
đồng biết ai là người ký thật thay vì người trả gas).

### Khuyến nghị

Làm **C**, nhưng đi theo hai giai đoạn để không tắc ở khâu phát hành khoá:

- **Giai đoạn 1**: admin vẫn nhập thay, trang công khai ghi đúng sự thật là "do
  thương hiệu công bố". Không dùng chữ "nhà cung cấp xác nhận".
- **Giai đoạn 2**: bật cổng nhà cung cấp cho từng bên một, bắt đầu bằng hợp tác
  xã Tú Lệ. Bên nào đã tự ký thì nhãn trên trang công khai đổi thành "hợp tác xã
  Tú Lệ tự ký ngày ...". Bên chưa bật vẫn hiện nhãn cũ.

Nhãn phản ánh đúng ai ký. Đó là ranh giới không được nhoè, vì cả sản phẩm này
bán bằng chữ tín.

## 5. Cổng nhà cung cấp trông như thế nào

Đường dẫn riêng, không dùng chung với `/admin`:

```
/ncc            đăng nhập bằng số điện thoại + OTP
/ncc/lo         danh sách lô nguyên liệu của chính mình
/ncc/lo/moi     tạo lô: tên, ngày thu hoạch, vùng, ảnh, công đoạn
```

Ba nguyên tắc cho màn này:

1. Không có chữ "ví", "gas", "hash", "blockchain" trong luồng thao tác. Nút cuối
   cùng là **"Gửi"**, sau khi gửi hiện **"Đã gửi lên blockchain"** kèm mã ngắn để
   tra cứu.
2. Mỗi nhà cung cấp chỉ thấy lô của mình. Không thấy giá, không thấy lô thành
   phẩm của thương hiệu.
3. Gửi rồi thì không sửa được, chỉ tạo bản mới — vì bản cũ đã nằm trên chuỗi.
   Nói trước điều này ở màn xác nhận, đừng để họ phát hiện sau.

Phía admin đổi một chỗ quan trọng: khi thêm nguyên liệu vào lô, thay vì gõ tay
thì **chọn từ các lô nguyên liệu đã được nhà cung cấp gửi**. Vẫn giữ đường nhập
tay cho bên chưa lên hệ thống, nhưng đánh dấu rõ là nhập hộ.

## 6. Hợp đồng thông minh

Đã triển khai: `contracts/TuleTrace.sol` nằm trên **VBSN Besu** (chainId 84001,
RPC `https://besu-rpc.vbsn.vn`) tại địa chỉ
`0xcd6811f9a06d706978033edb6ecaf72d37ffd3ca`, từ khối 4.410.749
(11.09.2026). Địa chỉ trùng với bản cũ trên VNID Chain vì cùng ví triển khai và
cùng nonce 0, không phải cùng một hợp đồng.

Hai điều kiện của mạng này, gặp lúc triển khai:

- **Máy ảo trước Shanghai.** Bytecode mặc định của solc 0.8.24 có opcode PUSH0
  (`0x5f`) và node từ chối ngay ở bước ước lượng gas: *Invalid opcode: 0x5f*.
  `scripts/deploy-contract.mjs` biên dịch với `evmVersion: 'paris'` để tránh.
- **RPC giới hạn bề rộng khoảng khối của `eth_getLogs`.** Quét từ khối 0 bị trả
  về *Requested range exceeds maximum RPC range limit*, nên
  `scripts/chain-verify.mjs` bắt đầu từ khối triển khai và cắt thành từng đoạn
  5.000 khối.

Hợp đồng chỉ phát sự kiện, không lưu dữ liệu — rẻ và đủ dùng, vì thứ cần bất
biến là mã băm và thời điểm, còn nội dung nằm ở D1 và R2 (và vì dữ liệu cá nhân
thì không được đưa lên chuỗi, xoá không được).

```solidity
contract TuleTrace {
  uint8 constant ROLE_NONE = 0;      // 1 SUPPLIER, 2 PACKAGER, 3 BRAND
  mapping(address => uint8) public roleOf;
  mapping(address => string) public nameOf;

  event ActorSet(address indexed actor, uint8 role, string name);
  event IngredientAnchored(bytes32 indexed hash, address indexed by, string ref, uint64 anchoredAt);
  event BatchAnchored(bytes32 indexed hash, address indexed by, string code,
                      uint32 version, bytes32[] inputs, uint64 anchoredAt);

  function setActor(address actor, uint8 role, string calldata name) external onlyOwner;
  function anchorIngredient(bytes32 hash, string calldata ref) external;      // vai bất kỳ
  function anchorBatch(bytes32 hash, string calldata code, uint32 version,
                       bytes32[] calldata inputs) external;                    // chỉ BRAND
}
```

Sổ đăng ký (`roleOf`, `nameOf`) do thương hiệu quản lý. Nó không phải chỗ yếu:
người xem vẫn thấy được ai cấp phép cho ai và từ lúc nào, và một địa chỉ bị cấp
sai thì hiện rõ trên chuỗi.

Hôm nay worker mới gọi `anchorBatch`, và mảng `inputs` còn rỗng vì lô nguyên
liệu chưa được neo riêng. Khi bật cổng nhà cung cấp thì `anchorIngredient` chạy
trước, rồi `inputs` mới có nội dung — hợp đồng không phải sửa.

Kiểm chứng phía khách chỉ cần đọc log theo `topic0` và mã băm, không cần chỉ mục
riêng: `worker/scripts/chain-verify.mjs` làm đúng việc đó trong 40 dòng.

## 7. Việc phải làm trong dữ liệu

Bảng mới:

```sql
CREATE TABLE suppliers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  region TEXT NOT NULL,
  role TEXT NOT NULL,              -- SUPPLIER | PACKAGER
  phone TEXT,                       -- đăng nhập
  wallet_address TEXT,              -- địa chỉ ký, có sau khi họ tạo khoá
  status TEXT NOT NULL,             -- INVITED | ACTIVE | REVOKED
  created_at TEXT NOT NULL
);
```

Sửa bảng có sẵn:

- `ingredient_batches`: thêm `supplier_id`, `snapshot_hash`, `signature`,
  `signed_at`, `chain_tx`.
- `blockchain_outbox`: thêm `kind` (`INGREDIENT` | `PRODUCT`) để một hàng chờ
  phục vụ cả hai tầng.
- Snapshot của lô thành phẩm: thêm mảng `ingredientHashes` để mã băm cha thật sự
  phụ thuộc mã băm con. Không có trường này thì tầng hai chỉ là hai bản ghi rời
  nhau đặt cạnh nhau.

## 8. Thứ tự làm

1. ~~**Relayer + hợp đồng, giữ nguyên luồng hiện tại.**~~ **Xong.** Hợp đồng
   `TuleTrace` đã lên VBSN Besu, worker ký bằng ví thương hiệu và tự gửi sau mỗi
   lần hoàn thành lô; nhãn `ĐÃ LƯU CHUỖI` giờ là sự thật đọc từ `tx_hash`.
2. **Sổ đăng ký và danh sách nhà cung cấp trong admin.** Chưa có đăng nhập, chỉ
   khai báo ai là ai.
3. **Cổng nhà cung cấp với khoá trên máy.** Bắt đầu bằng một hợp tác xã thật, đo
   xem họ vướng ở đâu trước khi mở cho cả bốn.
4. **Nối tầng hai.** Admin chọn lô nguyên liệu đã ký; snapshot nhúng mã băm con;
   trang công khai hiện ai ký phần nào.

Bước 1 làm được ngay và có giá trị ngay. Bước 3 mới là bước quyết định dự án này
có phi tập trung thật hay không, và nó là bài toán con người nhiều hơn bài toán
kỹ thuật: phải ngồi cùng một hợp tác xã, xem họ dùng điện thoại gì, ai là người
thật sự bấm máy.

## 9. Những chỗ dễ tự lừa mình

- **Ghi lên chuỗi không làm dữ liệu thành thật.** Nó chỉ làm dữ liệu không sửa
  được sau khi ghi. Sai từ đầu thì sai vĩnh viễn, và còn khó cãi hơn.
- **Server ký hộ vẫn là tập trung**, dù giao dịch nằm trên chuỗi công khai.
- **Ảnh phải nằm trong phạm vi băm** (hiện đã đúng: khoá R2 theo nội dung nằm
  trong snapshot). Nếu không, tráo ảnh sau khi ghi chuỗi vẫn qua mặt được.
- **Đừng ghi dữ liệu cá nhân lên chuỗi.** Tên hợp tác xã thì được; số điện thoại,
  số căn cước thì không, vì xoá không được.
