// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 C2 — the overview's own layout: Customize pins, unpins and reorders
// the key-indicator tiles with buttons (focus stays on the tile that moved),
// Save keeps it as the person's own saved report, and it survives a restart;
// Cancel saves nothing; a layout changed elsewhere is reported, never
// overwritten; a report's layout is copied in; an unknown figure still reads
// "Not available"; without the report designer there is no Customize button.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/bi_overview_layout.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:deskilo/features/workspace/domain/cost_allocation_rules.dart';
import 'package:deskilo/features/workspace/domain/kpi_overview.dart';
import 'package:deskilo/features/workspace/domain/kpi_purchases.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/screens/workspace_overview_screen.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/cost_allocation_providers.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/overview_kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _pending = 'purchases.pending_reviews';
const _members = 'people.active_memberships_current';
const _overdue = 'sales.overdue_receivables';
const _costs = 'purchases.operating_costs';

class _Purchases implements PurchaseKpiRepository {
  @override
  Future<PurchaseSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => purchaseSummaryFromJson({
    'from': fromMonth,
    'to': toMonth,
    'currency': 'EUR',
    'ap_outstanding_minor': '400',
    'member_due_minor': '70',
    'pending_count': 2,
    'pending_minor': '500',
    'outflows_minor': '600',
    'outflows': 1,
    'quality': const <String>[],
    'reasons': const <String>[],
    'computed_at': '2026-05-02T10:00:00Z',
  });
}

class _Overview implements OverviewKpiRepository {
  @override
  Future<OverviewFigure> figure(
    String workspaceId,
    String kpiId, {
    required String fromMonth,
    required String toMonth,
  }) async => overviewFigureFromJson({
    'value': kpiId == _overdue ? '1200' : 5,
    'count': kpiId == _overdue ? 2 : 5,
    'currency': kpiId == _overdue ? 'EUR' : '',
    'unknown_due_count': 0,
    'held_count': 0,
    'quality': const <String>[],
    'reasons': const <String>[],
    'computed_at': '2026-05-02T10:00:00Z',
  });
}

/// The store, whose next answer can be lost after the write landed.
class _Flaky implements BiViewRepository {
  _Flaky(this.inner);

  final InMemoryBiViewRepository inner;
  bool loseNext = false;

  /// #3061 — when set, a save waits for it: the request is in flight.
  Completer<void>? hold;
  int saves = 0;

  @override
  Future<List<BiSavedView>> list(String workspaceId) => inner.list(workspaceId);

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
    saves++;
    await hold?.future;
    final saved = await inner.save(
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
      throw TimeoutException('the answer was lost');
    }
    return saved;
  }

  @override
  Future<void> delete(String workspaceId, String id, int expectedRevision) =>
      inner.delete(workspaceId, id, expectedRevision);

  @override
  Future<void> setDefault(String workspaceId, BiViewScope scope, String? id) =>
      inner.setDefault(workspaceId, scope, id);
}

List<Override> _overrides(BiViewRepository views, {bool designer = true}) => [
  ...standardTestOverrides(
    workspace: FakeWorkspaceRepository.withWorkspace(),
    biViews: views,
  ),
  enabledFeaturesSyncProvider.overrideWithValue({
    WorkspaceFeature.purchaseAnalytics,
    WorkspaceFeature.workspaceOverview,
    if (designer) WorkspaceFeature.biReportDesigner,
  }),
  myPermissionsProvider.overrideWithValue({
    WorkspacePermission.viewAnalytics,
    WorkspacePermission.viewFinances,
  }),
  attentionProvider.overrideWith((ref) async => const []),
  purchaseKpiRepositoryProvider.overrideWithValue(_Purchases()),
  overviewKpiRepositoryProvider.overrideWithValue(_Overview()),
  costKpiRepositoryProvider.overrideWithValue(
    const UnavailableCostKpiRepository(),
  ),
  costAllocationRepositoryProvider.overrideWithValue(
    const UnavailableCostAllocationRepository(),
  ),
];

