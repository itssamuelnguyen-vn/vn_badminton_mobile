# Quy tắc nghiệp vụ của app khách

Cập nhật: 21/10/2026 (tải dữ liệu, link email mở trong app, thêm vào lịch của điện thoại)

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
| APP-05 | **Link trong email mở thẳng app** (Android App Links, `docs/app-links.md`): `/payments/<mã>` → màn chuyển khoản, `/bookings/<mã>` → lượt đặt, `/bookings` → tab Sân đã đặt (cả `/en/...`); chưa đăng nhập thì đăng nhập trước; link khác của máy chủ mở màn hình chính. Tên miền lấy từ `API_URL` lúc build. | AP-04 | `lib/deep_links.dart`, `lib/screens/home_shell.dart` |

## 2. Tài khoản

| Mã     | Quy tắc                                                                                                                                                                                         | Máy chủ    | Nguồn                                |
|--------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------|--------------------------------------|
| APP-10 | Token đăng nhập lưu trong **bộ nhớ an toàn** của điện thoại (`flutter_secure_storage`); đăng xuất hoặc xoá tài khoản thì xoá token. Máy chủ trả 401 → app coi như đã đăng xuất.                | AP-02      | `lib/app_state.dart`                 |
| APP-11 | Đăng ký phải **đồng ý chính sách quyền riêng tư** (có link đọc).                                                                                                                                | TK-01      | `lib/screens/auth_screens.dart`      |
| APP-12 | **Ảnh đại diện** thu nhỏ trên máy (tối đa 512 px, chất lượng 85) trước khi gửi; máy chủ nhận ≤ 2 MB. Năm sinh, giới tính, trình độ **không bắt buộc**; năm sinh từ 1900 tới năm nay.            | TK-10      | `lib/screens/profile_screen.dart`    |
| APP-13 | **Xoá tài khoản**: hỏi mật khẩu; máy chủ không cho xoá (còn lượt phải chơi/chờ chuyển khoản) thì báo lý do. Xoá xong app đăng xuất và báo ngày xoá hẳn (nếu có).                                | TK-08      | `lib/screens/account_screen.dart`    |
| APP-15 | **Tải dữ liệu của tôi** (Tài khoản): hỏi mật khẩu hiện tại, máy chủ trả file JSON (sai mật khẩu, quá 5 lần/giờ thì báo lỗi của máy chủ trong hộp thoại); app mở **bảng chia sẻ** của Android với file `vnbadminton-data-<ngày>.json` để lưu hoặc gửi. | TK-07 | `lib/screens/account_screen.dart` |
| APP-14 | **Khoá bằng vân tay/khuôn mặt** (tuỳ chọn): bật phải xác thực thành công một lần; khi bật, app hỏi lúc mở và khi quay lại sau **5 phút** ở nền. Máy không có khoá màn hình thì không bật được. |            | `lib/app_lock.dart`, `lib/screens/settings_screen.dart` |

## 3. Đặt sân

| Mã     | Quy tắc                                                                                                                                                                                                   | Máy chủ        | Nguồn                                |
|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|--------------------------------------|
| APP-20 | Lịch xem được **khi chưa đăng nhập**; bấm "Tiếp tục" mới phải đăng nhập.                                                                                                                                   | DAT-01         | `lib/screens/schedule_screen.dart`   |
| APP-21 | Chọn ô: **mỗi sân một khoảng giờ liền**, chọn được **nhiều sân**. Bỏ chọn một ô thì bỏ luôn các ô sau nó; chọn ô không liền thì bắt đầu khoảng mới.                                                       | DAT-03         | `lib/screens/schedule_screen.dart`   |
| APP-22 | Thanh tổng hiện số sân, số giờ, tổng tiền; khoảng ngắn hơn **thời lượng tối thiểu** thì không cho tiếp tục (máy chủ vẫn kiểm tra lại mọi quy tắc).                                                        | DAT-03         | `lib/screens/schedule_screen.dart`   |
| APP-23 | Tải lại lịch (kéo xuống, nút làm mới, sau khi đặt) **giữ ô đang chọn**, trừ ô vừa bị người khác lấy.                                                                                                      | VH-08          | `lib/screens/schedule_screen.dart`   |
| APP-24 | Email **chưa xác minh** → không đặt được; app mời gửi lại email xác minh.                                                                                                                                  | DAT-01         | `lib/screens/schedule_screen.dart`   |
| APP-26 | **Đổi giờ**: nút chỉ hiện khi máy chủ cho (`can_reschedule`); mở lịch ở **chế độ đổi giờ** đúng ngày của lượt, chỉ chọn **một sân**, giờ cũ chọn lại được; hộp xác nhận hiện **giờ cũ / giờ mới / giá mới** do máy chủ kiểm tra (lượt đã trả: giữ số tiền đã trả). | DOI-01, DOI-05 | `lib/screens/schedule_screen.dart`, `lib/screens/booking_screen.dart` |
| APP-27 | Chạm ô **đã đặt / đang giữ** → đề nghị **báo khi có sân trống** từ giờ đó, chờ 1 / 1,5 / 2 giờ (không quá giờ đóng cửa); cần đăng nhập. Danh sách đang chờ ở **Tài khoản → Đang chờ sân trống**, bỏ được. | TI-04 | `lib/screens/schedule_screen.dart`, `lib/screens/waitlist_screen.dart` |
| APP-28 | **Bảng tin** của sân hiện trên lịch (màu theo kiểu: thông tin / ưu đãi / lưu ý); không tải được thì lịch vẫn chạy. | TI-02 | `lib/screens/schedule_screen.dart` |
| APP-25 | Bước xác nhận: **giữ chỗ 3 phút** có đếm ngược; rời màn này mà chưa đặt thì **trả chỗ ngay** cho người khác; hết giờ thì phải chọn lại.                                                                   | DAT-05         | `lib/screens/confirm_screen.dart`    |

