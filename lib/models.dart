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
  Court.fromJson(Map<String, dynamic> json) : id = json['id'] as int, name = json['name'] as String;

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
      cancellationCutoffHours = (json['policy']?['cancellation_cutoff_hours'] as int?) ?? 0,
      courts = [for (final court in json['courts'] as List? ?? const []) Court.fromJson(court)],
      products = [for (final product in json['products'] as List? ?? const []) Product.fromJson(product)];

  final String name;
  final String address;
  final String phone;
  final Map<String, String?> contactLinks;
  final bool paymentsEnabled;
  final int minBookingMinutes;
  final int maxBookingMinutes;
  final int cancellationCutoffHours;
  final List<Court> courts;

  /// What can be added to a booking (racket rental, shuttlecocks...), TI-01.
  final List<Product> products;
}

class Product {
  Product.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String? ?? '',
      priceVnd = (json['price_vnd'] as num?)?.toInt() ?? 0;

  final int id;
  final String name;
  final int priceVnd;
}

class BookingItem {
  BookingItem.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String? ?? '',
      quantity = (json['quantity'] as num?)?.toInt() ?? 1,
      unitPriceVnd = (json['unit_price_vnd'] as num?)?.toInt() ?? 0;

  final String name;
  final int quantity;
  final int unitPriceVnd;
}

class Review {
  Review.fromJson(Map<String, dynamic> json)
    : rating = (json['rating'] as num?)?.toInt() ?? 0,
      comment = json['comment'] as String?;

  final int rating;
  final String? comment;
}

/// The owner's news shown above the schedule (TI-02).
class Announcement {
  Announcement.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      title = json['title'] as String? ?? '',
      body = json['body'] as String?,
      tone = json['tone'] as String? ?? 'info';

  final int id;
  final String title;
  final String? body;

  /// info, offer or warning.
  final String tone;
}

/// "Tell me when it frees up" (TI-04).
class WaitlistEntry {
  WaitlistEntry.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      startsAt = DateTime.parse(json['starts_at'] as String),
      endsAt = DateTime.parse(json['ends_at'] as String);

  final int id;
  final DateTime startsAt;
  final DateTime endsAt;
}

/// A weekly booking asked for in the app (CD-09).
class SeriesRequest {
  SeriesRequest.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      courts = [for (final court in json['courts'] as List? ?? const []) court as String],
      daysOfWeek = [for (final day in json['days_of_week'] as List? ?? const []) (day as num).toInt()],
      startMinute = (json['start_minute'] as num).toInt(),
      endMinute = (json['end_minute'] as num).toInt(),
      startsOn = json['starts_on'] as String,
      endsOn = json['ends_on'] as String,
      note = json['note'] as String?,
      status = json['status'] as String,
      declineReason = json['decline_reason'] as String?;

  final int id;
  final List<String> courts;
  final List<int> daysOfWeek;
  final int startMinute;
  final int endMinute;
  final String startsOn;
  final String endsOn;
  final String? note;

  /// pending, approved, declined or cancelled.
  final String status;
  final String? declineReason;
}

/// A weekly booking made by the venue, with its months to pay (CD-10).
class Series {
  Series.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      courts = [for (final court in json['courts'] as List? ?? const []) court as String],
      daysOfWeek = [for (final day in json['days_of_week'] as List? ?? const []) (day as num).toInt()],
      startMinute = (json['start_minute'] as num).toInt(),
      endMinute = (json['end_minute'] as num).toInt(),
      startsOn = json['starts_on'] as String,
      endsOn = json['ends_on'] as String,
      months = [for (final month in json['months'] as List? ?? const []) SeriesMonth.fromJson(month)];

  final int id;
  final List<String> courts;
  final List<int> daysOfWeek;
  final int startMinute;
  final int endMinute;
  final String startsOn;
  final String endsOn;
  final List<SeriesMonth> months;
}

class SeriesMonth {
  SeriesMonth.fromJson(Map<String, dynamic> json)
    : month = json['month'] as String,
      sessions = (json['sessions'] as num?)?.toInt() ?? 0,
      dueVnd = (json['due_vnd'] as num?)?.toInt() ?? 0,
      creditVnd = (json['credit_vnd'] as num?)?.toInt() ?? 0,
      paid = json['paid'] == true,
      paymentToken = json['payment_token'] as String?;

