// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The two dashboards (the workspace overview and the analysis page) through
// the app, on the Demo, at a phone, a tablet and two desk widths: nothing
// overflows, the grid has as many columns as its own width holds for the
// named minimum tile width, and every figure is the Demo's own figure,
// the same at every width.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/ui/kit/dashboard_grid.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/presentation/screens/bi_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_module_section.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

const _widths = [390.0, 1024.0, 1440.0, 1920.0];

/// Tall enough that every tile of both pages is built: the figures are read
/// whole, the fit is a question of the width.
const _height = 2400.0;

Future<(DemoJourney, ProviderContainer)> _start(
  WidgetTester tester,
  double width,
) async {
  tester.view.physicalSize = Size(width, _height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start();
  addTearDown(journey.dispose);
  final spaces = journey.fixture.workspaces.workspaces;
  for (var i = 0; i < spaces.length; i++) {
    spaces[i] = spaces[i].copyWith(
      featureFlags: {...spaces[i].featureFlags, 'workspaceOverview': true},
    );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: journey.root,
      child: const DeskiloRoot(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DeskiloApp)),
  );
  return (journey, container);
}

String _keyOf(Widget w) => (w.key! as ValueKey<String>).value;

/// The texts of the widgets whose key starts with [prefix], by the rest of
/// the key.
Map<String, String> _figures(WidgetTester tester, String prefix) => {
  for (final t in tester.widgetList<Text>(
    find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.key is ValueKey<String> &&
          _keyOf(w).startsWith(prefix),
    ),
  ))
    _keyOf(t).substring(prefix.length): t.data!,
};

/// The figure of each analysis on the page, by its module id.
Map<String, String> _analysisFigures(WidgetTester tester) => {
  for (final card in tester.widgetList<Card>(
    find.byWidgetPredicate(
      (w) =>
          w is Card &&
          w.key is ValueKey<String> &&
          _keyOf(w).startsWith('bi-module-'),
    ),
  ))
    if (find
            .descendant(
              of: find.byKey(card.key!),
              matching: find.byKey(const ValueKey('bi-value')),
            )
            .evaluate()
            .firstOrNull
            ?.widget
        case final Text value)
      _keyOf(card).substring('bi-module-'.length): value.data!,
};

/// How many columns [grid] shows: the distinct left edges of its tiles.
int _columnsShown(WidgetTester tester, Finder grid) {
  final wrap = tester.widget<Wrap>(
    find.descendant(of: grid, matching: find.byType(Wrap)).first,
  );
  return {
    for (final tile in wrap.children)
      tester.getTopLeft(find.byWidget(tile)).dx.round(),
  }.length;
}

/// The columns [grid] should show: what its width holds, capped by its
/// tiles when they are fewer.
int _columnsExpected(WidgetTester tester, Finder grid, double minTileWidth) {
  final width = tester.getSize(grid).width;
  final tiles = tester.widget<DashboardGrid>(grid).children.length;
  final columns = dashboardColumns(width, minTileWidth: minTileWidth);
  return tiles < columns ? tiles : columns;
}

final _overviewFigures = <double, Map<String, String>>{};
final _analysisFiguresByWidth = <double, Map<String, String>>{};

void main() {
  for (final width in _widths) {
    testWidgets('the overview at ${width.toInt()}: no overflow, its own '
        'columns, the Demo figures', (tester) async {
      final (_, container) = await _start(tester, width);
      container.read(routerProvider).go('/workspace-overview');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'nothing overflows');

      final grids = find.byWidgetPredicate(
        (w) =>
            w is DashboardGrid &&
            w.key is ValueKey<String> &&
            _keyOf(w).startsWith('overview-grid-'),
      );
      expect(grids, findsWidgets, reason: 'the Demo owner reads figures');
      for (final e in grids.evaluate()) {
        final grid = find.byWidget(e.widget);
        expect(
          _columnsShown(tester, grid),
          _columnsExpected(tester, grid, kpiTileMinWidth),
          reason: '${_keyOf(e.widget)} at $width',
        );
      }

      // Each figure is what the Demo answers for the month, in the
      // module's own words.
      final shown = _figures(tester, 'overview-value-');
      expect(shown, isNotEmpty);
      final workspaceId = container.read(currentWorkspaceProvider).value!.id;
      final tile = find.byKey(ValueKey('overview-tile-${shown.keys.first}'));
      final locale = Localizations.localeOf(tester.element(tile)).toString();
      final modules = {for (final m in biModules) m.id: m};
      for (final MapEntry(key: id, value: text) in shown.entries) {
        final read = container.read(
          biModuleResultProvider(workspaceId, id, const BiQueryContext()),
        );
        final result = read.value;
        final known =
            result != null &&
            !result.total.current.quality.contains(KpiQuality.unavailable);
        expect(
          text,
          known
              ? biModuleViews[id]!.value(
                  result.total.current.value(modules[id]!.aggregation),
                  locale,
                  result.currency,
                )
              : AppLocalizationsEn().overviewUnavailable,
          reason: '$id at $width',
        );
      }
      expect(
        shown.values.where(
          (v) => v != AppLocalizationsEn().overviewUnavailable,
        ),
        isNotEmpty,
        reason: 'the Demo answers figures, not only refusals',
      );
      _overviewFigures[width] = shown;
      expect(
        shown,
        _overviewFigures[_widths.first],
        reason: 'the same figures at every width',
      );
    });

    testWidgets('the analysis page at ${width.toInt()}: no overflow, its '
        'own columns, the same figures', (tester) async {
      final (_, container) = await _start(tester, width);
      container.read(routerProvider).go('/bi');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'nothing overflows');
      expect(find.byType(BiScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bi-filter-bar')),
        findsOneWidget,
        reason: 'the filters stand in one bar above the grid',
      );

      final grids = find.byWidgetPredicate(
        (w) =>
            w is DashboardGrid &&
            w.key is ValueKey<String> &&
            _keyOf(w).startsWith('bi-grid-'),
      );
      expect(grids, findsWidgets);
      for (final e in grids.evaluate()) {
        final grid = find.byWidget(e.widget);
        expect(
          _columnsShown(tester, grid),
          _columnsExpected(tester, grid, biAnalysisMinWidth),
          reason: '${_keyOf(e.widget)} at $width',
        );
      }

      final shown = _analysisFigures(tester);
      expect(shown, isNotEmpty);
      // A narrow page builds fewer analyses in the window: every one built
      // at two widths reads the same.
      for (final MapEntry(key: w, value: before)
          in _analysisFiguresByWidth.entries) {
        for (final id in shown.keys.where(before.containsKey)) {
          expect(shown[id], before[id], reason: '$id at $width and $w');
        }
      }
      _analysisFiguresByWidth[width] = shown;
    });
  }
}
