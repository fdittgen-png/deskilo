// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2569 — the premises lease the demo space holds as tenant: the nine-year
// commercial lease of the premises in Pézenas, its rent and its service
// charge advance. The rent matches the scheduled expense of the demo year.
import '../../../features/money/domain/lease_commitment.dart';
import '../../../features/money/domain/premises_lease.dart';
import '../../time/date_text.dart';
import '../data/lease_commitment_repository.dart';
import '../data/premises_lease_repository.dart';

FakePremisesLeaseRepository seedDemoLease(DateTime now) {
  final starts = DateTime(now.year - 1, 7);
  final months = (now.year - starts.year) * 12 + now.month - starts.month + 1;
  return FakePremisesLeaseRepository([
    PremisesLease(
      id: 'demo-lease-premises',
      revision: 3,
      supplierId: 'demo-supplier-landlord',
      supplierName: 'SCI Les Remparts',
      premises: '4 rue de la Foire, 34120 Pézenas',
      coveredLevels: 'Ground floor and first floor',
      areaM2: 142.5,
      startsOn: starts,
      fixedUntil: DateTime(starts.year + 9, 6, 30),
      noticeMonths: 6,
      noticeDeadline: DateTime(starts.year + 8, 12, 31),
      indexationNote: 'ILC, each 1 July',
      depositCents: 444000,
      status: LeaseStatus.active,
      terms: [
        LeaseTerm(
          id: 'demo-term-rent',
          kind: LeaseTermKind.rent,
          amountCents: 222000,
          effectiveFrom: starts,
          occurrencesDone: months,
        ),
        LeaseTerm(
          id: 'demo-term-charges',
          kind: LeaseTermKind.serviceChargeAdvance,
          amountCents: 15000,
          effectiveFrom: starts,
          occurrencesDone: months,
        ),
      ],
    ),
  ]);
}

/// The rent the demo lease expects, one occurrence a month from its start to
/// this month: the older months matched by the lessor's bills, this month
/// still expected.
FakeLeaseCommitmentRepository seedDemoCommitments(DateTime now) {
  final starts = DateTime(now.year - 1, 7);
  final months = (now.year - starts.year) * 12 + now.month - starts.month + 1;
  final out = <CommitmentOccurrence>[];
  for (var k = months - 1; k >= 0; k--) {
    final due = DateTime(starts.year, starts.month + k);
    final matched = k < months - 1;
    out.add(
      CommitmentOccurrence(
        id: 'demo-occ-$k',
        dueOn: due,
        expectedCents: 222000,
        matchedCents: matched ? 222000 : 0,
        matches: [
          if (matched)
            CommitmentMatch(
              id: 'demo-match-seed-$k',
              purchaseId: 'demo-bill-rent-$k',
              lineNo: 1,
              allocatedCents: 222000,
              reference:
                  'LOY-${yearMonth(due.year, due.month)}',
              lineGrossCents: 222000,
            ),
        ],
      ),
    );
  }
  return FakeLeaseCommitmentRepository({'demo-lease-premises': out});
}
