// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/visits/domain/guest_participation.dart';

/// #1835 — the guest's visits in memory, for the suite and for Demo
/// (which holds none: a visitor is not admitted anywhere by default).
class FakeGuestParticipationRepository implements GuestParticipationRepository {
  FakeGuestParticipationRepository({List<GuestParticipation>? visits})
    : visits = visits ?? [];

  final List<GuestParticipation> visits;
  final cancelled = <String>[];

  /// What the next cancel answers; the server's word, scripted.
  GuestVisitCancelOutcome nextCancel = GuestVisitCancelOutcome.cancelled;

  @override
  Future<List<GuestParticipation>> myVisits() async => List.of(visits);

  @override
  Future<GuestVisitCancelOutcome> cancel(String visitId) async {
    cancelled.add(visitId);
    final outcome = nextCancel;
    if (outcome == GuestVisitCancelOutcome.cancelled) {
      final i = visits.indexWhere((v) => v.id == visitId);
      if (i >= 0) {
        final v = visits[i];
        visits[i] = GuestParticipation(
          id: v.id,
          workspaceId: v.workspaceId,
          workspaceName: v.workspaceName,
          siteId: v.siteId,
          siteName: v.siteName,
          status: GuestVisitStatus.cancelled,
          startsAt: v.startsAt,
          endsAt: v.endsAt,
          message: v.message,
          requestedAt: v.requestedAt,
          decidedAt: v.decidedAt,
          cancelledAt: DateTime.utc(2026, 1, 1),
          revision: v.revision + 1,
        );
      }
    }
    return outcome;
  }
}
