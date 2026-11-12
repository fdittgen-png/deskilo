// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3606 (desk K1) — the records table: sort, filter, chips with counts, a
// footer with one total per currency of its stated scope, selection by
// stable keys (a sort, a new row, a filter, a reload never move it to
// another record), the bulk bar, the keyboard, the row's actions on the
// secondary click, the three states, and cards on a phone.
import 'package:deskilo/core/storage/prefs_stores.dart';
import 'package:deskilo/core/ui/kit/records_table.dart';
import 'package:deskilo/core/ui/kit/records_table_parts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/pump_app.dart';

typedef _Rec = ({
  String id,
  String name,
  int cents,
  String currency,
  bool late,
});

const _a = (id: 'a', name: 'Ada', cents: 1000, currency: 'EUR', late: true);
const _b = (id: 'b', name: 'Bruno', cents: 2000, currency: 'CHF', late: false);
const _c = (id: 'c', name: 'Chiara', cents: 500, currency: 'EUR', late: true);

Finder _k(String key) => find.byKey(ValueKey(key));

class _Host extends StatefulWidget {
  const _Host({
    required this.rows,
    this.state = RecordsState.ready,
    this.complete = true,
    this.onBulk,
    this.onOpen,
    this.onAction,
  });

  final List<_Rec> rows;
  final RecordsState state;
  final bool complete;
  final void Function(Set<String>)? onBulk;
  final void Function(_Rec)? onOpen;
  final void Function(_Rec)? onAction;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => RecordsTable<_Rec>(
    tableId: 'test',
    rows: widget.rows,
    keyOf: (r) => r.id,
    state: widget.state,
    onRetry: () {},
    complete: widget.complete,
    columnStore: const PrefsStringStore('records_columns_test'),
    columns: [
      RecordColumn(
        id: 'name',
        label: 'Name',
        hideable: false,
        sortKey: (r) => r.name,
        cell: (_, r) => Text(r.name),
      ),
      RecordColumn(
        id: 'amount',
        label: 'Amount',
        numeric: true,
        sortKey: (r) => r.cents,
        cell: (_, r) => Text('${r.cents} ${r.currency}'),
      ),
    ],
    searchText: (r) => r.name,
    chips: [RecordChip(id: 'late', label: 'Late', keeps: (r) => r.late)],
    amountOf: (r) => (currency: r.currency, minor: r.cents),
    formatAmount: (c, m) => '$m $c',
    onOpen: widget.onOpen ?? (_) {},
    rowActions: (r) => [
      RecordAction(
        id: 'remind',
        label: 'Remind',
        icon: Icons.notifications_outlined,
        onRun: widget.onAction ?? (_) {},
      ),
      RecordAction(
        id: 'void',
        label: 'Void',
        icon: Icons.block,
        destructive: true,
        unavailable: 'Issued today',
        onRun: (_) {},
      ),
    ],
    bulkActions: [
      RecordBulkAction(
        id: 'export',
        label: (n) => 'Export $n',
        icon: Icons.download,
        onRun: widget.onBulk ?? (_) {},
      ),
    ],
    cardBuilder: (_, r) => Card(child: Text('card ${r.name}')),
    empty: const Text('Nothing yet', key: ValueKey('records-empty')),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget host, {
  Size size = const Size(1200, 800),
}) async {
  SharedPreferences.setMockInitialValues({});
  await pumpApp(tester, Scaffold(body: host), size: size);
  await tester.pumpAndSettle();
}

List<String> _order(WidgetTester tester) => [
  for (final e in find.byType(Text).evaluate())
    if ((e.widget as Text).data case final t?
        when ['Ada', 'Bruno', 'Chiara'].contains(t))
      t,
];

void main() {
  testWidgets('a click on a header sorts, a second reverses', (tester) async {
    await _pump(tester, const _Host(rows: [_b, _c, _a]));
    await tester.tap(_k('records-sort-name'));
    await tester.pumpAndSettle();
    expect(_order(tester), ['Ada', 'Bruno', 'Chiara']);
    await tester.tap(_k('records-sort-name'));
    await tester.pumpAndSettle();
    expect(_order(tester), ['Chiara', 'Bruno', 'Ada']);
  });

  testWidgets('typing filters; / goes to the filter; a chip keeps its rows '
      'and says how many', (tester) async {
    await _pump(tester, const _Host(rows: [_a, _b, _c]));
    expect(find.text('Late 2'), findsOneWidget);
    await tester.tap(_k('records-row-a'));
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pump();
    expect(
      tester.widget<TextField>(_k('records-filter')).focusNode!.hasFocus,
      isTrue,
    );
    await tester.enterText(_k('records-filter'), 'br');
    await tester.pumpAndSettle();
    expect(_order(tester), ['Bruno']);
    await tester.enterText(_k('records-filter'), '');
    await tester.tap(_k('records-chip-late'));
    await tester.pumpAndSettle();
    expect(_order(tester), ['Ada', 'Chiara']);
  });

  testWidgets('the footer totals per currency, never across, and says what '
      'it adds up', (tester) async {
    await _pump(tester, const _Host(rows: [_a, _b, _c]));
    expect(_k('records-total-EUR'), findsOneWidget);
    String total(String c) => tester.widget<Text>(_k('records-total-$c')).data!;
    expect(total('EUR'), '1500 EUR');
    expect(total('CHF'), '2000 CHF');
    expect(find.text('Total of the rows shown'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).at(1)); // Ada's tick
    await tester.pumpAndSettle();
    expect(find.text('Total of the selection'), findsOneWidget);
    expect(total('EUR'), '1000 EUR');
    expect(_k('records-total-CHF'), findsNothing);
  });

  testWidgets('a partly read table says so and never claims the whole', (
    tester,
  ) async {
    await _pump(tester, const _Host(rows: [_a, _b], complete: false));
    expect(_k('records-partly-read'), findsOneWidget);
    expect(find.textContaining('2 loaded'), findsOneWidget);
  });

  testWidgets('selection is by key: a sort and a new row keep it on the same '
      'record; the bulk action gets exactly those keys', (tester) async {
    Set<String>? exported;
    var rows = <_Rec>[_a, _b];
    late StateSetter set;
    SharedPreferences.setMockInitialValues({});
    await pumpApp(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, s) {
            set = s;
            return _Host(rows: rows, onBulk: (k) => exported = k);
          },
        ),
      ),
      size: const Size(1200, 800),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: _k('records-row-b'), matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    await tester.tap(_k('records-sort-amount'));
    await tester.pumpAndSettle();
    await tester.tap(_k('records-sort-amount'));
    await tester.pumpAndSettle();
    set(() => rows = [_c, _a, _b]);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: _k('records-row-b'),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
    await tester.tap(_k('records-bulk-export'));
    expect(exported, {'b'});
  });

  testWidgets('a filter that hides a selected row takes it out of the '
      'selection; a reload without it drops it and says so', (tester) async {
    Set<String>? exported;
    var rows = <_Rec>[_a, _b, _c];
    late StateSetter set;
    await pumpApp(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, s) {
            set = s;
            return _Host(rows: rows, onBulk: (k) => exported = k);
          },
        ),
      ),
      size: const Size(1200, 800),
    );
    await tester.pumpAndSettle();
    await tester.tap(_k('records-select-shown'));
    await tester.pumpAndSettle();
    await tester.enterText(_k('records-filter'), 'a');
    await tester.pumpAndSettle();
    await tester.tap(_k('records-bulk-export'));
    expect(exported, {'a', 'c'});
    set(() => rows = [_a]);
    await tester.pumpAndSettle();
    expect(_k('records-dropped'), findsOneWidget);
    await tester.tap(_k('records-bulk-export'));
    expect(exported, {'a'});
  });

  testWidgets('the keyboard: arrows move, Space ticks, Enter opens, Ctrl+A '
      'selects what is shown', (tester) async {
    _Rec? opened;
    await _pump(
      tester,
      _Host(rows: const [_a, _b, _c], onOpen: (r) => opened = r),
    );
    tester.widget<Focus>(_k('records-rows')).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, _b);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets('the secondary click opens the row\'s actions; one that cannot '
      'run says why and does nothing', (tester) async {
    _Rec? reminded;
    await _pump(
      tester,
      _Host(rows: const [_a, _b], onAction: (r) => reminded = r),
    );
    await tester.tap(_k('records-row-a'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(_k('records-action-remind'), findsOneWidget);
    expect(
      tester.widget<MenuItemButton>(_k('records-action-void')).onPressed,
      isNull,
    );
    await tester.tap(_k('records-action-remind'));
    await tester.pumpAndSettle();
    expect(reminded, _a);
  });

  testWidgets('loading, failed with Try again, and empty with its sentence', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(
      tester,
      const Scaffold(
        body: _Host(rows: [], state: RecordsState.loading),
      ),
      size: const Size(1200, 800),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _pump(tester, const _Host(rows: [], state: RecordsState.failed));
    expect(_k('records-failed'), findsOneWidget);
    expect(_k('records-retry'), findsOneWidget);
    await _pump(tester, const _Host(rows: []));
    expect(_k('records-empty'), findsOneWidget);
  });

  testWidgets('at 390 the same rows are cards', (tester) async {
    await _pump(
      tester,
      const _Host(rows: [_a, _b]),
      size: const Size(390, 800),
    );
    expect(_k('records-card-a'), findsOneWidget);
    expect(find.text('card Ada'), findsOneWidget);
    expect(find.byType(RecordRow<_Rec>), findsNothing);
  });

  testWidgets('rows are 36 with a mouse and 48 once touched', (tester) async {
    await _pump(tester, const _Host(rows: [_a]));
    double height() => tester.getSize(_k('records-row-a')).height;
    expect(height(), lessThan(kMinInteractiveDimension));
    await tester.tap(_k('records-row-a'));
    await tester.pumpAndSettle();
    expect(height(), greaterThanOrEqualTo(kMinInteractiveDimension));
  });
}
