// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- Settings > Units of measure > Conversions as a person uses it, at a phone and a desk width: what converts to what is
// listed as a line (1 kg = 1000 g) and is defined, never implied; a conversion is added from one unit to another with a factor,
// the same unit twice is refused in words, a packaging unit is not offered, one is deleted, and a failed read says so and reads again.
import 'package:deskilo/core/demo/data/demo_unit_conversions.dart';
import 'package:deskilo/core/demo/data/demo_workspace_units.dart';
import 'package:deskilo/features/stock/domain/unit_conversions.dart';
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

/// Fails its first read, then answers as the Demo does.
class _Flaky implements UnitConversions {
  _Flaky(this._inner);

  final UnitConversions _inner;
  int reads = 0;

  @override
  Future<List<UnitConversion>> conversions(String workspaceId) => ++reads == 1 ? Future.error(Exception('down')) : _inner.conversions(workspaceId);

  @override
  Future<UnitConversion> save(String workspaceId, {required String requestId, required UnitConversion conversion}) =>
      _inner.save(workspaceId, requestId: requestId, conversion: conversion);

  @override
  Future<void> delete(String workspaceId, {required String requestId, required String fromUnit, required String toUnit}) =>
      _inner.delete(workspaceId, requestId: requestId, fromUnit: fromUnit, toUnit: toUnit);
}

Future<DemoUnitConversions> _open(WidgetTester tester, Size size, {UnitConversions Function(DemoUnitConversions)? wrap}) async {
  final conversions = DemoUnitConversions();
  final units = DemoWorkspaceUnits()..onSaved = conversions.unitSaved;
  conversions.unitsOf = units.heldBy;
  await pumpApp(
    tester,
    const UnitsOfMeasureScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      workspaceUnitsProvider.overrideWithValue(units),
      unitConversionsProvider.overrideWithValue(wrap == null ? conversions : wrap(conversions)),
    ],
  );
  await _frames(tester);
  return conversions;
}

Future<void> _reveal(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  // the list builds what is on screen: the conversions are at its end
  if (target.evaluate().isEmpty) await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await _reveal(tester, key);
  await tester.tap(find.byKey(ValueKey(key)));
  await _frames(tester);
}

Future<void> _pick(WidgetTester tester, String key, String text) async {
  await _tap(tester, key);
  await tester.tap(find.text(text).last);
  await _frames(tester);
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the conversions are listed as lines, from what the built-in units give', (tester) async {
        await _open(tester, size);
        await _reveal(tester, 'unit-conversions');
        expect(tester.takeException(), isNull);
        expect(find.text('1 kg = 1000 g'), findsOneWidget);
        expect(find.text('1 l = 100 cl'), findsOneWidget);
        expect(find.text('1 h = 60 min'), findsOneWidget);
      });

      testWidgets('a conversion is added from one unit to another, and listed', (tester) async {
        final conversions = await _open(tester, size);
        await _tap(tester, 'unit-conversion-new');
        await _pick(tester, 'unit-conversion-from', 'kg');
        await _pick(tester, 'unit-conversion-to', 'l');
        await tester.enterText(find.byKey(const ValueKey('unit-conversion-factor')), '1');
        await _tap(tester, 'unit-conversion-save');
        expect(tester.takeException(), isNull);
        expect((await conversions.conversions('ws-1')).where((c) => c.joins('kg', 'l')).single.factorNum, 1);
        expect(find.text('1 kg = 1 l'), findsOneWidget);
      });

      testWidgets('the same unit twice is refused in words and nothing is saved', (tester) async {
        final conversions = await _open(tester, size);
        final before = (await conversions.conversions('ws-1')).length;
        await _tap(tester, 'unit-conversion-new');
        await _pick(tester, 'unit-conversion-from', 'kg');
        await _pick(tester, 'unit-conversion-to', 'kg');
        await tester.enterText(find.byKey(const ValueKey('unit-conversion-factor')), '1');
        await _tap(tester, 'unit-conversion-save');
        expect(find.text(_en.stockReasonConversionSameUnit), findsOneWidget);
        expect((await conversions.conversions('ws-1')).length, before);
      });

      testWidgets('a packaging unit is not offered: it converts through an item\'s own factor', (tester) async {
        await _open(tester, size);
        await _tap(tester, 'unit-conversion-new');
        await _tap(tester, 'unit-conversion-from');
        expect(find.text('Box'), findsNothing);
        expect(find.text('Carton'), findsNothing);
        expect(find.text('kg'), findsWidgets);
      });

      testWidgets('a conversion is deleted', (tester) async {
        final conversions = await _open(tester, size);
        await _tap(tester, 'unit-conversion-delete-kg-g');
        expect((await conversions.conversions('ws-1')).where((c) => c.joins('kg', 'g')), isEmpty);
        expect(find.text('1 kg = 1000 g'), findsNothing);
      });

      testWidgets('a failed read says so and reads again, never an empty list', (tester) async {
        await _open(tester, size, wrap: _Flaky.new);
        await _reveal(tester, 'unit-conversions');
        expect(find.byKey(const ValueKey('unit-conversions-failed')), findsOneWidget);
        expect(find.byKey(const ValueKey('unit-conversions-empty')), findsNothing);
      });
    });
  }
}
