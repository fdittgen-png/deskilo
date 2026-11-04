// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 — the customer figures: read from `kpi_customer_quality` (0670),
// exact to the minor unit, a missing amount never 0; payment punctuality
// dated by the reported payment, never by the match; the counts surviving
// a currency mix that leaves every amount unknown; the dunning load only
// with dunning; names only for a reader of personal data. The Demo
// computes the same figures from pgTAP 352's month.
import 'package:deskilo/core/demo/data/customer_kpi_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_customers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_module_section.dart';
import 'package:deskilo/features/workspace/providers/bi_customer_reader.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _ids = [
  'customers.payment_behaviour',
  'customers.dunning_load',
  'customers.credit_and_writeoff',
  'customers.concentration',
];

/// What pgTAP 352 reads for the owner, March 2025.
Map<String, Object?> _row({
  bool names = true,
  bool mixed = false,
  bool dunning = true,
  Object? creditedMinor = '160',
}) {
  String? a(String v) => mixed ? null : v;
  return {
    'from': '2025-03',
    'to': '2025-03',
    'currency': 'EUR',
    'names_visible': names,
    'payment': {
      'cohorts': {
        'on_time': {'count': 1, 'minor': a('1200')},
        'late': {'count': 1, 'minor': a('900')},
        'undated': {'count': 0, 'minor': a('0')},
        'partial': {'count': 1, 'minor': a('1000')},
        'open': {'count': 3, 'minor': a('1500')},
        'held': {'count': 1, 'minor': a('300')},
        'written_off': {'count': 1, 'minor': a('800')},
        'unknown_due': {'count': 1, 'minor': a('400')},
      },
      'median_days': -2,
      'p90_days': 10,
      'weighted_days': mixed ? null : 3.1,
    },
    'dunning': dunning
        ? {
            'due_invoices': 8,
            'reminded_invoices': 3,
            'reminders': 4,
            'by_level': {'1': 3, '2': 1},
            'paid_after_reminder': 1,
          }
        : null,
    'credit': {
      'net_unknown': 0,
      'credit_notes': 1,
      'credited_minor': mixed ? null : creditedMinor,
      'write_offs': 1,
      'written_off_minor': a('480'),
      'months': [
        {
          'month': '2025-03',
          'credited_minor': a('160'),
          'written_off_minor': a('480'),
        },
      ],
    },
    'concentration': {
      'top_count': 5,
      'net_unknown': 1,
      'customers': 4,
      'net_minor': a('5780'),
      'top_net_minor': a('5780'),
      'debtors': 5,
      'open_minor': a('4000'),
      'top_open_minor': a('4000'),
      'rows': [
        for (final (rank, name, net) in [
          (1, 'Name c3', '2400'),
          (2, 'Name c2', '1440'),
          (3, 'Name c5', '1000'),
          (4, 'Name c4', '940'),
        ])
          {'rank': rank, 'name': names ? name : null, 'minor': a(net)},
      ],
      'debtor_rows': [
        for (final (rank, name, open) in [
          (1, 'Name c6', '1200'),
          (2, 'Name c3', '1100'),
          (3, 'Name c5', '1000'),
          (4, 'Name c2', '400'),
          (5, 'Name c4', '300'),
        ])
          {'rank': rank, 'name': names ? name : null, 'minor': a(open)},
      ],
    },
    'quality': [if (mixed) 'unavailable'],
    'reasons': [
      'net_not_proven',
      if (mixed) 'currency_mix',
      if (!dunning) 'dunning_off',
    ],
    'computed_at': '2025-04-02T10:00:00Z',
  };
}

class _Customers implements CustomerKpiRepository {
  _Customers(this.row);

  final Map<String, Object?> Function() row;
  final calls = <(String, String)>[];

  @override
  Future<CustomerQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    calls.add((fromMonth, toMonth));
    return customerQualityFromJson(row());
  }
}

