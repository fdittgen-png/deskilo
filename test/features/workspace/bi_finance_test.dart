// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1924 — the first finance KPIs on the Web-BI host: invoiced and
// collected, read once from the server (the money report's predicates),
// exact to the minor unit across the JSON boundary, never a default
// currency, never a missing amount read as 0, never labelled a profit;
// compared through the shared toolbar, opened at the money report, and
// absent for a reader without the finance right.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/presentation/screens/workspace_status_screen.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Map<String, dynamic> _row({
  String from = '2026-03',
  String to = '2026-03',
  Object? invoiced = '123456',
  Object? credit = '15000',
  Object? collected = '98765',
  Object? currency = 'EUR',
  List<String> quality = const [],
  List<String> reasons = const [],
}) => {
  'from': from,
  'to': to,
  'currency': currency,
  'invoiced_minor': invoiced,
  'credit_notes_minor': credit,
  'collected_minor': collected,
  'invoices': 12,
  'matches': 8,
  'quality': quality,
  'reasons': reasons,
  'last_change_at': '2026-03-14T09:00:00Z',
  'computed_at': '2026-03-15T10:00:00Z',
};

/// March 2026: invoiced 1 234,56, collected 987,65; February: invoiced
/// 1 000,00, collected 0 (measured).
class _Finance implements FinanceKpiRepository {
  final calls = <(String, String)>[];
  Object? failure;

  @override
  Future<FinanceSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    calls.add((fromMonth, toMonth));
    if (failure case final f?) throw f;
    return financeSummaryFromJson(
      fromMonth == '2026-02'
          ? _row(
              from: fromMonth,
              to: toMonth,
              invoiced: '100000',
              collected: '0',
            )
          : _row(from: fromMonth, to: toMonth),
    );
  }
}

Future<_Finance> _pump(
  WidgetTester tester, {
  Set<WorkspacePermission>? permissions,
  bool capacity = false,
}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final finance = _Finance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {
              'invoicing': true,
              'workspaceStatus': true,
              'capacityKpi': capacity,
            },
          ),
          clock: FixedClock(DateTime(2026, 3, 15, 12)),
          financeKpis: finance,
        ),
        platformIsWebProvider.overrideWithValue(true),
        webShellProvider.overrideWithValue(true),
        kpiRepositoryProvider.overrideWithValue(
          const UnavailableKpiRepository(),
        ),
        if (permissions != null)
          myPermissionsProvider.overrideWithValue(permissions),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return finance;
}

Future<void> _open(WidgetTester tester, String location) async {
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location),
  );
  await tester.pumpAndSettle();
}

Map<String, String> _query(WidgetTester tester) =>
    GoRouterState.of(tester.element(find.byKey(const ValueKey('bi-page'))))
        .uri
        .queryParameters;

String _in(WidgetTester tester, String module, String key) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('bi-module-$module')),
        matching: find.byKey(ValueKey(key)),
      ),
    )
    .data!;

