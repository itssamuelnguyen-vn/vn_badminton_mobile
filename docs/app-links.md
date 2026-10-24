# Link trong email mở thẳng app (Android App Links)

Cập nhật: 24/10/2026

Email của sân có link `https://<máy chủ>/payments/<mã>` và `https://<máy chủ>/bookings/<mã>` (cả `/en/...`); khách gửi
cho nhau link giải đấu `https://<máy chủ>/tournaments/<mã>` và link nhập tỉ số `.../tournaments/<mã>/organize/<mã>`.
Khi app đã cài và link đã được **xác minh**, Android mở thẳng app thay vì trình duyệt:

| Link                          | Mở trong app                     |
|-------------------------------|----------------------------------|
| `/payments/<token>`           | Màn chuyển khoản                 |
| `/bookings/<mã>`              | Chi tiết lượt đặt                |
| `/bookings`                   | Tab Sân đã đặt                   |
| `/tournaments/<mã>`           | Trang giải (không cần đăng nhập) |
| `/tournaments/<mã>/organize/<mã>` | Nhận quyền nhập tỉ số        |
| link khác của máy chủ         | Màn hình chính                   |

Chưa đăng nhập thì app mở màn đăng nhập trước. Code: `lib/deep_links.dart` (đọc link, gói `app_links`),
`HomeShell` (mở màn), `android/app/src/main/AndroidManifest.xml` (intent-filter `autoVerify`).

## Tên miền lấy từ đâu

Tên miền trong intent-filter là `${appLinkHost}`, do `android/app/build.gradle.kts` lấy từ `API_URL` của
`config/dev.json` (Flutter chuyển các `--dart-define` cho Gradle trong thuộc tính `dart-defines`, mỗi giá trị mã hoá
base64). Không có `API_URL` thì dùng `example.invalid` (link không mở app). Đổi máy chủ là phải **build lại**.

## Để Android xác minh link

1. **Vân tay SHA-256 của khoá ký APK.** Hiện APK ký bằng khoá debug:
   ```
   keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   Lấy dòng `SHA256: AB:CD:...`. Khi có keystore phát hành riêng (hoặc Google Play App Signing) thì lấy thêm vân tay
   của khoá đó (Play Console → App integrity).
2. **Trên máy chủ** đặt biến môi trường `ANDROID_CERT_SHA256` (nhiều vân tay cách nhau bởi dấu phẩy), khởi động lại
   rồi kiểm tra `https://<máy chủ>/.well-known/assetlinks.json` có vân tay đó.
3. **Cài lại app** (Android xác minh lúc cài). Kiểm tra: Cài đặt → Ứng dụng → VN Badminton → Mở theo mặc định:
   tên miền phải là "đã xác minh". Hoặc `adb shell pm get-app-links com.vnbadminton.vn_badminton_mobile`.

## Giới hạn

- Chỉ chạy với **HTTPS** và tên miền trả được `assetlinks.json`. Tunnel `trycloudflare.com` có HTTPS nên xác minh
  được, nhưng mỗi lần tunnel đổi URL thì APK cũ không còn khớp: phải build và cài lại. Link trong email cũng phải
  dùng đúng tên miền đó (`APP_HOST` của máy chủ).
- Chưa xác minh được (sai vân tay, máy chủ tắt lúc cài): link mở trình duyệt như cũ. Có thể bật tay trong
  "Mở theo mặc định" → "Thêm đường liên kết".
