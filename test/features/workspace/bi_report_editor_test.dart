// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2580 — the report editor at /bi/report/<id>, driven by its controls and
// keys, not by screenshots:
//   * Edit report opens it from the analytics page; Alt+arrows move the
//     focused visual (focus stays on it), Shift+arrows resize it; Undo/Redo
//     step back and forth; Save writes one revision with the same ids; Close
//     returns to the analytics page; reopening shows what was saved;
//   * leaving with unsaved changes asks Save / Discard / Keep editing, and
//     Keep editing or Discard saves nothing;
//   * a save that lost the race is a conflict: nothing is overwritten, and
//     the draft is kept as a private copy on request, the original unchanged;
//   * a save whose answer was lost is retried as the same request: one
//     revision;
//   * styling performs no read, and a duplicated figure reuses its answer;
//   * on a 360 px screen the panels are labelled sheets and focus returns to
//     the selected visual when one closes;
//   * a report with figures withheld from the reader is not edited, and the
//     editor does not open while the designer is off.
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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/unavailable_kpi_repository.dart';

class _Finance implements FinanceKpiRepository {
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

/// The store, whose next answer can be lost after the write landed.
class _Flaky implements BiViewRepository {
  _Flaky(this.inner);

  final InMemoryBiViewRepository inner;
  bool loseNext = false;

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

const _capacity = 'capacity.seat_utilisation';
const _invoiced = 'finance.invoiced';

/// Page 1: a capacity figure and a floor bar; page 2: a finance table.
BiReportDefinition _report() => BiReportDefinition(
  period: const BiReportPeriod.relative(BiGrain.month, 0),
  pages: [
    BiReportPage(
      id: 'p1',
      title: 'Capacity',
      visuals: [
        BiReportVisual.kpi(
          id: 'v1',
          metricId: _capacity,
          layout: const BiVisualLayout(order: 0, span: 3, height: 1),
        ),
        BiReportVisual.kpi(
          id: 'v2',
          metricId: _capacity,
          layout: const BiVisualLayout(order: 1),
        ).copyWith(type: BiVisualType.bar, dimension: 'level'),
      ],
    ),
    BiReportPage(
      id: 'p2',
      title: 'Finance',
      visuals: [
        BiReportVisual.kpi(
          id: 'v3',
          metricId: _invoiced,
          layout: const BiVisualLayout(order: 0),
        ).copyWith(type: BiVisualType.table),
      ],
    ),
  ],
);

Future<String> _seed(BiViewRepository views) async => (await views.save(
  'ws-1',
  scope: BiViewScope.private,
  name: 'Mine',
  definition: BiViewDefinition.ofReport(_report()),
  expectedRevision: 0,
)).id;

Future<void> _pump(
  WidgetTester tester,
  BiViewRepository views, {
  Size size = const Size(1400, 2600),
  bool designer = true,
  bool web = true,
  _Finance? finance,
}) async {
  tester.view.physicalSize = size;
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
          financeKpis: finance ?? _Finance(),
          biViews: views,
        ),
        platformIsWebProvider.overrideWithValue(web),
        webShellProvider.overrideWithValue(web),
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

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)).first);
  await tester.tap(find.byKey(ValueKey(key)).first);
  await tester.pumpAndSettle();
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

/// The visuals of the page in the outline, top to bottom.
List<String> _outline(WidgetTester tester) {
  final tiles = find.byWidgetPredicate(
    (w) =>
        w is ListTile &&
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('bi-outline-'),
  );
  final found = [
    for (final e in tiles.evaluate())
      (
        ((e.widget.key! as ValueKey<String>).value).substring(
          'bi-outline-'.length,
        ),
        tester.getTopLeft(find.byWidget(e.widget)).dy,
      ),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final f in found) f.$1];
}

