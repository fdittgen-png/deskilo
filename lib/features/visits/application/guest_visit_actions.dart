// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1835 — what the guest does to one of their visits. The widget says
// what the person asked for; the decision of what that means (here, one
// call whose answer is the server's) lives here, ADR 0024.
import '../domain/guest_participation.dart';

class GuestVisitActions {
  const GuestVisitActions(this._repository);

  final GuestParticipationRepository _repository;

  /// Withdraws a request or cancels a confirmed visit; the server answers
  /// whether it did, and the screen re-reads what it holds either way.
  Future<GuestVisitCancelOutcome> cancel(String visitId) =>
      _repository.cancel(visitId);
}
