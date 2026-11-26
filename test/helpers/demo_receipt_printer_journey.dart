// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 -- the receipt printer journey through the Demo's own till and printer: a cash sale is made, its receipt is
// printed with the drawer opened, a second print is the copy the server counted (COPY 1) and never a new receipt, and
// a printer that cannot be reached is refused while the sale stays made. Shared by the scenario checklist.
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/demo_receipt_printer.dart';
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/features/money/domain/receipt_sender.dart';
import 'package:deskilo/features/money/domain/till_print_job.dart';
import 'package:deskilo/features/money/domain/till_printer_settings.dart';
import 'package:deskilo/features/money/presentation/till_receipt.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';

/// True when every step of the journey answered as the till and the printer should.
Future<bool> receiptPrinterJourney() async {
  const ws = 'ws-1';
  final till = DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20);
  final session = TillSession(port: till, workspaceId: ws);
  await session.add(itemId: 'demo-item-milk', name: 'Oat milk', unit: 'l');
  await session.payCash(500);
  final s = session.state.value;
  final sold = s.sold;
  if (sold == null || s.draft == null || !s.soldCash) return false;
  const settings = TillPrinterSettings(host: 'demo-printer.local', drawer: true);
  final l10n = AppLocalizationsEn();
  const format = AppFormat(locale: 'en', currencyCode: 'EUR');
  Uint8List job({int? copy, bool kick = false}) => tillPrintJob(
    receipt: tillReceiptOf(
      l10n: l10n,
      fmt: format,
      business: 'Demo',
      sold: sold,
      draft: s.draft!,
      lines: s.lines,
      at: DateTime(2026, 11, 25, 9),
      givenMinor: 500,
      changeMinor: s.change ?? 0,
      copy: copy,
    ),
    settings: settings,
    kickDrawer: kick,
  );
  final printer = DemoReceiptPrinter();
  await printer.send(job(kick: true));
  final n = await till.copy(ws, requestId: 'demo-copy-1', receiptId: sold.receiptId);
  await printer.send(job(copy: n));
  final original = String.fromCharCodes(printer.jobs.first);
  final copied = String.fromCharCodes(printer.jobs.last);
  final kicks = printer.jobs.first.length > job().length;
  var refused = false;
  try {
    await DemoReceiptPrinter(reachable: false).send(job());
  } on ReceiptNotPrinted {
    refused = true;
  }
  return n == 1 && kicks && !original.contains('COPY') && copied.contains('COPY 1') && copied.contains(sold.number) && refused &&
      session.state.value.sold?.number == sold.number;
}
