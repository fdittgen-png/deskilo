// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/premises_lease.dart';

/// #2569 — the lease in memory, with the server's rules that the screen
/// shows: a term supersedes the one in force of its kind the day before it
/// starts, a notice closes every open term, a terminated lease takes nothing
/// more, and the same request answers the same lease.
class FakePremisesLeaseRepository implements PremisesLeaseRepository {
  FakePremisesLeaseRepository([Iterable<PremisesLease> leases = const []])
    : leases = [...leases];

  final List<PremisesLease> leases;
  final Map<String, PremisesLease> _answers = {};
  var _next = 1;

  int _find(String id) {
    final i = leases.indexWhere((l) => l.id == id);
    if (i < 0) throw StateError('unknown lease');
    return i;
  }

  PremisesLease _current(String id, int revision) {
    final l = leases[_find(id)];
    if (l.revision != revision) throw StateError('stale revision');
    return l;
  }

  PremisesLease _put(PremisesLease next, String requestId) {
    leases[_find(next.id)] = next;
    return _answers[requestId] = next;
  }

  PremisesLease _copy(
    PremisesLease l, {
    LeaseStatus? status,
    List<LeaseTerm>? terms,
    DateTime? noticeGivenOn,
    DateTime? effectiveEnd,
    String? reason,
  }) => PremisesLease(
    id: l.id,
    revision: l.revision + 1,
    supplierId: l.supplierId,
    supplierName: l.supplierName,
    premises: l.premises,
    coveredLevels: l.coveredLevels,
    areaM2: l.areaM2,
    startsOn: l.startsOn,
    fixedUntil: l.fixedUntil,
    noticeMonths: l.noticeMonths,
    noticeDeadline: l.noticeDeadline,
    indexationNote: l.indexationNote,
    depositCents: l.depositCents,
    status: status ?? l.status,
    noticeGivenOn: noticeGivenOn ?? l.noticeGivenOn,
    effectiveEnd: effectiveEnd ?? l.effectiveEnd,
    terminationReason: reason ?? l.terminationReason,
    depositDueBackCents: status == LeaseStatus.noticeGiven
        ? l.depositCents
        : l.depositDueBackCents,
    terms: terms ?? l.terms,
  );

  @override
  Future<List<PremisesLease>> fetchLeases(String workspaceId) async => [
    ...leases,
  ];

  @override
  Future<PremisesLease> saveLease(String workspaceId, LeaseDraft draft) async {
    final replay = _answers[draft.requestId];
    if (replay != null) return replay;
    final id = draft.leaseId;
    if (id == null) {
      final deadline = draft.fixedUntil == null
          ? null
          : DateTime(
              draft.fixedUntil!.year,
              draft.fixedUntil!.month - draft.noticeMonths,
              draft.fixedUntil!.day,
            );
      final lease = PremisesLease(
        id: 'demo-lease-${_next++}',
        revision: 1,
        supplierId: draft.supplierId,
        supplierName: draft.supplierId,
        premises: draft.premises,
        coveredLevels: draft.coveredLevels,
        areaM2: draft.areaM2,
        startsOn: draft.startsOn,
        fixedUntil: draft.fixedUntil,
        noticeMonths: draft.noticeMonths,
        noticeDeadline: deadline,
        indexationNote: draft.indexationNote,
        depositCents: draft.depositCents,
        status: LeaseStatus.draft,
      );
      leases.insert(0, lease);
      return _answers[draft.requestId] = lease;
    }
    final l = _current(id, draft.revision);
    if (l.terminated) throw StateError('a terminated lease is not edited');
    return _put(_copy(l), draft.requestId);
  }

  @override
  Future<PremisesLease> addTerm(
    String workspaceId,
    LeaseTermCommand command,
  ) async {
    final replay = _answers[command.requestId];
    if (replay != null) return replay;
    final l = _current(command.leaseId, command.revision);
    if (l.terminated) throw StateError('a terminated lease takes no term');
    if (command.effectiveFrom.isBefore(l.startsOn)) {
      throw StateError('a term cannot start before the lease');
    }
    final terms = <LeaseTerm>[];
    for (final t in l.terms) {
      final sameCharge = t.kind == command.kind && t.label == command.label;
      if (sameCharge && t.inForce) {
        if (!command.effectiveFrom.isAfter(t.effectiveFrom)) {
          throw StateError('a new term starts after the one in force');
        }
        terms.add(
          LeaseTerm(
            id: t.id,
            kind: t.kind,
            label: t.label,
            amountCents: t.amountCents,
            everyMonths: t.everyMonths,
            effectiveFrom: t.effectiveFrom,
            effectiveTo: command.effectiveFrom.subtract(
              const Duration(days: 1),
            ),
          ),
        );
      } else {
        terms.add(t);
      }
    }
    terms.add(
      LeaseTerm(
        id: 'demo-term-${_next++}',
        kind: command.kind,
        label: command.label,
        amountCents: command.amountCents,
        everyMonths: command.everyMonths,
        effectiveFrom: command.effectiveFrom,
      ),
    );
    return _put(
      _copy(l, status: LeaseStatus.active, terms: terms),
      command.requestId,
    );
  }

  @override
  Future<PremisesLease> giveNotice(
    String workspaceId,
    LeaseNoticeCommand command,
  ) async {
    final replay = _answers[command.requestId];
    if (replay != null) return replay;
    final l = _current(command.leaseId, command.revision);
    if (l.status != LeaseStatus.active) {
      throw StateError('only an active lease is terminated');
    }
    final terms = [
      for (final t in l.terms)
        LeaseTerm(
          id: t.id,
          kind: t.kind,
          label: t.label,
          amountCents: t.amountCents,
          everyMonths: t.everyMonths,
          effectiveFrom: t.effectiveFrom,
          effectiveTo: t.effectiveTo ?? command.effectiveEnd,
          occurrencesDone: t.occurrencesDone,
        ),
    ];
    return _put(
      _copy(
        l,
        status: LeaseStatus.noticeGiven,
        terms: terms,
        noticeGivenOn: command.givenOn,
        effectiveEnd: command.effectiveEnd,
        reason: command.reason,
      ),
      command.requestId,
    );
  }
}