  /// "2026-11".
  final String month;
  final int sessions;
  final int dueVnd;
  final int creditVnd;
  final bool paid;
  final String? paymentToken;
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
      paymentToken = json['payment_token'] as String?,
      itemsAmountVnd = (json['items_amount_vnd'] as num?)?.toInt() ?? 0,
      totalVnd = (json['total_vnd'] as num?)?.toInt() ?? (json['amount_vnd'] as num?)?.toInt() ?? 0,
      items = [for (final item in json['items'] as List? ?? const []) BookingItem.fromJson(item)],
      canReschedule = json['can_reschedule'] == true,
      discountVnd = (json['discount_vnd'] as num?)?.toInt() ?? 0,
      paidWithPackage = json['paid_with_package'] == true,
      canReview = json['can_review'] == true,
      review = json['review'] is Map ? Review.fromJson(json['review'] as Map<String, dynamic>) : null;

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

  /// The extras picked with the booking (TI-01); totalVnd is the court plus them.
  final int itemsAmountVnd;
  final int totalVnd;
  final List<BookingItem> items;
  final bool canReschedule;
  final int discountVnd;
  final bool paidWithPackage;
  final bool canReview;
  final Review? review;
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
      discountVnd = (json['discount_vnd'] as num?)?.toInt() ?? 0,
      offer = json['offer'] as String?,
      purpose = json['purpose'] as String? ?? 'bookings',
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

  /// Taken off by the member tier or a voucher (UD-03): "tier" or "voucher".
  final int discountVnd;
  final String? offer;

  /// bookings, series_period, package or tickets.
  final String purpose;
}

/// The customer's member tier (UD-01).
class Loyalty {
  Loyalty.fromJson(Map<String, dynamic> json)
    : tier = json['tier'] as String? ?? 'bronze',
      name = json['name'] as String? ?? '',
      percent = (json['percent'] as num?)?.toInt() ?? 0,
      hours = (json['hours'] as num?)?.toDouble() ?? 0,
      enabled = json['enabled'] != false,
      nextName = json['next']?['name'] as String?,
      nextHours = (json['next']?['hours'] as num?)?.toInt();

  final String tier;
  final String name;
  final int percent;
  final double hours;
  final bool enabled;
  final String? nextName;
  final int? nextHours;
}

/// Prepaid hours on sale (UD-04).
class PackageOffer {
  PackageOffer.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String? ?? '',
      minutes = (json['minutes'] as num?)?.toInt() ?? 0,
      priceVnd = (json['price_vnd'] as num?)?.toInt() ?? 0,
      validDays = (json['valid_days'] as num?)?.toInt() ?? 0,
      startMinute = (json['start_minute'] as num?)?.toInt(),
      endMinute = (json['end_minute'] as num?)?.toInt();

  final int id;
  final String name;
  final int minutes;
  final int priceVnd;
  final int validDays;
  final int? startMinute;
  final int? endMinute;
}

/// Prepaid hours the customer bought.
class PackagePurchase {
  PackagePurchase.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String? ?? '',
      status = json['status'] as String? ?? 'awaiting',
      minutesTotal = (json['minutes_total'] as num?)?.toInt() ?? 0,
      minutesLeft = (json['minutes_left'] as num?)?.toInt() ?? 0,
      expiresAt = _time(json['expires_at']),
      startMinute = (json['start_minute'] as num?)?.toInt(),
      endMinute = (json['end_minute'] as num?)?.toInt(),
      paymentToken = json['payment_token'] as String?;

  final int id;
  final String name;

  /// awaiting (not paid yet) or active.
  final String status;
  final int minutesTotal;
  final int minutesLeft;
  final DateTime? expiresAt;
  final int? startMinute;
  final int? endMinute;
  final String? paymentToken;

  bool get usable => status == 'active' && minutesLeft > 0 && (expiresAt?.isAfter(DateTime.now()) ?? false);
}

