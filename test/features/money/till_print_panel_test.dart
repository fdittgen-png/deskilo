// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 -- the receipt of the sale just made, on the till's printer: with the business printing its receipts, a cash
// sale opens the drawer the printer drives; Print sends the receipt and a second print is the copy the server counted
// (COPY 1), never a new receipt; a printer that cannot be reached says so in words and the sale stays made; a card sale
// opens no drawer; with the business printing nothing, the till shows no printing at all. At 1024 and 1440.
import 'dart:async';

import 'package:deskilo/core/demo/data/demo_receipt_printer.dart';
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/core/demo/demo_receipt_printer_overrides.dart';
import 'package:deskilo/features/money/domain/till_print_job.dart';
import 'package:deskilo/features/money/domain/till_printer_settings.dart';
import 'package:deskilo/features/money/presentation/till_print_panel.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:deskilo/features/money/providers/till_printer_providers.dart';
import 'package:deskilo/features/money/providers/till_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();
const _workspace = Workspace(id: 'ws', name: 'Épicerie', countryCode: 'FR', currencyCode: 'EUR', timezone: 'Europe/Paris', inviteCode: 'x');
const _settings = TillPrinterSettings(host: 'printer.local', drawer: true);
final _kick = tillPrintJob(settings: _settings, kickDrawer: true);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<(DemoReceiptPrinter, TillSession)> _sold(WidgetTester tester, {required Size size, bool on = true, bool reachable = true, bool card = false}) async {
  final till = DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20);
  final session = TillSession(port: till, workspaceId: 'ws');
  final printer = DemoReceiptPrinter(reachable: reachable);
  final panel = ValueNotifier<Widget>(const SizedBox());
  await pumpApp(
    tester,
    Scaffold(body: ValueListenableBuilder<Widget>(valueListenable: panel, builder: (_, w, _) => w)),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      tillPortProvider.overrideWithValue(till),
      tillPrinterOnProvider.overrideWithValue(on),
      tillPrinterStoreProvider.overrideWithValue(DemoTillPrinterStore(_settings)),
      receiptSenderProvider.overrideWith((ref, s) => printer),
      currentWorkspaceProvider.overrideWith((ref) async => _workspace),
    ],
  );
  unawaited(session.add(itemId: 'demo-item-milk', name: 'Oat milk', unit: 'l'));
  await _settle(tester);
  unawaited(card ? session.payCard() : session.payCash(500));
  await _settle(tester);
  if (card) {
    // the terminal accepts the card: the sale is made
    unawaited(session.cardAnswer('accepted'));
    await _settle(tester);
  }
  final s = session.state.value;
  panel.value = TillPrintPanel(sold: s.sold!, draft: s.draft!, lines: s.lines, changeMinor: s.change ?? 0, cash: s.soldCash);
  await _settle(tester);
  return (printer, session);
}

void main() {
  for (final size in const [Size(1024, 768), Size(1440, 900)]) {
    testWidgets('a cash sale opens the drawer; Print sends the receipt and a second print is COPY 1 (${size.width.toInt()})', (tester) async {
      final (printer, _) = await _sold(tester, size: size);
      expect(printer.jobs, [_kick], reason: 'the drawer opens for the cash, once');
      await tester.tap(find.byKey(const ValueKey('till-print')));
      await _settle(tester);
      expect(find.text(_en.tillPrinted), findsOneWidget);
      expect(String.fromCharCodes(printer.jobs.last), isNot(contains('COPY')));
      await tester.tap(find.byKey(const ValueKey('till-print-copy')));
      await _settle(tester);
      expect(String.fromCharCodes(printer.jobs.last), contains('COPY 1'), reason: 'the copy the server counted');
      expect(printer.jobs.where((j) => j.length == _kick.length && j.toString() == _kick.toString()), hasLength(1), reason: 'the drawer opens once');
    });
  }

  testWidgets('a printer that cannot be reached says so, and the sale stays made', (tester) async {
    final (_, session) = await _sold(tester, size: const Size(1024, 768), reachable: false);
    await tester.tap(find.byKey(const ValueKey('till-print')));
    await _settle(tester);
    expect(find.text(_en.tillNotPrinted), findsOneWidget);
    expect(find.byKey(const ValueKey('till-print-again')), findsOneWidget);
    expect(session.state.value.sold, isNotNull);
  });

  testWidgets('a card sale opens no drawer', (tester) async {
    final (printer, session) = await _sold(tester, size: const Size(1024, 768), card: true);
    expect(session.state.value.sold, isNotNull);
    expect(session.state.value.soldCash, isFalse);
    expect(printer.jobs, isEmpty);
  });

  testWidgets('with the business printing nothing, the till shows no printing', (tester) async {
    final (printer, _) = await _sold(tester, size: const Size(1024, 768), on: false);
    expect(find.byKey(const ValueKey('till-print')), findsNothing);
    expect(find.byKey(const ValueKey('till-printer-setup')), findsNothing);
    expect(printer.jobs, isEmpty);
  });
}
