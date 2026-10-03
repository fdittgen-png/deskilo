// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1835 — a person's visit to a space they are not a member of, as the
// server projects it to its guest (0351 `guest_participation_self_view`):
// where, when, what the host decided. Never the host's note, never who
// decided. A visit is a relationship of the account, not a membership:
// nothing here names a member, a role or a subscription.
//
// Pure Dart: the CLI and the tests import it without Flutter.

/// What the server says about a visit. `expired` is the server's reading
/// of its clock: a visit nobody cancelled whose window has passed.
enum GuestVisitStatus {
  requested,
  confirmed,
  declined,
  cancelled,
  expired,

  /// A status this app does not know: shown as such, never promoted.
  unknown;

  static GuestVisitStatus parse(Object? wire) => switch (wire) {
    'requested' => requested,
    'confirmed' => confirmed,
    'declined' => declined,
    'cancelled' => cancelled,
    'expired' => expired,
    _ => unknown,
  };

  /// Whether the guest may still cancel it (the server decides again).
  bool get cancellable => this == requested || this == confirmed;
}

class GuestParticipation {
  const GuestParticipation({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    this.siteId,
    this.siteName,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.message = '',
    this.requestedAt,
    this.decidedAt,
    this.cancelledAt,
    this.revision = 1,
  });

  final String id;
  final String workspaceId;
  final String workspaceName;
  final String? siteId;
  final String? siteName;
  final GuestVisitStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final String message;
  final DateTime? requestedAt;
  final DateTime? decidedAt;
  final DateTime? cancelledAt;
  final int revision;

  /// Reads one projected row. A row without an id, workspace or window is
  /// dropped by [listFromJson]; an unknown status is kept as `unknown`.
  static GuestParticipation? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final workspaceId = json['workspace_id'];
    final starts = DateTime.tryParse('${json['starts_at']}');
    final ends = DateTime.tryParse('${json['ends_at']}');
    if (id is! String ||
        workspaceId is! String ||
        starts == null ||
        ends == null) {
      return null;
    }
    String? text(String key) =>
        json[key] is String ? json[key] as String : null;
    return GuestParticipation(
      id: id,
      workspaceId: workspaceId,
      workspaceName: text('workspace_name') ?? '',
      siteId: text('site_id'),
      siteName: text('site_name'),
      status: GuestVisitStatus.parse(json['status']),
      startsAt: starts.toUtc(),
      endsAt: ends.toUtc(),
      message: text('message') ?? '',
      requestedAt: DateTime.tryParse(text('requested_at') ?? '')?.toUtc(),
      decidedAt: DateTime.tryParse(text('decided_at') ?? '')?.toUtc(),
      cancelledAt: DateTime.tryParse(text('cancelled_at') ?? '')?.toUtc(),
      revision: json['revision'] is int ? json['revision'] as int : 1,
    );
  }

  static List<GuestParticipation> listFromJson(Object? json) => [
    for (final row in json is List ? json : const []) ?fromJson(row),
  ];
}

/// What cancelling answered: the server's word, never the screen's guess.
enum GuestVisitCancelOutcome { cancelled, unchanged, refused }

/// The account's own visits (`my_guest_participations`) and the one thing
/// the guest does to one (`cancel_my_guest_visit`). Asking for a visit and
/// deciding one belong to the flows that own them (#1837 B, #1835 B).
abstract interface class GuestParticipationRepository {
  Future<List<GuestParticipation>> myVisits();
  Future<GuestVisitCancelOutcome> cancel(String visitId);
}