/// What an order will cost (POST /quote): the court, the extras and the offer taken off.
class Quote {
  Quote.fromJson(Map<String, dynamic> json)
    : courtVnd = (json['court_vnd'] as num?)?.toInt() ?? 0,
      itemsVnd = (json['items_vnd'] as num?)?.toInt() ?? 0,
      discountVnd = (json['discount_vnd'] as num?)?.toInt() ?? 0,
      totalVnd = (json['total_vnd'] as num?)?.toInt() ?? 0,
      offerKind = json['offer']?['kind'] as String?,
      offerLabel = json['offer']?['label'] as String?,
      messages = [for (final m in json['messages'] as List? ?? const []) m.toString()];

  final int courtVnd;
  final int itemsVnd;
  final int discountVnd;
  final int totalVnd;

  /// tier, voucher or package.
  final String? offerKind;
  final String? offerLabel;
  final List<String> messages;
}

DateTime? _time(Object? value) => value is String ? DateTime.parse(value) : null;

/// An open play session (GL-01): places sold per player.
class PlaySession {
  PlaySession.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      title = json['title'] as String? ?? '',
      description = json['description'] as String?,
      courts = [for (final court in json['courts'] as List? ?? const []) court as String],
      startsAt = DateTime.parse(json['starts_at'] as String),
      endsAt = DateTime.parse(json['ends_at'] as String),
      capacity = (json['capacity'] as num?)?.toInt() ?? 0,
      seatsLeft = (json['seats_left'] as num?)?.toInt() ?? 0,
      priceVnd = (json['price_vnd'] as num?)?.toInt() ?? 0,
      level = json['level'] as String?,
      bookable = json['bookable'] == true,
      myTickets = [for (final ticket in json['my_tickets'] as List? ?? const []) Ticket.fromJson(ticket)];

  final int id;
  final String title;
  final String? description;
  final List<String> courts;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final int seatsLeft;
  final int priceVnd;

  /// beginner, intermediate, advanced, expert or null (any level).
  final String? level;
  final bool bookable;
  final List<Ticket> myTickets;
}

/// Places the customer bought in an open play session.
class Ticket {
  Ticket.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      quantity = (json['quantity'] as num?)?.toInt() ?? 1,
      amountVnd = (json['amount_vnd'] as num?)?.toInt() ?? 0,
      status = json['status'] as String? ?? 'pending',
      canCancel = json['can_cancel'] == true,
      cancelWithoutRefund = json['cancel_without_refund'] == true,
      paymentToken = json['payment_token'] as String?;

  final int id;
  final int quantity;
  final int amountVnd;

  /// pending (awaiting the transfer), confirmed or cancelled.
  final String status;
  final bool canCancel;
  final bool cancelWithoutRefund;
  final String? paymentToken;
}

/// Customers who play together (NH-01).
class Group {
  Group.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String? ?? '',
      inviteCode = json['invite_code'] as String? ?? '',
      owner = json['owner'] == true,
      members = [for (final member in json['members'] as List? ?? const []) GroupMember.fromJson(member)],
      shares = [for (final share in json['shares'] as List? ?? const []) GroupShare.fromJson(share)];

  final int id;
  final String name;
  final String inviteCode;

  /// The signed-in customer owns it.
  final bool owner;
  final List<GroupMember> members;
  final List<GroupShare> shares;
}

class GroupMember {
  GroupMember.fromJson(Map<String, dynamic> json) : name = json['name'] as String? ?? '', owner = json['owner'] == true;

  final String name;
  final bool owner;
}

/// A booking shared with a group (NH-02).
class GroupShare {
  GroupShare.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      sharedBy = json['shared_by'] as String? ?? '',
      mine = json['mine'] == true,
      players = (json['players'] as num?)?.toInt() ?? 1,
      perPlayerVnd = (json['per_player_vnd'] as num?)?.toInt() ?? 0,
      totalVnd = (json['total_vnd'] as num?)?.toInt() ?? 0,
      court = json['court'] as String? ?? '',
      startsAt = DateTime.parse(json['starts_at'] as String),
      endsAt = DateTime.parse(json['ends_at'] as String);

  final int id;
  final String sharedBy;
  final bool mine;
  final int players;
  final int perPlayerVnd;
  final int totalVnd;
  final String court;
  final DateTime startsAt;
  final DateTime endsAt;
}
