# Build file APK

Cập nhật: 21/10/2026

Dùng khi cần một file APK để cài lên điện thoại (gửi cho người khác, cài không cần cắm cáp).
Khi chỉ chạy thử trên máy mình thì vẫn dùng `F5` / `flutter run` như bình thường.

## Các bước

1. **Kiểm tra server.** Mở `config/dev.json`: `API_URL` là địa chỉ app sẽ gọi tới, và nó được **ghi cứng vào APK**.
   - Tunnel thử nghiệm: `start-tunnel` (trong WSL, repo vn_badminton) tự ghi URL mới vào file này.
   - Mỗi lần tunnel đổi URL thì APK cũ không kết nối được nữa: phải build lại.
2. **Build.** Trong VS Code nhấn **`Ctrl+Shift+B`** (task "Build APK").
   Hoặc gõ trong terminal: `powershell -ExecutionPolicy Bypass -File tool/build_apk.ps1`
3. **Chờ.** Lần đầu (hoặc sau `flutter clean`) khoảng **7 phút**, các lần sau khoảng **2 phút**.
   Cuối cùng terminal in ra:
   ```
   APK: D:\dev\vn_badminton_mobile\build\apk\vnbadminton-0.5.0.apk
   Server: https://....trycloudflare.com
   ```
   Xem lại dòng **Server** cho đúng địa chỉ muốn dùng.
4. **Cài.** Chép `build\apk\vnbadminton-<phiên bản>.apk` sang điện thoại, mở file, cho phép
   "Cài ứng dụng không rõ nguồn gốc". Cài đè lên bản cũ được (cùng khoá ký).

## Các file tạo ra (`build\apk\`)

| File                                | Dùng cho                                     |
|-------------------------------------|----------------------------------------------|
| `vnbadminton-<phiên bản>.apk`        | Gần như mọi điện thoại hiện nay (arm64)      |
| `vnbadminton-<phiên bản>-arm32.apk`  | Điện thoại Android rất cũ (32-bit)           |
| `vnbadminton-<phiên bản>-x86_64.apk` | Máy ảo (emulator)                            |

Phiên bản lấy từ dòng `version:` của `pubspec.yaml` (phần trước dấu `+`).
Khi gửi bản mới cho khách: tăng `version` và thêm mục vào `releases` trong `lib/screens/whats_new_screen.dart`.

## Khi có lỗi

- **Lỗi lạ sau khi đổi thư viện / pull code mới:** `flutter clean`, `flutter pub get`, rồi build lại (lần này lâu như lần đầu).
- **`OutOfMemoryError` hoặc build treo ở bước R8:** RAM cho Gradle là `org.gradle.jvmargs=-Xmx3g` trong
  `android/gradle.properties`; đóng bớt ứng dụng, hoặc tăng lên `-Xmx4g`.
- **App mở được nhưng không tải được dữ liệu:** server trong APK không còn chạy (tunnel đã đổi URL hoặc WSL đã tắt).
  Kiểm tra `<URL>/up` trên trình duyệt điện thoại phải hiện trang xanh, rồi build lại nếu URL đã đổi.

## Lưu ý

- APK hiện ký bằng **khoá debug**: cài thử thoải mái, nhưng **không đưa lên Google Play** được.
  Trước khi phát hành phải tạo keystore riêng (cấu hình `signingConfig` trong `android/app/build.gradle.kts`).
- `config/dev.json` không được commit.
