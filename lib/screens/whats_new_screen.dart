import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

/// One release of the app, newest first in [releases]. Add an entry with every version sent to customers.
class Release {
  const Release(this.version, this.date, this.vi, this.en);

  final String version;
  final String date;
  final List<String> vi;
  final List<String> en;
}

const releases = [
  Release(
    '0.3.0',
    '20/10/2026',
    [
      'Đổi giờ lượt đặt ngay trong app.',
      'Thuê thêm vợt, ống cầu, nước uống khi đặt sân.',
      'Báo cho bạn khi khung giờ kín có sân trống.',
      'Bảng tin của sân, đánh giá buổi chơi.',
      'Thêm lịch chơi vào Google Calendar, chia sẻ qua Zalo kèm số tiền mỗi người.',
      'Lịch cố định: gửi yêu cầu, xem lịch và đóng tiền tháng.',
    ],
    [
      'Change the time of a booking in the app.',
      'Add racket rental, shuttlecocks or drinks when booking.',
      'Get told when a taken time has a free court.',
      'Venue news and session reviews.',
      'Add your game to Google Calendar, share it on Zalo with each player\'s share.',
      'Regular bookings: send a request, see your schedule and pay each month.',
    ],
  ),
  Release('0.2.0', '20/10/2026', [
    'Giao diện mới: màu sắc tươi hơn, thẻ bo tròn, trạng thái sân và thanh toán có màu riêng.',
    'Chọn ngày dễ hơn, lịch sân rõ hơn, tổng tiền hiện ngay khi chọn giờ.',
    'Trang tài khoản có lối tắt gọi điện, Zalo, Messenger và chỉ đường.',
  ], [
    'New look: brighter colours, rounded cards, a colour for each court and payment status.',
    'Easier day picker, clearer court grid, the total shows as soon as you pick a time.',
    'Shortcuts on the account page to call, Zalo, Messenger and directions.',
  ]),
  Release(
    '0.1.0',
    '19/10/2026',
    [
      'Đặt sân: xem lịch trống theo ngày, chọn nhiều sân, giữ chỗ 3 phút khi xác nhận.',
      'Chuyển khoản bằng mã QR, app tự xác nhận khi nhận được tiền.',
      'Xem và huỷ sân đã đặt.',
      'Hồ sơ: ảnh đại diện, năm sinh, giới tính, trình độ.',
      'Mở app bằng vân tay / khuôn mặt, chỉ đường đến sân, Tiếng Việt và English.',
    ],
    [
      'Booking: free slots by day, several courts at once, a 3-minute hold while confirming.',
      'Bank transfer by QR code, confirmed automatically when the money arrives.',
      'See and cancel your bookings.',
      'Profile: photo, year of birth, gender, level.',
      'Open the app with fingerprint / face, directions to the venue, Vietnamese and English.',
    ],
  ),
];

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final english = AppScope.of(context).locale == 'en';
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(title: s.whatsNew),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final release in releases)
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                release.version,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              release.date,
                              style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final line in english ? release.en : release.vi)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.amber),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(line, style: const TextStyle(height: 1.4))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
