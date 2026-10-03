// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 C — saved Web-BI views in the app: save → open again → duplicate
// → rename → delete; a fixed period stays fixed; my default opens a bare
// /bi and wins over the team's, and clearing mine falls back to the
// team's; without the management right there is no team option; a lost
// update is refused and said; a view whose analyses are gone names what
// it leaves out, and an unreadable one opens nothing.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

class _Kpis implements KpiRepository {
  int calls = 0;

  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async {
    calls++;
    return seatCapacityFromJson({
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'offered_seat_hours': 100,
      'reserved_seat_hours': 30,
      'computed_at': '2026-03-15T10:00:00Z',
    });
  }
}

Future<_Kpis> _pump(
  WidgetTester tester,
  InMemoryBiViewRepository views, {
  bool manage = true,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final kpis = _Kpis();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {'capacityKpi': true},
          ),
          clock: FixedClock(DateTime(2026, 3, 15, 12)),
          biViews: views,
        ),
        platformIsWebProvider.overrideWithValue(true),
        webShellProvider.overrideWithValue(true),
        kpiRepositoryProvider.overrideWithValue(kpis),
        if (!manage)
          myPermissionsProvider.overrideWithValue({
            WorkspacePermission.viewAnalytics,
          }),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return kpis;
}

Future<void> _open(WidgetTester tester, String location) async {
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push(location),
  );
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
  await tester.pumpAndSettle();
}

Map<String, String> _query(WidgetTester tester) =>
    GoRouterState.of(tester.element(find.byKey(const ValueKey('bi-page'))))
        .uri
        .queryParameters;

Future<void> _menu(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(const ValueKey('bi-views')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _saveAs(
  WidgetTester tester,
  String name, {
  bool team = false,
  bool fixed = false,
}) async {
  await _menu(tester, 'bi-views-save-as');
  await tester.enterText(find.byKey(const ValueKey('bi-views-name')), name);
  if (team) await tester.tap(find.text('The team'));
  if (fixed) {
    await tester.tap(find.byKey(const ValueKey('bi-views-period-fixed')));
  }
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('bi-views-save-ok')));
  await tester.pumpAndSettle();
}

String _current(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('bi-views-current'))).data!;

