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

  // Headers
  String hello(String name) => _('Xin chào, $name 👋', 'Hi, $name 👋');
  String get readyToPlay => _('Hôm nay ra sân nhé?', 'Ready to play today?');
  String get bookingsSubtitle => _('Lịch chơi và thanh toán của bạn', 'Your games and payments');
  String get welcome => _('Chào mừng bạn!', 'Welcome!');
  String get welcomeText => _(
    'Đăng nhập để đặt sân, thanh toán và theo dõi lịch chơi.',
    'Sign in to book courts, pay and keep track of your games.',
  );

  // Common
  String get retry => _('Thử lại', 'Retry');
  String get cancel => _('Huỷ', 'Cancel');
  String get close => _('Đóng', 'Close');
  String get save => _('Lưu', 'Save');
  String get copied => _('Đã chép', 'Copied');
  String get networkError => _(
    'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
    'Could not reach the server. Check the connection and try again.',
  );
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
  String get privacyRequired =>
      _('Cần đồng ý với chính sách bảo mật để đăng ký.', 'You need to agree to the privacy policy to sign up.');
  String get verificationSent => _(
    'Đã gửi email xác minh. Mở email và bấm vào liên kết để có thể đặt sân.',
    'A verification email was sent. Open it and follow the link to be able to book.',
  );
  String get signInWithGoogle => _('Đăng nhập với Google', 'Sign in with Google');
  String get or => _('hoặc', 'or');
  String get googleFailed => _(
    'Chưa đăng nhập được bằng Google. Thử lại, hoặc dùng email và mật khẩu.',
    'Could not sign in with Google. Try again, or use your email and password.',
  );
  String get googleSignupTitle => _('Hoàn tất đăng ký', 'Finish signing up');
  String googleSignupText(String email) => _(
    'Bạn đăng nhập bằng Google ($email). Thêm số điện thoại để sân liên hệ khi cần.',
    'You signed in with Google ($email). Add your phone number so the venue can reach you.',
  );
  String get signInToContinue => _('Đăng nhập để tiếp tục', 'Sign in to continue');
  String get signInToSeeBookings => _('Đăng nhập để xem các sân bạn đã đặt.', 'Sign in to see your bookings.');

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
  String get emailUnverified =>
      _('Bạn cần xác minh email trước khi đặt sân.', 'You need to verify your email before booking.');
  String get resendVerification => _('Gửi lại email xác minh', 'Resend the verification email');
  String get resent => _('Đã gửi lại email xác minh.', 'The verification email was sent again.');

  // Confirm
  String get confirmTitle => _('Xác nhận đặt sân', 'Confirm booking');
  String heldFor(String left) => _('Đang giữ chỗ cho bạn: còn $left', 'Held for you: $left left');
  String get holdExpired =>
      _('Hết thời gian giữ chỗ. Vui lòng chọn lại giờ.', 'The hold has expired. Please pick your time again.');
  String get pickAgain => _('Chọn lại', 'Pick again');
  String get note => _('Ghi chú (không bắt buộc)', 'Note (optional)');
  String get total => _('Tổng cộng', 'Total');
  String get bookAndPay => _('Đặt sân và chuyển khoản', 'Book and pay by transfer');
  String get payInfo => _(
    'Thanh toán 100% bằng chuyển khoản. Sân được xác nhận ngay khi nhận được tiền.',
    'Paid 100% by bank transfer. The booking is confirmed as soon as the money arrives.',
  );

  // Payment
  String get paymentTitle => _('Chuyển khoản', 'Bank transfer');
  String payWithin(String left) => _('Chuyển khoản trong $left', 'Transfer within $left');
  String get scanQr => _(
    'Mở app ngân hàng, quét mã QR (đã điền sẵn số tiền và nội dung).',
    'Open your banking app and scan the QR code (amount and content are filled in).',
  );
  String get orTransferManually => _('Hoặc chuyển khoản thủ công:', 'Or transfer manually:');
  String get bank => _('Ngân hàng', 'Bank');
  String get accountNumber => _('Số tài khoản', 'Account number');
  String get accountName => _('Chủ tài khoản', 'Account name');
  String get amount => _('Số tiền', 'Amount');
  String get transferContent => _('Nội dung', 'Content');
  String get exactContent => _(
    'Ghi đúng nội dung chuyển khoản để hệ thống tự xác nhận.',
    'Use exactly this content so the payment is confirmed automatically.',
  );
  String partlyReceived(String received, String remaining) => _(
    'Đã nhận $received. Vui lòng chuyển thêm $remaining với cùng nội dung.',
    'Received $received. Please transfer $remaining more with the same content.',
  );
  String get waitingForMoney => _('Đang chờ tiền về…', 'Waiting for the money…');
  String get paid => _('Đã nhận được tiền', 'Payment received');
  String get paidText =>
      _('Sân của bạn đã được xác nhận. Hẹn gặp bạn ở sân!', 'Your booking is confirmed. See you at the court!');
  String get paymentExpired => _(
    'Đã hết thời gian chuyển khoản, chỗ đã được trả lại. Nếu bạn đã chuyển tiền, sân sẽ liên hệ để xử lý.',
    'The time to transfer is over and the slots were released. If you already transferred, the venue will contact you.',
  );
  String get paymentCancelled => _('Đơn này đã bị huỷ.', 'This order was cancelled.');
  String get cancelPlaces => _('Huỷ giữ chỗ', 'Cancel places');
  String get cancelEntry => _('Huỷ đăng ký giải', 'Cancel my entry');
  String get cancelPaymentHint => _(
    'Không đặt nữa? Huỷ để trả lại chỗ ngay, khỏi chờ hết giờ.',
    'Changed your mind? Cancel to release the slot now.',
  );
  String get cancelPaymentConfirm => _(
    'Huỷ đơn này và trả lại chỗ đã giữ? Nếu bạn đã chuyển khoản, đừng huỷ – chờ vài phút để hệ thống xác nhận.',
    'Cancel this order and release what is held? If you already transferred, do not cancel – wait a few minutes for the confirmation.',
  );
  String get paymentCancelledNow => _('Đã huỷ, chỗ đã giữ được mở lại.', 'Cancelled; what was held is open again.');
  String get seeMyBookings => _('Xem sân đã đặt', 'See my bookings');
  String get qrUnavailable => _('Không tải được mã QR', 'Could not load the QR code');

  // Bookings
  String get awaitingPayment => _('Chờ chuyển khoản', 'Awaiting payment');
  String get upcoming => _('Sắp tới', 'Upcoming');
  String get past => _('Đã qua / đã huỷ', 'Past and cancelled');
  String get noBookings =>
      _('Bạn chưa có sân nào. Đặt sân ở tab "Đặt sân".', 'You have no bookings yet. Book in the "Book" tab.');
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
  String get cancelNoRefund =>
      _('Sân đã thanh toán: huỷ sẽ không được hoàn tiền.', 'This booking is paid: cancelling gives no refund.');
  String cancelCutoff(int hours) => _(
    'Chỉ huỷ được trước giờ chơi ít nhất $hours giờ.',
    'Bookings can be cancelled until $hours h before the start.',
  );
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
  String get profileHint => _(
    'Ảnh, năm sinh, giới tính và trình độ không bắt buộc; chỉ hiển thị trong tài khoản của bạn.',
    'Photo, year of birth, gender and level are optional and only shown in your account.',
  );
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
  String get biometricHint =>
      _('Hỏi vân tay hoặc khuôn mặt khi mở app.', 'Ask for your fingerprint or face when opening the app.');
  String get biometricUnavailable =>
      _('Điện thoại chưa cài vân tay hoặc khoá màn hình.', 'This phone has no fingerprint or screen lock set up.');
  String get unlockReason => _('Mở khoá VN Badminton', 'Unlock VN Badminton');

  // Notifications
  String get notifications => _('Thông báo', 'Notifications');
  String get notificationsHint => _(
    'Xác nhận đặt sân, nhắc giờ chơi, thay đổi từ sân. Không quảng cáo.',
    'Booking confirmations, reminders, changes by the venue. No ads.',
  );
  String get notificationsDenied => _(
    'Thông báo đang bị tắt cho app. Bật lại trong Cài đặt của điện thoại → Ứng dụng → VN Badminton.',
    "Notifications are turned off for the app. Turn them on in the phone's Settings → Apps → VN Badminton.",
  );
  String get notificationsUnavailable =>
      _('Bản app này chưa có thông báo.', 'Notifications are not available in this version of the app.');

  /// The Android channel of the notifications, as shown in the phone's settings.
  String get notificationChannel => _('Lượt đặt và nhắc lịch', 'Bookings and reminders');
  String get notificationsAskTitle => _('Nhận thông báo?', 'Get notifications?');
  String get notificationsAskText => _(
    'Sân sẽ báo khi xác nhận đặt sân, nhắc bạn trước giờ chơi và báo khi lịch có thay đổi. Không có quảng cáo; tắt được bất cứ lúc nào trong Cài đặt.',
    'The venue lets you know when a booking is confirmed, reminds you before you play and tells you about changes. '
        'No ads; turn them off any time in Settings.',
  );
  String get notificationsAllow => _('Bật thông báo', 'Turn on');
  String get notLater => _('Để sau', 'Not now');
  String get unlock => _('Mở khoá', 'Unlock');
  String get locked => _('App đang khoá', 'The app is locked');
  String get versionInfo => _('Thông tin phiên bản', 'Version');
  String version(String version, String build) =>
      _('Phiên bản $version (bản $build)', 'Version $version (build $build)');
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
  // Data export (TK-07), same wording as the web's account page.
  String get exportData => _('Tải dữ liệu của tôi', 'Download my data');
  String get exportExplain => _(
    'Một file JSON gồm thông tin tài khoản, mọi lượt đặt kèm lịch sử, các khoản thanh toán và chuyển khoản của bạn. Nhập mật khẩu để tải.',
    'A JSON file with your account details, every booking with its history, your payments and transfers. Enter your password to download it.',
  );
  String get currentPassword => _('Mật khẩu hiện tại', 'Current password');
  String get exportSubmit => _('Tải file dữ liệu (JSON)', 'Download my data (JSON)');
  String get exportReady => _('Dữ liệu của bạn: lưu file hoặc gửi đi.', 'Your data: save the file or send it.');
  String get deleteAccount => _('Xoá tài khoản', 'Delete account');
  String get deleteExplain => _(
    'Tài khoản và dữ liệu cá nhân của bạn sẽ bị xoá. Nếu còn sân sắp chơi, tài khoản bị khoá ngay và xoá hẳn sau khi chơi xong. Nhập mật khẩu để xác nhận.',
    'Your account and personal data will be deleted. If you still have bookings to play, the account is locked now and deleted after them. Enter your password to confirm.',
  );
  String get deleteNotAllowed => _(
    'Không thể xoá tài khoản lúc này. Vui lòng liên hệ sân.',
    'The account cannot be deleted now. Please contact the venue.',
  );
  String get accountDeleted => _('Tài khoản đã được xoá.', 'The account was deleted.');
  String deletedAfter(String date) =>
      _('Tài khoản đã bị khoá và sẽ được xoá sau $date.', 'The account is locked and will be deleted after $date.');
  String bookingLocked(String date) =>
      _('Tài khoản tạm khoá đặt sân đến $date.', 'Booking is locked for this account until $date.');

  // Reschedule (DOI-05)
  String get reschedule => _('Đổi giờ', 'Change time');
  String get rescheduleTitle => _('Chọn giờ mới', 'Pick a new time');
  String get rescheduleHint => _(
    'Chọn một khoảng giờ liền trên một sân. Giờ cũ vẫn chọn lại được.',
    'Pick one unbroken range on one court. Your current time can be picked again.',
  );
  String get rescheduleOneCourt =>
      _('Đổi giờ chỉ chọn được một sân.', 'Only one court can be picked when changing the time.');
  String get oldTime => _('Giờ cũ', 'Current time');
  String get newTime => _('Giờ mới', 'New time');
  String get newPrice => _('Giá mới', 'New price');
  String get rescheduled => _('Đã đổi giờ.', 'The time was changed.');
  String get keepPaidAmount => _(
    'Lượt đã thanh toán: giữ nguyên số tiền đã trả, không hoàn chênh lệch.',
    'Paid booking: the amount paid is kept, the difference is not refunded.',
  );
  String get confirm => _('Xác nhận', 'Confirm');

  // Extras (TI-01)
  String get extras => _('Thuê thêm', 'Extras');
  String get extrasHint =>
      _('Nhân viên chuẩn bị sẵn khi bạn đến nhận sân.', 'The staff have them ready when you check in.');
  String get courtPrice => _('Tiền sân', 'Court');

  // Announcements, waitlist (TI-02, TI-04)
  String get notifyWhenFree => _('Báo tôi khi có sân trống', 'Tell me when a court is free');
  String notifyRange(String range) =>
      _('Khung $range đang kín. Bạn muốn chờ bao lâu?', '$range is taken. How long do you want to play?');
  String get notifyHint => _(
    'Khi có sân trống trọn khung này, app gửi email cho bạn. Ai đặt trước được trước.',
    'When a court frees up for all of it, you get an email. First come, first served.',
  );
  String get notifySaved =>
      _('Đã đăng ký. Bạn sẽ nhận email khi có sân trống.', "Done. You'll get an email when a court is free.");
  String get waitlist => _('Đang chờ sân trống', 'Waiting for a free court');
  String get waitlistEmpty => _(
    'Bạn chưa chờ khung giờ nào. Chạm vào ô đã kín trên lịch để đăng ký.',
    'You are not waiting for any time. Tap a taken cell on the schedule to start.',
  );
  String get remove => _('Bỏ', 'Remove');

  // Review (TI-03)
  String get rateSession => _('Đánh giá buổi chơi', 'Rate this session');
  String get yourReview => _('Đánh giá của bạn', 'Your review');
  String get reviewComment => _('Góp ý cho sân (không bắt buộc)', 'Comment for the venue (optional)');
  String get send => _('Gửi', 'Send');
  String get thanksReview => _('Cảm ơn bạn đã đánh giá!', 'Thanks for your review!');

  // Calendar, share
  String get addToCalendar => _('Thêm vào lịch', 'Add to calendar');
  String get share => _('Chia sẻ', 'Share');
  String get players => _('Số người chơi', 'Players');
  String get splitTitle => _('Chia tiền cho nhóm', 'Split with your group');
  String perPerson(String amount) => _('$amount / người', '$amount per person');
  String shareText({
    required String court,
    required String date,
    required String time,
    required String venue,
    required String address,
    required String total,
    String? split,
  }) => _(
    '🏸 Đặt sân cầu lông\n$court · $time\n$date\n$venue – $address\nTổng: $total${split == null ? '' : '\nMỗi người góp: $split'}',
    '🏸 Badminton court booked\n$court · $time\n$date\n$venue – $address\nTotal: $total${split == null ? '' : '\nEach player: $split'}',
  );

  // Regular bookings (CD-09, CD-10)
  String get regularBookings => _('Lịch cố định', 'Regular bookings');
  String get regularIntro => _(
    'Chơi cùng giờ mỗi tuần? Gửi yêu cầu, sân sẽ xếp lịch và báo lại cho bạn.',
    'Playing at the same time every week? Send a request; the venue sets it up and lets you know.',
  );
  String get newRequest => _('Gửi yêu cầu', 'Send a request');
  String get myRequests => _('Yêu cầu đã gửi', 'My requests');
  String get mySeries => _('Lịch của tôi', 'My regular bookings');
  String get courts => _('Sân', 'Courts');
  String get anyCourtNote => _('Chọn một hoặc nhiều sân.', 'Pick one or more courts.');
  String get daysOfWeek => _('Các ngày trong tuần', 'Days of the week');
  String get startTime => _('Giờ bắt đầu', 'Start time');
  String get endTime => _('Giờ kết thúc', 'End time');
  String get fromDate => _('Từ ngày', 'From');
  String get toDate => _('Đến ngày', 'Until');
  String get requestSent =>
      _('Đã gửi yêu cầu. Sân sẽ trả lời qua email.', 'Request sent. The venue will answer by email.');
  String get withdraw => _('Rút lại', 'Withdraw');
  String requestStatus(String status) => switch (status) {
    'pending' => _('Chờ sân trả lời', 'Waiting for the venue'),
    'approved' => _('Đã tạo lịch', 'Set up'),
    'declined' => _('Bị từ chối', 'Declined'),
    'cancelled' => _('Đã rút lại', 'Withdrawn'),
    _ => status,
  };
  String reason(String reason) => _('Lý do: $reason', 'Reason: $reason');
  String monthLabel(String month) {
    final parts = month.split('-');
    return _('Tháng ${int.parse(parts[1])}/${parts[0]}', '${parts[1]}/${parts[0]}');
  }

  String sessionsCount(int count) => _('$count buổi', '$count session${count == 1 ? '' : 's'}');
  String get monthPaid => _('Đã đóng', 'Paid');
  String payMonth(String amount) => _('Đóng $amount', 'Pay $amount');
  String get nothingYet => _('Chưa có gì.', 'Nothing yet.');
  String weekday(int day) =>
      _(['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'][day], ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day]);

  // Offers (UD-01..06)
  String get memberTier => _('Hạng thành viên', 'Member tier');
  String tierDiscount(int percent) =>
      _('Giảm $percent% tiền sân khi đặt online', '$percent% off the court price online');
  String get noTierDiscount => _('Chơi thêm để lên hạng và được giảm giá', 'Play more to reach a tier with a discount');
  String hoursPlayed(String hours) => _('$hours giờ chơi trong 12 tháng', '$hours hours played in 12 months');
  String toNextTier(String hours, String tier) => _('Còn $hours giờ nữa lên hạng $tier', '$hours more hours to $tier');
  String get voucher => _('Mã giảm giá', 'Voucher code');
  String get apply => _('Áp dụng', 'Apply');
  String get discount => _('Ưu đãi', 'Discount');
  String get payWithPackage => _('Trả bằng gói giờ', 'Pay with prepaid hours');
  String packageLeft(String left) => _('Còn $left', '$left left');
  String get extrasAtCounter => _(
    'Khi trả bằng gói giờ, đồ thuê thêm vui lòng thuê tại quầy.',
    'With prepaid hours, please rent extras at the counter.',
  );
  String get bookWithPackage => _('Đặt sân bằng gói giờ', 'Book with prepaid hours');
  String get bookedWithPackage =>
      _('Đã đặt sân bằng gói giờ. Hẹn gặp bạn ở sân!', 'Booked with your prepaid hours. See you at the court!');
  String get packages => _('Gói giờ', 'Prepaid hours');
  String get packagesIntro => _(
    'Mua trước nhiều giờ với giá tốt, đặt sân không cần chuyển khoản mỗi lần.',
    'Buy hours ahead at a better price and book without a transfer each time.',
  );
  String get myPackages => _('Gói của tôi', 'My prepaid hours');
  String get forSale => _('Gói đang bán', 'On sale');
  String validFor(int days) => _('Dùng trong $days ngày', 'Use within $days days');
  String onlyBetween(String from, String to) => _('Chỉ dùng $from–$to', 'Only $from–$to');
  String expiresOn(String date) => _('Hạn $date', 'Until $date');
  String get buy => _('Mua', 'Buy');
  String get awaitingTransfer => _('Chờ chuyển khoản', 'Awaiting transfer');
  String get packageRules => _(
    'Giờ chưa dùng không hoàn tiền. Tự huỷ lượt đã đặt bằng gói thì không trả lại giờ.',
    'Unused hours are not refunded. Cancelling a booking paid with hours does not give them back.',
  );
  String savedAmount(String amount) => _('Đã giảm $amount', '$amount off');

  // Open play (GL-01..03)
  String get tabPlay => _('Giao lưu', 'Open play');
  String get playTitle => _('Giao lưu – vãng lai', 'Open play');
  String get playIntro => _(
    'Đi một mình hay ít người? Mua chỗ theo người và vào chơi cùng mọi người.',
    'On your own or a few? Buy a place per player and join the others.',
  );
  String get noPlaySessions =>
      _('Chưa có buổi giao lưu nào sắp tới. Quay lại sau nhé!', 'No open play coming up. Check back soon!');
  String seatsLeft(int left, int capacity) => _('Còn $left/$capacity chỗ', '$left/$capacity places left');
  String get full => _('Hết chỗ', 'Full');
  String perPlayer(String amount) => _('$amount/người', '$amount per player');
  String get joinSession => _('Đăng ký', 'Join');
  String get howManyPlayers => _('Bạn đi mấy người?', 'How many players?');
  String yourPlaces(int count) => _('Bạn có $count chỗ', 'You have $count place${count == 1 ? '' : 's'}');
  String get ticketPending => _('Chờ chuyển khoản', 'Awaiting transfer');
  String get ticketConfirmed => _('Đã thanh toán', 'Paid');
  String get givePlacesBack => _('Huỷ chỗ', 'Give places back');
  String get givePlacesBackConfirm => _(
    'Huỷ các chỗ này? Chỗ đã thanh toán không được hoàn tiền.',
    'Give these places back? Paid places are not refunded.',
  );
  String levelLabel(String? level) => level == null ? _('Mọi trình độ', 'All levels') : skillLabel(level);

  // Tournaments (GD-01..09)
  String get tabTournaments => _('Giải đấu', 'Tournaments');
  String get tournamentsIntro => _(
    'Giải đấu nội bộ của sân: đăng ký, đóng lệ phí và theo dõi sơ đồ thi đấu ngay trong app.',
    "The venue's in-house tournaments: enter, pay the fee and follow the draw in the app.",
  );
  String get noTournaments =>
      _('Hiện chưa có giải đấu nào. Quay lại sau nhé!', 'No tournament at the moment. Check back soon!');
  String formatLabel(String format) => switch (format) {
    'groups_knockout' => _('Vòng bảng + loại trực tiếp', 'Groups + knockout'),
    'round_robin' => _('Vòng tròn', 'Round robin'),
    _ => _('Loại trực tiếp', 'Knockout'),
  };
  String spotsLeft(int left, int max) => _('Còn $left/$max suất', '$left/$max places left');
  String get registrationClosed => _('Đã hết hạn đăng ký', 'Registration closed');
  String get inProgress => _('Đang thi đấu', 'In progress');
  String get finishedLabel => _('Đã kết thúc', 'Finished');
  String get cancelledLabel => _('Đã huỷ', 'Cancelled');
  String championIs(String name) => _('Vô địch: $name', 'Champion: $name');
  String get champion => _('Vô địch', 'Champion');
  String fee(String amount, bool pair) =>
      pair ? _('Lệ phí $amount/cặp', 'Fee $amount/pair') : _('Lệ phí $amount', 'Fee $amount');
  String get free => _('Miễn phí', 'Free');
  String registrationCloses(String time) => _('Hạn đăng ký: $time', 'Registration closes $time');
  String get enterTournament => _('Đăng ký thi đấu', 'Enter');
  String get partner => _('Đồng đội', 'Partner');
  String get partnerName => _('Họ tên đồng đội', "Partner's name");
  String get partnerPhone => _('Số điện thoại đồng đội', "Partner's phone number");
  String get partnerGender => _('Giới tính đồng đội', "Partner's gender");
  String get partnerHint => _(
    'Nếu đồng đội có tài khoản với số này, suất được gắn vào tài khoản của họ.',
    'If your partner has an account with this number, the entry is linked to it.',
  );
  String get namesPublic =>
      _('Tên người chơi hiện công khai trên trang giải.', "Players' names are shown publicly on the tournament page.");
  String get genderNeeded => _(
    'Nội dung này chia theo giới tính: chọn giới tính trong Tài khoản → Hồ sơ trước khi đăng ký.',
    'This event is by gender: set your gender in Account → Profile before entering.',
  );
  String entryPending(String name) =>
      _('Bạn đã đăng ký ($name), chờ chuyển khoản lệ phí.', 'You entered ($name); the fee transfer is pending.');
  String entryConfirmed(String name) => _('Bạn đã có suất: $name', 'You have a place: $name');
  String get entered => _('Bạn đã đăng ký', 'You entered');
  String get enteredFree => _('Đăng ký thành công, bạn đã có suất thi đấu!', "You're in, your place is confirmed!");
  String get withdrawEntry => _('Rút khỏi giải', 'Withdraw');
  String withdrawConfirm(bool paid) => paid
      ? _(
          'Rút khỏi giải này? Lệ phí đã đóng sẽ không được hoàn lại.',
          'Withdraw from this tournament? The fee paid is not refunded.',
        )
      : _('Rút khỏi giải này?', 'Withdraw from this tournament?');
  String entriesTitle(int count) => _('Danh sách thi đấu ($count)', 'Entries ($count)');
  String get noEntries => _('Chưa có ai đăng ký.', 'Nobody has entered yet.');
  String get groupStage => _('Vòng bảng', 'Groups');
  String groupLetter(String letter) => _('Bảng $letter', 'Group $letter');
  String get standingsTitle => _('Bảng xếp hạng', 'Standings');
  String get standingsHeader => _('Tr · T · Ván · HS', 'P · W · Games · +/-');
  String get bracket => _('Sơ đồ loại trực tiếp', 'Knockout bracket');
  String get byeLabel => _('Miễn đấu', 'Bye');
  String get walkoverLabel => _('Thắng do đối thủ bỏ cuộc', 'Won by walkover');
  String onCourt(String court) => _('Đang đấu ở $court', 'Playing on $court');

  // Groups (NH-01..03)
  String get groups => _('Nhóm chơi', 'Groups');
  String get groupsIntro => _(
    'Rủ bạn bè vào nhóm, chia sẻ sân đã đặt và xem mỗi người góp bao nhiêu.',
    'Bring your friends into a group, share your bookings and see what each one pays.',
  );
  String get newGroup => _('Tạo nhóm', 'New group');
  String get joinGroup => _('Vào nhóm bằng mã', 'Join with a code');
  String get groupName => _('Tên nhóm', 'Group name');
  String get groupCode => _('Mã nhóm', 'Group code');
  String inviteText(String name, String code) => _(
    'Vào nhóm "$name" trên app VN Badminton với mã: $code',
    'Join "$name" on the VN Badminton app with the code: $code',
  );
  String membersCount(int count) => _('$count thành viên', '$count member${count == 1 ? '' : 's'}');
  String get leaveGroup => _('Rời nhóm', 'Leave');
  String get deleteGroup => _('Xoá nhóm', 'Delete group');
  String get sharedBookings => _('Sân đã chia sẻ', 'Shared bookings');
  String sharedBy(String name) => _('$name chia sẻ', 'Shared by $name');
  String get shareToGroup => _('Chia sẻ vào nhóm', 'Share with a group');
  String get sharedToGroup => _('Đã chia sẻ vào nhóm.', 'Shared with the group.');
  String get noGroups => _('Bạn chưa ở nhóm nào.', 'You are not in any group yet.');
  String get owner => _('Chủ nhóm', 'Owner');
}
