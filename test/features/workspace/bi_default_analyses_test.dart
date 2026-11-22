// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4340 — the analyses page remembers each person's chosen analyses and their order: choosing
// them in "Analyses shown" keeps them as the person's own default for the business (on the
// server, so on any device), a bare /bi opens them again, an address or an opened saved view wins
// for that visit, "Back to the standard" clears the default, an analysis that is no longer
// available is left out and the rest keep their order, and the rows drag into a new order (the
// arrows stay for the keyboard and a screen reader).

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
  Size size = const Size(1200, 2400),
  Map<String, bool> flags = const {'capacityKpi': true, 'workspaceStatus': true},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final kpis = _Kpis();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: flags,
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

/// Frames enough for a route, a dialog and a request answered by the in-memory server.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _go(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
  await _settle(tester);
}

Map<String, String> _query(WidgetTester tester) =>
    GoRouterState.of(tester.element(find.byKey(const ValueKey('bi-page')))).uri.queryParameters;

List<String> _cards(WidgetTester tester) => (_query(tester)['cards'] ?? '').split(',').where((c) => c.isNotEmpty).toList();

Future<void> _choose(WidgetTester tester, {List<String> up = const [], List<String> off = const []}) async {
  await tester.ensureVisible(find.byKey(const ValueKey('bi-cards')));
  await tester.tap(find.byKey(const ValueKey('bi-cards')));
  await _settle(tester);
  for (final id in off) {
    await tester.tap(find.byKey(ValueKey('bi-card-$id')));
  }
  for (final id in up) {
    await tester.tap(find.byKey(ValueKey('bi-card-up-$id')));
  }
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('bi-cards-ok')));
  await _settle(tester);
}

Future<BiSavedView?> _mine(InMemoryBiViewRepository views) async =>
    (await views.list('ws-1')).where((v) => v.isDefault && v.scope == BiViewScope.private).firstOrNull;

void main() {
  testWidgets('the analyses a person chose open again on a bare /bi, in their order', (tester) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    await _go(tester, '/bi');
    expect(await _mine(views), isNull, reason: 'nothing is remembered until the person chooses');
    await _choose(tester, off: const ['capacity.seat_utilisation'], up: const ['finance.collected']);
    final chosen = _cards(tester);
    expect(chosen.first, 'finance.collected');
    expect(chosen, isNot(contains('capacity.seat_utilisation')));
    final saved = await _mine(views);
    expect(saved, isNotNull, reason: 'kept on the server as the person\'s own default');
    expect(saved!.definition!.cards, chosen);

    // another visit (the page is left and a bare /bi is asked for again)
    await _go(tester, '/reserve');
    await _go(tester, '/bi');
    expect(_cards(tester), chosen, reason: 'the default opens again, in its order');
  });

  testWidgets('an address that names analyses, or an opened saved view, wins for that visit', (tester) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    await _go(tester, '/bi');
    await _choose(tester, off: const ['capacity.seat_utilisation']);
    final remembered = _cards(tester);
    await _go(tester, '/bi?cards=capacity.seat_utilisation');
    expect(_cards(tester), ['capacity.seat_utilisation'], reason: 'the address wins');
    await _go(tester, '/bi?saved=standard');
    expect(_query(tester), {'saved': 'standard'}, reason: 'an opened view wins: the default is not applied');
    await _go(tester, '/bi');
    expect(_cards(tester), remembered, reason: 'and the default is still there for the next bare visit');
  });

  testWidgets('"Back to the standard" clears the default', (tester) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    await _go(tester, '/bi');
    await _choose(tester, off: const ['capacity.seat_utilisation']);
    expect(await _mine(views), isNotNull);
    await tester.tap(find.byKey(const ValueKey('bi-cards')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('bi-cards-standard')));
    await _settle(tester);
    expect(_cards(tester), isEmpty, reason: 'the standard analyses');
    expect(await _mine(views), isNull, reason: 'no default is left');
    expect((await views.list('ws-1')).where((v) => v.mine), isEmpty, reason: 'and the view that held it is gone');
    await _go(tester, '/reserve');
    await _go(tester, '/bi');
    expect(_cards(tester), isEmpty);
  });

  testWidgets('an analysis the person cannot see (its feature is off) is left out, the rest keep their order', (tester) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    final saved = await views.save(
      'ws-1',
      scope: BiViewScope.private,
      name: 'My analyses',
      definition: const BiViewDefinition(
        cards: ['finance.collected', 'purchases.ap_outstanding', 'capacity.seat_utilisation'],
      ),
      expectedRevision: 0,
    );
    await views.setDefault('ws-1', BiViewScope.private, saved.id);
    await _go(tester, '/bi');
    expect(_cards(tester), ['finance.collected', 'capacity.seat_utilisation']);
  });

  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the rows of "Analyses shown" drag into a new order, from a visible 48 dp handle', (tester) async {
        final views = InMemoryBiViewRepository();
        await _pump(tester, views, size: size);
        await _go(tester, '/bi');
        await tester.ensureVisible(find.byKey(const ValueKey('bi-cards')));
        await tester.tap(find.byKey(const ValueKey('bi-cards')));
        await _settle(tester);
        final handle = find.byKey(const ValueKey('bi-card-handle-capacity.seat_utilisation'));
        expect(handle, findsOneWidget);
        expect(tester.getSize(handle), const Size(48, 48));
        final before = tester.getTopLeft(find.byKey(const ValueKey('bi-card-capacity.seat_utilisation'))).dy;
        final gesture = await tester.startGesture(tester.getCenter(handle));
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 20));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await gesture.up();
        await _settle(tester);
        final after = tester.getTopLeft(find.byKey(const ValueKey('bi-card-capacity.seat_utilisation'))).dy;
        expect(after, greaterThan(before), reason: 'the dragged row moved down');
        await tester.tap(find.byKey(const ValueKey('bi-cards-ok')));
        await _settle(tester);
        expect(_cards(tester).first, isNot('capacity.seat_utilisation'));
        expect(await _mine(views), isNotNull, reason: 'the new order is remembered');
      });

      testWidgets('the arrows still reorder: the way for the keyboard and a screen reader', (tester) async {
        final views = InMemoryBiViewRepository();
        await _pump(tester, views, size: size);
        await _go(tester, '/bi');
        await _choose(tester, up: const ['finance.collected']);
        final cards = _cards(tester);
        expect(cards.indexOf('finance.collected'), lessThan(cards.indexOf('finance.invoiced')));
      });
    });
  }
}
