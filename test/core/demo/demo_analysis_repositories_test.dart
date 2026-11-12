// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3785 — the Demo's own computations of the analyses it used to answer
// "no server in this mode", each on a small hand-made space with the
// expected figures written out, by the rule of the server function it
// follows (`kpi_costs_summary` 0532, `kpi_cost_allocation` 0531,
// `kpi_memberships_current` / `kpi_overdue_receivables` 0536,
// `kpi_pending_actions_current` 0598).
import 'package:deskilo/core/demo/data/asset_valuation_repository.dart';
import 'package:deskilo/core/demo/data/demo_contract_schedules.dart';
import 'package:deskilo/core/demo/data/demo_cost_allocation_repository.dart';
import 'package:deskilo/core/demo/data/demo_cost_kpi_repository.dart';
import 'package:deskilo/core/demo/data/demo_overview_kpi_repository.dart';
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/lease_commitment_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/premises_lease_repository.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/room_rental_repository.dart';
import 'package:deskilo/core/demo/data/workspace_asset_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/asset_valuation.dart';
import 'package:deskilo/features/money/domain/lease_commitment.dart';
import 'package:deskilo/features/money/domain/premises_lease.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/room_rental.dart';
import 'package:deskilo/features/money/domain/workspace_asset.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/workspace/domain/cost_allocation.dart';
import 'package:deskilo/features/workspace/domain/cost_allocation_rules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_overview.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = 'ws-1';
final _now = DateTime(2026, 5, 13, 10);

PurchaseDetail _doc(
  String id, {
  required DateTime received,
  required List<PurchaseLine> lines,
  DateTime? dated,
  PurchaseKind kind = PurchaseKind.bill,
  PurchaseState state = PurchaseState.approved,
  String currency = 'EUR',
  String category = 'Cleaning',
}) => PurchaseDetail(
  summary: PurchaseSummary(
    id: id,
    kind: kind,
    state: state,
    category: category,
    reference: id,
    currency: currency,
    receivedOn: received,
    originalDate: dated,
  ),
  revision: 1,
  lines: lines,
  sources: const [],
);

PurchaseLine _line(
  int no,
  String kind, {
  required int gross,
  int? net,
  int? tax,
  int? recoverable,
}) => PurchaseLine(
  lineNo: no,
  description: kind,
  grossCents: gross,
  netCents: net,
  taxCents: tax,
  recoverableTaxCents: recoverable,
  recognitionKind: kind,
);

Invoice _invoice(
  String id, {
  required int total,
  String? period = '2026-04',
  int? net,
  InvoiceKind kind = InvoiceKind.full,
  DateTime? voidedAt,
  DateTime? dueOn,
  String currency = 'EUR',
  String? replaces,
  String? settledBy,
}) => Invoice(
  id: id,
  workspaceId: _ws,
  memberId: 'member-2',
  number: 'INV-$id',
  issuedAt: DateTime(2026, 4, 2),
  period: period,
  title: id,
  lines: const [],
  totalCents: total,
  currency: currency,
  memberName: 'Ana Martin',
  memberAddress: '',
  workspaceName: 'Test Space',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
  voidedAt: voidedAt,
  kind: kind,
  dueOn: dueOn,
  replacesInvoiceId: replaces,
  settledByInvoiceId: settledBy,
  vatTotals: [
    if (net != null)
      InvoiceVatTotal(
        percent: 20,
        category: 'S',
        grossCents: total,
        netCents: net,
        vatCents: total - net,
      ),
  ],
);

