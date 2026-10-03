// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1855 — what a member confirmed, kept exactly until the server's answer
// is known. A booking whose response was lost is neither a success nor a
// failure; it is THIS intent, and recovering it means asking about this
// request id with this payload on this server as this account — never a
// fresh request, never the workspace that happens to be selected later.
//
// Pure Dart: the ledger is a value, the store a string, the scope a pair
// of ids. Nothing here knows how the sheet looks or how the RPC is named.
import 'dart:convert';

/// Where an intent is valid: one account on one server. An intent made
/// under another login or against another installation is never shown,
/// replayed or inherited.
class BookingIntentScope {
  const BookingIntentScope({required this.account, required this.origin});

  /// The signed-in account's id on that server.
  final String account;

  /// The server's origin (the Supabase URL), not a bearer or a key.
  final String origin;

  @override
  bool operator ==(Object other) =>
      other is BookingIntentScope &&
      other.account == account &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(account, origin);
}

/// What the device knows about one confirmed booking.
enum BookingIntentStatus {
  /// Saved, sent or about to be sent; no answer read yet.
  pending,

  /// The server refused with a message the member saw.
  refused,

  /// The transport failed after the send: committed or not, unknown.
  unknown,

  /// The server answered with a reservation.
  committed,
}

class BookingIntent {
  const BookingIntent({
    required this.requestId,
    required this.scope,
    required this.workspaceId,
    required this.seatId,
    this.deskId,
    this.officeId,
    this.levelId,
    required this.startsAt,
    required this.endsAt,
    required this.checkIn,
    required this.schemaVersion,
    required this.createdAt,
    this.status = BookingIntentStatus.pending,
    this.reservationId,
    this.lastCheckedAt,
  });

  /// The client request id the server claims; the SAME one on every
  /// attempt at this booking. Minted once, before the first send.
  final String requestId;
  final BookingIntentScope scope;
  final String workspaceId;
  final String? seatId;
  final String? deskId;
  final String? officeId;
  final String? levelId;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool checkIn;

  /// The schema the payload was shaped for; a replay against a server
  /// that moved on is still the same request, but the reader knows.
  final int schemaVersion;
  final DateTime createdAt;
  final BookingIntentStatus status;
  final String? reservationId;
  final DateTime? lastCheckedAt;

  /// Open: the member does not know whether this booking exists.
  bool get unresolved =>
      status == BookingIntentStatus.pending ||
      status == BookingIntentStatus.unknown;

  BookingIntent copyWith({
    BookingIntentStatus? status,
    String? reservationId,
    DateTime? lastCheckedAt,
  }) => BookingIntent(
    requestId: requestId,
    scope: scope,
    workspaceId: workspaceId,
    seatId: seatId,
    deskId: deskId,
    officeId: officeId,
    levelId: levelId,
    startsAt: startsAt,
    endsAt: endsAt,
    checkIn: checkIn,
    schemaVersion: schemaVersion,
    createdAt: createdAt,
    status: status ?? this.status,
    reservationId: reservationId ?? this.reservationId,
    lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
  );

  Map<String, Object?> toJson() => {
    'request_id': requestId,
    'account': scope.account,
    'origin': scope.origin,
    'workspace_id': workspaceId,
    'seat_id': seatId,
    'desk_id': deskId,
    'office_id': officeId,
    'level_id': levelId,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'check_in': checkIn,
    'schema_version': schemaVersion,
    'created_at': createdAt.toUtc().toIso8601String(),
    'status': status.name,
    'reservation_id': reservationId,
    'last_checked_at': lastCheckedAt?.toUtc().toIso8601String(),
  };

