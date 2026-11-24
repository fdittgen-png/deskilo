// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4435 (G20) -- the handling units as a person uses them, on the Demo's pallet of 30 mugs and carton of 10 kg of coffee, at a
// phone and a desk width: the units are listed with their place; a unit shows its content and moves with it to another place;
// a person who read an old revision is told the unit changed (and reads it again); an unpack leaves the unit out of the list; a
// unit is made from loose stock, refused when more than is loose is asked and made when the quantity fits; a failed read says so.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_handling_units.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/features/stock/domain/handling_units.dart';
import 'package:deskilo/features/stock/presentation/stock_units_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
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

class _Kit {
  _Kit() {
    final config = DemoStockConfigCommands('ws-1');
    ledger = DemoStockLedger('ws-1', config, () => kTestNow);
    units = DemoStockHandlingUnits(ledger);
    queries = DemoStockQueries(ledger);
    this.config = config;
  }

  late final DemoStockConfigCommands config;
  late final DemoStockLedger ledger;
  late final DemoStockHandlingUnits units;
  late final DemoStockQueries queries;
}

Future<_Kit> _open(WidgetTester tester, Size size, {StockHandlingUnits Function(StockHandlingUnits)? wrap, String? format}) async {
  final kit = _Kit();
  await pumpApp(
    tester,
    const StockUnitsScreen(),
    size: size,
    overrides: [
      // a test that names a format locale reads what is typed in it
      ...standardTestOverrides(pinFormats: format == null),
      if (format != null) ...[
        appFormatProvider.overrideWithValue(AppFormat(locale: format, currencyCode: 'EUR')),
        personalFormatProvider.overrideWithValue(AppFormat(locale: format, currencyCode: 'EUR')),
      ],
      stockHandlingUnitsProvider.overrideWithValue(wrap == null ? kit.units : wrap(kit.units)),
      stockConfigCommandsProvider.overrideWithValue(kit.config),
      stockQueriesProvider.overrideWithValue(kit.queries),
    ],
  );
  await _frames(tester);
  return kit;
}

/// A port whose list cannot be read the first time.
class _Flaky implements StockHandlingUnits {
  _Flaky(this._inner);

  final StockHandlingUnits _inner;
  int reads = 0;

  @override
  Future<HandlingUnitPage> page(String workspaceId, {String? locationId, HandlingUnitState state = HandlingUnitState.open, Map<String, Object?>? after}) =>
      ++reads == 1 ? Future.error(Exception('down')) : _inner.page(workspaceId, locationId: locationId, state: state, after: after);

  @override
  Future<HandlingUnitDetail?> unit(String workspaceId, String unitId) => _inner.unit(workspaceId, unitId);

  @override
  Future<HandlingUnit> make(String workspaceId, String requestId, UnitDraft draft) => _inner.make(workspaceId, requestId, draft);

  @override
  Future<HandlingUnit> move(String workspaceId, String requestId, {required String unitId, required String toLocationId, required int revision}) =>
      _inner.move(workspaceId, requestId, unitId: unitId, toLocationId: toLocationId, revision: revision);

  @override
  Future<HandlingUnit> unpack(String workspaceId, String requestId, {required String unitId, required int revision}) =>
      _inner.unpack(workspaceId, requestId, unitId: unitId, revision: revision);

  @override
  Future<List<HandlingUnit>> repack(String workspaceId, String requestId, {required List<RepackSource> sources, required List<UnitDraft> targets}) =>
      _inner.repack(workspaceId, requestId, sources: sources, targets: targets);

  @override
  Future<LotUnitTrace> lotTrace(String workspaceId, {required String itemId, required String lotId}) => _inner.lotTrace(workspaceId, itemId: itemId, lotId: lotId);
}

