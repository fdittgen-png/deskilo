// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The dashboard grid counts its columns from the width it really has and a
// named minimum tile width, never from the window class; a tile may span
// two; the filter bar stays in view while the grid scrolls; a trend's sign
// is said in words.
import 'package:deskilo/core/ui/kit/dashboard_grid.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// The width [n] tiles of [min] need side by side.
double _room(int n, double min) => n * min + (n - 1) * dashboardGap;

Future<void> _pumpGrid(
  WidgetTester tester,
  double width,
  List<Widget> children,
) async {
  await pumpApp(
    tester,
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: DashboardGrid(minTileWidth: kpiTileMinWidth, children: children),
      ),
    ),
    size: const Size(2400, 1200),
  );
  await tester.pumpAndSettle();
}

List<Widget> _tiles(int n) => [
  for (var i = 0; i < n; i++) SizedBox(key: ValueKey('t$i'), height: 40),
];

/// A box a hit test can find.
Widget _box(String key, {double? width, required double height}) => SizedBox(
  key: ValueKey(key),
  width: width,
  height: height,
  child: const ColoredBox(color: Colors.transparent),
);

void main() {
  test('the column count follows the room for the named minimum', () {
    for (var n = 1; n <= 4; n++) {
      final room = _room(n, kpiTileMinWidth);
      expect(
        dashboardColumns(room, minTileWidth: kpiTileMinWidth),
        n,
        reason: 'exactly $n tiles fit in $room',
      );
      if (n > 1) {
        expect(
          dashboardColumns(room - 1, minTileWidth: kpiTileMinWidth),
          n - 1,
          reason: 'one pixel short of $n tiles is ${n - 1}',
        );
      }
    }
    expect(
      dashboardColumns(
        _room(9, kpiTileMinWidth),
        minTileWidth: kpiTileMinWidth,
      ),
      4,
      reason: 'never more than four, however wide',
    );
    expect(dashboardColumns(1, minTileWidth: kpiTileMinWidth), 1);
    expect(
      dashboardColumns(
        _room(9, kpiTileMinWidth),
        minTileWidth: kpiTileMinWidth,
        maxColumns: 12,
      ),
      9,
    );
  });

  test('a row of tiles never adds up to more than the row', () {
    for (final width in [333.3, 517.7, 1001.9, 1639.1]) {
      final columns = dashboardColumns(width, minTileWidth: kpiTileMinWidth);
      final row =
          columns * dashboardTileWidth(width, columns, 1) +
          (columns - 1) * dashboardGap;
      expect(row, lessThanOrEqualTo(width), reason: '$width');
      expect(row, greaterThan(width - columns), reason: '$width');
    }
  });

  for (final n in [1, 2, 3, 4]) {
    testWidgets('$n tiles fit side by side in their room, and wrap one pixel '
        'short of it', (tester) async {
      final room = _room(n, kpiTileMinWidth);
      await _pumpGrid(tester, room, _tiles(n + 1));
      final tops = {
        for (var i = 0; i < n; i++)
          tester.getTopLeft(find.byKey(ValueKey('t$i'))).dy,
      };
      expect(tops, hasLength(1), reason: 'the first $n share one row');
      final row = tester.getTopLeft(find.byKey(const ValueKey('t0'))).dy;
      expect(
        tester.getTopLeft(find.byKey(ValueKey('t$n'))).dy,
        greaterThan(row),
        reason: 'tile ${n + 1} starts the next row',
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('t0'))).width,
        greaterThanOrEqualTo(kpiTileMinWidth - 1),
      );
      if (n > 1) {
        await _pumpGrid(tester, room - 1, _tiles(n));
        expect(
          tester.getTopLeft(find.byKey(ValueKey('t${n - 1}'))).dy,
          greaterThan(row),
          reason: 'one pixel short, the last of $n wraps',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a spanning tile takes two columns where there are two or '
      'more, and the whole row on one', (tester) async {
    const spanning = DashboardTile(
      span: 2,
      child: SizedBox(key: ValueKey('wide'), height: 40),
    );
    final room = _room(4, kpiTileMinWidth);
    await _pumpGrid(tester, room, [spanning, ..._tiles(2)]);
    final one = tester.getSize(find.byKey(const ValueKey('t0'))).width;
    final wide = tester.getSize(find.byKey(const ValueKey('wide'))).width;
    expect(wide, closeTo(2 * one + dashboardGap, 1));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('t1'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('wide'))).dy,
      reason: 'two columns spanned and two single ones fill one row',
    );

    await _pumpGrid(tester, kpiTileMinWidth, [spanning]);
    expect(
      tester.getSize(find.byKey(const ValueKey('wide'))).width,
      kpiTileMinWidth,
      reason: 'on one column it is the whole row',
    );
  });

  testWidgets('the filter bar stays in view while the grid scrolls, and '
      'holds the Export slot', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: DashboardScrollView(
          header: [_box('head', height: 120)],
          filterBar: FilterBar(
            key: const ValueKey('bar'),
            filters: Wrap(children: [_box('filter', width: 200, height: 48)]),
            actions: [
              IconButton(
                key: const ValueKey('export'),
                tooltip: 'Export',
                onPressed: () {},
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
          children: [
            DashboardGrid(
              minTileWidth: kpiTileMinWidth,
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(key: ValueKey('t$i'), height: 120),
              ],
            ),
          ],
        ),
      ),
      size: const Size(390, 700),
    );
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.byKey(const ValueKey('t0'))).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('head')).hitTestable(),
      findsNothing,
      reason: 'the header scrolled away',
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('t0'))).dy,
      lessThan(first),
      reason: 'the grid scrolled',
    );
    final bar = tester.getRect(find.byKey(const ValueKey('bar')));
    expect(bar.top, 0, reason: 'the filters are pinned at the top');
    expect(find.byKey(const ValueKey('filter')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('export')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a filter bar taller than its share scrolls inside itself and '
      'leaves the grid room', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: DashboardScrollView(
          filterBar: FilterBar(
            key: const ValueKey('bar'),
            filters: Wrap(
              children: [
                for (var i = 0; i < 30; i++)
                  _box('f$i', width: 200, height: 48),
              ],
            ),
          ),
          children: [_box('grid', height: 2000)],
        ),
      ),
      size: const Size(390, 700),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('bar'))).height,
      lessThan(700 / 2),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('grid'))).dy,
      lessThan(700 / 2),
      reason: 'the grid starts in the window, below the bar',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('f29')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('f29')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a figure tile says its trend in words, not by colour alone', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final en = AppLocalizationsEn();
    await pumpApp(
      tester,
      const Center(
        child: SizedBox(
          width: kpiTileMinWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KpiTile(
                key: ValueKey('up'),
                label: 'Invoiced',
                figure: '€1,200.00',
                note: 'This month',
                trend: KpiTrendDirection.up,
                trendChange: '+€150.00',
              ),
              KpiTile(
                key: ValueKey('down'),
                label: 'Collected',
                figure: '€900.00',
                trend: KpiTrendDirection.down,
                trendChange: '−€30.00',
              ),
              KpiTile(
                key: ValueKey('flat'),
                label: 'Members',
                figure: '5',
                trend: KpiTrendDirection.flat,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final (key, word) in [
      ('up', en.dashboardTrendUp),
      ('down', en.dashboardTrendDown),
      ('flat', en.dashboardTrendFlat),
    ]) {
      final mark = find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(KpiTrendMark),
      );
      expect(
        tester.getSemantics(mark).label,
        contains(word),
        reason: 'the $key arrow is said as a word',
      );
    }
    expect(KpiTrendDirection.of(3), KpiTrendDirection.up);
    expect(KpiTrendDirection.of(-0.5), KpiTrendDirection.down);
    expect(KpiTrendDirection.of(0), KpiTrendDirection.flat);
    expect(KpiTrendDirection.of(null), isNull);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
