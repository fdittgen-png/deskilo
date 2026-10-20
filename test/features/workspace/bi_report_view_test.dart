// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 C1 — a saved view becomes a report: Duplicate as report → rename,
// add, remove and reorder the cards → Save → reopen the persisted first page.
// The editor exists only while biReportDesigner is on (reading a report never
// needs it); a save that lost the race keeps the draft and says why.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

class _Finance implements FinanceKpiRepository {
  @override
  Future<FinanceSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => financeSummaryFromJson({
    'from': fromMonth,
    'to': toMonth,
    'currency': 'EUR',
    'invoiced_minor': '123456',
    'credit_notes_minor': '0',
    'collected_minor': '98765',
    'invoices': 12,
    'matches': 8,
    'quality': const <String>[],
    'reasons': const <String>[],
    'last_change_at': '2026-03-14T09:00:00Z',
    'computed_at': '2026-03-15T10:00:00Z',
  });
}

Future<void> _pump(
  WidgetTester tester,
  InMemoryBiViewRepository views, {
  bool designer = true,
}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {
              'invoicing': true,
              'workspaceStatus': true,
              'capacityKpi': true,
              'biReportDesigner': designer,
            },
          ),
          clock: FixedClock(DateTime(2026, 3, 15, 12)),
          financeKpis: _Finance(),
          biViews: views,
        ),
        platformIsWebProvider.overrideWithValue(true),
        webShellProvider.overrideWithValue(true),
        kpiRepositoryProvider.overrideWithValue(
          const UnavailableKpiRepository(),
        ),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String location) async {
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location),
  );
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(const ValueKey('bi-views')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

List<String> _cards(BiSavedView v) => v.definition!.report!.firstPageCards;

void main() {
  testWidgets('duplicate as report, reorder, remove, add, save, reopen', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    await _open(tester, '/bi?cards=capacity.seat_utilisation,finance.invoiced');
    await _tap(tester, 'bi-views-duplicate-report');

    final copy = (await views.list('ws-1')).single;
    expect(copy.scope, BiViewScope.private);
    expect(copy.definition!.report, isNotNull);
    expect(_cards(copy), ['capacity.seat_utilisation', 'finance.invoiced']);
    expect(find.byKey(const ValueKey('bi-report-panel')), findsOneWidget);

    await _tap(tester, 'bi-report-down-v1');
    await _tap(tester, 'bi-report-save');
    var saved = (await views.list('ws-1')).single;
    expect(saved.revision, 2);
    expect(_cards(saved), ['finance.invoiced', 'capacity.seat_utilisation']);
    // The ids stay with their cards; only the reading order moved.
    expect(
      saved.definition!.report!.pages.first.visuals.map((v) => v.id).toSet(),
      {'v1', 'v2'},
    );

    await _tap(tester, 'bi-report-remove-v2');
    await _tap(tester, 'bi-report-save');
    saved = (await views.list('ws-1')).single;
    expect(_cards(saved), ['capacity.seat_utilisation']);

    await _tap(tester, 'bi-report-add');
    await tester.tap(
      find.byKey(const ValueKey('bi-report-add-finance.invoiced')),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'bi-report-save');
    saved = (await views.list('ws-1')).single;
    expect(_cards(saved), ['capacity.seat_utilisation', 'finance.invoiced']);
    expect(
      saved.definition!.report!.pages.first.visuals.map((v) => v.id).toSet(),
      hasLength(2),
    );

    // Reopen from the standard page: the persisted first page is the query.
    await _open(tester, '/bi?saved=standard');
    await _menu(tester, 'bi-views-open-${saved.id}');
    expect(find.byKey(const ValueKey('bi-report-card-v1')), findsOneWidget);
    expect(find.byKey(const ValueKey('bi-report-card-v2')), findsOneWidget);
  });

  testWidgets('a save that lost the race keeps the draft and says why', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    await _open(tester, '/bi?cards=capacity.seat_utilisation,finance.invoiced');
    await _tap(tester, 'bi-views-duplicate-report');
    final first = (await views.list('ws-1')).single;

    // Someone else saves the same report first.
    await views.save(
      'ws-1',
      id: first.id,
      scope: first.scope,
      name: first.name,
      definition: first.definition!,
      expectedRevision: first.revision,
    );
    await _tap(tester, 'bi-report-down-v1');
    await _tap(tester, 'bi-report-save');

    expect(find.textContaining('Someone saved this view'), findsOneWidget);
    // The draft survives: the first card is still the moved one.
    expect(find.byKey(const ValueKey('bi-report-card-v1')), findsOneWidget);
    expect(_cards((await views.list('ws-1')).single), [
      'capacity.seat_utilisation',
      'finance.invoiced',
    ]);
  });

  testWidgets('with the designer off a report is read, not edited', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    final report = await views.save(
      'ws-1',
      scope: BiViewScope.private,
      name: 'Old report',
      definition: BiViewDefinition.ofReport(
        BiReportDefinition.standard(
          query: BiQueryContext.standard,
          cards: const ['capacity.seat_utilisation'],
          pageTitle: 'Page 1',
        ),
      ),
      expectedRevision: 0,
    );
    await _pump(tester, views, designer: false);
    await _open(tester, '/bi?saved=standard');
    await _menu(tester, 'bi-views-open-${report.id}');
    expect(find.byKey(const ValueKey('bi-report-panel')), findsNothing);
    expect(find.byKey(const ValueKey('bi-views-current')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bi-views-duplicate-report')),
      findsNothing,
    );
  });
}