Future<void> _pump(
  WidgetTester tester,
  BiViewRepository views, {
  bool designer = true,
}) async {
  await pumpApp(
    tester,
    const WorkspaceOverviewScreen(),
    size: const Size(1200, 3600),
    overrides: _overrides(views, designer: designer),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// The pinned tiles on screen, in their order.
List<String> _shown(WidgetTester tester) {
  final wrap = tester.widget<Wrap>(
    find.byKey(const ValueKey('overview-pinned')),
  );
  return [
    for (final c in wrap.children)
      ((c.key ?? const ValueKey('')) as ValueKey<String>).value,
  ];
}

/// The pinned tile ids in the editor, in order.
List<String> _drafted(WidgetTester tester) => [
  for (final e in tester.widgetList<Row>(
    find.byWidgetPredicate(
      (w) =>
          w is Row &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'overview-layout-tile-',
          ),
    ),
  ))
    (e.key! as ValueKey<String>).value.substring(
      'overview-layout-tile-'.length,
    ),
];

Future<List<String>> _saved(BiViewRepository views) async {
  final layout = biOverviewLayoutOf(await views.list('ws-1'));
  return layout == null ? const [] : biTilesOf(layout.definition!.report!);
}

void main() {
  testWidgets('pin, reorder and save: the layout survives a restart', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    await _pump(tester, views);
    expect(find.byKey(const ValueKey('overview-pinned')), findsNothing);
    await _tap(tester, 'overview-customize');
    final all = _drafted(tester);
    expect(all, containsAll([_pending, _members, _overdue]));

    // Unpin everything but three, then order them.
    for (final id in all) {
      if (![_pending, _members, _overdue].contains(id)) {
        await _tap(tester, 'overview-unpin-$id');
      }
    }
    expect(_drafted(tester), [_pending, _members, _overdue]);
    await _tap(tester, 'overview-later-$_pending');
    expect(_drafted(tester), [_members, _pending, _overdue]);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'overview-$_pending',
      reason: 'focus lands on the tile that moved',
    );
    await _tap(tester, 'overview-earlier-$_overdue');
    expect(_drafted(tester), [_members, _overdue, _pending]);

    await _tap(tester, 'overview-layout-save');
    expect(await _saved(views), [_members, _overdue, _pending]);
    expect(find.byKey(const ValueKey('overview-layout-editor')), findsNothing);
    expect(_shown(tester), [
      'overview-pinned-$_members',
      'overview-pinned-$_overdue',
      'overview-pinned-$_pending',
    ]);

    // A restart reads the same layout from the store.
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, views);
    expect(_shown(tester), [
      'overview-pinned-$_members',
      'overview-pinned-$_overdue',
      'overview-pinned-$_pending',
    ]);
    expect((await views.list('ws-1')).single.revision, 1);
  });

  testWidgets('pin a tile back; Cancel saves nothing', (tester) async {
    final views = InMemoryBiViewRepository();
    await views.save(
      'ws-1',
      scope: BiViewScope.private,
      name: 'My overview',
      definition: BiViewDefinition.ofReport(
        biOverviewReport([_members], title: 'Overview'),
      ),
      expectedRevision: 0,
    );
    await _pump(tester, views);
    expect(_shown(tester), ['overview-pinned-$_members']);
    await _tap(tester, 'overview-customize');
    await _tap(tester, 'overview-pin');
    await _tap(tester, 'overview-pin-$_costs');
    expect(_drafted(tester), [_members, _costs]);
    await _tap(tester, 'overview-layout-cancel');
    expect(await _saved(views), [_members]);
    expect(_shown(tester), ['overview-pinned-$_members']);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'overview-customize',
      reason: 'focus returns to the button that opened customizing',
    );

    await _tap(tester, 'overview-customize');
    await _tap(tester, 'overview-pin');
    await _tap(tester, 'overview-pin-$_costs');
    await _tap(tester, 'overview-layout-save');
    expect(await _saved(views), [_members, _costs]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-tile-$_costs')),
        matching: find.text('Not available'),
      ),
      findsOneWidget,
      reason: 'an unknown figure still reads Not available',
    );
  });

  testWidgets('a layout changed elsewhere is reported, never overwritten', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    final first = await views.save(
      'ws-1',
      scope: BiViewScope.private,
      name: 'My overview',
      definition: BiViewDefinition.ofReport(
        biOverviewReport([_members, _pending], title: 'Overview'),
      ),
      expectedRevision: 0,
    );
    await _pump(tester, views);
    await _tap(tester, 'overview-customize');
    await _tap(tester, 'overview-unpin-$_members');

    // Another device saves the layout meanwhile.
    await views.save(
      'ws-1',
      id: first.id,
      scope: BiViewScope.private,
      name: 'My overview',
      definition: BiViewDefinition.ofReport(
        biOverviewReport([_overdue], title: 'Overview'),
      ),
      expectedRevision: 1,
    );
    await _tap(tester, 'overview-layout-save');
    expect(
      find.byKey(const ValueKey('overview-layout-conflict')),
      findsOneWidget,
    );
    expect(await _saved(views), [_overdue], reason: 'nothing overwritten');
    await _tap(tester, 'overview-layout-reload');
    expect(_shown(tester), ['overview-pinned-$_overdue']);
  });

  testWidgets('a report\'s layout is copied in; the layout is saved as a '
      'report of its own', (tester) async {
    final views = InMemoryBiViewRepository();
    await views.save(
      'ws-1',
      scope: BiViewScope.private,
      name: 'Board',
      definition: BiViewDefinition.ofReport(
        BiReportDefinition.standard(
          query: BiQueryContext.standard,
          cards: [_overdue, _pending],
          pageTitle: 'Board',
        ),
      ),
      expectedRevision: 0,
    );
    await _pump(tester, views);
    await _tap(tester, 'overview-customize');
    await _tap(tester, 'overview-copy-from');
    final board = (await views.list('ws-1')).single;
    await _tap(tester, 'overview-copy-from-${board.id}');
    expect(_drafted(tester), [_overdue, _pending]);
    await _tap(tester, 'overview-copy-to');
    final names = [for (final v in await views.list('ws-1')) v.name];
    expect(names, contains('Overview (report)'));
    expect(
      biOverviewLayoutOf(await views.list('ws-1')),
      isNull,
      reason: 'the copy is a report, not the layout',
    );
  });

  testWidgets('without the report designer there is no Customize button', (
    tester,
  ) async {
    await _pump(tester, InMemoryBiViewRepository(), designer: false);
    expect(find.byKey(const ValueKey('overview-customize')), findsNothing);
    expect(find.byKey(const ValueKey('overview-group-sales')), findsOneWidget);
  });

  testWidgets('a lost answer is retried as the same request: one layout, '
      'one revision', (tester) async {
    final inner = InMemoryBiViewRepository();
    final views = _Flaky(inner);
    await _pump(tester, views);
    await _tap(tester, 'overview-customize');
    for (final id in _drafted(tester)) {
      if (id != _members) await _tap(tester, 'overview-unpin-$id');
    }
    views.loseNext = true;
    await _tap(tester, 'overview-layout-save');
    expect(find.byKey(const ValueKey('overview-layout-lost')), findsOneWidget);
    expect(_drafted(tester), [_members], reason: 'the draft is kept');

    await _tap(tester, 'overview-layout-retry');
    expect(find.byKey(const ValueKey('overview-layout-editor')), findsNothing);
    final all = await inner.list('ws-1');
    expect(all, hasLength(1));
    expect(all.single.revision, 1, reason: 'the retry was answered once');
    expect(await _saved(inner), [_members]);
  });

  testWidgets('#3061 — Save enters pending at once; a second activation while '
      'the request is in flight is one command, and the draft is kept', (
    tester,
  ) async {
    final inner = InMemoryBiViewRepository();
    final views = _Flaky(inner)..hold = Completer<void>();
    await _pump(tester, views);
    await _tap(tester, 'overview-customize');
    for (final id in _drafted(tester)) {
      if (id != _members) await _tap(tester, 'overview-unpin-$id');
    }
    final save = find.byKey(const ValueKey('overview-layout-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    expect(views.saves, 1, reason: 'one effective command');
    expect(_drafted(tester), [_members], reason: 'the draft stays meanwhile');

    views.hold!.complete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await inner.list('ws-1'), hasLength(1));
  });

  testWidgets('with the designer off, a saved layout gives way to the '
      'registry\'s groups', (tester) async {
    final views = InMemoryBiViewRepository();
    await views.save(
      'ws-1',
      scope: BiViewScope.private,
      name: 'My overview',
      definition: BiViewDefinition.ofReport(
        biOverviewReport([_members], title: 'Overview'),
      ),
      expectedRevision: 0,
    );
    await _pump(tester, views, designer: false);
    expect(find.byKey(const ValueKey('overview-pinned')), findsNothing);
    expect(find.byKey(const ValueKey('overview-group-sales')), findsOneWidget);
  });
}
