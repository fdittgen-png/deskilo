// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2051 — the open-data import: every day a checkbox, the server's verdict
// shown, only the days the owner kept sent, and an unreachable source
// said as such.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/holiday_import.dart';
import 'package:deskilo/features/workspace/providers/holiday_import_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

class _FakeSource implements HolidaySource {
  _FakeSource({this.down = false});

  bool down;
  int calls = 0;

  @override
  Future<List<ImportedHoliday>> fetch(String country, int year) async {
    calls++;
    if (down) throw const HolidaySourceUnavailable('offline');
    return [
      (
        day: DateTime(year),
        localName: 'Neujahr',
        name: "New Year's Day",
        regions: const <String>[],
      ),
      (
        day: DateTime(year, 1, 6),
        localName: 'Heilige Drei Könige',
        name: 'Epiphany',
        regions: const ['DE-BY'],
      ),
      (
        day: DateTime(year, 5, 1),
        localName: 'Tag der Arbeit',
        name: 'Labour Day',
        regions: const <String>[],
      ),
      (
        day: DateTime(year, 7, 1),
        localName: 'Sommertag',
        name: 'Summer day',
        regions: const <String>[],
      ),
      (
        day: DateTime(year, 12, 25),
        localName: 'Weihnachtstag',
        name: 'Christmas Day',
        regions: const <String>[],
      ),
    ];
  }
}

Future<void> _open(
  WidgetTester tester,
  FakeWorkspaceRepository workspace,
  HolidaySource source,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 2700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        holidaySourceProvider.overrideWithValue(source),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/availability'));
  await tester.pumpAndSettle();
}

FakeWorkspaceRepository _workspace({bool importOn = true}) =>
    FakeWorkspaceRepository.withWorkspace(
      featureFlags: {'publicHolidays': true, 'holidayImport': importOn},
    );

const _tile = ValueKey('availability-holiday-import');

void main() {
  testWidgets('the action is absent until the feature is asked for', (
    tester,
  ) async {
    final source = _FakeSource();
    await _open(tester, _workspace(importOn: false), source);
    expect(find.byKey(_tile), findsNothing);
    expect(source.calls, 0);
  });

  testWidgets('the owner unticks a day; only the kept days are imported', (
    tester,
  ) async {
    final workspace = _workspace();
    await _open(tester, workspace, _FakeSource());
    await tester.ensureVisible(find.byKey(_tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();

    final preview = workspace.holidayImportCalls.single;
    expect(preview.apply, isFalse, reason: 'opening the sheet writes nothing');
    expect(workspace.closureDays, isEmpty);
    final y = preview.days.first.day.year;
    expect(preview.days.map((d) => d.name), [
      'Neujahr',
      'Tag der Arbeit',
      'Sommertag',
      'Weihnachtstag',
    ], reason: 'nationwide only until a region is chosen');

    // Labour Day stays open: the owner unticks it.
    await tester.tap(find.byKey(ValueKey('holiday-import-day-$y-05-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('holiday-import-confirm')));
    await tester.pumpAndSettle();

    final apply = workspace.holidayImportCalls.last;
    expect(apply.apply, isTrue);
    expect(apply.days.map((d) => d.name), [
      'Neujahr',
      'Sommertag',
      'Weihnachtstag',
    ]);
    expect(workspace.closureDays.map((c) => c.reason), [
      'Neujahr',
      'Sommertag',
      'Weihnachtstag',
    ]);
  });

  testWidgets('an invoiced month or an existing day cannot be ticked', (
    tester,
  ) async {
    final workspace = _workspace();
    workspace.invoicedMonths.add('${kTestNow.year}-07');
    await _open(tester, workspace, _FakeSource());

    await tester.ensureVisible(find.byKey(_tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    final year = workspace.holidayImportCalls.single.days.first.day.year;
    final summer = tester.widget<CheckboxListTile>(
      find.byKey(ValueKey('holiday-import-day-$year-07-01')),
    );
    expect(summer.value, isFalse);
    expect(summer.onChanged, isNull);
    expect(
      find.textContaining('$year-07'),
      findsWidgets,
      reason: 'the refused month is named',
    );
  });

  testWidgets('an unreachable source is said, and retried on demand', (
    tester,
  ) async {
    final workspace = _workspace();
    final source = _FakeSource(down: true);
    await _open(tester, workspace, source);

    await tester.ensureVisible(find.byKey(_tile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('holiday-import-unavailable')),
      findsOneWidget,
    );
    expect(workspace.holidayImportCalls, isEmpty);

    source.down = false;
    await tester.tap(find.byKey(const ValueKey('holiday-import-retry')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('holiday-import-unavailable')),
      findsNothing,
    );
    expect(workspace.holidayImportCalls.single.apply, isFalse);
  });
}
