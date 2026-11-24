// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- Settings > Units of measure as a person uses it, at a phone and a desk width: the units are listed by what they
// measure with their conversion line (1 km = 1000 m); a new unit is made from a code, a name, what it measures and its factor
// (the fields name their own problem); a built-in takes a word of the business's own but not another factor; an unused unit is
// archived and shown again, a used one is refused in words; a failed read says so and reads again.
import 'package:deskilo/core/demo/data/demo_workspace_units.dart';
import 'package:deskilo/core/ui/async_read_body.dart';
import 'package:deskilo/core/ui/form_kit.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:deskilo/features/stock/presentation/units_of_measure_screen.dart';
import 'package:deskilo/features/stock/providers/workspace_units_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<DemoWorkspaceUnits> _open(
  WidgetTester tester,
  Size size, {
  WorkspaceUnits Function(WorkspaceUnits)? wrap,
  Future<void> Function(DemoWorkspaceUnits)? seed,
}) async {
  final units = DemoWorkspaceUnits();
  await seed?.call(units);
  await pumpApp(
    tester,
    const UnitsOfMeasureScreen(),
    size: size,
    overrides: [...standardTestOverrides(), workspaceUnitsProvider.overrideWithValue(wrap == null ? units : wrap(units))],
  );
  await _frames(tester);
  return units;
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

/// Brings the element under [key] fully into view, then lets the frame settle.
Future<void> _reveal(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pump();
}

/// Picks "Length" in the dimension field of the open sheet.
Future<void> _pickLength(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('measure-unit-dimension')));
  await _frames(tester);
  await tester.tap(find.text(_en.measureDimensionLength).last);
  await _frames(tester);
}

Future<void> _drum(DemoWorkspaceUnits units) =>
    units.save('ws-1', requestId: 'seed', draft: const MeasureUnitDraft(code: 'drum', label: 'Cable drum', dimension: UnitDimension.length, factorNum: 50));

class _Flaky implements WorkspaceUnits {
  _Flaky(this._inner);

  final WorkspaceUnits _inner;
  int reads = 0;

  @override
  Future<List<WorkspaceUnit>> units(String workspaceId) => ++reads == 1 ? Future.error(Exception('down')) : _inner.units(workspaceId);

  @override
  Future<WorkspaceUnit> save(String workspaceId, {required String requestId, required MeasureUnitDraft draft}) =>
      _inner.save(workspaceId, requestId: requestId, draft: draft);

  @override
  Future<void> archive(String workspaceId, {required String requestId, required String code, required bool archived}) =>
      _inner.archive(workspaceId, requestId: requestId, code: code, archived: archived);
}

void main() {
  for (final (name, size) in [('a phone', const Size(390, 844)), ('a desk', const Size(1440, 900))]) {
    group('on $name', () {
      testWidgets('the units are listed by what they measure, each with its conversion line', (tester) async {
        await _open(tester, size);
        expect(find.byKey(const ValueKey('measure-dimension-length')), findsOneWidget);
        expect(find.byKey(const ValueKey('measure-dimension-mass')), findsOneWidget);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('measure-unit-km')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.descendant(of: find.byKey(const ValueKey('measure-unit-km')), matching: find.textContaining('1 km = 1000 m')), findsOneWidget);
        expect(find.descendant(of: find.byKey(const ValueKey('measure-unit-km')), matching: find.textContaining(_en.measureUnitBuiltIn)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a new unit is made from a code, a name, a dimension and a factor', (tester) async {
        final units = await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('measure-units-new')));
        await _frames(tester);
        await _enter(tester, 'measure-unit-code', 'drum');
        await _enter(tester, 'measure-unit-name', 'Cable drum');
        await _pickLength(tester);
        await _enter(tester, 'measure-unit-factor', '50');
        await tester.tap(find.byKey(const ValueKey('measure-unit-save')));
        await _frames(tester);
        final drum = (await units.units('ws-1')).firstWhere((u) => u.code == 'drum');
        expect([drum.label, drum.dimension, drum.factorNum, drum.factorDen], ['Cable drum', UnitDimension.length, 50, 1]);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('measure-unit-drum')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.descendant(of: find.byKey(const ValueKey('measure-unit-drum')), matching: find.textContaining('1 drum = 50 m')), findsOneWidget);
      });

      testWidgets('an empty form names each of its problems and saves nothing', (tester) async {
        final units = await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('measure-units-new')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('measure-unit-save')));
        await _frames(tester);
        expect(find.text(_en.measureReasonName), findsOneWidget);
        expect(find.text(_en.measureReasonDimension), findsOneWidget);
        expect((await units.units('ws-1')).length, 13);
      });

      testWidgets('a built-in takes the business\'s own word, and its factor cannot be typed', (tester) async {
        final units = await _open(tester, size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('measure-unit-km')), 200, scrollable: find.byType(Scrollable).first);
        await _reveal(tester, 'measure-unit-km');
        await tester.tap(find.byKey(const ValueKey('measure-unit-km')));
        await _frames(tester);
        expect(tester.widget<AppTextField>(find.byKey(const ValueKey('measure-unit-factor'))).enabled, isFalse);
        await _enter(tester, 'measure-unit-name', 'Kilometre');
        await tester.tap(find.byKey(const ValueKey('measure-unit-save')));
        await _frames(tester);
        expect((await units.units('ws-1')).firstWhere((u) => u.code == 'km').label, 'Kilometre');
        expect(find.text('Kilometre'), findsOneWidget);
      });

      testWidgets('an unused unit is archived and shown again', (tester) async {
        final units = await _open(tester, size, seed: _drum);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('measure-unit-archive-drum')), 200, scrollable: find.byType(Scrollable).first);
        await _reveal(tester, 'measure-unit-archive-drum');
        await tester.tap(find.byKey(const ValueKey('measure-unit-archive-drum')));
        await _frames(tester);
        expect((await units.units('ws-1')).firstWhere((u) => u.code == 'drum').archived, isTrue);
        expect(find.descendant(of: find.byKey(const ValueKey('measure-unit-drum')), matching: find.textContaining(_en.measureUnitArchivedTag)), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('measure-unit-archive-drum')));
        await _frames(tester);
        expect((await units.units('ws-1')).firstWhere((u) => u.code == 'drum').archived, isFalse);
      });

      testWidgets('a unit in use cannot be archived, and the refusal is told in words', (tester) async {
        final units = await _open(tester, size, seed: (u) async {
          await _drum(u);
          u.usedBy = (workspaceId, code) => code == 'drum';
        });
        await tester.scrollUntilVisible(find.byKey(const ValueKey('measure-unit-archive-drum')), 200, scrollable: find.byType(Scrollable).first);
        await _reveal(tester, 'measure-unit-archive-drum');
        await tester.tap(find.byKey(const ValueKey('measure-unit-archive-drum')));
        await _frames(tester);
        expect(find.text(_en.measureReasonInUse), findsOneWidget);
        expect((await units.units('ws-1')).firstWhere((u) => u.code == 'drum').archived, isFalse);
      });

      testWidgets('a failed read says so, and reads again', (tester) async {
        await _open(tester, size, wrap: _Flaky.new);
        expect(find.byType(ReadFailureBanner), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('measure-units-retry')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('measure-dimension-length')), findsOneWidget);
      });
    });
  }
}
