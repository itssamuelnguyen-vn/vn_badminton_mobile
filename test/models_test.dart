import 'package:flutter_test/flutter_test.dart';
import 'package:vn_badminton_mobile/models.dart';

// The JSON shapes of the server (app/serializers/api_json.rb in the web app), as it writes them.

final _booking = {
  'code': 'K7MPX2QA',
  'court': {'id': 3, 'name': 'Sân 3'},
  'starts_at': '2026-10-20T18:00:00+07:00',
  'ends_at': '2026-10-20T19:30:00+07:00',
  'status': 'pending',
  'payment_status': 'unpaid',
  'discount_vnd': 12000,
  'paid_with_package': false,
  'amount_vnd': 180000,
  'items_amount_vnd': 40000,
  'total_vnd': 208000,
  'items': [
    {'name': 'Ống cầu', 'quantity': 1, 'unit_price_vnd': 30000},
    {'name': 'Nước suối', 'quantity': 2, 'unit_price_vnd': 5000},
  ],
  'note': null,
  'held_until': '2026-10-20T10:15:00+07:00',
  'cancellation_reason': null,
  'refund_vnd': null,
  'series': false,
  'can_cancel': true,
  'can_reschedule': true,
  'cancel_without_refund': false,
  'payment_token': 'aBc-123_xyz',
  'can_review': false,
  'review': null,
};

