// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 2 — the vendor figures: read from `kpi_vendor_quality` (0673),
// exact to the minor unit, a missing amount never 0; a credit note
// subtracting under its supplier; supplier payables dated by the reported
// payment; the counts and days surviving a currency mix that leaves every
// amount unknown. The Demo computes the same figures from pgTAP 353's month.
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/vendor_kpi_repository.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_vendors.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_module_section.dart';
import 'package:deskilo/features/workspace/providers/bi_vendor_reader.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

const _ids = [
  'vendors.spend',
  'vendors.category_spend',
  'vendors.payment_punctuality',
  'vendors.billing_lag',
  'vendors.delivery',
];

const _alpha = '00000000-0000-4000-8000-0000032942f1';
const _beta = '00000000-0000-4000-8000-0000032942f2';
const _gamma = '00000000-0000-4000-8000-0000032942f3';

/// What pgTAP 353 reads for the owner, March 2025.
Map<String, Object?> _row({bool mixed = false, Object? costMinor = '25000'}) {
  String? a(String v) => mixed ? null : v;
  return {
    'from': '2025-03',
    'to': '2025-03',
    'currency': 'EUR',
    'spend': {
      'documents': mixed ? 8 : 7,
      'credit_notes': 1,
      'cost_minor': mixed ? null : costMinor,
      'credited_minor': a('1000'),
      'unassigned_minor': a('0'),
      'top_count': 5,
      'suppliers': 3,
      'top_cost_minor': a('25000'),
      'rows': [
        {
          'rank': 1,
          'supplier_id': _alpha,
          'name': 'Alpha',
          'documents': 2,
          'cost_minor': a('15000'),
        },
        {
          'rank': 2,
          'supplier_id': _beta,
          'name': 'Beta',
          'documents': 3,
          'cost_minor': a('6500'),
        },
        {
          'rank': 3,
          'supplier_id': _gamma,
          'name': 'Gamma',
          'documents': 3,
          'cost_minor': a('3500'),
        },
      ],
      'months': [
        {'month': '2025-03', 'cost_minor': a('25000')},
      ],
    },
    'categories': {
      'categories': 4,
      'rows': [
        {'category': 'rent', 'documents': 1, 'cost_minor': a('10000')},
        {'category': 'cleaning', 'documents': 3, 'cost_minor': a('6500')},
        {'category': 'repairs', 'documents': 1, 'cost_minor': a('5000')},
        {'category': 'energy', 'documents': 3, 'cost_minor': a('3500')},
      ],
    },
    'payment': {
      'cohorts': {
        'on_time': {'count': 1, 'minor': a('10000')},
        'late': {'count': 1, 'minor': a('5000')},
        'undated': {'count': 0, 'minor': a('0')},
        'partial': {'count': 1, 'minor': a('4000')},
        'open': {'count': 1, 'minor': a('1500')},
        'held': {'count': 1, 'minor': a('2000')},
        'unknown_due': {'count': 1, 'minor': a('500')},
      },
      'median_days': -2,
      'p90_days': 10,
      'weighted_days': mixed ? null : 2.0,
      'rows': [
        {
          'supplier_id': _beta,
          'name': 'Beta',
          'due': 3,
          'on_time': 0,
          'late': 0,
          'median_days': null,
        },
        {
          'supplier_id': _alpha,
          'name': 'Alpha',
          'due': 2,
          'on_time': 1,
          'late': 1,
          'median_days': -2,
        },
        {
          'supplier_id': _gamma,
          'name': 'Gamma',
          'due': 1,
          'on_time': 0,
          'late': 0,
          'median_days': null,
        },
      ],
    },
    'billing_lag': {
      'documents': 7,
      'undated': 0,
      'lag_days': 18,
      'median_days': 2,
      'p90_days': 10,
      'rows': [
        {
          'supplier_id': _beta,
          'name': 'Beta',
          'documents': 3,
          'lag_days': 4,
          'median_days': 2,
        },
        {
          'supplier_id': _alpha,
          'name': 'Alpha',
          'documents': 2,
          'lag_days': 13,
          'median_days': 3,
        },
        {
          'supplier_id': _gamma,
          'name': 'Gamma',
          'documents': 2,
          'lag_days': 1,
          'median_days': 0,
        },
      ],
    },
    // pgTAP 375's March: six orders sent, 1 on time of 2 with a date.
    'delivery': {
      'orders': 6,
      'cohorts': {
        'on_time': 1,
        'late': 1,
        'unknown_expected': 1,
        'partial': 1,
        'overdue': 1,
        'open': 1,
      },
      'median_lead_days': 13,
      'p90_lead_days': 19,
      'median_delay_days': -2,
      'p90_delay_days': 10,
      'rows': [
        {
          'supplier_id': _alpha,
          'name': 'Alpha',
          'orders': 2,
          'on_time': 1,
          'late': 1,
          'median_lead_days': 13,
        },
        {
          'supplier_id': _beta,
          'name': 'Beta',
          'orders': 2,
          'on_time': 0,
          'late': 0,
          'median_lead_days': null,
        },
        {
          'supplier_id': _gamma,
          'name': 'Gamma',
          'orders': 2,
          'on_time': 0,
          'late': 0,
          'median_lead_days': 5,
        },
      ],
    },
    'quality': [if (mixed) 'unavailable'],
    'reasons': [if (mixed) 'currency_mix'],
    'computed_at': '2026-11-04T12:00:00Z',
  };
}

