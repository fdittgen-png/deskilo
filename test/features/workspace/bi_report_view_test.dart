// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 C1 — a saved view becomes a report: Duplicate as report → rename,
// add, remove and reorder the cards → Save → reopen the persisted first page.
// The editor exists only while biReportDesigner is on (reading a report never
// needs it). C2: a save that lost the race keeps the draft until the person
// saves it over the newer version or discards it; a lost answer is retried as
// the same request (one revision); an operational reader of a mixed team
// report asks for no finance figure; pages open and are added; an answer that
// arrives once the reader moved to another server is dropped.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_views_bar.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/unavailable_kpi_repository.dart';

class _Finance implements FinanceKpiRepository {
  /// How many finance figures were asked for.
  int calls = 0;

  @override
  Future<FinanceSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    calls++;
    return financeSummaryFromJson({
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
}

Future<void> _pump(
  WidgetTester tester,
  BiViewRepository views, {
  bool designer = true,
  _Finance? finance,
  Map<String, bool>? flags,
}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags:
                flags ??
                {
                  'invoicing': true,
                  'workspaceStatus': true,
                  'capacityKpi': true,
                  'biReportDesigner': designer,
                },
          ),
          clock: FixedClock(DateTime(2026, 3, 15, 12)),
          financeKpis: finance ?? _Finance(),
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

  testWidgets('a capacity-only space authors a report: no invoicing, no '
      'workspace status, only the capacity figure and the designer', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    await _pump(
      tester,
      views,
      flags: {'capacityKpi': true, 'biReportDesigner': true},
    );
    await _open(tester, '/bi?cards=capacity.seat_utilisation');
    await _tap(tester, 'bi-views-duplicate-report');
    final copy = (await views.list('ws-1')).single;
    expect(_cards(copy), ['capacity.seat_utilisation']);

    await _open(tester, '/bi/report/${copy.id}');
    await _tap(tester, 'bi-visual-select-v1');
    await _tap(tester, 'bi-prop-width-v1-more');
    await _tap(tester, 'bi-editor-save');
    final saved = (await views.list('ws-1')).single;
    expect(saved.revision, 2);
    expect(
      saved.definition!.report!.pages.first.visuals.single.layout.span,
      copy.definition!.report!.pages.first.visuals.single.layout.span + 1,
    );
  });

  testWidgets('a save that lost the race keeps the draft until the person '
      'decides: save it over the newer version, or discard it', (
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
      name: 'Theirs',
      definition: first.definition!,
      expectedRevision: first.revision,
    );
    await _tap(tester, 'bi-report-down-v1');
    await _tap(tester, 'bi-report-save');

    expect(find.byKey(const ValueKey('bi-report-conflict')), findsOneWidget);
    // The draft survives and is not rebased: Save stays off until the
    // person chooses, and the stored report is theirs.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('bi-report-save')))
          .onPressed,
      isNull,
    );
    expect(_cards((await views.list('ws-1')).single), [
      'capacity.seat_utilisation',
      'finance.invoiced',
    ]);

    await _tap(tester, 'bi-report-overwrite');
    final saved = (await views.list('ws-1')).single;
    expect(saved.revision, 3);
    expect(_cards(saved), ['finance.invoiced', 'capacity.seat_utilisation']);
    expect(find.byKey(const ValueKey('bi-report-conflict')), findsNothing);