void main() {
  test('a booking keeps its times in UTC, its extras, total and flags', () {
    final booking = Booking.fromJson(_booking);

    expect(booking.code, 'K7MPX2QA');
    expect(booking.court.name, 'Sân 3');
    expect(booking.startsAt, DateTime.utc(2026, 10, 20, 11));
    expect(booking.endsAt.difference(booking.startsAt), const Duration(minutes: 90));
    expect(booking.heldUntil, DateTime.utc(2026, 10, 20, 3, 15));
    expect(booking.totalVnd, 208000);
    expect(booking.items.map((item) => item.quantity), [1, 2]);
    expect(booking.canCancel && booking.canReschedule, isTrue);
    expect(booking.paymentToken, 'aBc-123_xyz');
    expect(booking.review, isNull);
  });

  test('an older booking without total_vnd falls back to the court amount', () {
    final booking = Booking.fromJson({
      ..._booking,
      'total_vnd': null,
      'items': null,
      'review': {'rating': 5},
    });

    expect(booking.totalVnd, 180000);
    expect(booking.items, isEmpty);
    expect(booking.review?.rating, 5);
    expect(booking.review?.comment, isNull);
  });

  test('a payment with its bank, offer and bookings', () {
    final payment = Payment.fromJson({
      'token': 'aBc-123_xyz',
      'code': 'VNB K7MPX2QA',
      'status': 'awaiting',
      'open': true,
      'amount_vnd': 208000,
      'discount_vnd': 12000,
      'offer': 'tier',
      'purpose': 'bookings',
      'received_vnd': 100000,
      'remaining_vnd': 108000,
      'expires_at': '2026-10-20T10:15:00+07:00',
      'paid_at': null,
      'bank': {'code': 'VPB', 'account_number': '0123456789', 'account_name': 'VN BADMINTON'},
      'qr_image_url': 'https://img.vietqr.io/image/VPB-0123456789-compact2.png?amount=108000',
      'bookings': [_booking],
    });

    expect(payment.remainingVnd, 108000);
    expect(payment.bank.accountName, 'VN BADMINTON');
    expect(payment.offer, 'tier');
    expect(payment.expiresAt, DateTime.utc(2026, 10, 20, 3, 15));
    expect(payment.paidAt, isNull);
    expect(payment.bookings.single.code, 'K7MPX2QA');
  });

  test('a tournament with its entry, group table and matches', () {
    final tournament = Tournament.fromJson({
      'id': 4,
      'title': 'Giải tháng 11',
      'event': 'Đơn nữ',
      'discipline': 'singles',
      'gender': 'female',
      'play_format': 'groups_knockout',
      'courts': ['Sân 1', 'Sân 2'],
      'starts_at': '2026-11-01T08:00:00+07:00',
      'ends_at': '2026-11-01T12:00:00+07:00',
      'registration_closes_at': '2026-10-31T20:00:00+07:00',
      'max_entries': 8,
      'spots_left': 0,
      'fee_vnd': 100000,
      'status': 'in_progress',
      'registration_open': false,
      'my_entry': {'id': 3, 'name': 'Lê Chi', 'status': 'confirmed', 'amount_vnd': 100000, 'can_cancel': false},
      'groups': [
        {
          'number': 2,
          'rows': [
            {
              'entry': {'id': 3, 'name': 'Lê Chi'},
              'played': 2,
              'won': 1,
              'games_for': 3,
              'games_against': 2,
              'point_difference': -4,
            },
          ],
        },
      ],
      'matches': [
        {
          'id': 9,
          'stage': 'group',
          'group': 2,
          'round': 1,
          'round_name': 'Vòng 1',
          'position': 1,
          'a': {'id': 3, 'name': 'Lê Chi'},
          'b': null,
          'winner_id': null,
          'scores': [
            [21, 19],
          ],
          'court': 'Sân 2',
        },
      ],
    });

    expect(tournament.byGender, isTrue);
    expect(tournament.doubles, isFalse);
    expect(tournament.myEntry?.status, 'confirmed');
    expect(tournament.groups.single.letter, 'B');
    expect(tournament.groups.single.rows.single.pointDifference, -4);
    final match = tournament.matches.single;
    expect(
      [match.a?.name, match.b, match.finished, match.scores, match.court],
      [
        'Lê Chi',
        null,
        false,
        [
          [21, 19],
        ],
        'Sân 2',
      ],
    );
  });

  test('the venue with its policy, courts and products; defaults when missing', () {
    final venue = Venue.fromJson({
      'name': 'VN Badminton',
      'address': '12 Nguyễn Huệ, Quận 1',
      'phone': '+84901234567',
      'contact_links': {'phone': 'tel:+84901234567', 'zalo': 'https://zalo.me/0901234567', 'messenger': null},
      'payments_enabled': true,
      'courts': [
        {'id': 1, 'name': 'Sân 1'},
        {'id': 2, 'name': 'VIP'},
      ],
      'policy': {'min_booking_minutes': 60, 'max_booking_minutes': 180, 'cancellation_cutoff_hours': 2},
      'products': [
        {'id': 7, 'name': 'Thuê vợt', 'price_vnd': 20000},
      ],
    });

    expect(venue.courts.map((court) => court.name), ['Sân 1', 'VIP']);
    expect(venue.maxBookingMinutes, 180);
    expect(venue.contactLinks['messenger'], isNull);
    expect(venue.products.single.priceVnd, 20000);

    final empty = Venue.fromJson({});
    expect(empty.minBookingMinutes, 60);
    expect(empty.courts, isEmpty);
  });

  test('the user and the loyalty tier', () {
    final user = User.fromJson({
      'id': 4,
      'full_name': 'Nguyễn An',
      'email': 'an@example.com',
      'phone': '+84901234567',
      'locale': 'vi',
      'email_verified': true,
      'booking_locked_until': null,
      'birth_year': 1995,
      'gender': 'female',
      'skill_level': 'intermediate',
      'avatar_path': null,
    });
    expect(user.emailVerified, isTrue);
    expect(user.birthYear, 1995);
    expect(user.bookingLockedUntil, isNull);

    final loyalty = Loyalty.fromJson({
      'tier': 'silver',
      'name': 'Bạc',
      'percent': 5,
      'hours': 23.5,
      'enabled': true,
      'next': {'tier': 'gold', 'name': 'Vàng', 'hours': 50},
    });
    expect(loyalty.hours, 23.5);
    expect(loyalty.nextName, 'Vàng');
    expect(loyalty.nextHours, 50);
    expect(Loyalty.fromJson({'tier': 'diamond', 'hours': 300, 'next': null}).nextHours, isNull);
  });

  test('the schedule grid: slots by court id', () {
    final day = ScheduleDay.fromJson({
      'date': '2026-10-20',
      'dates': ['2026-10-20', '2026-10-21'],
      'courts': [
        {'id': 1, 'name': 'Sân 1'},
      ],
      'times': ['2026-10-20T18:00:00+07:00', '2026-10-20T18:30:00+07:00'],
      'slots': {
        '1': [
          {'starts_at': '2026-10-20T18:00:00+07:00', 'state': 'available', 'price_vnd': 60000},
          {'starts_at': '2026-10-20T18:30:00+07:00', 'state': 'booked'},
        ],
      },
    });

    expect(day.slots[1]!.first.available, isTrue);
    expect(day.slots[1]!.first.startsAtText, '2026-10-20T18:00:00+07:00');
    expect(day.slots[1]!.last.priceVnd, 0);
    expect(day.times.first, DateTime.utc(2026, 10, 20, 11));
  });

  test('series with its months, packages, open play and groups', () {
    final series = Series.fromJson({
      'id': 2,
      'courts': ['Sân 1'],
      'days_of_week': [2, 4],
      'start_minute': 1080,
      'end_minute': 1200,
      'starts_on': '2026-11-01',
      'ends_on': '2027-01-31',
      'price_per_hour_vnd': 100000,
      'months': [
        {'month': '2026-11', 'sessions': 9, 'amount_vnd': 1800000, 'credit_vnd': 0, 'due_vnd': 1800000, 'paid': false},
      ],
    });
    expect(series.daysOfWeek, [2, 4]);
    expect(series.months.single.dueVnd, 1800000);
    expect(series.months.single.paymentToken, isNull);

    final purchase = PackagePurchase.fromJson({
      'id': 1,
      'name': '10 giờ',
      'status': 'active',
      'minutes_total': 600,
      'minutes_left': 90,
      'expires_at': '2999-01-01T00:00:00+07:00',
    });
    expect(purchase.usable, isTrue);
    expect(PackagePurchase.fromJson({'id': 2, 'status': 'awaiting', 'minutes_left': 600}).usable, isFalse);

    final session = PlaySession.fromJson({
      'id': 5,
      'title': 'Giao lưu tối thứ Sáu',
      'courts': ['Sân 1', 'Sân 2'],
      'starts_at': '2026-10-23T19:00:00+07:00',
      'ends_at': '2026-10-23T21:00:00+07:00',
      'capacity': 16,
      'seats_left': 3,
      'price_vnd': 50000,
      'level': null,
      'bookable': true,
      'my_tickets': [
        {'id': 9, 'quantity': 2, 'amount_vnd': 100000, 'status': 'pending', 'payment_token': 'tok'},
      ],
    });
    expect(session.myTickets.single.quantity, 2);
    expect(session.level, isNull);

    final group = Group.fromJson({
      'id': 3,
      'name': 'Thứ Bảy',
      'invite_code': 'AB12CD',
      'owner': true,
      'members': [
        {'id': 4, 'name': 'Nguyễn An', 'owner': true},
      ],
      'shares': [
        {
          'id': 1,
          'shared_by': 'Nguyễn An',
          'mine': true,
          'players': 4,
          'per_player_vnd': 52000,
          'total_vnd': 208000,
          'court': 'Sân 3',
          'starts_at': '2026-10-20T18:00:00+07:00',
          'ends_at': '2026-10-20T19:30:00+07:00',
          'code': 'K7MPX2QA',
        },
      ],
    });
    expect(group.members.single.owner, isTrue);
    expect(group.shares.single.perPlayerVnd, 52000);
  });

  test('a quote with an offer and messages', () {
    final quote = Quote.fromJson({
      'court_vnd': 180000,
      'items_vnd': 40000,
      'discount_vnd': 12000,
      'total_vnd': 208000,
      'offer': {'kind': 'voucher', 'label': 'GIAM10'},
      'messages': ['Mã đã hết hạn'],
    });
    expect(quote.offerKind, 'voucher');
    expect(quote.messages, ['Mã đã hết hạn']);
    expect(Quote.fromJson({'total_vnd': 1000, 'offer': null}).offerKind, isNull);
  });
}
