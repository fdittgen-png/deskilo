// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';

/// #2569 — the premises lease the space holds as tenant (`premises_leases`,
/// 0474). The server owns every rule; these are the shapes it answers with
/// and the commands it takes.

/// The permission that records the lease, its terms and its termination.
const leaseManagePermission = 'manageLease';

enum LeaseStatus {
  draft('draft'),
  active('active'),
  noticeGiven('notice_given'),
  ended('ended');

  const LeaseStatus(this.wire);

  final String wire;

  static LeaseStatus of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => draft);
}

enum LeaseTermKind {
  rent('rent'),
  serviceChargeAdvance('service_charge_advance'),
  other('other');

  const LeaseTermKind(this.wire);

  final String wire;

  static LeaseTermKind of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => rent);
}

/// One amount from a date. History: never edited, superseded by the next.
class LeaseTerm {
  const LeaseTerm({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.effectiveFrom,
    this.label = '',
    this.everyMonths = 1,
    this.effectiveTo,
    this.occurrencesDone = 0,
  });

  factory LeaseTerm.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'lease term');
    return LeaseTerm(
      id: r.string('id'),
      kind: LeaseTermKind.of(r.stringOrNull('kind')),
      label: r.stringOr('label'),
      amountCents: r.integer('amount_cents'),
      everyMonths: r.intOrNull('every_months') ?? 1,
      effectiveFrom: DateTime.parse(r.string('effective_from')),
      effectiveTo: DateTime.tryParse(r.stringOr('effective_to')),
      occurrencesDone: r.intOrNull('occurrences_done') ?? 0,
    );
  }

  final String id;
  final LeaseTermKind kind;
  final String label;
  final int amountCents;
  final int everyMonths;
  final DateTime effectiveFrom;

  /// Null while the term is the one in force.
  final DateTime? effectiveTo;
  final int occurrencesDone;

  bool get inForce => effectiveTo == null;
}

class PremisesLease {
  const PremisesLease({
    required this.id,
    required this.revision,
    required this.supplierId,
    required this.supplierName,
    required this.premises,
    required this.startsOn,
    required this.status,
    this.coveredLevels = '',
    this.areaM2,
    this.fixedUntil,
    this.noticeMonths = 0,
    this.noticeDeadline,
    this.indexationNote = '',
    this.depositCents = 0,
    this.noticeGivenOn,
    this.effectiveEnd,
    this.terminationReason = '',
    this.depositDueBackCents = 0,
    this.occurrencesAfterEnd = 0,
    this.terms = const [],
  });

  factory PremisesLease.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'premises lease');
    return PremisesLease(
      id: r.string('id'),
      revision: r.integer('revision'),
      supplierId: r.string('supplier_id'),
      supplierName: r.stringOr('supplier_name'),
      premises: r.stringOr('premises'),
      coveredLevels: r.stringOr('covered_levels'),
      areaM2: r.doubleOrNull('area_m2'),
      startsOn: DateTime.parse(r.string('starts_on')),
      fixedUntil: DateTime.tryParse(r.stringOr('fixed_until')),
      noticeMonths: r.intOrNull('notice_months') ?? 0,
      noticeDeadline: DateTime.tryParse(r.stringOr('notice_deadline')),
      indexationNote: r.stringOr('indexation_note'),
      depositCents: r.intOrNull('deposit_cents') ?? 0,
      status: LeaseStatus.of(r.stringOrNull('status')),
      noticeGivenOn: DateTime.tryParse(r.stringOr('notice_given_on')),
      effectiveEnd: DateTime.tryParse(r.stringOr('effective_end')),
      terminationReason: r.stringOr('termination_reason'),
      depositDueBackCents: r.intOrNull('deposit_due_back_cents') ?? 0,
      occurrencesAfterEnd: r.intOrNull('occurrences_after_end') ?? 0,
      terms: [for (final t in r.list('terms')) LeaseTerm.fromJson(t)],
    );
  }

  final String id;
  final int revision;
  final String supplierId;
  final String supplierName;
  final String premises;
  final String coveredLevels;
  final double? areaM2;
  final DateTime startsOn;
  final DateTime? fixedUntil;
  final int noticeMonths;

  /// The last day notice can be given for the fixed term to end, or null.
  final DateTime? noticeDeadline;
  final String indexationNote;
  final int depositCents;
  final LeaseStatus status;
  final DateTime? noticeGivenOn;
  final DateTime? effectiveEnd;
  final String terminationReason;

  /// What the lessor owes back once the lease is ending.
  final int depositDueBackCents;

  /// Occurrences already presented for a date after the end.
  final int occurrencesAfterEnd;
  final List<LeaseTerm> terms;

  bool get terminated =>
      status == LeaseStatus.noticeGiven || status == LeaseStatus.ended;
}

/// A lease to create (no [leaseId]) or amend.
class LeaseDraft {
  const LeaseDraft({
    required this.supplierId,
    required this.premises,
    required this.startsOn,
    required this.requestId,
    this.leaseId,
    this.revision = 0,
    this.fixedUntil,
    this.noticeMonths = 0,
    this.depositCents = 0,
    this.indexationNote = '',
    this.areaM2,
    this.coveredLevels = '',
  });

  final String? leaseId;
  final int revision;
  final String supplierId;
  final String premises;
  final DateTime startsOn;
  final DateTime? fixedUntil;
  final int noticeMonths;
  final int depositCents;
  final String indexationNote;
  final double? areaM2;
  final String coveredLevels;
  final String requestId;

  Map<String, Object?> toPayload() => {
    'supplier_id': supplierId,
    'premises': premises,
    'starts_on': isoDay(startsOn),
    'fixed_until': fixedUntil == null ? null : isoDay(fixedUntil!),
    'notice_months': noticeMonths,
    'deposit_cents': depositCents,
    'indexation_note': indexationNote,
    'area_m2': areaM2,
    'covered_levels': coveredLevels,
  };
}

class LeaseTermCommand {
  const LeaseTermCommand({
    required this.leaseId,
    required this.revision,
    required this.kind,
    required this.amountCents,
    required this.effectiveFrom,
    required this.requestId,
    this.label = '',
    this.everyMonths = 1,
  });

  final String leaseId;
  final int revision;
  final LeaseTermKind kind;
  final String label;
  final int amountCents;
  final int everyMonths;
  final DateTime effectiveFrom;
  final String requestId;
}

class LeaseNoticeCommand {
  const LeaseNoticeCommand({
    required this.leaseId,
    required this.revision,
    required this.givenOn,
    required this.effectiveEnd,
    required this.reason,
    required this.requestId,
  });

  final String leaseId;
  final int revision;
  final DateTime givenOn;
  final DateTime effectiveEnd;
  final String reason;
  final String requestId;
}

/// The leases of one space; every write goes through an RPC.
abstract class PremisesLeaseRepository {
  Future<List<PremisesLease>> fetchLeases(String workspaceId);

  /// Creates or amends a lease; returns it as the server now has it.
  Future<PremisesLease> saveLease(String workspaceId, LeaseDraft draft);

  /// Adds a term, superseding the one in force of the same kind.
  Future<PremisesLease> addTerm(String workspaceId, LeaseTermCommand command);

  /// Records notice: who, when, why, and the day the lease ends.
  Future<PremisesLease> giveNotice(
    String workspaceId,
    LeaseNoticeCommand command,
  );
}
