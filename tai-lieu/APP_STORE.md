# Đưa ứng dụng Tú Lệ Trace lên CH Play và App Store

Ứng dụng di động chỉ có **trang tra cứu**: quét QR, đọc hồ sơ lô, xem lại lô đã
quét. Màn quản trị không nằm trong bản app (xem `lib/main.dart`, route `/admin`
chỉ khai khi `kIsWeb`), nên người tải app từ cửa hàng không có đường nào chạm
vào dữ liệu vận hành.

## 1. Đã xong trong repo

| Việc | Ở đâu |
|---|---|
| Nền tảng Android và iOS | `android/`, `ios/` |
| Định danh ứng dụng `store.smartbreakfast.trace` | `android/app/build.gradle.kts`, `ios/Runner.xcodeproj` |
| Tên hiển thị "Tú Lệ Trace" | `AndroidManifest.xml`, `ios/Runner/Info.plist` |
| Icon lấy từ logo trên thanh điều hướng | `android/app/src/main/res/mipmap-*`, `ios/.../AppIcon.appiconset` |
| Quét QR bằng camera máy (mobile_scanner) | `lib/ui/qr_scan_screen.dart`, `lib/data/qr_scanner_io.dart` |
| Giải thích quyền camera | `ios/Runner/Info.plist` → `NSCameraUsageDescription` |
| Hồ sơ đã xem, mở lại được khi mất mạng | `lib/data/trace_cache.dart` |
| Mở app từ link QR (App Links / Universal Links) | `AndroidManifest.xml`, `web/.well-known/` |
| Trang chính sách quyền riêng tư | `web/quyen-rieng-tu/index.html` |
| Chỗ cắm khoá ký bản phát hành | `android/key.properties.example` |

Bản thử đã dựng được: `flutter build apk --release` ra APK 68 MB (bản gộp cả ba
kiến trúc CPU), `flutter build appbundle` ra AAB 61 MB. Máy thật tải từ Play chỉ
khoảng 25 MB vì Play tách theo từng dòng máy.

## 2. Việc cần người làm, máy không làm thay được

### 2.1 Tài khoản nhà phát triển

- **Google Play**: 25 USD, trả một lần. Tài khoản **cá nhân mở sau 2023** còn
  phải chạy thử nghiệm khép kín với **ít nhất 12 người trong 14 ngày liên tục**
  trước khi được phát hành công khai. Tài khoản **tổ chức** (có mã số thuế /
  đăng ký kinh doanh) không bị điều kiện này. Nếu dự án có pháp nhân đứng sau
  thì nên mở tài khoản tổ chức ngay từ đầu.
- **Apple**: 99 USD mỗi năm. Tài khoản tổ chức cần mã **D-U-N-S**, xin mất một
  đến hai tuần. Tài khoản cá nhân thì nhanh hơn nhưng tên nhà phát hành trên
  cửa hàng sẽ là tên người, không phải tên thương hiệu.

Điều kiện hai cửa hàng hay đổi, lúc đăng ký nên đọc lại trang chính sách.

### 2.2 Khoá ký Android

```bat
keytool -genkey -v -keystore C:\Users\sontm\keys\tule-upload.jks ^
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Chép `android/key.properties.example` thành `android/key.properties` rồi điền
mật khẩu. File `.jks` và `key.properties` **không bao giờ vào git** (đã nằm
trong `.gitignore`). Mất kho khoá là mất quyền cập nhật ứng dụng.

Lấy vân tay SHA-256 để điền vào `web/.well-known/assetlinks.json`:

```bat
keytool -list -v -keystore C:\Users\sontm\keys\tule-upload.jks -alias upload
```

Nếu bật Play App Signing (mặc định), vân tay phải lấy từ Play Console, mục
**Release → Setup → App signing**, chứ không phải từ kho khoá tải lên.

### 2.3 Liên kết cho iOS

Sau khi có tài khoản Apple, thay `THAYBANGTEAMID` trong
`web/.well-known/apple-app-site-association` bằng Team ID thật, và bật
**Associated Domains** (`applinks:trace.smartbreakfast.store`) trong Xcode.

### 2.4 Dựng bản iOS

Không dựng được trên Windows. Cần một máy macOS có Xcode, hoặc một dịch vụ CI
có máy ảo macOS (Codemagic, GitHub Actions `macos-latest`). Mã nguồn trong
`ios/` đã đủ để mở bằng Xcode và archive.

### 2.5 Hộp thư liên hệ

Trang quyền riêng tư ghi `lien-he@smartbreakfast.store`. Bật Email Routing của
Cloudflare cho địa chỉ này trỏ về hộp thư thật, vì cả hai cửa hàng đều có thể
gửi thư tới đó.

## 3. Lệnh dựng bản nộp

```bash
flutter build appbundle --release          # file nộp lên Play
flutter build apk --release --split-per-abi # bản cài tay để thử
flutter build ipa --release                 # chỉ chạy được trên macOS
```

Muốn trỏ về máy chủ khác thì thêm `--dart-define=API_BASE_URL=...`. Không khai
gì thì app dùng `https://trace.smartbreakfast.store/api`.