void main() {
  testWidgets('save, open again, duplicate, rename and delete', (tester) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    await _open(tester, '/bi?by=level&cmp=previous');
    await _saveAs(tester, 'By level');
    final saved = (await views.list('ws-1')).single;
    expect(saved.definition!.query, {'cmp': 'previous', 'by': 'level'});
    expect(_query(tester)['saved'], saved.id);
    expect(_current(tester), 'By level');

    await _go(tester, '/bi?saved=standard');
    expect(_query(tester), {'saved': 'standard'});
    await _menu(tester, 'bi-views-open-${saved.id}');
    expect(_query(tester), {
      'cmp': 'previous',
      'by': 'level',
      'saved': saved.id,
    });

    await _menu(tester, 'bi-views-duplicate');
    final all = await views.list('ws-1');
    expect(all.map((v) => v.name), ['By level', 'By level (copy)']);
    expect(_current(tester), 'By level (copy)');

    await _menu(tester, 'bi-views-rename');
    await tester.enterText(find.byKey(const ValueKey('bi-views-name')), 'Copy');
    await tester.tap(find.byKey(const ValueKey('bi-views-name-ok')));
    await tester.pumpAndSettle();
    expect(_current(tester), 'Copy');

    await _menu(tester, 'bi-views-delete');
    await tester.tap(find.byKey(const ValueKey('bi-views-delete-confirm')));
    await tester.pumpAndSettle();
    expect((await views.list('ws-1')).map((v) => v.name), ['By level']);
    expect(_query(tester)['saved'], 'standard');
  });

  testWidgets('a fixed period is saved as that period', (tester) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    await _open(tester, '/bi?at=-1');
    await _saveAs(tester, 'February', fixed: true);
    expect((await views.list('ws-1')).single.definition!.query, {
      'at': '2026-02',
    });
  });

  testWidgets('my default opens a bare /bi and wins over the team default; '
      'clearing mine falls back to the team', (tester) async {
    final views = InMemoryBiViewRepository();
    final team = await views.save(
      'ws-1',
      scope: BiViewScope.workspace,
      name: 'Team',
      definition: const BiViewDefinition(query: {'grain': 'year'}),
      expectedRevision: 0,
    );
    await views.setDefault('ws-1', BiViewScope.workspace, team.id);
    final mine = await views.save(
      'ws-1',
      scope: BiViewScope.private,
      name: 'Mine',
      definition: const BiViewDefinition(query: {'grain': 'quarter'}),
      expectedRevision: 0,
    );
    await views.setDefault('ws-1', BiViewScope.private, mine.id);
    await _pump(tester, views);

    await _open(tester, '/bi');
    expect(_query(tester), {'grain': 'quarter', 'saved': mine.id});

    await _menu(tester, 'bi-views-clear-my-default');
    await _go(tester, '/bi');
    expect(_query(tester), {'grain': 'year', 'saved': team.id});
    expect(
      (await views.list('ws-1')).firstWhere((v) => v.id == team.id).isDefault,
      isTrue,
      reason: 'clearing my default leaves the team default alone',
    );
  });

  testWidgets('without the management right: no team option, and a team '
      'view can be opened and duplicated but not changed', (tester) async {
    final views = InMemoryBiViewRepository();
    final team = await views.save(
      'ws-1',
      scope: BiViewScope.workspace,
      name: 'Team',
      definition: const BiViewDefinition(),
      expectedRevision: 0,
    );
    views.canManage = false;
    await _pump(tester, views, manage: false);
    await _open(tester, '/bi?saved=${team.id}');
    await tester.tap(find.byKey(const ValueKey('bi-views')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bi-views-save')), findsNothing);
    expect(find.byKey(const ValueKey('bi-views-rename')), findsNothing);
    expect(find.byKey(const ValueKey('bi-views-delete')), findsNothing);
    expect(find.byKey(const ValueKey('bi-views-team-default')), findsNothing);
    expect(find.byKey(const ValueKey('bi-views-duplicate')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bi-views-save-as')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bi-views-scope')), findsNothing);
  });

  testWidgets('a lost update is refused and said', (tester) async {
    final views = InMemoryBiViewRepository();
    final v = await views.save(
      'ws-1',
      scope: BiViewScope.private,
      name: 'Mine',
      definition: const BiViewDefinition(),
      expectedRevision: 0,
    );
    await _pump(tester, views);
    await _open(tester, '/bi?saved=${v.id}');
    // Someone else saves it meanwhile (another tab, another session).
    await views.save(
      'ws-1',
      id: v.id,
      scope: BiViewScope.private,
      name: 'Mine',
      definition: const BiViewDefinition(query: {'grain': 'year'}),
      expectedRevision: 1,
    );
    await _menu(tester, 'bi-views-save');
    expect(find.textContaining('Someone saved this view'), findsOneWidget);
    expect((await views.list('ws-1')).single.definition!.query, {
      'grain': 'year',
    }, reason: 'the other save is not overwritten');
  });

  testWidgets('a view whose analyses are gone names what it leaves out; an '
      'unreadable one opens nothing', (tester) async {
    final views = InMemoryBiViewRepository();
    final partial = await views.save(
      'ws-1',
      scope: BiViewScope.private,
      name: 'Partial',
      definition: const BiViewDefinition(
        cards: ['finance.retired', 'capacity.seat_utilisation'],
      ),
      expectedRevision: 0,
    );
    await _pump(tester, views);
    await _open(tester, '/bi?saved=standard');
    await _menu(tester, 'bi-views-open-${partial.id}');
    expect(_query(tester)['cards'], 'capacity.seat_utilisation');
    expect(
      find.byKey(const ValueKey('bi-module-capacity.seat_utilisation')),
      findsOneWidget,
    );

    await _go(tester, '/bi?cards=finance.retired,capacity.seat_utilisation');
    expect(find.byKey(const ValueKey('bi-cards-unavailable')), findsOneWidget);

    const unreadable = BiSavedView(
      id: 'v-old',
      scope: BiViewScope.private,
      name: 'Old',
      definition: null,
      isDefault: false,
      revision: 1,
      mine: true,
    );
    final broken = _BrokenViews(unreadable);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, broken);
    await _open(tester, '/bi?saved=standard');
    await _menu(tester, 'bi-views-open-v-old');
    expect(find.textContaining('cannot be opened here'), findsOneWidget);
    expect(_query(tester), {'saved': 'standard'});
  });
}

/// A store holding one view this version cannot read.
class _BrokenViews extends InMemoryBiViewRepository {
  _BrokenViews(this.view);

  final BiSavedView view;

  @override
  Future<List<BiSavedView>> list(String workspaceId) async => [view];
}