    // Discarding instead: the saved version comes back, the draft goes.
    await views.save(
      'ws-1',
      id: saved.id,
      scope: saved.scope,
      name: 'Theirs again',
      definition: first.definition!,
      expectedRevision: saved.revision,
    );
    await _tap(tester, 'bi-report-down-v2');
    await _tap(tester, 'bi-report-save');
    expect(find.byKey(const ValueKey('bi-report-conflict')), findsOneWidget);
    await _tap(tester, 'bi-report-discard');
    expect(find.byKey(const ValueKey('bi-report-conflict')), findsNothing);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('bi-report-name')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Theirs again',
    );
    expect((await views.list('ws-1')).single.revision, 4);
  });

  testWidgets('a save whose answer was lost is retried as the same request '
      'and makes one revision', (tester) async {
    final store = InMemoryBiViewRepository();
    final views = _LosesOneAnswer(store);
    await _pump(tester, views);
    await _open(tester, '/bi?cards=capacity.seat_utilisation,finance.invoiced');
    await _tap(tester, 'bi-views-duplicate-report');

    views.loseNext = true;
    await _tap(tester, 'bi-report-down-v1');
    await _tap(tester, 'bi-report-save');
    expect(find.byKey(const ValueKey('bi-report-failed')), findsOneWidget);
    // The server did save it; the device does not know yet.
    expect((await store.list('ws-1')).single.revision, 2);

    await _tap(tester, 'bi-report-retry');
    expect(find.byKey(const ValueKey('bi-report-failed')), findsNothing);
    // Not a conflict with itself: the server answered the same request.
    expect(find.byKey(const ValueKey('bi-report-conflict')), findsNothing);
    expect(views.requests.last, views.requests[views.requests.length - 2]);
    final saved = (await store.list('ws-1')).single;
    expect(saved.revision, 2);
    expect(_cards(saved), ['finance.invoiced', 'capacity.seat_utilisation']);
  });

  testWidgets('an operational reader of a mixed team report asks for no '
      'finance figure and never sees its name', (tester) async {
    final views = InMemoryBiViewRepository();
    final shared = await views.save(
      'ws-1',
      scope: BiViewScope.workspace,
      name: 'Mixed',
      definition: BiViewDefinition.ofReport(
        BiReportDefinition.standard(
          query: BiQueryContext.standard,
          cards: const ['finance.invoiced', 'capacity.seat_utilisation'],
          pageTitle: 'Page 1',
        ),
      ),
      expectedRevision: 0,
    );
    views.readable = {'capacity.seat_utilisation'};
    final finance = _Finance();
    await _pump(tester, views, finance: finance);
    await _open(tester, '/bi?saved=standard');
    finance.calls = 0;
    await _menu(tester, 'bi-views-open-${shared.id}');

    expect(find.textContaining('1 figures of this view'), findsOneWidget);
    expect(finance.calls, 0);
    // Not shown every figure, the reader does not edit it (they copy it).
    expect(find.byKey(const ValueKey('bi-report-panel')), findsNothing);
    final uri = GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).routeInformationProvider.value.uri;
    expect(uri.queryParameters['cards'], 'capacity.seat_utilisation');
  });

  testWidgets('a report of two pages: each page opens, a page is added', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    await _open(tester, '/bi?cards=capacity.seat_utilisation');
    await _tap(tester, 'bi-views-duplicate-report');

    await _tap(tester, 'bi-report-add-page');
    await tester.tap(
      find.byKey(const ValueKey('bi-report-add-page-finance.invoiced')),
    );
    await tester.pumpAndSettle();
    final saved = (await views.list('ws-1')).single;
    final pages = saved.definition!.report!.pages;
    expect(pages.map((p) => p.id), ['p1', 'p2']);
    expect(BiReportDefinition.cardsOf(pages[1]), ['finance.invoiced']);
    // The new page is the one on screen, with its own card in the editor.
    expect(find.byKey(const ValueKey('bi-report-card-v2')), findsOneWidget);
    expect(find.byKey(const ValueKey('bi-report-card-v1')), findsNothing);

    await _tap(tester, 'bi-report-page-p1');
    expect(find.byKey(const ValueKey('bi-report-card-v1')), findsOneWidget);
    expect(find.byKey(const ValueKey('bi-report-card-v2')), findsNothing);
  });

  test('team views are shared by whoever manages the space or designs its '
      'documents', () {
    expect(biCanShareViews({WorkspacePermission.viewAnalytics}), isFalse);
    expect(
      biCanShareViews({
        WorkspacePermission.viewAnalytics,
        WorkspacePermission.designDocuments,
      }),
      isTrue,
    );
    expect(
      biCanShareViews({
        WorkspacePermission.viewAnalytics,
        WorkspacePermission.workspaceSettings,
      }),
      isTrue,
    );
  });

  test('an answer that arrives after the reader moved to another server is '
      'dropped', () async {
    final slow = Completer<void>();
    final before = _Gated(InMemoryBiViewRepository(), slow.future);
    final after = InMemoryBiViewRepository();
    final container = ProviderContainer(
      overrides: [
        biViewRepositoryProvider.overrideWith(
          (ref) => ref.watch(_server) ? after : before,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(biViewRepositoryProvider);
    final saving = container
        .read(biViewActionsProvider)
        .save(
          'ws-1',
          scope: BiViewScope.private,
          name: 'R',
          definition: const BiViewDefinition(),
        );
    container.read(_server.notifier).moved();
    container.read(biViewRepositoryProvider);
    slow.complete();
    await expectLater(saving, throwsA(isA<BiViewRefused>()));
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

/// The other server (or identity) the reader moved to.
final _server = NotifierProvider<_Server, bool>(_Server.new);

class _Server extends Notifier<bool> {
  @override
  bool build() => false;

  void moved() => state = true;
}

/// A store whose answer is held until [gate] opens.
class _Gated implements BiViewRepository {
  _Gated(this._inner, this._gate);

  final BiViewRepository _inner;
  final Future<void> _gate;

  @override
  Future<List<BiSavedView>> list(String workspaceId) =>
      _inner.list(workspaceId);

  @override
  Future<BiSavedView> save(
    String workspaceId, {
    String? id,
    required BiViewScope scope,
    required String name,
    required BiViewDefinition definition,
    required int expectedRevision,
    String? requestId,
  }) async {
    await _gate;
    return _inner.save(
      workspaceId,
      id: id,
      scope: scope,
      name: name,
      definition: definition,
      expectedRevision: expectedRevision,
      requestId: requestId,
    );
  }

  @override
  Future<void> delete(String workspaceId, String id, int expectedRevision) =>
      _inner.delete(workspaceId, id, expectedRevision);

  @override
  Future<void> setDefault(String workspaceId, BiViewScope scope, String? id) =>
      _inner.setDefault(workspaceId, scope, id);
}

/// A store that saves, then loses the answer once ([loseNext]), as a
/// dropped connection does; it records every request id it was sent.
class _LosesOneAnswer extends _Gated {
  _LosesOneAnswer(InMemoryBiViewRepository inner) : super(inner, Future.value());

  bool loseNext = false;
  final requests = <String?>[];

  @override
  Future<BiSavedView> save(
    String workspaceId, {
    String? id,
    required BiViewScope scope,
    required String name,
    required BiViewDefinition definition,
    required int expectedRevision,
    String? requestId,
  }) async {
    requests.add(requestId);
    final saved = await super.save(
      workspaceId,
      id: id,
      scope: scope,
      name: name,
      definition: definition,
      expectedRevision: expectedRevision,
      requestId: requestId,
    );
    if (loseNext) {
      loseNext = false;
      throw const SocketException('connection lost');
    }
    return saved;
  }
}