/// pgTAP 353's March in the Demo's own records.
FakePurchaseRepository _march() {
  final purchases = FakePurchaseRepository();
  final names = {_alpha: 'Alpha', _beta: 'Beta', _gamma: 'Gamma'};
  void bill(
    String id,
    String supplier,
    String category,
    int dated,
    int received,
    DateTime? due,
    int cents, {
    List<(int, DateTime)> paid = const [],
    bool held = false,
    PurchaseKind kind = PurchaseKind.bill,
  }) {
    final summary = PurchaseSummary(
      id: id,
      supplierId: supplier,
      kind: kind,
      state: PurchaseState.approved,
      category: category,
      reference: id,
      currency: 'EUR',
      grossCents: cents,
      originalDate: DateTime(2025, 3, dated),
      receivedOn: DateTime(2025, 3, received),
    );
    purchases.add(
      PurchaseDetail(
        summary: summary,
        revision: 1,
        sources: const [],
        supplierName: names[supplier],
        dueOn: due,
        lines: [
          PurchaseLine(
            lineNo: 1,
            description: category,
            grossCents: cents,
            netCents: cents,
            taxCents: 0,
          ),
        ],
      ),
    );
    if (kind == PurchaseKind.creditNote) return;
    final settled = paid.fold<int>(0, (s, p) => s + p.$1);
    purchases.payables.add(
      PayableRow(
        purchase: summary,
        obligation: PurchaseObligation(
          id: '$id-payable',
          purchaseId: id,
          creditorKind: CreditorKind.supplier,
          creditorId: supplier,
          creditorName: names[supplier],
          amountCents: cents,
          currency: 'EUR',
          dueOn: due,
          state: held ? ObligationState.held : ObligationState.open,
          paidCents: settled,
          appliedCents: 0,
          remainingCents: cents - settled,
          allocations: [
            for (final (i, (amount, on)) in paid.indexed)
              SettlementAllocation(
                id: '$id-$i',
                isReversal: false,
                amountCents: amount,
                method: 'bank_transfer',
                reference: 'wire',
                paidOn: on,
              ),
          ],
        ),
      ),
    );
  }

  bill(
    'b1',
    _alpha,
    'rent',
    2,
    5,
    DateTime(2025, 3, 20),
    10000,
    paid: [(10000, DateTime(2025, 3, 18))],
  );
  bill(
    'b2',
    _alpha,
    'repairs',
    10,
    20,
    DateTime(2025, 3, 25),
    5000,
    paid: [(5000, DateTime(2025, 4, 4))],
  );
  bill(
    'b3',
    _beta,
    'cleaning',
    1,
    1,
    DateTime(2025, 3, 31),
    4000,
    paid: [(1500, DateTime(2025, 3, 15))],
  );
  bill(
    'b4',
    _beta,
    'cleaning',
    12,
    14,
    DateTime(2025, 3, 28),
    2000,
    held: true,
  );
  bill('b5', _gamma, 'energy', 15, 15, DateTime(2025, 4, 15), 3000);
  bill('b6', _gamma, 'energy', 5, 6, DateTime(2025, 3, 15), 1500);
  bill('b7', _beta, 'cleaning', 20, 22, null, 500);
  bill(
    'd8',
    _gamma,
    'energy',
    25,
    25,
    null,
    1000,
    kind: PurchaseKind.creditNote,
  );
  return purchases;
}

