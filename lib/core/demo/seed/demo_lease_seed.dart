// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2569 — the premises lease the demo space holds as tenant: the nine-year
// commercial lease of the premises in Pézenas, its rent and its service
// charge advance. The rent matches the scheduled expense of the demo year.
import '../../../features/money/domain/premises_lease.dart';
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
