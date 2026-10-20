import 'package:flutter/widgets.dart';

import 'api.dart';
import 'app_state.dart';

/// Every text of the app, in Vietnamese and English: S.of(context).book.
class S {
  const S(this.locale);

  static S of(BuildContext context) => S(AppScope.of(context).locale);

  final String locale;

  String _(String vi, String en) => locale == 'en' ? en : vi;

  // Navigation
  String get tabBook => _('Đặt sân', 'Book');
  String get tabBookings => _('Sân đã đặt', 'My bookings');
  String get tabAccount => _('Tài khoản', 'Account');

  // Common
  String get retry => _('Thử lại', 'Retry');
  String get cancel => _('Huỷ', 'Cancel');
  String get close => _('Đóng', 'Close');
  String get save => _('Lưu', 'Save');
  String get copied => _('Đã chép', 'Copied');
  String get networkError => _('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      'Could not reach the server. Check the connection and try again.');
  String get unknownError => _('Đã có lỗi, vui lòng thử lại.', 'Something went wrong, please try again.');
  String get noServer => _('Chưa cấu hình địa chỉ máy chủ (API_URL).', 'The server address (API_URL) is not set.');

  String error(Object error) {
    if (error is ApiError) {
      if (error.isNetwork) return networkError;
      if (error.messages.isNotEmpty) return error.messages.join('\n');
    }
    return unknownError;
  }

  // Sign in / up
  String get signIn => _('Đăng nhập', 'Sign in');
  String get signUp => _('Đăng ký', 'Sign up');
  String get signOut => _('Đăng xuất', 'Sign out');
  String get login => _('Email hoặc số điện thoại', 'Email or phone number');
  String get password => _('Mật khẩu', 'Password');
  String get fullName => _('Họ và tên', 'Full name');
  String get phone => _('Số điện thoại', 'Phone number');
  String get email => _('Email', 'Email');
  String get passwordHint => _('Ít nhất 8 ký tự', 'At least 8 characters');
  String get required => _('Bắt buộc', 'Required');
  String get noAccount => _('Chưa có tài khoản? Đăng ký', 'No account yet? Sign up');
  String get privacyConsent => _('Tôi đồng ý với chính sách bảo mật', 'I agree to the privacy policy');
  String get readPrivacy => _('Xem chính sách', 'Read the policy');
  String get privacyRequired => _('Cần đồng ý với chính sách bảo mật để đăng ký.',
      'You need to agree to the privacy policy to sign up.');
  String get verificationSent => _('Đã gửi email xác minh. Mở email và bấm vào liên kết để có thể đặt sân.',
      'A verification email was sent. Open it and follow the link to be able to book.');
  String get signInToContinue => _('Đăng nhập để tiếp tục', 'Sign in to continue');
  String get signInToSeeBookings =>
      _('Đăng nhập để xem các sân bạn đã đặt.', 'Sign in to see your bookings.');

  // Schedule
  String get chooseSlots => _('Chạm vào các ô trống để chọn giờ.', 'Tap free cells to pick your time.');
  String get noSlots => _('Không còn giờ nào để đặt trong ngày này.', 'No time left to book on this day.');
  String get legendFree => _('Trống', 'Free');
  String get legendPicked => _('Đang chọn', 'Picked');
  String get legendTaken => _('Đã đặt', 'Taken');
  String get legendHeld => _('Đang giữ', 'Held');
  String get legendMine => _('Của bạn', 'Yours');
  String get continueLabel => _('Tiếp tục', 'Continue');
  String get clear => _('Bỏ chọn', 'Clear');
  String pickedSummary(int courts, String duration) =>
      _('$courts sân · $duration', '$courts court${courts == 1 ? '' : 's'} · $duration');
  String hours(int minutes) {
    // Slots are 30 minutes: 90 -> "1,5 giờ" / "1.5 h".
    final h = minutes ~/ 60;
    if (minutes % 60 == 0) return _('$h giờ', '$h h');
    return _('$h,5 giờ', '$h.5 h');
  }

  String minDuration(String duration) =>
      _('Mỗi sân cần đặt ít nhất $duration.', 'Each court needs at least $duration.');
  String get emailUnverified => _('Bạn cần xác minh email trước khi đặt sân.',
      'You need to verify your email before booking.');
  String get resendVerification => _('Gửi lại email xác minh', 'Resend the verification email');
  String get resent => _('Đã gửi lại email xác minh.', 'The verification email was sent again.');

  // Confirm
  String get confirmTitle => _('Xác nhận đặt sân', 'Confirm booking');
  String heldFor(String left) => _('Đang giữ chỗ cho bạn: còn $left', 'Held for you: $left left');
  String get holdExpired => _('Hết thời gian giữ chỗ. Vui lòng chọn lại giờ.',
      'The hold has expired. Please pick your time again.');
  String get pickAgain => _('Chọn lại', 'Pick again');
  String get note => _('Ghi chú (không bắt buộc)', 'Note (optional)');
  String get total => _('Tổng cộng', 'Total');
  String get bookAndPay => _('Đặt sân và chuyển khoản', 'Book and pay by transfer');
  String get payInfo => _('Thanh toán 100% bằng chuyển khoản. Sân được xác nhận ngay khi nhận được tiền.',
      'Paid 100% by bank transfer. The booking is confirmed as soon as the money arrives.');

  // Payment
  String get paymentTitle => _('Chuyển khoản', 'Bank transfer');
  String payWithin(String left) => _('Chuyển khoản trong $left', 'Transfer within $left');
  String get scanQr => _('Mở app ngân hàng, quét mã QR (đã điền sẵn số tiền và nội dung).',
      'Open your banking app and scan the QR code (amount and content are filled in).');
  String get orTransferManually => _('Hoặc chuyển khoản thủ công:', 'Or transfer manually:');
  String get bank => _('Ngân hàng', 'Bank');
  String get accountNumber => _('Số tài khoản', 'Account number');
  String get accountName => _('Chủ tài khoản', 'Account name');
  String get amount => _('Số tiền', 'Amount');
  String get transferContent => _('Nội dung', 'Content');
  String get exactContent => _('Ghi đúng nội dung chuyển khoản để hệ thống tự xác nhận.',
      'Use exactly this content so the payment is confirmed automatically.');
  String partlyReceived(String received, String remaining) => _(
      'Đã nhận $received. Vui lòng chuyển thêm $remaining với cùng nội dung.',
      'Received $received. Please transfer $remaining more with the same content.');
  String get waitingForMoney => _('Đang chờ tiền về…', 'Waiting for the money…');
  String get paid => _('Đã nhận được tiền', 'Payment received');
  String get paidText => _('Sân của bạn đã được xác nhận. Hẹn gặp bạn ở sân!',
      'Your booking is confirmed. See you at the court!');
  String get paymentExpired => _('Đã hết thời gian chuyển khoản, chỗ đã được trả lại. Nếu bạn đã chuyển tiền, sân sẽ liên hệ để xử lý.',
      'The time to transfer is over and the slots were released. If you already transferred, the venue will contact you.');
  String get paymentCancelled => _('Đơn này đã bị huỷ.', 'This order was cancelled.');
  String get seeMyBookings => _('Xem sân đã đặt', 'See my bookings');
  String get qrUnavailable => _('Không tải được mã QR', 'Could not load the QR code');

  // Bookings
  String get awaitingPayment => _('Chờ chuyển khoản', 'Awaiting payment');
  String get upcoming => _('Sắp tới', 'Upcoming');
  String get past => _('Đã qua / đã huỷ', 'Past and cancelled');
  String get noBookings => _('Bạn chưa có sân nào. Đặt sân ở tab "Đặt sân".',
      'You have no bookings yet. Book in the "Book" tab.');
  String get payNow => _('Chuyển khoản', 'Pay now');
  String get bookingCode => _('Mã đặt sân', 'Booking code');
  String get court => _('Sân', 'Court');
  String get date => _('Ngày', 'Date');
  String get time => _('Giờ', 'Time');
  String get status => _('Trạng thái', 'Status');
  String get payment => _('Thanh toán', 'Payment');
  String get regular => _('Lịch cố định', 'Regular booking');
  String get cancelBooking => _('Huỷ đặt sân', 'Cancel booking');
  String get cancelConfirm => _('Bạn chắc chắn muốn huỷ sân này?', 'Are you sure you want to cancel this booking?');
  String get cancelNoRefund => _('Sân đã thanh toán: huỷ sẽ không được hoàn tiền.',
      'This booking is paid: cancelling gives no refund.');
  String cancelCutoff(int hours) => _('Chỉ huỷ được trước giờ chơi ít nhất $hours giờ.',
      'Bookings can be cancelled until $hours h before the start.');
  String get cancelled => _('Đã huỷ đặt sân.', 'The booking was cancelled.');
  String get keep => _('Không huỷ', 'Keep it');
  String refunded(String amount) => _('Đã hoàn $amount', 'Refunded $amount');

  String bookingStatus(String status) => switch (status) {
        'pending' => _('Chờ xác nhận', 'Pending'),
        'confirmed' => _('Đã xác nhận', 'Confirmed'),
        'checked_in' => _('Đã nhận sân', 'Checked in'),
        'completed' => _('Hoàn thành', 'Completed'),
        'cancelled' => _('Đã huỷ', 'Cancelled'),
        'no_show' => _('Không đến', 'No show'),
        _ => status,
      };

  String paymentStatus(String status) => switch (status) {
        'unpaid' => _('Chưa thanh toán', 'Unpaid'),
        'paid' => _('Đã thanh toán', 'Paid'),
        'refunded' => _('Đã hoàn tiền', 'Refunded'),
        _ => status,
      };

  // Account
  String get activity => _('Hoạt động', 'Activity');
  String get system => _('Hệ thống', 'System');
  String get profile => _('Hồ sơ', 'Profile');
  String get profileHint => _('Ảnh, năm sinh, giới tính và trình độ không bắt buộc; chỉ hiển thị trong tài khoản của bạn.',
      'Photo, year of birth, gender and level are optional and only shown in your account.');
  String get birthYear => _('Năm sinh', 'Year of birth');
  String get gender => _('Giới tính', 'Gender');
  String get skillLevel => _('Trình độ cầu lông', 'Badminton level');
  String get notSet => _('Chưa chọn', 'Not set');
  String get invalidYear => _('Năm sinh không hợp lệ', 'Invalid year');
  String genderLabel(String value) => switch (value) {
        'male' => _('Nam', 'Male'),
        'female' => _('Nữ', 'Female'),
        _ => _('Khác', 'Other'),
      };
  String skillLabel(String value) => switch (value) {
        'beginner' => _('Mới chơi', 'Beginner'),
        'intermediate' => _('Trung bình', 'Intermediate'),
        'advanced' => _('Khá', 'Advanced'),
        _ => _('Giỏi', 'Expert'),
      };
  String get takePhoto => _('Chụp ảnh', 'Take a photo');
  String get choosePhoto => _('Chọn ảnh có sẵn', 'Choose a photo');
  String get removePhoto => _('Xoá ảnh', 'Remove photo');
  String get photoSaved => _('Đã cập nhật ảnh đại diện.', 'Profile photo updated.');
  String get settings => _('Cài đặt', 'Settings');
  String get biometric => _('Mở app bằng vân tay / khuôn mặt', 'Open the app with fingerprint / face');
  String get biometricHint => _('Hỏi vân tay hoặc khuôn mặt khi mở app.', 'Ask for your fingerprint or face when opening the app.');
  String get biometricUnavailable => _('Điện thoại chưa cài vân tay hoặc khoá màn hình.',
      'This phone has no fingerprint or screen lock set up.');
  String get unlockReason => _('Mở khoá VN Badminton', 'Unlock VN Badminton');
  String get unlock => _('Mở khoá', 'Unlock');
  String get locked => _('App đang khoá', 'The app is locked');
  String get versionInfo => _('Thông tin phiên bản', 'Version');
  String version(String version, String build) => _('Phiên bản $version (bản $build)', 'Version $version (build $build)');
  String get terms => _('Điều khoản và chính sách', 'Terms and privacy policy');
  String get whatsNew => _('Ứng dụng có gì mới', "What's new");
  String get directions => _('Chỉ đường đến sân', 'Directions to the venue');
  String get myBookings => _('Lịch đã đặt', 'My bookings');
  String get language => _('Ngôn ngữ', 'Language');
  String get verified => _('Đã xác minh', 'Verified');
  String get notVerified => _('Chưa xác minh', 'Not verified');
  String get editProfile => _('Sửa thông tin', 'Edit details');
  String get saved => _('Đã lưu.', 'Saved.');
  String get contactVenue => _('Liên hệ sân', 'Contact the venue');
  String get call => _('Gọi điện', 'Call');
  String get deleteAccount => _('Xoá tài khoản', 'Delete account');
  String get deleteExplain => _(
      'Tài khoản và dữ liệu cá nhân của bạn sẽ bị xoá. Nếu còn sân sắp chơi, tài khoản bị khoá ngay và xoá hẳn sau khi chơi xong. Nhập mật khẩu để xác nhận.',
      'Your account and personal data will be deleted. If you still have bookings to play, the account is locked now and deleted after them. Enter your password to confirm.');
  String get deleteNotAllowed => _('Không thể xoá tài khoản lúc này. Vui lòng liên hệ sân.',
      'The account cannot be deleted now. Please contact the venue.');
  String get accountDeleted => _('Tài khoản đã được xoá.', 'The account was deleted.');
  String deletedAfter(String date) =>
      _('Tài khoản đã bị khoá và sẽ được xoá sau $date.', 'The account is locked and will be deleted after $date.');
  String bookingLocked(String date) =>
      _('Tài khoản tạm khoá đặt sân đến $date.', 'Booking is locked for this account until $date.');
}