## 4. Thanh toán

| Mã     | Quy tắc                                                                                                                                                                                       | Máy chủ        | Nguồn                               |
|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|-------------------------------------|
| APP-30 | Màn chuyển khoản: mã QR, thông tin tài khoản (bấm để chép), **số tiền còn thiếu** và **nội dung chuyển khoản** (phải đúng), đếm ngược **15 phút**.                                            | TT-02, TT-03   | `lib/screens/payment_screen.dart`   |
| APP-31 | Khi màn chuyển khoản đang mở, app **hỏi máy chủ 4 giây một lần**; tiền về thì chuyển sang "Đã nhận tiền". Dừng hỏi khi đã thanh toán, hết hạn hoặc bị huỷ.                                     | TT-04          | `lib/screens/payment_screen.dart`   |
| APP-33 | **Thuê thêm** ở bước xác nhận: mỗi món chọn 0–20; tổng cộng = tiền sân + đồ; gửi kèm khi đặt. | TI-01 | `lib/screens/confirm_screen.dart` |
| APP-34 | Bước xác nhận **hỏi máy chủ giá** (`POST /quote`) khi mở, khi đổi số lượng đồ, khi áp mã, khi chọn gói: hiện **ưu đãi** (hạng hoặc mã, mức có lợi hơn) và **tổng**; lý do mã không dùng được hiện ngay dưới ô mã. Chỉ câu trả lời mới nhất được hiện. | UD-01…03 | `lib/screens/confirm_screen.dart` |
| APP-35 | Có **gói giờ còn dùng được** → công tắc **Trả bằng gói giờ** (mỗi gói một công tắc, còn bao nhiêu giờ): bật thì ẩn đồ thuê thêm và ô mã (thuê tại quầy), nút thành **Đặt sân bằng gói giờ**; đặt xong không có màn chuyển khoản, về tab Sân đã đặt. | UD-05 | `lib/screens/confirm_screen.dart` |
| APP-36 | Màn chuyển khoản ghi **"Đã giảm …"** khi đơn có ưu đãi. Lượt trả bằng gói có nhãn **Gói giờ** trong danh sách. | UD-03 | `lib/screens/payment_screen.dart`, `lib/screens/bookings_screen.dart` |
| APP-32 | Chuyển thiếu: hiện số đã nhận và số còn thiếu, chuyển thêm cùng nội dung.                                                                                                                     | TT-04          | `lib/screens/payment_screen.dart`   |

## 5. Sân đã đặt

