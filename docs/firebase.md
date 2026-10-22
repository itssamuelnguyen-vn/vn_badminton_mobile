# Firebase và Google: thông báo đẩy, đăng nhập với Google

Cập nhật: 21/10/2026

Dự án Firebase / Google Cloud: **`vn-badminton-32238`**. Gói Android: `com.vnbadminton.vn_badminton_mobile`.

## `google-services.json` (không commit)

File cấu hình Firebase của app Android, cần cho **thông báo đẩy**. Nằm ở `android/app/google-services.json`, **đã có
trong `.gitignore`** (không phải mật khẩu, nhưng không cần đưa lên repo).

Lấy file: [Firebase console](https://console.firebase.google.com) → dự án `vn-badminton-32238` → ⚙️ **Project settings**
→ **General** → **Your apps** → app Android `com.vnbadminton.vn_badminton_mobile` → **google-services.json**
(Download). Chép vào `android/app/`.

- Có file: `android/app/build.gradle.kts` bật plugin `com.google.gms.google-services` (khai báo trong
  `android/settings.gradle.kts`), app nhận được thông báo.
- Không có file: vẫn build và chạy được, Gradle cảnh báo, app **không có thông báo** (công tắc trong Cài đặt báo
  "Bản app này chưa có thông báo"). `flutter analyze` / `flutter test` và CI không cần file này.

## Thông báo đẩy

- App (`lib/push.dart`): `firebase_core`, `firebase_messaging` (token FCM, thông báo bấm khi app ở nền/đã tắt),
  `flutter_local_notifications` (hiện thông báo khi đang mở app, tạo kênh `updates` có tên theo ngôn ngữ).
  Icon nhỏ `res/drawable/ic_notification.xml` (giữ khi R8 thu gọn tài nguyên: `res/raw/keep.xml`).
- Máy chủ gửi qua FCM HTTP v1 bằng **service account** (biến `FIREBASE_SERVICE_ACCOUNT_PATH` hoặc
  `FIREBASE_SERVICE_ACCOUNT_JSON` trên máy chủ, xem repo vn_badminton, quy tắc TB-01…04). Mỗi thông báo có
  `data.path` (`/bookings/<mã>`, `/payments/<token>`...) để app mở đúng trang như link email.
- `firebase_messaging` 17 khuyên dùng Installation ID (`register()` / `onRegistered`) thay cho `getToken()`; app vẫn
  dùng token FCM vì máy chủ gửi theo `token`. Đổi thì phải đổi cả hai bên.

## Đăng nhập với Google

- App (`lib/google_auth.dart`, gói `google_sign_in` 7): `GoogleSignIn.instance.initialize(serverClientId: ...)` rồi
  `authenticate()`; ID token gửi lên `POST /api/v1/session/google`.
- `serverClientId` là **Web client ID** của dự án (công khai):
  `644407501095-l2oe4an1g7j2ont7spmevspm1l0ea8f0.apps.googleusercontent.com`, mặc định trong code; đổi khi build
  bằng `--dart-define=GOOGLE_WEB_CLIENT_ID=...` (hoặc thêm vào `config/dev.json`). Máy chủ phải nhận cùng ID
  (biến `GOOGLE_WEB_CLIENT_ID`, mặc định cũng là ID này).
- Google chỉ cho đăng nhập khi dự án có **OAuth client loại Android** với đúng gói và **vân tay SHA-1 của khoá ký**.
  APK hiện ký bằng khoá debug: lấy SHA-1 bằng lệnh `keytool` trong [`app-links.md`](app-links.md) (dòng `SHA1:`).
  Khi có khoá phát hành / Google Play App Signing thì thêm SHA-1 của khoá đó. Thiếu → app báo
  "Chưa đăng nhập được bằng Google".