## 4. Nội dung khai báo trên cửa hàng

**Tên**: Tú Lệ Trace

**Mô tả ngắn (Play, tối đa 80 ký tự)**:
Quét QR trên bao bì để xem nguồn gốc từng lô nông sản Tây Bắc.

**Mô tả đầy đủ**:

> Tú Lệ Trace cho người mua tự kiểm tra nguồn gốc của gói hàng đang cầm trên
> tay. Quét mã QR in trên bao bì, ứng dụng mở hồ sơ của đúng lô đó: nguyên liệu
> lấy từ vùng nào, qua những công đoạn nào, ngày nào, khối lượng vào ra bao
> nhiêu, kèm hình ảnh của từng bước.
>
> Mỗi lần nhà sản xuất công bố một lô, toàn bộ hồ sơ được tính thành một mã băm
> và ghi lên blockchain. Ứng dụng tính lại mã băm từ dữ liệu đang hiển thị và
> đối chiếu, nên bạn thấy ngay hồ sơ còn nguyên vẹn hay đã bị sửa sau khi công
> bố, và xem được giao dịch tương ứng trên trình duyệt chuỗi.
>
> - Quét QR bằng camera, hoặc nhập mã in trên bao bì
> - Sơ đồ nguyên liệu và công đoạn theo từng nhánh
> - Hình ảnh vùng nguyên liệu, công đoạn, phiếu kiểm nghiệm
> - Lô đã xem được lưu lại, mở lại được cả khi không có mạng
> - Không cần tài khoản, không quảng cáo, không thu thập dữ liệu cá nhân

**Phân loại**: Mua sắm (Shopping) · **Đối tượng**: 3+ / 4+

**Chính sách quyền riêng tư**: https://trace.smartbreakfast.store/quyen-rieng-tu/

**Khai báo Data safety (Play) và App Privacy (Apple)**: không thu thập dữ liệu
nào. Camera chỉ xử lý tại chỗ, không gửi đi, nên khai là *không thu thập*.

**Ảnh chụp màn hình**: tối thiểu 2 ảnh cho Play (dọc 1080×1920 trở lên), và cho
App Store cần bộ 6.7 inch (1290×2796). Chụp bốn màn: trang tra cứu, hồ sơ lô,
sơ đồ nguồn gốc, dải kiểm chứng blockchain.

## 5. Ghi chú gửi cho người duyệt App Store

Apple hay từ chối theo mục 4.2 những ứng dụng chỉ là trang web đóng gói lại.
Trong phần *App Review Information* nên nói rõ phần mà bản web không làm được:

> Ứng dụng dùng camera của máy để quét mã QR trên bao bì sản phẩm, và lưu hồ sơ
> đã xem vào bộ nhớ máy để người mua mở lại được tại nơi không có sóng (vùng
> trồng, chợ đầu mối). Mã thử: TL-2026-002 và TB-2026-001, nhập thẳng vào ô tra
> cứu nếu không có bao bì để quét.

## 6. Việc còn lại trong mã nguồn

- `assets/brand/logo-mark.png` chỉ 128px. Icon 1024px của cửa hàng đang phóng
  từ file này nên hơi mềm nét; có file gốc độ phân giải cao thì chạy lại đoạn
  sinh icon trong lịch sử commit.
- Chưa có màn hình "giới thiệu lần đầu" và chưa có bản tiếng Anh. Cả hai cửa
  hàng đều không bắt buộc.
