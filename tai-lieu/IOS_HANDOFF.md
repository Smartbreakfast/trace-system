# Dựng và nộp bản iOS trên máy macOS

Tài liệu này viết cho phiên làm việc trên máy Mac. Phần cấu hình đã làm sẵn ở
máy Windows, bên đó chỉ còn ký, dựng và nộp. Đọc hết trước khi gõ lệnh đầu tiên.

Ứng dụng chỉ có **trang tra cứu**: quét QR, đọc hồ sơ lô, kiểm chứng mã băm.
Màn quản trị không nằm trong bản app (`lib/main.dart`, route `/admin` chỉ khai
khi `kIsWeb`), và có test chặn hồi quy chỗ đó.

## 1. Đã làm sẵn trong repo

| Việc | Ở đâu |
|---|---|
| Định danh `store.smartbreakfast.trace` | `ios/Runner.xcodeproj/project.pbxproj` |
| Tên hiển thị "Tú Lệ Trace" | `ios/Runner/Info.plist` → `CFBundleDisplayName` |
| Giải thích quyền camera (tiếng Việt) | `Info.plist` → `NSCameraUsageDescription` |
| Khai miễn mã hoá xuất khẩu | `Info.plist` → `ITSAppUsesNonExemptEncryption` = false |
| Associated Domains | `ios/Runner/Runner.entitlements`, đã nối vào cả ba cấu hình build |
| Bộ icon đầy đủ, không kênh alpha | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Tệp khai quyền riêng tư của thư viện | mobile_scanner, shared_preferences, url_launcher đều có sẵn `PrivacyInfo.xcprivacy` |
| Máy chủ mặc định | `https://trace.smartbreakfast.store/api`, không cần `--dart-define` |

Chưa có `ios/Podfile`: Flutter tự sinh ở lần build đầu trên macOS.

## 2. Việc cần làm, theo thứ tự

### 2.1 Chuẩn bị

```bash
git pull
flutter --version          # máy Windows đang dùng 3.44.8
flutter pub get
flutter analyze            # phải sạch
flutter test               # 42 test, phải xanh hết
```

### 2.2 Ký

Mở `ios/Runner.xcworkspace` bằng Xcode (chạy `flutter build ipa --release` một
lần trước để có Podfile và workspace, lệnh này hỏng ở bước ký cũng không sao).

Trong Xcode: chọn target **Runner** → tab **Signing & Capabilities** → bật
*Automatically manage signing* → chọn **Team**. Xcode sẽ tự tạo App ID và tự bật
quyền Associated Domains, vì tệp entitlements đã khai sẵn. Nếu mục **Associated
Domains** không hiện ra trong tab đó thì build setting chưa được đọc, kiểm lại
`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`.

### 2.3 Điền Team ID vào máy chủ (bắt buộc, nếu không thì liên kết chết)

Lấy **Team ID** (10 ký tự, xem ở Xcode mục Signing hoặc trang Membership của
Apple Developer), rồi sửa `web/.well-known/apple-app-site-association`, thay
`THAYBANGTEAMID`:

```json
"appIDs": ["ABCDE12345.store.smartbreakfast.trace"]
```

Rồi deploy lại Cloudflare Pages:

```bash
flutter build web --release --pwa-strategy=none --no-web-resources-cdn \
  --dart-define=PUBLIC_BASE_URL=https://trace.smartbreakfast.store
npx wrangler pages deploy build/web --project-name tule-trace --branch main
```

Máy Mac có thể chưa đăng nhập Cloudflare. Nếu `wrangler` đòi đăng nhập thì chạy
`npx wrangler login`, và nhớ `CLOUDFLARE_ACCOUNT_ID=13a60d82b30a98d81aa85fdc37755a1c`
vì tài khoản có hai account, wrangler không tự chọn được.

Không làm được bước này trên Mac thì commit phần sửa `apple-app-site-association`
rồi nhắn về máy Windows, bên đó deploy.

Kiểm tra sau khi deploy:

```bash
curl -s https://trace.smartbreakfast.store/.well-known/apple-app-site-association
```

Phải ra JSON có Team ID thật, và `Content-Type: application/json`.

### 2.4 Dựng và nộp

```bash
flutter build ipa --release
```

Rồi mở Xcode → **Window → Organizer** → chọn bản vừa dựng → **Distribute App** →
*App Store Connect*. Hoặc dùng app **Transporter** với tệp
`build/ios/ipa/*.ipa`.

Số build (`CFBundleVersion`) phải tăng ở mỗi lần tải lên. Nó lấy từ phần sau dấu
`+` trong `pubspec.yaml` (`version: 1.0.0+1`). Nộp bản thứ hai thì sửa thành
`1.0.0+2`.

### 2.5 Khai báo trên App Store Connect

Chữ đã soạn sẵn ở `tai-lieu/APP_STORE.md` mục 4, dán thẳng vào. Mấy chỗ hay
quên:

- **Chính sách quyền riêng tư**: `https://trace.smartbreakfast.store/quyen-rieng-tu/` (đã chạy thật)
- **App Privacy**: không thu thập dữ liệu nào. Camera xử lý tại chỗ, không gửi đi, không lưu lại.
- **Ảnh màn hình**: chụp bằng giả lập iPhone lớn nhất có trong Xcode. App Store Connect ghi rõ kích thước nó đòi, cứ theo đó. Chụp bốn màn: trang tra cứu, hồ sơ lô, sơ đồ nguồn gốc, dải kiểm chứng blockchain.
- **App Review Information**: dán đoạn ở `APP_STORE.md` mục 5. Quan trọng, vì Apple hay gạt theo mục 4.2 những app bị cho là web đóng gói lại. Đoạn đó nói rõ hai thứ bản web không làm được: quét QR bằng camera máy, và xem lại hồ sơ đã tải khi mất sóng. Mã để người duyệt thử: `TL-2026-002` và `TB-2026-001`, nhập thẳng vào ô tra cứu.

## 3. Những chỗ dễ vấp

- **Liên kết không mở app**: iOS chỉ xác minh `apple-app-site-association` lúc cài app. Sửa file trên máy chủ xong phải gỡ app và cài lại mới thấy tác dụng.
- **Icon bị từ chối**: icon 1024 không được có kênh alpha. Bộ hiện tại đã bỏ alpha, nhưng nếu sinh lại icon thì nhớ điều đó.
- **Ảnh nguồn của icon chỉ 128px** (`assets/brand/logo-mark.png`), nên icon 1024 hơi mềm nét. Có file logo gốc lớn hơn thì sinh lại trước khi nộp.
- **Camera trên giả lập**: giả lập iOS không có camera thật, nút quét sẽ báo lỗi. Thử quét phải dùng iPhone thật.

## 4. Dữ liệu đang chạy

Production thật, không phải mock: 4 lô Tú Lệ, 3 lô thịt trâu và 1 lô nguyên
liệu, tất cả đều ĐÃ XÁC MINH và có giao dịch đã xác nhận trên VBSN Besu
(chainId 84001). Đừng chạy `worker/scripts/smoke-test.js` trỏ vào production:
nó tạo lô thật và bắn giao dịch thật lên chuỗi.
