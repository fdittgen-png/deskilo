// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- a free line of a quote or an invoice may be sold in a unit of the business's own (kilometres, a drum of cable): the
// picker lists it after the four it always had, and the line carries its code and its UN/ECE code. With none offered the picker is
// what it was; a line stored in a unit that is no longer offered keeps it.
import 'package:deskilo/features/money/presentation/standalone/standalone_line_form.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _drum = WorkspaceUnit(code: 'drum', label: 'Drum', dimension: UnitDimension.length, factorNum: 50, factorDen: 1, unEceCode: 'DR');
final _km = builtInUnits.firstWhere((u) => u.code == 'km');
final _piece = builtInUnits.firstWhere((u) => u.code == 'piece');

Future<BuildContext> _pump(WidgetTester tester, StandaloneLineForm form, List<WorkspaceUnit> units) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (c, setState) {
              context = c;
              return StandaloneLineEditor(index: 0, form: form, rates: const [], units: units, onChanged: () => setState(() {}), onRemove: null);
            },
          ),
        ),
      ),
    ),
  );
  return context;
}

Future<void> _pick(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('standalone-line-0-unit')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a unit of the business is offered and the line carries its code and its UN/ECE code', (tester) async {
    final form = StandaloneLineForm();
    addTearDown(form.dispose);
    final context = await _pump(tester, form, [_piece, _km, _drum]);
    await _pick(tester, 'Drum');
    final unit = form.toLine(context).toWire()['unit']! as Map;
    expect(unit['code'], 'drum');
    expect(unit['label'], 'Drum');
    expect(unit['un_ece_code'], 'DR');
  });

  testWidgets('a built-in the business has is offered under the app\'s own word, with its UN/ECE code', (tester) async {
    final form = StandaloneLineForm();
    addTearDown(form.dispose);
    final context = await _pump(tester, form, [_piece, _km]);
    await tester.tap(find.byKey(const ValueKey('standalone-line-0-unit')));
    await tester.pumpAndSettle();
    expect([for (final u in form.extraUnits) u.code], ['km'], reason: 'the piece is already one of the four: it is not listed twice');
    await tester.tap(find.byType(DropdownMenuItem<String>).last);
    await tester.pumpAndSettle();
    final unit = form.toLine(context).toWire()['unit']! as Map;
    expect(unit['code'], 'km');
    expect(unit['un_ece_code'], 'KMT');
  });

  testWidgets('with none offered the picker is what it was', (tester) async {
    final form = StandaloneLineForm();
    addTearDown(form.dispose);
    await _pump(tester, form, const []);
    await tester.tap(find.byKey(const ValueKey('standalone-line-0-unit')));
    await tester.pumpAndSettle();
    expect(form.extraUnits, isEmpty);
    expect(find.text('Drum'), findsNothing);
  });
}