void main() {
  group('the contract', () {
    test('unknown finance quality never becomes a qualified amount', () {
      final k = financeSummaryFromJson(_row(quality: ['future_quality']));
      expect(k.quality, contains(KpiQuality.unavailable));
    });

    test('missing finance evidence and fractional counts are refused', () {
      expect(
        () => financeSummaryFromJson(_row()..remove('quality')),
        throwsFormatException,
      );
      expect(
        () => financeSummaryFromJson(_row()..['matches'] = 1.5),
        throwsFormatException,
      );
    });

    test('amounts are exact to 2^53 − 1 and refused beyond, never rounded', () {
      expect(exactMinor('9007199254740991'), 9007199254740991);
      expect(exactMinor('-9007199254740991'), -9007199254740991);
      expect(exactMinor('9007199254740992'), isNull);
      expect(exactMinor('12.5'), isNull);
      expect(exactMinor(null), isNull);
      final big = financeSummaryFromJson(_row(invoiced: '9007199254740992'));
      expect(big.invoicedMinor, isNull);
      expect(big.quality, contains(KpiQuality.unavailable));
      expect(big.reasons, contains('amount_not_exact'));
    });

    test('a missing amount or currency is unavailable, not zero, not euro', () {
      final missing = financeSummaryFromJson(_row(collected: null));
      expect(missing.collectedMinor, isNull);
      expect(
        financeMeasure(missing, 'finance.collected').value(KpiAggregation.sum),
        isNull,
      );
      final noCurrency = financeSummaryFromJson(_row(currency: null));
      expect(noCurrency.currency, '');
      expect(noCurrency.quality, contains(KpiQuality.unavailable));
    });

    test('a measured zero is a known zero; a currency mix is unavailable', () {
      final zero = financeMeasure(
        financeSummaryFromJson(_row(collected: '0')),
        'finance.collected',
      );
      expect(zero.value(KpiAggregation.sum), 0);
      expect(zero.quality, contains(KpiQuality.knownZero));
      final mixed = financeMeasure(
        financeSummaryFromJson(
          _row(quality: ['unavailable'], reasons: ['currency_mix']),
        ),
        'finance.invoiced',
      );
      expect(mixed.value(KpiAggregation.sum), isNull);
      expect(mixed.quality, isNot(contains(KpiQuality.knownZero)));
    });

    test('a period is read as its whole months', () {
      expect(biMonths(const BiPeriod(BiGrain.month, 2026, 3)), (
        from: '2026-03',
        to: '2026-03',
      ));
      expect(biMonths(const BiPeriod(BiGrain.quarter, 2026, 4)), (
        from: '2026-10',
        to: '2026-12',
      ));
      expect(biMonths(const BiPeriod(BiGrain.year, 2025, 1)), (
        from: '2025-01',
        to: '2025-12',
      ));
    });

    test('the catalogue registers both, financial, behind viewFinances', () {
      for (final k in [invoicedKpi, collectedKpi]) {
        expect(kpiCatalogue, contains(k));
        expect(k.disclosure, KpiDisclosure.financial);
        expect(k.permissions, ['viewAnalytics', 'viewFinances']);
        expect(k.aggregation, KpiAggregation.sum);
      }
    });
  });

  testWidgets('the cards show the exact amounts, once per period, and say '
      'what they are not', (tester) async {
    final finance = await _pump(tester);
    await _open(tester, '/bi');
    expect(_in(tester, 'finance.invoiced', 'bi-value'), '€1,234.56');
    expect(_in(tester, 'finance.collected', 'bi-value'), '€987.65');
    expect(finance.calls, [
      ('2026-03', '2026-03'),
    ], reason: 'both cards read one summary');
    expect(
      find.textContaining('credit notes €150.00, shown apart'),
      findsOneWidget,
    );
    expect(find.textContaining('not over'), findsNothing);
    expect(
      find.textContaining('profit'),
      findsNothing,
      reason: 'only inside the explanation, which is folded',
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('bi-module-finance.invoiced')),
        matching: find.byKey(const ValueKey('bi-explain')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Not a profit'), findsOneWidget);
  });

  testWidgets('a comparison gives the difference in money and in percent; '
      'a measured zero base has no percent', (tester) async {
    await _pump(tester);
    await _open(tester, '/bi?cmp=previous');
    expect(
      _in(tester, 'finance.invoiced', 'bi-compared'),
      'February 2026: €1,000.00 (+€234.56 (+23.5%))',
    );
    expect(
      _in(tester, 'finance.collected', 'bi-compared'),
      'February 2026: €0.00 (+€987.65)',
    );
  });

  testWidgets('grouping is refused with its reason, not ignored', (
    tester,
  ) async {
    final finance = await _pump(tester);
    await _open(tester, '/bi?by=level');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bi-module-finance.invoiced')),
        matching: find.byKey(const ValueKey('bi-refused')),
      ),
      findsOneWidget,
    );
    expect(finance.calls, isEmpty);
  });

  testWidgets('the analyses can be chosen and ordered; the address keeps '
      'the order', (tester) async {
    await _pump(tester);
    await _open(tester, '/bi');
    await tester.tap(find.byKey(const ValueKey('bi-cards')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bi-card-finance.invoiced')));
    await tester.tap(
      find.byKey(const ValueKey('bi-card-up-finance.collected')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bi-cards-ok')));
    await tester.pumpAndSettle();
    expect(_query(tester)['cards'], 'finance.collected');
    expect(
      find.byKey(const ValueKey('bi-module-finance.invoiced')),
      findsNothing,
    );
  });

  testWidgets('the source opens the money report; Back returns to the '
      'same analysis', (tester) async {
    await _pump(tester);
    await _open(tester, '/bi?cmp=year&cards=finance.invoiced');
    await tester.tap(find.byKey(const ValueKey('bi-drill')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceStatusScreen), findsOneWidget);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();
    expect(_query(tester), {'cmp': 'year', 'cards': 'finance.invoiced'});
  });

  testWidgets('without viewFinances the finance cards do not exist and '
      'nothing is read', (tester) async {
    final finance = await _pump(
      tester,
      permissions: {WorkspacePermission.viewAnalytics},
      capacity: true,
    );
    await _open(tester, '/bi?cards=finance.invoiced,capacity.seat_utilisation');
    expect(
      find.byKey(const ValueKey('bi-module-finance.invoiced')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('bi-cards-unavailable')), findsOneWidget);
    expect(finance.calls, isEmpty);
  });

  testWidgets('a server refusal and a failure are said, never shown as 0', (
    tester,
  ) async {
    final finance = await _pump(tester);
    finance.failure = const KpiForbidden();
    await _open(tester, '/bi?cards=finance.invoiced');
    expect(find.byKey(const ValueKey('bi-forbidden')), findsOneWidget);
    expect(find.text('€0.00'), findsNothing);
  });
}
