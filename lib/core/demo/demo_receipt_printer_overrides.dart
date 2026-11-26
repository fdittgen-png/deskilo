// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 -- the Demo's till prints: its device has a receipt printer set (80 mm, a cash drawer on it, the cashier asked
// after each sale), and every job goes to the Demo printer, which keeps the bytes. Nothing leaves the device.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/data/till_printer_store.dart';
import '../../features/money/domain/till_printer_settings.dart';
import '../../features/money/providers/till_printer_providers.dart';
import 'data/demo_receipt_printer.dart';

/// The Demo device's printer, as a cashier set it; kept for the session.
class DemoTillPrinterStore implements TillPrinterStore {
  DemoTillPrinterStore([this._settings = const TillPrinterSettings(host: 'demo-printer.local', drawer: true)]);

  TillPrinterSettings _settings;

  @override
  Future<TillPrinterSettings> read() async => _settings;

  @override
  Future<void> write(TillPrinterSettings settings) async => _settings = settings;
}

List<Override> demoReceiptPrinterOverrides() {
  final printer = DemoReceiptPrinter();
  return [
    tillPrinterStoreProvider.overrideWithValue(DemoTillPrinterStore()),
    receiptSenderProvider.overrideWith((ref, settings) => printer),
  ];
}