/// April: two operating lines (one with its recoverable share qualified, one
/// without), a capitalised and a not capitalised asset line, an unresolved
/// line, a supplier credit note dated in April that arrived in May, a
/// pending bill and a March bill.
FakePurchaseRepository _purchases() => FakePurchaseRepository()
  ..add(
    _doc(
      'bill-a',
      received: DateTime(2026, 4, 10),
      lines: [
        _line(
          1,
          'operating',
          gross: 12000,
          net: 10000,
          tax: 2000,
          recoverable: 2000,
        ),
        _line(2, 'operating', gross: 6000, net: 5000, tax: 1000),
        _line(
          3,
          'asset',
          gross: 60000,
          net: 50000,
          tax: 10000,
          recoverable: 10000,
        ),
        _line(4, 'unresolved', gross: 999),
        _line(5, 'asset', gross: 2400, net: 2000, tax: 400, recoverable: 400),
      ],
    ),
  )
  ..add(
    _doc(
      'credit-b',
      kind: PurchaseKind.creditNote,
      received: DateTime(2026, 5, 2),
      dated: DateTime(2026, 4, 20),
      lines: [_line(1, 'operating', gross: 1200)],
    ),
  )
  ..add(
    _doc(
      'bill-c',
      state: PurchaseState.pending,
      received: DateTime(2026, 4, 12),
      lines: [_line(1, 'operating', gross: 7000)],
    ),
  )
  ..add(
    _doc(
      'bill-d',
      received: DateTime(2026, 3, 30),
      lines: [_line(1, 'operating', gross: 3000)],
    ),
  )
  ..payables.add(
    PayableRow(
      obligation: const PurchaseObligation(
        id: 'ob-a',
        purchaseId: 'bill-a',
        creditorKind: CreditorKind.supplier,
        creditorId: 'supplier-1',
        amountCents: 9000,
        currency: 'EUR',
        appliedCents: 0,
        remainingCents: 9000,
      ),
      purchase: PurchaseSummary(
        id: 'bill-a',
        kind: PurchaseKind.bill,
        state: PurchaseState.approved,
        category: 'Cleaning',
        reference: 'bill-a',
        currency: 'EUR',
        receivedOn: DateTime(2026, 4, 10),
      ),
    ),
  );

List<Invoice> _invoices() => [
  _invoice('i1', total: 24000, net: 20000),
  _invoice('i2', total: 5000, kind: InvoiceKind.settlement),
  _invoice('i3', total: 7000, voidedAt: DateTime(2026, 4, 3)),
  _invoice('i4', total: -1200, net: -1000),
  _invoice('i5', total: 3000, period: null),
  _invoice('i6', total: 800, period: '2026-05'),
];

/// The lease the occurrences come from: the rent, generated for April and
/// May, and a service charge advance of 150.00 a month nothing generated.
FakePremisesLeaseRepository _lease({
  DateTime? chargesUntil,
  LeaseStatus status = LeaseStatus.active,
}) => FakePremisesLeaseRepository([
  PremisesLease(
    id: 'lease-1',
    revision: 1,
    supplierId: 'landlord',
    supplierName: 'Landlord',
    premises: 'Premises',
    startsOn: DateTime(2026, 4),
    status: status,
    terms: [
      LeaseTerm(
        id: 'term-rent',
        kind: LeaseTermKind.rent,
        amountCents: 222000,
        effectiveFrom: DateTime(2026, 4),
      ),
      LeaseTerm(
        id: 'term-charges',
        kind: LeaseTermKind.serviceChargeAdvance,
        amountCents: 15000,
        effectiveFrom: DateTime(2026, 4),
        effectiveTo: chargesUntil,
      ),
    ],
  ),
]);

DemoCostKpiRepository _costs({
  FakePurchaseRepository? purchases,
  Set<WorkspaceFeature>? features,
  List<ValuationBatch>? batches,
}) => DemoCostKpiRepository(
  sources: (
    purchases: purchases ?? _purchases(),
    invoices: _invoices,
    assets: FakeWorkspaceAssetRepository(
      assets: const [
        WorkspaceAsset(
          id: 'asset-1',
          revision: 2,
          assetNumber: 1,
          description: 'Printer',
          currency: 'EUR',
          decision: AssetDecision.capitalise,
          state: AssetState.inUse,
          purchaseId: 'bill-a',
          lineNo: 3,
        ),
        WorkspaceAsset(
          id: 'asset-2',
          revision: 2,
          assetNumber: 2,
          description: 'Ladder',
          currency: 'EUR',
          decision: AssetDecision.expense,
          state: AssetState.expensed,
          purchaseId: 'bill-a',
          lineNo: 5,
        ),
      ],
    ),
    valuations: FakeAssetValuationRepository(
      batches:
          batches ??
          [
            ValuationBatch(
              id: 'april',
              revision: 1,
              basis: ValuationBasis.book,
              sourceSystem: 'Cabinet',
              periodFrom: DateTime(2026, 4),
              periodTo: DateTime(2026, 4, 30),
              currency: 'EUR',
              movements: 'period',
              completeScope: true,
              status: ValuationStatus.confirmed,
            ),
          ],
      rows: const {
        'april': [
          ValuationRow(
            assetId: 'asset-1',
            assetNumber: 1,
            description: 'Printer',
            openingMinor: 50000,
            additionsMinor: 0,
            disposalsMinor: 0,
            depreciationMinor: 2500,
            impairmentMinor: 0,
            closingMinor: 47500,
            bridge: ValuationBridge.ok,
          ),
        ],
      },
    ),
    commitments: FakeLeaseCommitmentRepository(
      {
        'lease-1': [
          CommitmentOccurrence(
            id: 'occ-apr',
            dueOn: DateTime(2026, 4),
            expectedCents: 222000,
            matchedCents: 222000,
          ),
          CommitmentOccurrence(
            id: 'occ-may',
            dueOn: DateTime(2026, 5),
            expectedCents: 222000,
            matchedCents: 2000,
          ),
        ],
      },
      {'occ-apr': 'term-rent', 'occ-may': 'term-rent'},
    ),
    leases: _lease(),
    rooms: FakeRoomRentalRepository(),
  ),
  currencyOf: (_) => 'EUR',
  features: () =>
      features ??
      {WorkspaceFeature.assetRegister, WorkspaceFeature.premisesLease},
  now: _now,
);

