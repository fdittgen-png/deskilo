// SPDX-License-Identifier: 0BSD
import 'event_decision.dart';
import 'validation_policy.dart';
import 'workspace_event.dart';
import '../../money/domain/payment_terms.dart';

/// Events boundary. Fetching also triggers the lazy timeout sweep
/// (spec §8.2) until Epic #9 adds a scheduled runner.
abstract class EventRepository {
  Future<List<WorkspaceEvent>> fetchEvents(String workspaceId, {int limit});

  /// Validator decision on a pending event (#130: possibly one of several
  /// before the quorum confirms); rejecting voids what the event would
  /// have applied (e.g. the tentative reservation).
  Future<void> respond(String eventId, {required bool accept});

  /// Per-validator audit trail for [eventIds], grouped by event id
  /// (#130). Batched so the events screen loads one query per feed.
  Future<Map<String, List<EventDecision>>> fetchDecisions(
    String workspaceId,
    List<String> eventIds,
  );

  /// One event by id, whatever its age (#841). [fetchEvents] returns the
  /// newest hundred, so a document older than that could never show who
  /// released it; this reads the governing event directly.
  Future<WorkspaceEvent?> fetchEvent(String eventId);

  Future<List<ValidationPolicy>> fetchValidationPolicies(String workspaceId);

  /// Request cancelling the outstanding remainder of a partially paid
  /// invoice (0100, #504); returns the pending event id.
  Future<String> requestInvoiceWriteoff(
    String invoiceId, {
    String reason = '',
  });

  /// Request the validated DELETION of a past or checked-in booking
  /// (0097, #492); returns the pending event id.
  Future<String> requestReservationDeletion(
    String reservationId, {
    String reason = '',
  });

  /// #881 — an authorised admin asks to change [memberId]'s payment
  /// conditions (RPC `request_payment_terms_change`, 0154): a pending
  /// 'payment_terms_change' event validators decide; the override is
  /// written on confirm. An empty [terms] asks to inherit again.
  Future<String> requestPaymentTermsChange(
    String memberId, {
    required PaymentTerms terms,
    String reason = '',
  });

  /// Request [halfDays] extra half-days for [period] ('YYYY-MM') beyond
  /// the subscription entitlement (0031). Lands as a pending 'quota'
  /// event that owners/admins validate per policy; returns the event id.
  Future<String> requestQuotaExtension(
    String workspaceId, {
    required String period,
    required int halfDays,
  });

  /// Insert-or-update on (workspace_id, event_type) — owner-only per RLS.
  Future<void> upsertValidationPolicy(ValidationPolicy policy);
}