void main() {
  for (final (name, size) in [('a phone', const Size(390, 844)), ('a desk', const Size(1440, 900))]) {
    group('on $name', () {
      testWidgets('the units are listed with their kind and place', (tester) async {
        await _open(tester, size);
        expect(find.byKey(const ValueKey('stock-unit-PAL-001')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-unit-CT-001')), findsOneWidget);
        expect(find.textContaining(_en.stockUnitKindPallet), findsOneWidget);
        expect(find.textContaining('MAIN'), findsWidgets);
      });

      testWidgets('a unit shows its content and moves with it to another place', (tester) async {
        final kit = await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('stock-unit-PAL-001')));
        await _frames(tester);
        expect(find.textContaining('Mugs'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stock-unit-move')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-unit-move-save')));
        await _frames(tester);
        expect(find.textContaining('PAL-001 moved'), findsOneWidget);
        final page = await kit.units.page('ws-1');
        final moved = page.rows.firstWhere((u) => u.code == 'PAL-001');
        expect(moved.locationId, isNot('demo-place-main'));
        expect(double.parse(kit.ledger.balance('demo-item-mugs', moved.locationId).text), greaterThanOrEqualTo(30));
      });

      testWidgets('a unit that someone else moved is refused in words and reads again', (tester) async {
        final kit = await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('stock-unit-PAL-001')));
        await _frames(tester);
        final seen = (await kit.units.page('ws-1')).rows.firstWhere((u) => u.code == 'PAL-001');
        // the other person moves it while this sheet is open
        await kit.units.move('ws-1', 'other', unitId: seen.id, toLocationId: 'demo-place-branch', revision: seen.revision);
        await tester.tap(find.byKey(const ValueKey('stock-unit-move')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-unit-move-save')));
        await _frames(tester);
        expect(find.text(_en.refusalStockUnitChanged), findsOneWidget);
      });

      testWidgets('an unpacked unit leaves the list and its content stays', (tester) async {
        final kit = await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('stock-unit-CT-001')));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-unit-unpack')));
        await _frames(tester);
        expect(find.textContaining('CT-001 unpacked'), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-unit-CT-001')), findsNothing);
        expect(kit.ledger.balance('demo-item-beans', 'demo-place-main').text, '12.5');
      });

      // #4425 -- what is typed is read in the member's format: 1,5 in German and 1.5 in English make the same unit
      for (final (format, typed) in [('de_DE', '1,5'), ('en_US', '1.5')]) {
        testWidgets('a unit of $typed typed in $format holds 1.5', (tester) async {
          final kit = await _open(tester, size, format: format);
          await tester.tap(find.byKey(const ValueKey('stock-units-make')));
          await _frames(tester);
          await tester.enterText(find.byKey(const ValueKey('stock-unit-code')), 'BOX-7');
          await tester.tap(find.byKey(const ValueKey('stock-unit-item')));
          await _frames(tester);
          await tester.tap(find.text('Coffee beans').last);
          await _frames(tester);
          await tester.enterText(find.byKey(const ValueKey('stock-unit-quantity')), typed);
          await tester.tap(find.byKey(const ValueKey('stock-unit-make-save')));
          await _frames(tester);
          final made = (await kit.units.page('ws-1')).rows.firstWhere((u) => u.code == 'BOX-7');
          expect((await kit.units.unit('ws-1', made.id))!.lines.single.quantity.text, '1.5');
        });

        testWidgets('a carton repacked into two boxes of ${typed == '1,5' ? '2,5' : '2.5'} in $format', (tester) async {
          final kit = await _open(tester, size, format: format);
          await tester.tap(find.byKey(const ValueKey('stock-unit-CT-001')));
          await _frames(tester);
          await tester.tap(find.byKey(const ValueKey('stock-unit-repack')));
          await _frames(tester);
          await tester.tap(find.byKey(const ValueKey('stock-unit-repack-item')));
          await _frames(tester);
          await tester.tap(find.textContaining('Coffee beans').last);
          await _frames(tester);
          await tester.enterText(find.byKey(const ValueKey('stock-unit-repack-boxes')), '2');
          await tester.enterText(find.byKey(const ValueKey('stock-unit-repack-each')), typed == '1,5' ? '2,5' : '2.5');
          await tester.tap(find.byKey(const ValueKey('stock-unit-repack-save')));
          await _frames(tester);
          final boxes = [for (final u in (await kit.units.page('ws-1')).rows) if (u.code.startsWith('CT-001-')) u];
          expect(boxes, hasLength(2));
          for (final b in boxes) {
            expect((await kit.units.unit('ws-1', b.id))!.lines.single.quantity.text, '2.5');
          }
        });
      }

      testWidgets('a unit is made from loose stock: more than is loose is refused, a quantity that fits is made', (tester) async {
        await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('stock-units-make')));
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-unit-code')), 'BOX-9');
        await tester.tap(find.byKey(const ValueKey('stock-unit-item')));
        await _frames(tester);
        await tester.tap(find.text('Coffee beans').last);
        await _frames(tester);
        // the first item is the coffee: 12.5 kg at the main store, 10 of them already in a carton, 2.5 loose
        await tester.enterText(find.byKey(const ValueKey('stock-unit-quantity')), '5');
        await tester.tap(find.byKey(const ValueKey('stock-unit-make-save')));
        await _frames(tester);
        expect(find.text(_en.refusalStockNotEnough), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('stock-unit-quantity')), '2');
        await tester.tap(find.byKey(const ValueKey('stock-unit-make-save')));
        await _frames(tester);
        expect(find.textContaining('BOX-9 made'), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-unit-BOX-9')), findsOneWidget);
      });
    });
  }

  testWidgets('a failed read says so and reads again', (tester) async {
    late _Flaky flaky;
    await _open(tester, const Size(390, 844), wrap: (u) => flaky = _Flaky(u));
    expect(find.text(_en.stockUnitsReadFailed), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stock-units-retry')));
    await _frames(tester);
    expect(find.byKey(const ValueKey('stock-unit-PAL-001')), findsOneWidget);
    expect(flaky.reads, 2);
  });
}
