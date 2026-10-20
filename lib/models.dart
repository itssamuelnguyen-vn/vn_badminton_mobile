// The JSON shapes of the API (docs/api.md in the web app). Times arrive as ISO 8601 with the venue's offset
// and are kept in UTC; format.dart shows them in the venue's time.

class User {
  User.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        fullName = json['full_name'] as String? ?? '',
        email = json['email'] as String? ?? '',
        phone = json['phone'] as String? ?? '',
        locale = json['locale'] as String? ?? 'vi',
        emailVerified = json['email_verified'] == true,
        bookingLockedUntil = _time(json['booking_locked_until']),
        birthYear = json['birth_year'] as int?,
        gender = json['gender'] as String?,
        skillLevel = json['skill_level'] as String?,
        avatarPath = json['avatar_path'] as String?;

  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String locale;
  final bool emailVerified;
  final DateTime? bookingLockedUntil;

  // The optional profile (TK-10).
  final int? birthYear;

  /// male, female or other.
  final String? gender;

  /// beginner, intermediate, advanced or expert.
  final String? skillLevel;

  /// On the server (see avatarUrl in api.dart); null without a photo.
  final String? avatarPath;
}

class Court {
  Court.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int,
        name = json['name'] as String;

  final int id;
  final String name;
}

class Venue {
  Venue.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String? ?? '',
        address = json['address'] as String? ?? '',
        phone = json['phone'] as String? ?? '',
        contactLinks = Map<String, String?>.from(json['contact_links'] as Map? ?? const {}),
        paymentsEnabled = json['payments_enabled'] == true,
        minBookingMinutes = (json['policy']?['min_booking_minutes'] as int?) ?? 60,
        maxBookingMinutes = (json['policy']?['max_booking_minutes'] as int?) ?? 240,
        cancellationCutoffHours = (json['policy']?['cancellation_cutoff_hours'] as int?) ?? 0;

  final String name;
  final String address;
  final String phone;
  final Map<String, String?> contactLinks;
  final bool paymentsEnabled;
  final int minBookingMinutes;
  final int maxBookingMinutes;
  final int cancellationCutoffHours;
}

/// One 30-minute cell of the booking grid.
class Slot {
  Slot.fromJson(Map<String, dynamic> json)
      : startsAtText = json['starts_at'] as String,
        startsAt = DateTime.parse(json['starts_at'] as String),
        state = json['state'] as String,
        priceVnd = (json['price_vnd'] as num?)?.toInt() ?? 0;

  /// As the server wrote it (with the venue's offset), sent back as is when booking.
  final String startsAtText;
  final DateTime startsAt;

  /// available, booked, held, mine, blocked or unavailable.
  final String state;
  final int priceVnd;

  bool get available => state == 'available';
}

class ScheduleDay {
  ScheduleDay.fromJson(Map<String, dynamic> json)
      : date = json['date'] as String?,
        dates = [for (final date in json['dates'] as List? ?? const []) date as String],
        courts = [for (final court in json['courts'] as List? ?? const []) Court.fromJson(court)],
        times = [for (final time in json['times'] as List? ?? const []) DateTime.parse(time as String)],
        slots = {
          for (final entry in (json['slots'] as Map? ?? const {}).entries)
            int.parse(entry.key as String): [for (final slot in entry.value as List) Slot.fromJson(slot)],
        };

  final String? date;
  final List<String> dates;
  final List<Court> courts;
  final List<DateTime> times;
  final Map<int, List<Slot>> slots;
}

class Booking {
  Booking.fromJson(Map<String, dynamic> json)
      : code = json['code'] as String,
        court = Court.fromJson(json['court'] as Map<String, dynamic>),
        startsAt = DateTime.parse(json['starts_at'] as String),
        endsAt = DateTime.parse(json['ends_at'] as String),
        status = json['status'] as String,
        paymentStatus = json['payment_status'] as String? ?? 'unpaid',
        amountVnd = (json['amount_vnd'] as num?)?.toInt() ?? 0,
        note = json['note'] as String?,
        heldUntil = _time(json['held_until']),
        cancellationReason = json['cancellation_reason'] as String?,
        refundVnd = (json['refund_vnd'] as num?)?.toInt(),
        series = json['series'] == true,
        canCancel = json['can_cancel'] == true,
        cancelWithoutRefund = json['cancel_without_refund'] == true,
        paymentToken = json['payment_token'] as String?;

  final String code;
  final Court court;
  final DateTime startsAt;
  final DateTime endsAt;

  /// pending, confirmed, checked_in, completed, cancelled or no_show.
  final String status;

  /// unpaid, paid or refunded.
  final String paymentStatus;
  final int amountVnd;
  final String? note;
  final DateTime? heldUntil;
  final String? cancellationReason;
  final int? refundVnd;
  final bool series;
  final bool canCancel;
  final bool cancelWithoutRefund;
  final String? paymentToken;
}

class Bank {
  Bank.fromJson(Map<String, dynamic> json)
      : code = json['code'] as String? ?? '',
        accountNumber = json['account_number'] as String? ?? '',
        accountName = json['account_name'] as String? ?? '';

  final String code;
  final String accountNumber;
  final String accountName;
}

class Payment {
  Payment.fromJson(Map<String, dynamic> json)
      : token = json['token'] as String,
        code = json['code'] as String,
        status = json['status'] as String,
        open = json['open'] == true,
        amountVnd = (json['amount_vnd'] as num?)?.toInt() ?? 0,
        receivedVnd = (json['received_vnd'] as num?)?.toInt() ?? 0,
        remainingVnd = (json['remaining_vnd'] as num?)?.toInt() ?? 0,
        expiresAt = _time(json['expires_at']),
        paidAt = _time(json['paid_at']),
        bank = Bank.fromJson(json['bank'] as Map<String, dynamic>? ?? const {}),
        qrImageUrl = json['qr_image_url'] as String?,
        bookings = [for (final booking in json['bookings'] as List? ?? const []) Booking.fromJson(booking)];

  final String token;

  /// The transfer content the bank transfer must carry.
  final String code;

  /// awaiting, paid, expired or cancelled.
  final String status;
  final bool open;
  final int amountVnd;
  final int receivedVnd;
  final int remainingVnd;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final Bank bank;
  final String? qrImageUrl;
  final List<Booking> bookings;
}

DateTime? _time(Object? value) => value is String ? DateTime.parse(value) : null;