  /// Null for anything unreadable: a corrupt entry is dropped, never
  /// guessed into a request.
  static BookingIntent? fromJson(Object? json) {
    if (json is! Map) return null;
    String? text(String k) => json[k] is String ? json[k] as String : null;
    final requestId = text('request_id');
    final account = text('account');
    final origin = text('origin');
    final workspaceId = text('workspace_id');
    final startsAt = DateTime.tryParse(text('starts_at') ?? '');
    final endsAt = DateTime.tryParse(text('ends_at') ?? '');
    final createdAt = DateTime.tryParse(text('created_at') ?? '');
    final status = BookingIntentStatus.values
        .where((s) => s.name == json['status'])
        .firstOrNull;
    if (requestId == null ||
        account == null ||
        origin == null ||
        workspaceId == null ||
        startsAt == null ||
        endsAt == null ||
        createdAt == null ||
        status == null) {
      return null;
    }
    return BookingIntent(
      requestId: requestId,
      scope: BookingIntentScope(account: account, origin: origin),
      workspaceId: workspaceId,
      seatId: text('seat_id'),
      deskId: text('desk_id'),
      officeId: text('office_id'),
      levelId: text('level_id'),
      startsAt: startsAt.toUtc(),
      endsAt: endsAt.toUtc(),
      checkIn: json['check_in'] == true,
      schemaVersion: json['schema_version'] is int
          ? json['schema_version'] as int
          : 0,
      createdAt: createdAt.toUtc(),
      status: status,
      reservationId: text('reservation_id'),
      lastCheckedAt: DateTime.tryParse(text('last_checked_at') ?? '')?.toUtc(),
    );
  }
}

/// The device's list of intents, bounded. Settled entries leave; open
/// ones stay until the member resolves them, whatever the restart count.
class BookingIntentLedger {
  const BookingIntentLedger(this.intents);

  static const empty = BookingIntentLedger([]);

  /// More than this and the oldest settled entries go first, then the
  /// oldest open ones: a ledger is a short list of unanswered questions,
  /// not a history.
  static const int cap = 20;

  final List<BookingIntent> intents;

  static BookingIntentLedger decode(String? text) {
    if (text == null || text.isEmpty) return empty;
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return empty;
    }
    if (json is! List) return empty;
    return BookingIntentLedger([
      for (final e in json) ?BookingIntent.fromJson(e),
    ]);
  }

  String encode() => jsonEncode([for (final i in intents) i.toJson()]);

  BookingIntent? byRequestId(String requestId) =>
      intents.where((i) => i.requestId == requestId).firstOrNull;

  /// The open intents of one account on one server, in one workspace.
  List<BookingIntent> unresolvedFor(
    BookingIntentScope scope, {
    String? workspaceId,
  }) => [
    for (final i in intents)
      if (i.unresolved &&
          i.scope == scope &&
          (workspaceId == null || i.workspaceId == workspaceId))
        i,
  ];

  BookingIntentLedger upsert(BookingIntent intent) {
    final rest = intents.where((i) => i.requestId != intent.requestId);
    final next = [...rest, intent];
    if (next.length <= cap) return BookingIntentLedger(next);
    next.sort((a, b) {
      final openness = (a.unresolved ? 1 : 0) - (b.unresolved ? 1 : 0);
      return openness != 0 ? openness : a.createdAt.compareTo(b.createdAt);
    });
    return BookingIntentLedger(next.sublist(next.length - cap));
  }

  BookingIntentLedger remove(String requestId) => BookingIntentLedger([
    for (final i in intents)
      if (i.requestId != requestId) i,
  ]);
}

/// What the server knows about one request id, read back exactly.
enum RequestOutcomeStatus { committed, inProgress, absent, unavailable }

class RequestOutcome {
  const RequestOutcome({
    required this.status,
    this.reservationId,
    this.reservationStatus,
    this.retentionDays = 90,
  });

  static const unavailable = RequestOutcome(
    status: RequestOutcomeStatus.unavailable,
  );

  final RequestOutcomeStatus status;
  final String? reservationId;
  final String? reservationStatus;

  /// How long the server keeps a claim at least; absence beyond that is
  /// unresolved, not "nothing was booked".
  final int retentionDays;

  factory RequestOutcome.fromJson(Object? json) {
    if (json is! Map) return unavailable;
    final status = switch (json['status']) {
      'committed' => RequestOutcomeStatus.committed,
      'in_progress' => RequestOutcomeStatus.inProgress,
      'absent' => RequestOutcomeStatus.absent,
      _ => RequestOutcomeStatus.unavailable,
    };
    if (status == RequestOutcomeStatus.committed &&
        json['reservation_id'] is! String) {
      return unavailable;
    }
    return RequestOutcome(
      status: status,
      reservationId: json['reservation_id'] as String?,
      reservationStatus: json['reservation_status'] as String?,
      retentionDays: json['retention_days'] is int
          ? json['retention_days'] as int
          : 90,
    );
  }
}
