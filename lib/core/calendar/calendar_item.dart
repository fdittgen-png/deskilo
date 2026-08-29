// SPDX-License-Identifier: 0BSD

/// The kinds of dated fact the calendar hub shows (#718). Wire names
/// match `calendar_items()` (0133) one for one.
enum CalendarKind {
  reservation('reservation'),
  checkIn('checkin'),
  checkOut('checkout'),
  event('event'),
  message('message'),
  invoice('invoice'),
  payment('payment'),
  consumption('consumption'),
  reminder('reminder');

  const CalendarKind(this.wire);
  final String wire;

  static CalendarKind? fromWire(String? wire) =>
      values.where((k) => k.wire == wire).firstOrNull;

  /// The kinds that are somebody's MONEY — gated together by
  /// `may_view_member_finances()` and logged when read about others.
  bool get isMoney =>
      this == invoice || this == payment || this == consumption;
}

/// Where a row leads when tapped. The hub never renders a dead end: a
/// fact you can see is a fact you can open (#718).
sealed class CalendarLink {
  const CalendarLink();

  static CalendarLink? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return switch (json['type']) {
      'reservation' => ReservationLink(json['id'] as String),
      'conversation' => ConversationLink(json['id'] as String),
      'event' => EventLink(json['id'] as String),
      'invoice' => InvoiceLink(json['id'] as String),
      'ledger' => LedgerLink(json['period'] as String),
      _ => null,
    };
  }
}

class ReservationLink extends CalendarLink {
  const ReservationLink(this.id);
  final String id;
}

class ConversationLink extends CalendarLink {
  const ConversationLink(this.id);
  final String id;
}

class EventLink extends CalendarLink {
  const EventLink(this.id);
  final String id;
}

class InvoiceLink extends CalendarLink {
  const InvoiceLink(this.id);
  final String id;
}

class LedgerLink extends CalendarLink {
  const LedgerLink(this.period);

  /// `yyyy-MM` — the Money tab opens on that month.
  final String period;
}

/// One dated fact, whatever its source.
class CalendarItem {
  const CalendarItem({
    required this.kind,
    required this.id,
    required this.at,
    required this.memberId,
    required this.title,
    this.until,
    this.body = '',
    this.status = '',
    this.amountCents,
    this.currency,
    this.category = '',
    this.link,
  });

  final CalendarKind kind;
  final String id;
  final DateTime at;
  final DateTime? until;
  final String memberId;
  final String title;
  final String body;
  final String status;
  final int? amountCents;
  final String? currency;
  final String category;
  final CalendarLink? link;

  factory CalendarItem.fromRow(Map<String, dynamic> row) => CalendarItem(
        kind: CalendarKind.fromWire(row['kind'] as String?) ??
            CalendarKind.event,
        id: row['id'] as String,
        at: DateTime.parse(row['at'] as String).toUtc(),
        until: row['until'] == null
            ? null
            : DateTime.parse(row['until'] as String).toUtc(),
        memberId: row['member_id'] as String? ?? '',
        title: row['title'] as String? ?? '',
        body: row['body'] as String? ?? '',
        status: row['status'] as String? ?? '',
        amountCents: row['amount_cents'] as int?,
        currency: row['currency'] as String?,
        category: row['category'] as String? ?? '',
        link: CalendarLink.fromJson(
          (row['link'] as Map?)?.cast<String, dynamic>(),
        ),
      );
}

/// The answer to one range query: the items, and the kinds the server
/// declined for this subject — so the screen can say "locked" rather
/// than show an empty list that reads like "nothing happened".
class CalendarPage {
  const CalendarPage({
    required this.subjectMemberId,
    required this.items,
    required this.locked,
  });

  final String subjectMemberId;
  final List<CalendarItem> items;
  final Set<CalendarKind> locked;

  factory CalendarPage.fromJson(Map<String, dynamic> json) => CalendarPage(
        subjectMemberId: json['subject_member_id'] as String? ?? '',
        items: [
          for (final row in (json['items'] as List? ?? const []))
            CalendarItem.fromRow(Map<String, dynamic>.from(row as Map)),
        ],
        locked: {
          for (final k in (json['locked'] as List? ?? const []))
            ?CalendarKind.fromWire(k as String?),
        },
      );

  static const empty = CalendarPage(subjectMemberId: '', items: [], locked: {});
}

/// What the hub asks for. Value-equal, so a Riverpod family caches per
/// query and a re-tap of the same day costs nothing.
class CalendarQuery {
  const CalendarQuery({
    required this.from,
    required this.to,
    this.kinds,
    this.memberId,
  });

  /// Half-open UTC range `[from, to)`.
  final DateTime from;
  final DateTime to;

  /// Null = every kind.
  final Set<CalendarKind>? kinds;

  /// Null = the caller.
  final String? memberId;

  @override
  bool operator ==(Object other) =>
      other is CalendarQuery &&
      other.from == from &&
      other.to == to &&
      other.memberId == memberId &&
      _sameKinds(other.kinds, kinds);

  static bool _sameKinds(Set<CalendarKind>? a, Set<CalendarKind>? b) {
    if (a == null || b == null) return a == b;
    return a.length == b.length && a.containsAll(b);
  }

  @override
  int get hashCode => Object.hash(
        from,
        to,
        memberId,
        kinds == null ? null : Object.hashAllUnordered(kinds!),
      );
}