| Mã     | Quy tắc                                                                                                                                       | Máy chủ        | Nguồn                               |
|--------|-----------------------------------------------------------------------------------------------------------------------------------------------|----------------|-------------------------------------|
| APP-40 | Bốn tab: **Đặt sân**, **Sân đã đặt**, **Giao lưu**, **Tài khoản**. Danh sách sân đã đặt **tải lại mỗi lần mở tab**: chờ chuyển khoản, sắp tới, đã qua/đã huỷ.                                                               |                | `lib/screens/home_shell.dart`       |
| APP-42 | **Đánh giá** (1–5 sao + góp ý) khi máy chủ cho (`can_review`: đã nhận sân, đã chơi xong, trong 14 ngày), một lần; sau đó hiện đánh giá đã gửi. | TI-03 | `lib/screens/booking_screen.dart` |
| APP-43 | **Thêm vào lịch** (mở **ứng dụng lịch của điện thoại** với sự kiện điền sẵn sân, giờ, địa chỉ; máy không có ứng dụng lịch thì mở trang Google Calendar) và **Chia sẻ** (Zalo, Messenger… qua bảng chia sẻ của Android) cho lượt **đã xác nhận chưa chơi**. Chia sẻ hỏi **số người chơi** (1–20) và ghi **mỗi người góp** = tổng (sân + đồ) ÷ số người, **làm tròn lên nghìn đồng**. App không thu hộ. | | `lib/screens/booking_screen.dart`, `lib/calendar.dart` |
| APP-45 | **Hạng thành viên** (thẻ màu theo hạng ở tab Tài khoản, tải lại mỗi lần mở tab): tên hạng, mức giảm, số giờ chơi 12 tháng, thanh tiến tới **hạng kế tiếp**; ẩn khi sân tắt chương trình. | UD-01 | `lib/screens/account_screen.dart` |
| APP-46 | **Gói giờ** (Tài khoản): gói của tôi (còn bao nhiêu giờ, hạn, khung giờ dùng được; gói chưa chuyển khoản có nút mở lại màn chuyển khoản) và **gói đang bán** (nút **Mua** → màn chuyển khoản). | UD-04 | `lib/screens/packages_screen.dart` |
| APP-47 | Tab **Giao lưu** (tab thứ 3): các buổi sắp tới (ngày, giờ, sân, trình độ, giá mỗi người, thanh số chỗ đã có người, "Hết chỗ"); xem được khi chưa đăng nhập. **Đăng ký**: chọn số người (1–10, không quá số chỗ còn), thấy tổng tiền, mở màn chuyển khoản. Chỗ của mình hiện trong thẻ buổi (chờ chuyển khoản: nút mở lại; **Huỷ chỗ** khi máy chủ cho, cảnh báo không hoàn tiền). | GL-01…03 | `lib/screens/play_screen.dart` |
| APP-48 | **Nhóm chơi** (Tài khoản): tạo nhóm, vào nhóm bằng **mã 6 ký tự**, gửi mã mời qua bảng chia sẻ; thành viên (chủ nhóm có sao), các **sân đã chia sẻ** với tổng tiền và **mỗi người góp**. Gỡ chia sẻ (của mình, hoặc mọi chia sẻ nếu là chủ nhóm). **Rời nhóm**; chủ nhóm còn một mình thì nút thành **Xoá nhóm**. | NH-01…03 | `lib/screens/groups_screen.dart` |
| APP-49 | **Chia sẻ vào nhóm** (lượt đã xác nhận chưa chơi): chọn nhóm, số người chơi (mặc định số thành viên, 1–50), thấy mỗi người góp (làm tròn lên nghìn). | NH-02 | `lib/screens/booking_screen.dart` |
| APP-44 | **Lịch cố định** (Tài khoản): lịch sân đã tạo, mỗi tháng có số buổi và nút **Đóng <số tiền>** (mở màn chuyển khoản) hoặc "Đã đóng"; các **yêu cầu đã gửi** với trạng thái (chờ / đã tạo / bị từ chối kèm lý do / đã rút), rút lại khi còn chờ. **Gửi yêu cầu**: chọn sân, ngày trong tuần, giờ (05:00–24:00, tròn 30 phút), từ ngày (từ ngày mai) – đến ngày (tối đa 1 năm), ghi chú. | CD-09, CD-10 | `lib/screens/series_screen.dart` |
| APP-41 | Nút **Huỷ** chỉ hiện khi máy chủ cho (`can_cancel`, trước hạn huỷ); lượt **đã thanh toán** thì cảnh báo **không hoàn tiền** trước khi huỷ.   | HUY-01         | `lib/screens/booking_screen.dart`   |

## 6. Khác

| Mã     | Quy tắc                                                                                                       | Máy chủ | Nguồn                                  |
|--------|---------------------------------------------------------------------------------------------------------------|---------|----------------------------------------|
| APP-50 | **Có gì mới**: mỗi phiên bản gửi cho khách thêm một mục trong `releases` (mới nhất trước).                   |         | `lib/screens/whats_new_screen.dart`    |
| APP-51 | Liên hệ: gọi, Zalo, Messenger và **chỉ đường** (Google Maps theo địa chỉ sân) chỉ hiện kênh chủ sân đã nhập. | CS-05   | `lib/screens/account_screen.dart`      |
