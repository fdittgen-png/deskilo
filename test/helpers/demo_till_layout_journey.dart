// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till layout journey through the Demo's own store: the owner starts the bakery counter's new layout from
// the Bakery template with a calculator, saves it, publishes it; a second save over the version that moved is refused,
// an invalid layout is refused with its problem, and the same request answers the same version. Shared by the scenario
// checklist and the journey test.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/demo_till_layouts.dart';
import 'package:deskilo/features/money/domain/till_layout.dart';
import 'package:deskilo/features/money/domain/till_layout_templates.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

Future<String?> _refusal(Future<Object?> Function() act) async {
  try {
    await act();
    return null;
  } on PostgrestException catch (e) {
    return e.code;
  }
}

/// True when every step of the journey answered as the server would.
Future<bool> tillLayoutJourney() async {
  const ws = 'ws-1';
  final store = DemoTillLayouts()..seed();
  final before = await store.published(ws, demoBakeryTill);
  final layout = withCalculator(TillLayoutTemplate.bakery.build('Bakery counter', pageName: (p) => p.name));
  final v1 = await store.save(ws, requestId: 'l-1', tillId: demoBakeryTill, layout: layout, expectedVersion: 0);
  final again = await store.save(ws, requestId: 'l-1', tillId: demoBakeryTill, layout: layout, expectedVersion: 0);
  final stale = await _refusal(() => store.save(ws, requestId: 'l-2', tillId: demoBakeryTill, layout: layout, expectedVersion: 0));
  final broken = TillLayout(name: 'Bakery counter', pages: [
    TillPage(name: 'Sale', grids: {
      TillLayoutSize.phone: TillGrid(cols: 2, rows: 2, cells: [TillCell(kindWire: TillWidgetKind.keypad.wire, col: 0, row: 0, colSpan: 2, rowSpan: 2)]),
    }),
  ]);
  final invalid = await _refusal(() => store.save(ws, requestId: 'l-3', tillId: demoBakeryTill, layout: broken, expectedVersion: v1));
  final published = await store.publish(ws, requestId: 'l-4', tillId: demoBakeryTill, expectedVersion: v1);
  final after = await store.published(ws, demoBakeryTill);
  final kinds = {for (final c in after!.pages.first.grids[TillLayoutSize.desk]!.cells) c.kind};
  return before != null &&
      v1 == 1 &&
      again == v1 &&
      stale == DkCode.dkl10 &&
      invalid == DkCode.dkl02 &&
      published == before.version + 1 &&
      kinds.containsAll([TillWidgetKind.keypad, TillWidgetKind.calculator]) &&
      validateTillLayout(after, maxCells: store.maxCells).isEmpty;
}
