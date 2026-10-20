# Quy tắc nghiệp vụ của app khách

Cập nhật: 20/10/2026

Máy chủ (repo [vn_badminton](https://github.com/itssamuelnguyen-vn/vn_badminton), `docs/business-rules.md`) **quyết định mọi quy tắc**:
giờ mở cửa, giá, giới hạn đặt sân, hạn huỷ, thanh toán... App chỉ hiển thị và gửi yêu cầu; khi app và máy chủ khác nhau thì máy chủ đúng.
File này ghi những gì **app tự làm** (hiển thị, kiểm tra trước, lưu trên máy) và quy tắc máy chủ tương ứng (cột "Máy chủ").

## 1. Chung

| Mã     | Quy tắc                                                                                                                                                          | Máy chủ | Nguồn                                     |
|--------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|-------------------------------------------|
| APP-01 | App **chỉ dành cho khách**: không có chức năng nào của chủ sân/nhân viên.                                                                                        | AP-01   | `lib/screens/`                            |
| APP-02 | Giờ luôn hiện theo **giờ của sân (UTC+7)**, dù điện thoại đặt múi giờ khác.                                                                                      |         | `lib/format.dart`                         |
| APP-03 | **Tiếng Việt** (mặc định) và **English**. Đổi ngôn ngữ thì lưu trên máy và vào tài khoản; mọi yêu cầu gửi `Accept-Language` để máy chủ trả thông báo đúng tiếng. | AP-03   | `lib/strings.dart`, `lib/app_state.dart`  |
| APP-04 | Địa chỉ máy chủ lấy từ `config/dev.json` (`API_URL`) lúc build; thiếu thì app chỉ báo "Chưa cấu hình địa chỉ máy chủ".                                           |         | `lib/api.dart`, `lib/screens/home_shell.dart` |

## 2. Tài khoản

| Mã     | Quy tắc                                                                                                                                                                                         | Máy chủ    | Nguồn                                |
|--------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------|--------------------------------------|
| APP-10 | Token đăng nhập lưu trong **bộ nhớ an toàn** của điện thoại (`flutter_secure_storage`); đăng xuất hoặc xoá tài khoản thì xoá token. Máy chủ trả 401 → app coi như đã đăng xuất.                | AP-02      | `lib/app_state.dart`                 |
| APP-11 | Đăng ký phải **đồng ý chính sách quyền riêng tư** (có link đọc).                                                                                                                                | TK-01      | `lib/screens/auth_screens.dart`      |
| APP-12 | **Ảnh đại diện** thu nhỏ trên máy (tối đa 512 px, chất lượng 85) trước khi gửi; máy chủ nhận ≤ 2 MB. Năm sinh, giới tính, trình độ **không bắt buộc**; năm sinh từ 1900 tới năm nay.            | TK-10      | `lib/screens/profile_screen.dart`    |
| APP-13 | **Xoá tài khoản**: hỏi mật khẩu; máy chủ không cho xoá (còn lượt phải chơi/chờ chuyển khoản) thì báo lý do. Xoá xong app đăng xuất và báo ngày xoá hẳn (nếu có).                                | TK-08      | `lib/screens/account_screen.dart`    |
| APP-14 | **Khoá bằng vân tay/khuôn mặt** (tuỳ chọn): bật phải xác thực thành công một lần; khi bật, app hỏi lúc mở và khi quay lại sau **5 phút** ở nền. Máy không có khoá màn hình thì không bật được. |            | `lib/app_lock.dart`, `lib/screens/settings_screen.dart` |

## 3. Đặt sân

| Mã     | Quy tắc                                                                                                                                                                                                   | Máy chủ        | Nguồn                                |
|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|--------------------------------------|
| APP-20 | Lịch xem được **khi chưa đăng nhập**; bấm "Tiếp tục" mới phải đăng nhập.                                                                                                                                   | DAT-01         | `lib/screens/schedule_screen.dart`   |
| APP-21 | Chọn ô: **mỗi sân một khoảng giờ liền**, chọn được **nhiều sân**. Bỏ chọn một ô thì bỏ luôn các ô sau nó; chọn ô không liền thì bắt đầu khoảng mới.                                                       | DAT-03         | `lib/screens/schedule_screen.dart`   |
| APP-22 | Thanh tổng hiện số sân, số giờ, tổng tiền; khoảng ngắn hơn **thời lượng tối thiểu** thì không cho tiếp tục (máy chủ vẫn kiểm tra lại mọi quy tắc).                                                        | DAT-03         | `lib/screens/schedule_screen.dart`   |
| APP-23 | Tải lại lịch (kéo xuống, nút làm mới, sau khi đặt) **giữ ô đang chọn**, trừ ô vừa bị người khác lấy.                                                                                                      | VH-08          | `lib/screens/schedule_screen.dart`   |
| APP-24 | Email **chưa xác minh** → không đặt được; app mời gửi lại email xác minh.                                                                                                                                  | DAT-01         | `lib/screens/schedule_screen.dart`   |
| APP-25 | Bước xác nhận: **giữ chỗ 3 phút** có đếm ngược; rời màn này mà chưa đặt thì **trả chỗ ngay** cho người khác; hết giờ thì phải chọn lại.                                                                   | DAT-05         | `lib/screens/confirm_screen.dart`    |

## 4. Thanh toán

| Mã     | Quy tắc                                                                                                                                                                                       | Máy chủ        | Nguồn                               |
|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|-------------------------------------|
| APP-30 | Màn chuyển khoản: mã QR, thông tin tài khoản (bấm để chép), **số tiền còn thiếu** và **nội dung chuyển khoản** (phải đúng), đếm ngược **15 phút**.                                            | TT-02, TT-03   | `lib/screens/payment_screen.dart`   |
| APP-31 | Khi màn chuyển khoản đang mở, app **hỏi máy chủ 4 giây một lần**; tiền về thì chuyển sang "Đã nhận tiền". Dừng hỏi khi đã thanh toán, hết hạn hoặc bị huỷ.                                     | TT-04          | `lib/screens/payment_screen.dart`   |
| APP-32 | Chuyển thiếu: hiện số đã nhận và số còn thiếu, chuyển thêm cùng nội dung.                                                                                                                     | TT-04          | `lib/screens/payment_screen.dart`   |

## 5. Sân đã đặt

| Mã     | Quy tắc                                                                                                                                       | Máy chủ        | Nguồn                               |
|--------|-----------------------------------------------------------------------------------------------------------------------------------------------|----------------|-------------------------------------|
| APP-40 | Danh sách **tải lại mỗi lần mở tab**: chờ chuyển khoản, sắp tới, đã qua/đã huỷ.                                                               |                | `lib/screens/home_shell.dart`       |
| APP-41 | Nút **Huỷ** chỉ hiện khi máy chủ cho (`can_cancel`, trước hạn huỷ); lượt **đã thanh toán** thì cảnh báo **không hoàn tiền** trước khi huỷ.   | HUY-01         | `lib/screens/booking_screen.dart`   |

## 6. Khác

| Mã     | Quy tắc                                                                                                       | Máy chủ | Nguồn                                  |
|--------|---------------------------------------------------------------------------------------------------------------|---------|----------------------------------------|
| APP-50 | **Có gì mới**: mỗi phiên bản gửi cho khách thêm một mục trong `releases` (mới nhất trước).                   |         | `lib/screens/whats_new_screen.dart`    |
| APP-51 | Liên hệ: gọi, Zalo, Messenger và **chỉ đường** (Google Maps theo địa chỉ sân) chỉ hiện kênh chủ sân đã nhập. | CS-05   | `lib/screens/account_screen.dart`      |
