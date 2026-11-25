// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4450 -- the till drawer's terminal console: what a terminal rings up appears with the server's prices and total, it
// follows the draft as the terminal changes it, no open sale says so, and a failed read says so in words -- never as an
// empty console.
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/features/money/domain/counter_book.dart';
import 'package:deskilo/features/money/presentation/till_drawer/terminal_console.dart';
import 'package:deskilo/features/money/providers/counter_book_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

CounterBookLine _line(int no, String label, String qty, int gross) =>
    CounterBookLine(id: 'l$no', lineNo: no, label: label, quantity: qty, unit: 'piece', grossMinor: gross, goods: true);

CounterBookReceipt _draft(int revision, List<CounterBookLine> lines) => CounterBookReceipt(
  id: 'r1',
  kind: 'sale',
  state: 'draft',
  currency: 'EUR',
  totalMinor: lines.fold(0, (a, l) => a + l.grossMinor),
  taxMinor: 0,
  revision: revision,
  lines: lines,
  tenders: const [],
);

/// A terminal's server: answers whatever draft the test set last, or fails.
class _Terminal extends DemoTill implements CounterBookPort {
  _Terminal() : super(country: 'FR', currency: 'EUR', vatPercent: 20);

  CounterBookReceipt? open;
  bool broken = false;

  @override
  Future<CounterBookReceipt?> openDraft(String workspaceId) async {
    if (broken) throw StateError('no connection');
    return open;
  }
}

Future<void> _open(WidgetTester tester, _Terminal port) async {
  await pumpApp(
    tester,
    const Scaffold(body: SingleChildScrollView(child: TerminalConsole(workspaceId: 'ws-1'))),
    overrides: [...standardTestOverrides(), counterBookPortProvider.overrideWithValue(port)],
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('the products chosen on the terminal appear with their prices and the total, and follow the draft', (tester) async {
    final port = _Terminal()..open = _draft(1, [_line(1, 'Coffee', '1', 1000)]);
    await _open(tester, port);
    expect(find.text(_en.tillDrawerConsoleLine('1', 'Coffee')), findsOneWidget);
    expect(find.byKey(const ValueKey('terminal-console-line-1')), findsOneWidget);
    expect(find.text(_en.tillDrawerConsoleRevision('1')), findsOneWidget);

    // the terminal adds a second product: the next beat shows it and the new total
    port.open = _draft(2, [_line(1, 'Coffee', '1', 1000), _line(2, 'Cake', '2', 2000)]);
    await tester.pump(terminalConsoleBeat);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(_en.tillDrawerConsoleLine('2', 'Cake')), findsOneWidget);
    expect(find.byKey(const ValueKey('terminal-console-line-2')), findsOneWidget);
    expect(find.text(_en.tillDrawerConsoleRevision('2')), findsOneWidget);
    final total = tester.widget<Text>(find.byKey(const ValueKey('terminal-console-total'))).data!;
    expect(total, startsWith(_en.counterSaleTotal('').trim()));
    expect(total, contains('30'));
  });

  testWidgets('no open sale on a terminal says so', (tester) async {
    await _open(tester, _Terminal());
    expect(find.byKey(const ValueKey('terminal-console-empty')), findsOneWidget);
    expect(find.text(_en.tillDrawerConsoleEmpty), findsOneWidget);
  });

  testWidgets('a draft that cannot be read is said in words, never shown as no sale', (tester) async {
    await _open(tester, _Terminal()..broken = true);
    expect(find.byKey(const ValueKey('terminal-console-problem')), findsOneWidget);
    expect(find.byKey(const ValueKey('terminal-console-empty')), findsNothing);
  });
}
