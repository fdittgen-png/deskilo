// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2569 — the premises lease the demo space holds as tenant: the nine-year
// commercial lease of the premises in Pézenas, its rent and its service
// charge advance. The rent matches the scheduled expense of the demo year.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/lease_commitment.dart';
import '../../../features/money/domain/premises_lease.dart';
import '../data/lease_commitment_repository.dart';
import '../data/premises_lease_repository.dart';
import 'demo_room_seed.dart';

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
          amountCents: demoServiceChargeCents,
          effectiveFrom: starts,
          occurrencesDone: months,
        ),
      ],
    ),
  ]);
}

/// What the demo lease and the rented studio expect, one occurrence a month
/// per term from its start to this month, each generated from its schedule:
///
///   * the rent: the older months matched by the lessor's bills, this month
///     still expected. Last month's bill already carries the July indexation
///     the lease does not state yet: the occurrence is matched in full and
///     the 30.00 left on the bill line is a difference waiting to be
///     accepted;
///   * the service charge advance (#3794): the second line of the same
///     bills, matched in full, this month still expected;
///   * the studio rented from January (demo_room_seed.dart): matched by the
///     bills of its lessor, this month still expected.
FakeLeaseCommitmentRepository seedDemoCommitments(DateTime now) {
  final starts = DateTime(now.year - 1, 7);
  final months = (now.year - starts.year) * 12 + now.month - starts.month + 1;
  final lease = <CommitmentOccurrence>[];
  for (var k = months - 1; k >= 0; k--) {
    final due = DateTime(starts.year, starts.month + k);
    final matched = k < months - 1;
    final indexed = k == months - 2;
    final reference = 'LOY-${yearMonth(due.year, due.month)}';
    lease
      ..add(
        _occurrence('demo-occ-$k', due, 222000, 'demo-term-rent', [
          if (matched)
            CommitmentMatch(
              id: 'demo-match-seed-$k',
              purchaseId: 'demo-bill-rent-$k',
              lineNo: 1,
              allocatedCents: 222000,
              reference: reference,
              lineGrossCents: indexed ? 225000 : 222000,
              lineUnallocatedCents: indexed ? 3000 : 0,
            ),
        ]),
      )
      ..add(
        _occurrence(
          'demo-occ-charges-$k',
          due,
          demoServiceChargeCents,
          'demo-term-charges',
          [
            if (matched)
              CommitmentMatch(
                id: 'demo-match-charges-$k',
                purchaseId: 'demo-bill-rent-$k',
                lineNo: 2,
                allocatedCents: demoServiceChargeCents,
                reference: reference,
                lineGrossCents: demoServiceChargeCents,
              ),
          ],
        ),
      );
  }
  final studio = demoStudioOccurrences(now);
  return FakeLeaseCommitmentRepository(
    {'demo-lease-premises': lease, demoStudioRentalId: studio},
    {
      for (final o in lease) o.id: o.termId!,
      for (final o in studio) o.id: demoStudioRentalId,
    },
  );
}

/// The service charge advance of the demo lease, a month.
const demoServiceChargeCents = 15000;

CommitmentOccurrence _occurrence(
  String id,
  DateTime due,
  int cents,
  String? term,
  List<CommitmentMatch> matches,
) => CommitmentOccurrence(
  id: id,
  dueOn: due,
  expectedCents: cents,
  matchedCents: matches.fold(0, (s, m) => s + m.allocatedCents),
  termId: term,
  matches: matches,
);

/// The studio's occurrences (#3794): one a month from January, the months
/// before this one matched by the bill of the same month
/// (demo_purchase_history_seed.dart), this month still expected.
List<CommitmentOccurrence> demoStudioOccurrences(DateTime now) => [
  for (var month = now.month; month >= 1; month--)
    _occurrence(
      'demo-occ-studio-$month',
      DateTime(now.year, month),
      demoStudioRentCents,
      null,
      [
        if (month < now.month)
          CommitmentMatch(
            id: 'demo-match-studio-$month',
            purchaseId: 'demo-bill-studio-$month',
            lineNo: 1,
            allocatedCents: demoStudioRentCents,
            reference: 'IM-${yearMonth(now.year, month)}',
            lineGrossCents: demoStudioRentCents,
          ),
      ],
    ),
];
