// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tcp_receipt_sender.dart';
import '../data/till_printer_store.dart';
import '../domain/receipt_sender.dart';
import '../domain/till_printer_settings.dart';

/// #4368 -- whether the business prints the till's receipts (`counterReceiptPrinter`): wired by the app from its features
/// (`tillPrinterOnFromApp`), so the till reads it without reaching into the workspace. Off until the app says so.
final tillPrinterOnProvider = Provider<bool>((ref) => false);

/// #4368 -- where this device keeps its printer settings. A test or the Demo replaces it.
final tillPrinterStoreProvider = Provider<TillPrinterStore>((ref) => const PrefsTillPrinterStore());

/// #4368 -- the till printer of this device; the defaults (no printer named) until one is set.
final tillPrinterSettingsProvider = FutureProvider<TillPrinterSettings>((ref) => ref.watch(tillPrinterStoreProvider).read());

/// #4368 -- the way to a printer: raw TCP to its address. The Demo prints to a fake that keeps the bytes.
final receiptSenderProvider = Provider.family<ReceiptSender, TillPrinterSettings>(
  (ref, settings) => TcpReceiptSender(host: settings.host, port: settings.port),
);