List<String> _savedIds(BiSavedView view, int page) => [
  for (final v in [
    ...view.definition!.report!.pages[page].visuals,
  ]..sort((a, b) => a.layout.order.compareTo(b.layout.order)))
    v.id,
];

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  testWidgets('keyboard move and resize, undo/redo, save, reopen', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    final id = await _seed(views);
    await _pump(tester, views);
    await _open(tester, '/bi?saved=$id');
    await _tap(tester, 'bi-report-open-editor');
    expect(find.byKey(const ValueKey('bi-editor-canvas')), findsOneWidget);
    expect(_outline(tester), ['v1', 'v2']);

    await _tap(tester, 'bi-visual-select-v2');
    expect(_focused, 'bi-visual-v2');
    await _chord(
      tester,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowUp,
    );
    expect(_outline(tester), ['v2', 'v1']);
    expect(_focused, 'bi-visual-v2', reason: 'focus stays on the moved card');
    await _chord(
      tester,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.arrowRight,
    );
    expect(find.textContaining('7 of 12 columns'), findsOneWidget);

    await _tap(tester, 'bi-editor-undo');
    expect(find.textContaining('6 of 12 columns'), findsOneWidget);
    await _tap(tester, 'bi-editor-undo');
    expect(_outline(tester), ['v1', 'v2']);
    await _tap(tester, 'bi-editor-redo');
    expect(_outline(tester), ['v2', 'v1']);

    await _tap(tester, 'bi-editor-save');
    final saved = (await views.list('ws-1')).single;
    expect(saved.revision, 2);
    expect(_savedIds(saved, 0), ['v2', 'v1']);
    expect(_savedIds(saved, 1), ['v3'], reason: 'the other page is as it was');

    await _tap(tester, 'bi-editor-cancel');
    expect(find.byKey(const ValueKey('bi-editor-canvas')), findsNothing);
    expect(find.byKey(const ValueKey('bi-report-open-editor')), findsOneWidget);
    await _open(tester, '/bi/report/$id');
    expect(_outline(tester), ['v2', 'v1']);
  });

  testWidgets('leaving unsaved asks; Keep editing and Discard save nothing', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    final id = await _seed(views);
    await _pump(tester, views);
    await _open(tester, '/bi/report/$id');
    await _tap(tester, 'bi-visual-select-v1');
    await _tap(tester, 'bi-prop-delete-v1');
    expect(_outline(tester), ['v2']);

    await _tap(tester, 'bi-editor-cancel');
    expect(find.byKey(const ValueKey('bi-editor-leave')), findsOneWidget);
    await _tap(tester, 'bi-editor-keep-editing');
    expect(find.byKey(const ValueKey('bi-editor-canvas')), findsOneWidget);
    expect(_outline(tester), ['v2'], reason: 'the draft is kept');

    await _tap(tester, 'bi-editor-cancel');
    await _tap(tester, 'bi-editor-discard');
    expect(find.byKey(const ValueKey('bi-editor-canvas')), findsNothing);
    final stored = (await views.list('ws-1')).single;
    expect(stored.revision, 1);
    expect(_savedIds(stored, 0), ['v1', 'v2']);
  });

  testWidgets('a conflict overwrites nothing; mine becomes a private copy', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    final id = await _seed(views);
    await _pump(tester, views);
    await _open(tester, '/bi/report/$id');
    await _tap(tester, 'bi-visual-select-v1');
    await _tap(tester, 'bi-prop-delete-v1');

    // Another tab saves the report meanwhile.
    await views.save(
      'ws-1',
      id: id,
      scope: BiViewScope.private,
      name: 'Theirs',
      definition: BiViewDefinition.ofReport(_report()),
      expectedRevision: 1,
    );
    await _tap(tester, 'bi-editor-save');
    expect(find.byKey(const ValueKey('bi-editor-conflict')), findsOneWidget);
    var all = await views.list('ws-1');
    expect(all.single.name, 'Theirs', reason: 'nothing was overwritten');
    expect(all.single.revision, 2);

    await _tap(tester, 'bi-editor-keep-copy');
    all = await views.list('ws-1');
    expect(all, hasLength(2));
    final copy = all.firstWhere((v) => v.id != id);
    expect(copy.scope, BiViewScope.private);
    expect(_savedIds(copy, 0), ['v2']);
    final original = all.firstWhere((v) => v.id == id);
    expect(original.revision, 2);
    expect(_savedIds(original, 0), ['v1', 'v2'], reason: 'left unchanged');
    expect(find.text(copy.name), findsWidgets, reason: 'the copy is open');
  });

  testWidgets('a lost answer is retried as the same request: one revision', (
    tester,
  ) async {
    final inner = InMemoryBiViewRepository();
    final views = _Flaky(inner);
    final id = await _seed(views);
    await _pump(tester, views);
    await _open(tester, '/bi/report/$id');
    await _tap(tester, 'bi-visual-select-v1');
    await _tap(tester, 'bi-prop-delete-v1');

    views.loseNext = true;
    await _tap(tester, 'bi-editor-save');
    expect(find.byKey(const ValueKey('bi-editor-lost')), findsOneWidget);
    expect((await inner.list('ws-1')).single.revision, 2);

    await _tap(tester, 'bi-editor-retry');
    expect(find.byKey(const ValueKey('bi-editor-lost')), findsNothing);
    final stored = (await inner.list('ws-1')).single;
    expect(stored.revision, 2, reason: 'the retry was answered once');
    expect(_savedIds(stored, 0), ['v2']);
  });

  testWidgets('styling reads nothing; a duplicated figure reuses its answer', (
    tester,
  ) async {
    final finance = _Finance();
    final views = InMemoryBiViewRepository();
    final id = await _seed(views);
    await _pump(tester, views, finance: finance);
    await _open(tester, '/bi/report/$id');
    await _tap(tester, 'bi-editor-page-p2');
    await _tap(tester, 'bi-visual-select-v3');
    final reads = finance.calls;
    expect(reads, greaterThan(0));
    expect(find.byKey(const ValueKey('bi-visual-note-v3')), findsOneWidget);

    await _tap(tester, 'bi-prop-note-v3');
    await _tap(tester, 'bi-prop-legend-v3');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('bi-prop-title-v3')),
        matching: find.byType(EditableText),
      ),
      'Invoiced this month',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bi-visual-note-v3')), findsNothing);
    expect(find.text('Invoiced this month'), findsWidgets);
    await _tap(tester, 'bi-prop-duplicate-v3');
    expect(_outline(tester), ['v3', 'v4']);
    expect(finance.calls, reads, reason: 'no read for style or a duplicate');
  });

  testWidgets('at 360 px the panels are sheets; focus returns to the card', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    final id = await _seed(views);
    await _pump(tester, views, size: const Size(360, 2000), web: false);
    await _open(tester, '/bi/report/$id');
    expect(find.byKey(const ValueKey('bi-prop-report-name')), findsNothing);
    expect(find.byKey(const ValueKey('bi-editor-open-pages')), findsOneWidget);

    await _tap(tester, 'bi-visual-select-v1');
    await _tap(tester, 'bi-editor-open-properties');
    expect(find.byKey(const ValueKey('bi-prop-title-v1')), findsOneWidget);
    await _tap(tester, 'bi-prop-width-v1-more');
    Navigator.of(tester.element(find.byKey(const ValueKey('bi-prop-title-v1'))))
        .pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bi-prop-title-v1')), findsNothing);
    expect(_focused, 'bi-visual-v1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('withheld figures: not edited here; designer off: no editor', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    final id = await _seed(views);
    views.readable = {_capacity};
    await _pump(tester, views);
    await _open(tester, '/bi/report/$id');
    expect(
      find.byKey(const ValueKey('bi-editor-not-editable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bi-editor-canvas')), findsNothing);
  });

  testWidgets('the designer off sends the editor\'s address to the analytics', (
    tester,
  ) async {
    final views = InMemoryBiViewRepository();
    final id = await _seed(views);
    await _pump(tester, views, designer: false);
    await _open(tester, '/bi/report/$id');
    expect(find.byKey(const ValueKey('bi-editor-canvas')), findsNothing);
    expect(find.byKey(const ValueKey('bi-editor-not-editable')), findsNothing);
  });
}