void main() {
  group('the cost figures (kpi_costs_summary, 0532)', () {
    test('April: each figure by its rule', () async {
      final k = await _costs().summary(
        _ws,
        fromMonth: '2026-04',
        toMonth: '2026-04',
      );
      expect(k.currency, 'EUR');
      // 10000 (net, its tax recovered) + 6000 (net + tax, share not
      // qualified) - 1200 (the credit note, dated April).
      expect(k.operatingCostsMinor, 14800);
      expect(k.unqualifiedLines, 1);
      expect(k.unresolvedLines, 1);
      // The capitalised printer only, at net: the ladder was expensed.
      expect(k.acquisitionsMinor, 50000);
      // 20000 (i1's net) - 1000 (i4's net); settlement, voided, undated and
      // May invoices left out.
      expect(k.netSalesMinor, 19000);
      expect(k.contributionMinor, 4200);
      expect(k.bookDepreciationMinor, 2500);
      expect(k.afterDepreciationMinor, 1700);
      // April's rent occurrence is matched in full; the service charge
      // advance, never generated, is projected from its first day.
      expect(k.unbilledMinor, 15000);
      expect(k.forecastMinor, 24000);
      expect(k.quality, isEmpty);
      expect(k.reasons, ['tax_unqualified', 'unresolved_lines']);
    });

    test('May: the rent occurrence and the service charge still expected, '
        'overdue since the 1st; June projected from both terms', () async {
      final may = await _costs().summary(
        _ws,
        fromMonth: '2026-05',
        toMonth: '2026-05',
      );
      // 222000 - 2000 matched + 15000 (the charges, projected).
      expect(may.unbilledMinor, 235000);
      expect(may.unbilledOverdueMinor, 235000);
      expect(may.unbilledUpcomingMinor, 0);
      expect(may.forecastMinor, 244000);
      // The May confirmed batch is missing: unknown, never 0.
      expect(may.bookDepreciationMinor, isNull);
      expect(may.afterDepreciationMinor, isNull);
      expect(may.quality, {KpiQuality.partial});
      expect(may.reasons, contains('book_coverage_incomplete'));
      final june = await _costs().summary(
        _ws,
        fromMonth: '2026-06',
        toMonth: '2026-06',
      );
      // The rent's next due day follows its last occurrence (May).
      expect(june.unbilledMinor, 237000);
      expect(june.unbilledUpcomingMinor, 237000);
    });

    test('a batch that does not tile the months leaves the depreciation '
        'unknown', () async {
      final k = await _costs().summary(
        _ws,
        fromMonth: '2026-04',
        toMonth: '2026-05',
      );
      expect(k.bookDepreciationMinor, isNull);
    });

    test('the register and the contracts off: their figures unknown', () async {
      final k = await _costs(features: {})
          .summary(_ws, fromMonth: '2026-04', toMonth: '2026-04');
      expect(k.acquisitionsMinor, isNull);
      expect(k.bookDepreciationMinor, isNull);
      expect(k.unbilledMinor, isNull);
      expect(k.forecastMinor, isNull);
      expect(k.operatingCostsMinor, 14800);
      expect(k.reasons, containsAll(['asset_register_off', 'no_contracts']));
    });

    test('an operating line in another currency is never added', () async {
      final purchases = _purchases()
        ..add(
          _doc(
            'bill-chf',
            currency: 'CHF',
            received: DateTime(2026, 4, 15),
            lines: [_line(1, 'operating', gross: 4800)],
          ),
        );
      final k = await _costs(purchases: purchases)
          .summary(_ws, fromMonth: '2026-04', toMonth: '2026-04');
      expect(k.quality, contains(KpiQuality.unavailable));
      expect(k.reasons, contains('currency_mix'));
    });
  });

  group('the contract schedules (0474, 0515, 0532)', () {
    DemoUnbilled june(
      List<DemoContractSchedule> schedules,
      FakeLeaseCommitmentRepository commitments,
    ) => demoUnbilled(
      schedules: schedules,
      commitments: commitments,
      start: DateTime(2026, 6),
      cut: DateTime(2026, 6, 30),
      today: _now,
    );

    List<DemoContractSchedule> of(
      FakePremisesLeaseRepository leases, {
      FakeLeaseCommitmentRepository? commitments,
      List<RoomRental> rentals = const [],
    }) => demoContractSchedules(
      leases: leases.leases,
      rentals: rentals,
      commitments: commitments ?? FakeLeaseCommitmentRepository(),
    );

    test('a term that ended expects nothing after its end', () {
      final ended = of(_lease(chargesUntil: DateTime(2026, 5, 31)));
      // The rent only: 222000 from April on, nothing generated.
      expect(june(ended, FakeLeaseCommitmentRepository()).total, 222000);
    });

    test('a lease given notice ends its terms on its end', () {
      final leases = _lease();
      leases.leases[0] = PremisesLease(
        id: 'lease-1',
        revision: 2,
        supplierId: 'landlord',
        supplierName: 'Landlord',
        premises: 'Premises',
        startsOn: DateTime(2026, 4),
        status: LeaseStatus.noticeGiven,
        effectiveEnd: DateTime(2026, 5, 31),
        terms: leases.leases[0].terms,
      );
      expect(june(of(leases), FakeLeaseCommitmentRepository()).total, 0);
    });

    test('a count that runs out stops the projection', () {
      final schedule = (
        id: 's',
        amountCents: 1000,
        unit: 'month',
        every: 1,
        nextDue: DateTime(2026, 5),
        done: 2,
        endsOn: null,
        repeatCount: 3,
        active: true,
      );
      final r = demoUnbilled(
        schedules: [schedule],
        commitments: FakeLeaseCommitmentRepository(),
        start: DateTime(2026, 5),
        cut: DateTime(2026, 7, 31),
        today: _now,
      );
      // May is the third and last occurrence; June and July are not.
      expect(r.total, 1000);
      expect(r.overdue, 1000);
    });

    test('a rejected occurrence expects nothing', () {
      final commitments = FakeLeaseCommitmentRepository(
        {
          'lease-1': [
            CommitmentOccurrence(
              id: 'occ-jun',
              dueOn: DateTime(2026, 6),
              expectedCents: 222000,
              matchedCents: 0,
            ),
          ],
        },
        {'occ-jun': 'term-rent'},
        {'occ-jun'},
      );
      final schedules = of(
        _lease(chargesUntil: DateTime(2026, 5, 31)),
        commitments: commitments,
      );
      // Generated for June, so not projected; rejected, so not expected.
      expect(june(schedules, commitments).total, 0);
    });

    test('a schedule on the 31st falls on the last day of a shorter month', () {
      expect(
        addScheduleInterval(DateTime(2026, 1, 31), 'month', 1),
        DateTime(2026, 2, 28),
      );
      expect(
        addScheduleInterval(DateTime(2028, 1, 31), 'month', 1),
        DateTime(2028, 2, 29),
      );
      expect(
        addScheduleInterval(DateTime(2026, 3, 31), 'year', 1),
        DateTime(2027, 3, 31),
      );
      final r = demoUnbilled(
        schedules: [
          (
            id: 's',
            amountCents: 500,
            unit: 'month',
            every: 1,
            nextDue: DateTime(2026, 1, 31),
            done: 0,
            endsOn: null,
            repeatCount: null,
            active: true,
          ),
        ],
        commitments: FakeLeaseCommitmentRepository(),
        start: DateTime(2026, 2),
        cut: DateTime(2026, 2, 28),
        today: _now,
      );
      // February's occurrence falls on the 28th, inside February.
      expect(r.total, 500);
    });

    test('a room rented at a fixed cost per month is a schedule', () {
      final schedules = of(
        FakePremisesLeaseRepository(),
        rentals: [
          RoomRental(
            id: 'rental-1',
            revision: 1,
            officeId: 'office-1',
            officeName: 'Studio',
            supplierId: 'lessor',
            supplierName: 'Lessor',
            availableFrom: DateTime(2026),
            availableUntil: DateTime(2026, 12, 31),
            status: RoomRentalStatus.active,
            costCents: 40000,
          ),
        ],
      );
      expect(june(schedules, FakeLeaseCommitmentRepository()).total, 40000);
    });
  });

  group('the cost allocation (kpi_cost_allocation, 0531)', () {
    FakeFloorPlanRepository plan() =>
        FakeFloorPlanRepository()
          ..levels.addAll(const [
            Level(id: 'level-a', workspaceId: _ws, name: 'A', sortOrder: 0),
            Level(id: 'level-b', workspaceId: _ws, name: 'B', sortOrder: 1),
            Level(id: 'level-c', workspaceId: _ws, name: 'C', sortOrder: 2),
          ]);

    DemoCostAllocationRepository repo() => DemoCostAllocationRepository(
      purchases: _purchases(),
      plan: plan(),
      currencyOf: (_) => 'EUR',
      now: _now,
    );

    Future<void> rule(
      DemoCostAllocationRepository r,
      List<AllocationWeight> weights, {
      String? line,
      String category = 'Cleaning',
      String id = 'request',
    }) => r.save(
      _ws,
      ruleId: null,
      expectedRevision: 0,
      draft: AllocationRuleDraft(
        category: line == null ? category : '',
        purchaseLineId: line,
        effectiveFrom: DateTime(2026),
        basis: 'floor area',
        weights: weights,
      ),
      requestId: id,
    );

    test('a category rule spreads April by largest remainder', () async {
      final r = repo();
      await rule(r, const [
        AllocationWeight(
          resourceKind: 'level',
          resourceId: 'level-a',
          weight: 2,
        ),
        AllocationWeight(
          resourceKind: 'level',
          resourceId: 'level-b',
          weight: 1,
        ),
      ]);
      final k = await r.summary(_ws, fromMonth: '2026-04', toMonth: '2026-04');
      // The April operating lines: 10000 + 6000 - 1200 = 14800, all
      // "Cleaning"; 2:1 gives 9866.67 / 4933.33, the extra cent to level A.
      expect(k.operatingCostsMinor, 14800);
      expect(k.sharedMinor, 14800);
      expect(k.directMinor, 0);
      expect(k.unallocatedMinor, 0);
      expect(
        {for (final x in k.resources) x.resourceId: x.allocatedMinor},
        {'level-a': 9867, 'level-b': 4933},
      );
      expect(k.resources.first.name, 'A');
      expect(k.rulesUsed, [('floor area', 1)]);
    });

    test('a line rule beats the category rule; two of the same reach '
        'conflict', () async {
      final r = repo();
      await rule(r, const [
        AllocationWeight(
          resourceKind: 'level',
          resourceId: 'level-b',
          weight: 1,
        ),
      ]);
      await rule(
        r,
        const [
          AllocationWeight(
            resourceKind: 'level',
            resourceId: 'level-c',
            weight: 1,
          ),
        ],
        line: DemoCostAllocationRepository.lineKey('bill-a', 1),
        id: 'line',
      );
      final k = await r.summary(_ws, fromMonth: '2026-04', toMonth: '2026-04');
      // Line 1 (10000) to level C; the rest (6000 - 1200) to level B.
      expect(k.directMinor, 14800);
      expect(
        {for (final x in k.resources) x.resourceId: x.allocatedMinor},
        {'level-c': 10000, 'level-b': 4800},
      );
      await rule(r, const [
        AllocationWeight(
          resourceKind: 'level',
          resourceId: 'level-a',
          weight: 1,
        ),
      ], id: 'second');
      final both = await r.summary(
        _ws,
        fromMonth: '2026-04',
        toMonth: '2026-04',
      );
      expect(both.conflictingLines, 2);
      expect(both.directMinor, 10000);
      expect(both.unallocatedMinor, 4800);
      expect(both.reasons, containsAll(['rule_conflict', 'unallocated']));
    });

    test('a resource whose shares net to zero is listed at 0', () async {
      final purchases = _purchases()
        ..add(
          _doc(
            'credit-s',
            kind: PurchaseKind.creditNote,
            category: 'Supplies',
            received: DateTime(2026, 4, 25),
            lines: [_line(1, 'operating', gross: 14800)],
          ),
        );
      final r = DemoCostAllocationRepository(
        purchases: purchases,
        plan: plan(),
        currencyOf: (_) => 'EUR',
        now: _now,
      );
      await rule(r, const [
        AllocationWeight(
          resourceKind: 'level',
          resourceId: 'level-a',
          weight: 1,
        ),
      ]);
      await rule(
        r,
        const [
          AllocationWeight(
            resourceKind: 'level',
            resourceId: 'level-a',
            weight: 1,
          ),
        ],
        category: 'Supplies',
        id: 'supplies',
      );
      final k = await r.summary(_ws, fromMonth: '2026-04', toMonth: '2026-04');
      // +14800 from "Cleaning", -14800 from the "Supplies" credit note.
      expect(k.operatingCostsMinor, 0);
      expect(
        {for (final x in k.resources) x.resourceId: x.allocatedMinor},
        {'level-a': 0},
      );
      expect(k.resources.single.revisions, hasLength(2));
    });

    test('no rule: nothing allocated, all of it unallocated', () async {
      final k = await repo().summary(
        _ws,
        fromMonth: '2026-04',
        toMonth: '2026-04',
      );
      expect(k.allocatedMinor, 0);
      expect(k.unallocatedMinor, 14800);
    });

    test('a resource the space does not have is refused', () async {
      expect(
        () => rule(repo(), const [
          AllocationWeight(
            resourceKind: 'desk',
            resourceId: 'nowhere',
            weight: 1,
          ),
        ]),
        throwsStateError,
      );
    });
  });

  group('the overview figures (0536, 0598)', () {
    Member member(String id, MemberStatus status, {String ws = _ws}) => Member(
      id: id,
      workspaceId: ws,
      userId: 'user-$id',
      isAdmin: false,
      isOwner: false,
      status: status,
    );

    WorkspaceEvent event(String id, EventStatus status, {String ws = _ws}) =>
        WorkspaceEvent(
          id: id,
          workspaceId: ws,
          type: EventType.expense,
          action: EventAction.submitted,
          actorMemberId: 'member-2',
          subjectMemberId: 'member-2',
          payload: const {},
          status: status,
          createdAt: DateTime(2026, 5),
        );

    DemoOverviewKpiRepository repo() {
      final workspaces = FakeWorkspaceRepository.withWorkspace()
        ..otherMembers.addAll([
          member('member-2', MemberStatus.active),
          member('member-3', MemberStatus.paused),
          member('member-4', MemberStatus.pending),
          member('member-5', MemberStatus.active, ws: 'ws-other'),
        ]);
      final events = FakeEventRepository()
        ..events.addAll([
          event('e1', EventStatus.pending),
          event('e2', EventStatus.pending),
          event('e3', EventStatus.confirmed),
          event('e4', EventStatus.pending, ws: 'ws-other'),
        ]);
      final money = FakeMoneyRepository()
        ..invoices.addAll([
          // Overdue since 30 April, 4000 paid: 6000 collectible.
          _invoice('o1', total: 10000, dueOn: DateTime(2026, 4, 30)),
          // Due today: the due day itself is overdue.
          _invoice('o2', total: 3000, dueOn: DateTime(2026, 5, 13)),
          // Not yet due.
          _invoice('o3', total: 5000, dueOn: DateTime(2026, 5, 20)),
          // Overdue but on hold: counted apart.
          _invoice('o4', total: 7000, dueOn: DateTime(2026, 4)),
          // No proven due date.
          _invoice('o5', total: 2000),
          // Overdue, half credited: 1000 left.
          _invoice('o6', total: 2000, dueOn: DateTime(2026, 4)),
          _invoice('c6', total: -1000, replaces: 'o6'),
          // Regrouped into a settlement: owed through it, never twice.
          _invoice('o7', total: 9000, dueOn: DateTime(2026, 4), settledBy: 's'),
          // A payment waiting for validation holds it.
          _invoice('o8', total: 4000, dueOn: DateTime(2026, 4)),
        ])
        ..invoiceMatchesStore['o1'] = InvoiceMatch(
          invoiceId: 'o1',
          paidCents: 4000,
          resolution: 'under',
          matchedAt: DateTime(2026, 5, 2),
        )
        ..invoiceMatchesStore['o8'] = InvoiceMatch(
          invoiceId: 'o8',
          paidCents: 4000,
          resolution: 'exact',
          status: 'pending',
          matchedAt: DateTime(2026, 5, 2),
        )
        ..dunningHolds['o4'] = 'dispute';
      return DemoOverviewKpiRepository(
        workspaces: workspaces,
        events: events,
        money: money,
        now: _now,
      );
    }

    Future<OverviewFigure> read(String id, {String month = '2026-05'}) =>
        repo().figure(_ws, id, fromMonth: month, toMonth: month);

    test('active memberships: the active ones of the space, the owner '
        'included', () async {
      final f = await read('people.active_memberships_current');
      // member-1 (the owner) and member-2.
      expect(f.value, 2);
      expect(f.quality, isEmpty);
    });

    test('pending actions: pending requests and pending joins', () async {
      final f = await read('operations.pending_actions_current');
      expect(f.value, 3);
    });

    test('overdue receivables by the dunning rules', () async {
      final f = await read('sales.overdue_receivables');
      // o1 6000 + o2 3000 + o6 1000.
      expect(f.value, 10000);
      expect(f.count, 3);
      expect(f.currency, 'EUR');
      expect(f.unknownDueCount, 1);
      // o4 (dispute) and o8 (a payment pending).
      expect(f.heldCount, 2);
    });

    test('another month reads today, said as such', () async {
      final f = await read(
        'people.active_memberships_current',
        month: '2026-03',
      );
      expect(f.value, 2);
      expect(f.quality, {KpiQuality.notRecorded});
      expect(f.reasons, ['current_state']);
    });

    Future<OverviewFigure> overdueOf(
      List<Invoice> invoices, {
      Map<String, InvoiceMatch> matches = const {},
    }) {
      final money = FakeMoneyRepository()..invoices.addAll(invoices);
      money.invoiceMatchesStore.addAll(matches);
      return DemoOverviewKpiRepository(
        workspaces: FakeWorkspaceRepository.withWorkspace(),
        events: FakeEventRepository(),
        money: money,
        now: _now,
      ).figure(
        _ws,
        'sales.overdue_receivables',
        fromMonth: '2026-05',
        toMonth: '2026-05',
      );
    }

    test('an overdue invoice in another currency leaves the amount unknown, '
        'never a sum', () async {
      final f = await overdueOf([
        _invoice('e1', total: 10000, dueOn: DateTime(2026, 4)),
        _invoice('u1', total: 5000, dueOn: DateTime(2026, 4), currency: 'USD'),
      ]);
      expect(f.value, isNull);
      expect(f.quality, {KpiQuality.unavailable});
      expect(f.reasons, ['currency_mix']);
    });

    test('a credit note in another currency holds its invoice', () async {
      final f = await overdueOf([
        _invoice('h1', total: 10000, dueOn: DateTime(2026, 4)),
        _invoice('h1c', total: -2000, replaces: 'h1', currency: 'USD'),
      ]);
      expect(f.value, 0);
      expect(f.count, 0);
      expect(f.heldCount, 1);
    });

    test('a written-off or settling match, and a voided invoice, owe '
        'nothing', () async {
      final f = await overdueOf(
        [
          _invoice('w1', total: 10000, dueOn: DateTime(2026, 4)),
          _invoice('x1', total: 10000, dueOn: DateTime(2026, 4)),
          _invoice(
            'v1',
            total: 10000,
            dueOn: DateTime(2026, 4),
            voidedAt: DateTime(2026, 4, 20),
          ),
          _invoice('o1', total: 3000, dueOn: DateTime(2026, 4)),
        ],
        matches: {
          'w1': InvoiceMatch(
            invoiceId: 'w1',
            paidCents: 4000,
            resolution: 'under',
            matchedAt: DateTime(2026, 4, 10),
            writeoffAt: DateTime(2026, 4, 12),
          ),
          'x1': InvoiceMatch(
            invoiceId: 'x1',
            paidCents: 9900,
            resolution: 'exact',
            matchedAt: DateTime(2026, 4, 10),
          ),
        },
      );
      // Only o1 is still collectible; none is held.
      expect(f.value, 3000);
      expect(f.count, 1);
      expect(f.heldCount, 0);
    });
  });
}