// pgTAP 352's month, as the Demo keeps it.
Invoice _invoice(
  String id,
  String member,
  int total, {
  DateTime? due,
  List<InvoiceVatTotal>? vat,
  String? replaces,
  String currency = 'EUR',
  String period = '2025-03',
  InvoiceKind kind = InvoiceKind.full,
  String? settledBy,
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: member,
  number: 'K-$id',
  issuedAt: DateTime.parse('$period-01'),
  period: kind == InvoiceKind.settlement ? null : period,
  title: 'T',
  lines: const [],
  totalCents: total,
  currency: currency,
  memberName: 'Name $member',
  memberAddress: '',
  workspaceName: 'Customers',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 's',
  // Without [vat], a frozen breakdown proving it zero-rated (net = gross).
  vatTotals: vat ?? [_vat(total, total, percent: 0, category: 'Z')],
  replacesInvoiceId: replaces,
  dueOn: due,
  kind: kind,
  settledByInvoiceId: settledBy,
);

InvoiceVatTotal _vat(
  int gross,
  int net, {
  double percent = 25,
  String category = 'S',
}) => InvoiceVatTotal(
  percent: percent,
  category: category,
  grossCents: gross,
  netCents: net,
  vatCents: gross - net,
);

FakeMoneyRepository _march({bool settlementPaid = false}) {
  final money = FakeMoneyRepository();
  void pay(String id, String member, int cents, String resolution,
      DateTime paidOn, DateTime matchedAt) {
    money.ledger.add(
      LedgerEntry(
        id: 'pay-$id',
        memberId: member,
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: cents,
        description: 'transfer',
        period: '2025-03',
        createdAt: matchedAt,
        occurredOn: paidOn,
      ),
    );
    money.invoiceMatchesStore[id] = InvoiceMatch(
      invoiceId: id,
      paidCents: cents,
      resolution: resolution,
      paymentLedgerId: 'pay-$id',
      matchedAt: matchedAt,
    );
  }

  money.invoices.addAll([
    _invoice('d1', 'c2', 1200, due: DateTime(2025, 3, 10)),
    _invoice('d8', 'c3', 900, due: DateTime(2025, 3)),
    _invoice('d3', 'c3', 1000, due: DateTime(2025, 3, 15)),
    _invoice('d4', 'c3', 500, due: DateTime(2025, 3, 20)),
    _invoice('d5', 'c4', 300, due: DateTime(2025, 3, 20)),
    _invoice('d6', 'c4', 800, due: DateTime(2025, 3, 5), vat: [_vat(800, 640)]),
    _invoice('d7', 'c2', 400),
    _invoice('e1', 'c2', -200, vat: [_vat(-200, -160)], replaces: 'd1'),
    // c5's two March invoices regrouped into the settlement f1 (0148).
    _invoice('a7', 'c5', 600, due: DateTime(2025, 3, 12), settledBy: 'f1'),
    _invoice('a8', 'c5', 400, due: DateTime(2025, 3, 18), settledBy: 'f1'),
    _invoice('f1', 'c5', 1000, kind: InvoiceKind.settlement),
    // A taxable invoice without its breakdown, and a January debtor.
    _invoice('d9', 'c6', 500, due: DateTime(2025, 4, 10), vat: const []),
    _invoice('a9', 'c6', 700, due: DateTime(2025, 1, 31), period: '2025-01'),
  ]);
  pay('d1', 'c2', 1200, 'exact', DateTime(2025, 3, 8), DateTime(2025, 4, 30));
  pay('d8', 'c3', 900, 'exact', DateTime(2025, 3, 11), DateTime(2025, 3, 12));
  pay('d3', 'c3', 400, 'under_accepted', DateTime(2025, 3, 14),
      DateTime(2025, 3, 14));
  pay('d6', 'c4', 200, 'under_accepted', DateTime(2025, 3, 6),
      DateTime(2025, 3, 6));
  money.invoiceMatchesStore['d6'] = money.invoiceMatchesStore['d6']!.copyWith(
    writeoffAt: DateTime(2025, 3, 31),
  );
  money.invoiceReminders['d8'] = [DateTime(2025, 3, 5, 9)];
  money.invoiceReminders['d4'] = [
    DateTime(2025, 3, 21, 9),
    DateTime(2025, 3, 28, 9),
  ];
  money.invoiceReminders['d5'] = [DateTime(2025, 3, 21, 9)];
  money.dunningHolds['d5'] = 'dispute';
  if (settlementPaid) {
    pay('f1', 'c5', 1000, 'exact', DateTime(2025, 3, 25), DateTime(2025, 3, 26));
  }
  return money;
}

Future<CustomerQualityKpi> _demo(
  FakeMoneyRepository money, {
  bool names = true,
}) => DemoCustomerKpiRepository(
  money: money,
  now: DateTime(2025, 4, 2),
  namesVisible: () => names,
  dunningEnabled: () => true,
).quality('ws-1', fromMonth: '2025-03', toMonth: '2025-03');

void main() {
  group('the contract', () {
    test('the four cards exist with the status flag and the finance right; '
        'the dunning load also needs dunning', () {
      const rights = {
        WorkspacePermission.viewAnalytics,
        WorkspacePermission.viewFinances,
      };
      final shown = visibleBiModules({
        WorkspaceFeature.workspaceStatus,
        WorkspaceFeature.dunning,
      }, rights).map((m) => m.id);
      expect(shown, containsAll(_ids));
      expect(
        visibleBiModules({WorkspaceFeature.workspaceStatus}, rights)
            .map((m) => m.id),
        isNot(contains('customers.dunning_load')),
      );
      expect(
        visibleBiModules(
          {WorkspaceFeature.workspaceStatus, WorkspaceFeature.dunning},
          {WorkspacePermission.viewAnalytics},
        ).map((m) => m.id),
        isNot(contains('customers.payment_behaviour')),
        reason: 'without viewFinances',
      );
      for (final id in _ids) {
        expect(biModuleViews.containsKey(id), isTrue, reason: id);
        expect(
          biModules.firstWhere((m) => m.id == id).drill?.route,
          '/invoice-register',
        );
      }
    });

    test('the server row parses exactly', () {
      final k = customerQualityFromJson(_row());
      expect(k.cohorts[PaymentCohort.onTime], (count: 1, minor: 1200));
      expect(k.onTimeCount, 1);
      expect(k.completedCount, 2);
      expect((k.medianDays, k.p90Days, k.weightedDays), (-2, 10, 3.1));
      expect(k.dunning!.byLevel, {1: 3, 2: 1});
      expect(k.creditedAndWrittenOffMinor, 640);
      expect(k.customers.first.name, 'Name c3');
      expect(k.debtors.first.name, 'Name c6');
      // A net not proven makes the net figures partial, and only those.
      final share = customerMeasure(k, 'customers.concentration');
      expect(share.quality, contains(KpiQuality.partial));
      expect(share.reasons, contains('net_not_proven'));
      final punctual = customerMeasure(k, 'customers.payment_behaviour');
      expect(punctual.quality, isNot(contains(KpiQuality.partial)));
      expect(punctual.reasons, isNot(contains('net_not_proven')));
      expect(k.quality, isEmpty);
    });

    test('an amount that cannot travel exactly is unknown, never 0', () {
      final k = customerQualityFromJson(_row(creditedMinor: '1.5'));
      expect(k.creditedMinor, isNull);
      expect(k.quality, contains(KpiQuality.unavailable));
      expect(k.reasons, contains('amount_not_exact'));
      expect(
        customerMeasure(k, 'customers.payment_behaviour').unknown,
        isTrue,
        reason: 'an inexact amount is not a currency mix',
      );
    });

    test('a currency mix leaves the counts exact and every amount unknown', () {
      final k = customerQualityFromJson(_row(mixed: true));
      expect(k.reasons, contains('currency_mix'));
      final punctual = customerMeasure(k, 'customers.payment_behaviour');
      expect(punctual.unknown, isFalse);
      expect(punctual.value(KpiAggregation.ratioOfSums), 0.5);
      expect(customerMeasure(k, 'customers.dunning_load').numerator, 4);
      expect(
        customerMeasure(k, 'customers.credit_and_writeoff').unknown,
        isTrue,
      );
      expect(customerMeasure(k, 'customers.concentration').unknown, isTrue);
    });

    test('the dunning load is unknown while dunning is off', () {
      final m = customerMeasure(
        customerQualityFromJson(_row(dunning: false)),
        'customers.dunning_load',
      );
      expect(m.unknown, isTrue);
      expect(m.reasons, contains('dunning_off'));
      expect(
        customerMeasure(
          customerQualityFromJson(_row(dunning: false)),
          'customers.payment_behaviour',
        ).reasons,
        isNot(contains('dunning_off')),
        reason: 'only the dunning card says so',
      );
    });

    test('the rows: the cohorts, the levels, the months, the ranks', () {
      final k = customerQualityFromJson(_row());
      expect(
        customerRows(k, 'customers.payment_behaviour').map((r) => r.key),
        ['on_time', 'late', 'partial', 'open', 'held', 'written_off',
         'unknown_due'],
        reason: 'an empty cohort is not a row',
      );
      final share = customerRows(k, 'customers.payment_behaviour').first;
      expect(share.current.value(KpiAggregation.ratioOfSums), 1 / 9);
      expect(
        customerRows(k, 'customers.dunning_load').map((r) => r.current.numerator),
        [3, 1],
      );
      expect(
        customerRows(k, 'customers.credit_and_writeoff').single.current.numerator,
        640,
      );
      final top = customerRows(k, 'customers.concentration');
      expect(top.map((r) => r.key), ['rank-1', 'rank-2', 'rank-3', 'rank-4']);
      expect(top.first.current.value(KpiAggregation.ratioOfSums), 2400 / 5780);
    });

    test('a row is named by the server, else by its rank', () {
      final l10n = AppLocalizationsEn();
      final view = biModuleViews['customers.concentration']!;
      for (final (names, expected) in [
        (true, 'Name c3'),
        (false, 'Customer 1'),
      ]) {
        final k = customerQualityFromJson(_row(names: names));
        final row = customerRows(k, 'customers.concentration').first;
        expect(view.rowLabel(row, l10n, 'en'), expected);
      }
      final hidden = customerQualityFromJson(_row(names: false));
      expect(
        view.notes(
          customerMeasure(hidden, 'customers.concentration'),
          l10n,
          'en',
        ),
        contains(l10n.biCustomerNamesHidden),
      );
    });
  });

  group('the Demo computes what pgTAP 352 proves', () {
    test('every figure of the month', () async {
      final k = await _demo(_march());
      expect({
        for (final e in k.cohorts.entries) e.key.wire: e.value,
      }, {
        'on_time': (count: 1, minor: 1200),
        'late': (count: 1, minor: 900),
        'undated': (count: 0, minor: 0),
        'partial': (count: 1, minor: 1000),
        'open': (count: 3, minor: 1500),
        'held': (count: 1, minor: 300),
        'written_off': (count: 1, minor: 800),
        'unknown_due': (count: 1, minor: 400),
      }, reason: 'a source of an unpaid settlement is open, not settled');
      expect(
        (k.medianDays, k.p90Days, k.weightedDays),
        (-2, 10, 3.1),
        reason: 'dated by the reported payment; matched 30 April would '
            'have made d1 51 days late',
      );
      expect(k.dunning!.dueInvoices, 8);
      expect(k.dunning!.reminders, 4);
      expect(k.dunning!.remindedInvoices, 3);
      expect(k.dunning!.byLevel, {1: 3, 2: 1});
      expect(k.dunning!.paidAfterReminder, 1);
      expect((k.creditedMinor, k.writtenOffMinor), (160, 480));
      expect((k.netMinor, k.topNetMinor, k.netUnknown), (5780, 5780, 1));
      expect(k.reasons, contains('net_not_proven'));
      expect(
        [for (final c in k.customers) (c.rank, c.name, c.minor)],
        [
          (1, 'Name c3', 2400),
          (2, 'Name c2', 1440),
          (3, 'Name c5', 1000),
          (4, 'Name c4', 940),
        ],
      );
      expect((k.openMinor, k.topOpenMinor, k.debtorCount), (4000, 4000, 5));
      expect(
        [for (final d in k.debtors) (d.rank, d.name, d.minor)],
        [
          (1, 'Name c6', 1200),
          (2, 'Name c3', 1100),
          (3, 'Name c5', 1000),
          (4, 'Name c2', 400),
          (5, 'Name c4', 300),
        ],
        reason: 'the January debtor counts; debtors are another ranking',
      );
      expect(k.quality, isEmpty);
    });

    test('a paid settlement makes its sources late by its payment date, '
        'and nobody owes it', () async {
      final k = await _demo(_march(settlementPaid: true));
      expect(k.cohorts[PaymentCohort.late], (count: 3, minor: 1900));
      expect((k.medianDays, k.p90Days, k.weightedDays), (7, 13, 5.5));
      expect((k.openMinor, k.debtorCount), (3000, 4));
    });

    test('without personal data the customers are ranks', () async {
      final k = await _demo(_march(), names: false);
      expect(k.namesVisible, isFalse);
      expect(k.customers.map((c) => c.name), everyElement(isNull));
      expect(k.customers.first.minor, 2400);
      expect(k.debtors.map((c) => c.name), everyElement(isNull));
    });

    test('a dollar invoice leaves every amount unknown, never summed', () async {
      final money = _march()
        ..invoices.add(
          _invoice('usd', 'c4', 700, due: DateTime(2025, 3, 25),
              currency: 'USD'),
        );
      final k = await _demo(money);
      expect(k.reasons, contains('currency_mix'));
      expect(k.quality, contains(KpiQuality.unavailable));
      expect(k.netMinor, isNull);
      expect(k.creditedMinor, isNull);
      expect(k.cohorts[PaymentCohort.onTime]!.count, 1);
    });
  });

  testWidgets('the four cards show the share, the reminders, the amount '
      'and the concentration', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final customers = _Customers(_row);
    const query = BiQueryContext(
      period: BiPeriodRef.fixed(BiPeriod(BiGrain.month, 2025, 3)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            clock: FixedClock(DateTime(2025, 4, 2, 12)),
            customerKpis: customers,
          ),
          myPermissionsProvider.overrideWithValue({
            WorkspacePermission.viewAnalytics,
            WorkspacePermission.viewFinances,
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [
                for (final id in _ids)
                  BiModuleSection(
                    module: biModules.firstWhere((m) => m.id == id),
                    query: query,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    String value(String id) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('bi-module-$id')),
            matching: find.byKey(const ValueKey('bi-value')),
          ),
        )
        .data!;
    expect(value('customers.payment_behaviour'), '50.0%');
    expect(value('customers.dunning_load'), '4');
    expect(value('customers.credit_and_writeoff'), '€6.40');
    expect(value('customers.concentration'), '100.0%');
    expect(
      find.text('1 of 2 settled invoices paid by their due date'),
      findsOneWidget,
    );
    expect(
      find.text('4 reminders on 3 of 6 invoices falling due'),
      findsOneWidget,
    );
    expect(
      customers.calls.every((c) => c.$1 == c.$2),
      isTrue,
      reason: 'one read per month, whatever card asks',
    );
  });
}