void main() {
  final l10n = AppLocalizationsEn();

  group('the contract', () {
    test('the four cards need the purchase figures and the finance right', () {
      final modules = {for (final m in biModules) m.id: m};
      for (final id in _ids) {
        expect(
          modules[id]?.feature,
          WorkspaceFeature.purchaseAnalytics,
          reason: id,
        );
        expect(kpiDefinitionOf(id), isNotNull, reason: id);
        expect(biModuleViews[id], isNotNull, reason: id);
      }
      final analystOnly = visibleBiModules(
        {WorkspaceFeature.purchaseAnalytics},
        {WorkspacePermission.viewAnalytics},
      ).map((m) => m.id);
      expect(analystOnly.where(_ids.contains), isEmpty);
      final finance = visibleBiModules(
        {WorkspaceFeature.purchaseAnalytics},
        {WorkspacePermission.viewAnalytics, WorkspacePermission.viewFinances},
      ).map((m) => m.id);
      expect(finance.where(_ids.contains), _ids);
      expect(
        visibleBiModules(const {}, {
          WorkspacePermission.viewAnalytics,
          WorkspacePermission.viewFinances,
        }).map((m) => m.id).where(_ids.contains),
        isEmpty,
      );
    });

    test('the server row parses exactly', () {
      final k = vendorQualityFromJson(_row());
      expect(k.costMinor, 25000);
      expect(k.creditedMinor, 1000);
      expect(k.vendors.map((v) => (v.rank, v.name, v.costMinor)), [
        (1, 'Alpha', 15000),
        (2, 'Beta', 6500),
        (3, 'Gamma', 3500),
      ]);
      expect(k.categories.map((c) => c.category), [
        'rent',
        'cleaning',
        'repairs',
        'energy',
      ]);
      expect((k.onTimeCount, k.completedCount), (1, 2));
      expect((k.medianDays, k.p90Days, k.weightedDays), (-2, 10, 2.0));
      expect(
        (k.lagDocuments, k.lagDays, k.lagMedianDays, k.lagP90Days),
        (7, 18, 2, 10),
      );
      expect(k.quality, isEmpty);
    });

    test('the delivery figure parses what pgTAP 375 proves', () {
      final k = vendorQualityFromJson(_row());
      expect(k.deliveryOrders, 6);
      expect({for (final e in k.deliveryCohorts.entries) e.key.wire: e.value}, {
        'on_time': 1,
        'late': 1,
        'unknown_expected': 1,
        'partial': 1,
        'overdue': 1,
        'open': 1,
      });
      expect((k.deliveryOnTimeCount, k.deliveryCompletedCount), (1, 2));
      expect(
        (
          k.deliveryMedianLeadDays,
          k.deliveryP90LeadDays,
          k.deliveryMedianDelayDays,
          k.deliveryP90DelayDays,
        ),
        (13, 19, -2, 10),
      );
      expect(k.deliveries.map((d) => (d.name, d.orders, d.onTime, d.late)), [
        ('Alpha', 2, 1, 1),
        ('Beta', 2, 0, 0),
        ('Gamma', 2, 0, 0),
      ]);
      // A server older than 0699 sends no delivery: nothing is invented.
      final old = vendorQualityFromJson({..._row()}..remove('delivery'));
      expect(old.deliveryOrders, 0);
      expect(old.deliveryCohorts.values.every((n) => n == 0), isTrue);
    });

    test('the delivery card: the share on time, the cohorts by name, the '
        'switched-off note, and the counts surviving a currency mix', () {
      final k = vendorQualityFromJson(_row());
      final m = vendorMeasure(k, 'vendors.delivery');
      expect((m.numerator, m.denominator), (1, 2));
      expect(m.unknown, isFalse);
      final view = biModuleViews['vendors.delivery']!;
      expect(view.title(l10n), 'Suppliers delivering on time');
      expect(
        view.basis(m, l10n, 'en'),
        '1 of 2 received orders arrived by the expected date',
      );
      final details = view.details(m, l10n, 'en');
      expect(details, contains('Received on time: 1 order'));
      expect(details, contains('Awaited, overdue: 1 order'));
      expect(
        details,
        contains('Alpha: 1 on time, 1 late, of 2 orders'),
      );
      expect(
        vendorRows(k, 'vendors.delivery').map((r) => r.key),
        ['on_time', 'late', 'unknown_expected', 'partial', 'overdue', 'open'],
      );
      expect(
        view.rowLabel(
          vendorRows(k, 'vendors.delivery').first,
          l10n,
          'en',
        ),
        'Received on time',
      );
      final off = vendorQualityFromJson({
        ..._row(),
        'reasons': ['purchase_orders_off'],
      });
      expect(
        view.notes(vendorMeasure(off, 'vendors.delivery'), l10n, 'en'),
        contains('Purchase orders are switched off: no delivery is measured.'),
      );
      final mixed = vendorMeasure(
        vendorQualityFromJson(_row(mixed: true)),
        'vendors.delivery',
      );
      expect(mixed.unknown, isFalse);
      expect((mixed.numerator, mixed.denominator), (1, 2));
    });

    test('an amount that cannot travel exactly is unknown, never 0', () {
      final k = vendorQualityFromJson(_row(costMinor: '12.5'));
      expect(k.costMinor, isNull);
      expect(k.reasons, contains('amount_not_exact'));
      expect(vendorMeasure(k, 'vendors.spend').unknown, isTrue);
    });

    test('a currency mix leaves the counts and days exact and every amount '
        'unknown', () {
      final k = vendorQualityFromJson(_row(mixed: true));
      expect(vendorMeasure(k, 'vendors.spend').unknown, isTrue);
      expect(vendorMeasure(k, 'vendors.category_spend').unknown, isTrue);
      final punctual = vendorMeasure(k, 'vendors.payment_punctuality');
      expect(punctual.unknown, isFalse);
      expect((punctual.numerator, punctual.denominator), (1, 2));
      final lag = vendorMeasure(k, 'vendors.billing_lag');
      expect(lag.unknown, isFalse);
      expect((lag.numerator, lag.denominator), (18, 7));
    });

    test(
      'the rows: suppliers by cost, categories, cohorts, suppliers by lag',
      () {
        final k = vendorQualityFromJson(_row());
        expect(
          vendorRows(
            k,
            'vendors.spend',
          ).map((r) => (r.label, r.current.numerator)),
          [('Alpha', 15000), ('Beta', 6500), ('Gamma', 3500)],
        );
        expect(vendorRows(k, 'vendors.category_spend').map((r) => r.label), [
          'rent',
          'cleaning',
          'repairs',
          'energy',
        ]);
        final cohorts = vendorRows(k, 'vendors.payment_punctuality');
        expect(cohorts.map((r) => r.key), [
          'on_time',
          'late',
          'partial',
          'open',
          'held',
          'unknown_due',
        ]);
        expect(
          biModuleViews['vendors.payment_punctuality']!
              .labelled(cohorts, l10n, 'en')
              .map((r) => r.label)
              .first,
          l10n.biVendorCohortOnTime,
        );
        expect(
          vendorRows(
            k,
            'vendors.billing_lag',
          ).map((r) => (r.label, r.current.numerator, r.current.denominator)),
          [('Beta', 4, 3), ('Alpha', 13, 2), ('Gamma', 1, 2)],
        );
      },
    );

    test('a ratio with nothing to divide is unknown, never 0', () {
      final row = _row();
      (row['billing_lag']! as Map<String, Object?>)
        ..['documents'] = 0
        ..['lag_days'] = 0;
      final m = vendorMeasure(
        vendorQualityFromJson(row),
        'vendors.billing_lag',
      );
      expect(m.unknown, isTrue);
      expect(m.reasons, contains('nothing_to_share'));
    });
  });

  group('the Demo computes what pgTAP 353 proves', () {
    test('every figure of the month', () async {
      final k = await DemoVendorKpiRepository(
        purchases: _march(),
        now: DateTime(2026, 11, 4),
      ).quality('ws', fromMonth: '2025-03', toMonth: '2025-03');
      final server = vendorQualityFromJson(_row());
      expect(k.costMinor, server.costMinor);
      expect((k.documents, k.creditNotes, k.creditedMinor), (7, 1, 1000));
      expect(
        k.vendors.map(
          (v) => (v.rank, v.supplierId, v.name, v.documents, v.costMinor),
        ),
        server.vendors.map(
          (v) => (v.rank, v.supplierId, v.name, v.documents, v.costMinor),
        ),
      );
      expect((k.topCostMinor, k.supplierCount), (25000, 3));
      expect(k.months, server.months);
      expect(k.categories, server.categories);
      expect(k.cohorts, server.cohorts);
      expect((k.medianDays, k.p90Days, k.weightedDays), (-2, 10, 2.0));
      expect(k.punctuality, server.punctuality);
      expect(
        (
          k.lagDocuments,
          k.lagUndated,
          k.lagDays,
          k.lagMedianDays,
          k.lagP90Days,
        ),
        (7, 0, 18, 2, 10),
      );
      expect(k.lags, server.lags);
      expect(k.quality, isEmpty);
    });

    test('a dollar bill leaves every amount unknown, never summed', () async {
      final dated = _march()
        ..add(
          PurchaseDetail(
            summary: PurchaseSummary(
              id: 'd9',
              supplierId: _alpha,
              kind: PurchaseKind.bill,
              state: PurchaseState.approved,
              category: 'rent',
              reference: 'd9',
              currency: 'USD',
              grossCents: 700,
              originalDate: DateTime(2025, 3, 8),
              receivedOn: DateTime(2025, 3, 8),
            ),
            revision: 1,
            sources: const [],
            lines: const [
              PurchaseLine(lineNo: 1, description: 'rent', grossCents: 700),
            ],
          ),
        );
      final mixed = await DemoVendorKpiRepository(
        purchases: dated,
        now: DateTime(2026, 11, 4),
      ).quality('ws', fromMonth: '2025-03', toMonth: '2025-03');
      expect(mixed.reasons, contains('currency_mix'));
      expect(mixed.costMinor, isNull);
      expect(mixed.cohorts[PayableCohort.onTime], (count: 1, minor: null));
      expect((mixed.documents, mixed.medianDays), (8, -2));
    });
  });
}
