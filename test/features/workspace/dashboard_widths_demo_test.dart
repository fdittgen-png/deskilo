// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The two dashboards (the workspace overview and the analysis page) through
// the app, on the Demo, at a phone, a tablet and two desk widths: nothing
// overflows, the grid has as many columns as its own width holds for the
// named minimum tile width, and every figure is the Demo's own figure,
// the same at every width.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/app/shell/desk_scaffold.dart';
import 'package:deskilo/core/theme/app_spacing.dart';
import 'package:deskilo/core/ui/adaptive/page_measure.dart';
import 'package:deskilo/core/ui/adaptive/window_class.dart';
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
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_analyses.dart';
import '../../helpers/demo_journey.dart';
import '../../ux/experience_guards.dart';

const _widths = [390.0, 800.0, 1024.0, 1440.0, 1920.0];

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
  await loadSheetFonts();
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

/// The desk's divider beside its navigation (`VerticalDivider(width: 1)`).
const _deskDivider = 1.0;

/// With SHEET=1 the whole window is written to
/// `build/sheets/dashboard/<name>.png` once the page's checks passed (the
/// shared helper draws the first repaint boundary, a part of the desk's
/// navigation here). The real time that takes lets failed reads schedule
/// their retries, which are run out before the test ends.
Future<void> _sheet(WidgetTester tester, String name) async {
  if (Platform.environment['SHEET'] == '1') {
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final image = await tester.runAsync(
      () => layer.toImage(Offset.zero & size),
    );
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    final dir = Directory('build/sheets/dashboard')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(seconds: 10));
  }
}

/// The width of a dashboard's grid in a [window] wide window, from the named
/// measures: the desk's navigation beside it from the expanded class (a rail,
/// a sidebar from the large one), the work area's gutters and its maximum,
/// then the page's own [padding] on each side. Below the expanded class the
/// page has the whole window, as it had in the frame.
double _gridWidth(double window, double padding) {
  final kind = WindowClass.ofWidth(window);
  final navigation = kind.atLeast(WindowClass.large)
      ? DeskScaffold.sidebarWidth
      : kind.atLeast(WindowClass.expanded)
      ? DeskScaffold.railWidth
      : 0.0;
  // The desk draws a hairline between its navigation and the page.
  final room = navigation == 0 ? window : window - navigation - _deskDivider;
  final page = (room - 2 * WorkArea.gutterFor(room)).clamp(
    0.0,
    kWorkAreaMaxWidth,
  );
  return page - 2 * padding;
}

/// On the overview, the figures the server's own rule leaves unknown in the
/// Demo's month (said "Not available", never 0), each with that rule's
/// reason: no confirmed book values tile the month (`kpi_costs_summary`,
/// 0532), or a share of nothing (no invoice of the month to share among
/// customers, no bill dated by its supplier, no order delivered yet). They
/// are answers, not failures: the analysis page shows each as a figure.
const _overviewUnknown = {
  'assets.book_depreciation': 'book_coverage_incomplete',
  'finance.contribution_after_depreciation': 'book_coverage_incomplete',
  'customers.concentration': 'nothing_to_share',
  'vendors.billing_lag': 'nothing_to_share',
  'vendors.delivery': 'nothing_to_share',
};

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
          tester.getSize(grid).width,
          _gridWidth(width, AppSpacing.screenGutter),
          reason: '${_keyOf(e.widget)} at $width',
        );
        expect(
          _columnsShown(tester, grid),
          _columnsExpected(tester, grid, kpiTileMinWidth),
          reason: '${_keyOf(e.widget)} at $width',
        );
      }

      // Each figure is what the Demo answers for the month, in the
      // module's own words.
      final shown = _figures(tester, 'overview-value-');
      expect(
        {
          for (final MapEntry(:key, :value) in shown.entries)
            if (value == AppLocalizationsEn().overviewUnavailable) key,
        },
        {
          for (final id in shown.keys)
            if (demoServerOnlyAnalyses.contains(id) ||
                _overviewUnknown.containsKey(id))
              id,
        },
        reason: 'only the figures the rule leaves unknown are unavailable',
      );
      expect(shown, isNotEmpty);
      final workspaceId = container.read(currentWorkspaceProvider).value!.id;
      final tile = find.byKey(ValueKey('overview-tile-${shown.keys.first}'));
      final locale = Localizations.localeOf(tester.element(tile)).toString();
      final modules = {for (final m in biModules) m.id: m};
      for (final MapEntry(key: id, value: text) in shown.entries) {
        final read = container.read(
          biModuleResultProvider(workspaceId, id, const BiQueryContext()),
        );
        expect(
          read.hasError,
          demoServerOnlyAnalyses.contains(id),
          reason: 'the Demo answers $id from its own data',
        );
        if (_overviewUnknown[id] case final reason?) {
          expect(read.value!.total.current.reasons, contains(reason));
        }
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
      await _sheet(tester, 'overview-${width.toInt()}');
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
          tester.getSize(grid).width,
          _gridWidth(width, AppSpacing.md),
          reason: '${_keyOf(e.widget)} at $width',
        );
        expect(
          _columnsShown(tester, grid),
          _columnsExpected(tester, grid, biAnalysisMinWidth),
          reason: '${_keyOf(e.widget)} at $width',
        );
      }

      final shown = _analysisFigures(tester);
      final cards = {
        for (final c in tester.widgetList<Card>(
          find.byWidgetPredicate(
            (w) =>
                w is Card &&
                w.key is ValueKey<String> &&
                _keyOf(w).startsWith('bi-module-'),
          ),
        ))
          _keyOf(c).substring('bi-module-'.length): find
              .descendant(
                of: find.byKey(c.key!),
                matching: find.byKey(const ValueKey('bi-unavailable')),
              )
              .evaluate()
              .isNotEmpty,
      };
      expect(
        {
          for (final MapEntry(:key, :value) in cards.entries)
            if (value) key,
        },
        {
          for (final id in cards.keys)
            if (demoServerOnlyAnalyses.contains(id)) id,
        },
        reason: 'no analysis fails in the Demo (#3785)',
      );
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
      await _sheet(tester, 'bi-${width.toInt()}');
      // Scrolled: the analyses move under the filter bar, which stays.
      await tester.drag(
        find.byKey(const ValueKey('bi-page')),
        const Offset(0, -_height / 2),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('bi-filter-bar'))).top,
        greaterThanOrEqualTo(0),
      );
      expect(
        find.byKey(const ValueKey('bi-filter-bar')).hitTestable(),
        findsOneWidget,
        reason: 'the filter bar stays in view while the grid scrolls',
      );
      await _sheet(tester, 'bi-${width.toInt()}-scrolled');
    });
  }
}
