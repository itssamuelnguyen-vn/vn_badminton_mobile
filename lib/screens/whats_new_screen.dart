import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';

/// One release of the app, newest first in [releases]. Add an entry with every version sent to customers.
class Release {
  const Release(this.version, this.date, this.vi, this.en);

  final String version;
  final String date;
  final List<String> vi;
  final List<String> en;
}

const releases = [
  Release('0.1.0', '19/10/2026', [
    'Đặt sân: xem lịch trống theo ngày, chọn nhiều sân, giữ chỗ 3 phút khi xác nhận.',
    'Chuyển khoản bằng mã QR, app tự xác nhận khi nhận được tiền.',
    'Xem và huỷ sân đã đặt.',
    'Hồ sơ: ảnh đại diện, năm sinh, giới tính, trình độ.',
    'Mở app bằng vân tay / khuôn mặt, chỉ đường đến sân, Tiếng Việt và English.',
  ], [
    'Booking: free slots by day, several courts at once, a 3-minute hold while confirming.',
    'Bank transfer by QR code, confirmed automatically when the money arrives.',
    'See and cancel your bookings.',
    'Profile: photo, year of birth, gender, level.',
    'Open the app with fingerprint / face, directions to the venue, Vietnamese and English.',
  ]),
];

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final english = AppScope.of(context).locale == 'en';
    return Scaffold(
      appBar: AppBar(title: Text(s.whatsNew)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final release in releases)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${release.version} · ${release.date}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final line in english ? release.en : release.vi)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $line')),
              ]),
            ),
          ),
      ]),
    );
  }
}
