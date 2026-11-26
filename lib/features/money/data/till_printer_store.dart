// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- where a device keeps its till printer. The same seam as the other device preferences: a store a test
// replaces, so no widget test touches a platform channel. The settings are kept as JSON, read through the JsonReader:
// anything unreadable is the defaults (a printer to set up again, never a crash).
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/escpos_receipt.dart';
import '../domain/till_printer_settings.dart';

abstract interface class TillPrinterStore {
  Future<TillPrinterSettings> read();
  Future<void> write(TillPrinterSettings settings);
}

class PrefsTillPrinterStore implements TillPrinterStore {
  const PrefsTillPrinterStore();

  static const _key = 'till_printer';

  @override
  Future<TillPrinterSettings> read() async => _decodeTillPrinter((await SharedPreferences.getInstance()).getString(_key));

  @override
  Future<void> write(TillPrinterSettings settings) async {
    await (await SharedPreferences.getInstance()).setString(_key, _encodeTillPrinter(settings));
  }
}

/// [s] as the device keeps it.
String _encodeTillPrinter(TillPrinterSettings s) => jsonEncode({
  'host': s.host,
  'port': s.port,
  'paper_mm': s.paperMm,
  'code_page': s.codePage.name,
  'drawer': s.drawer,
  'mode': s.mode.name,
});

/// The settings kept as [json]; the defaults when there are none or they cannot be read.
TillPrinterSettings _decodeTillPrinter(String? json) {
  if (json == null || json.isEmpty) return const TillPrinterSettings();
  try {
    final r = JsonReader.of(jsonDecode(json), context: 'till_printer');
    final port = r.intOrNull('port');
    return TillPrinterSettings(
      host: (r.stringOrNull('host') ?? '').trim(),
      port: port != null && port >= 1 && port <= 65535 ? port : TillPrinterSettings.defaultPort,
      paperMm: r.intOrNull('paper_mm') == 58 ? 58 : 80,
      codePage: EscposCodePage.values.where((c) => c.name == r.stringOrNull('code_page')).firstOrNull ?? EscposCodePage.cp858,
      drawer: r.isTrue('drawer'),
      mode: TillPrintMode.values.where((x) => x.name == r.stringOrNull('mode')).firstOrNull ?? TillPrintMode.ask,
    );
  } on Object catch (e, st) {
    TraceLogger.instance.warn('money', 'the till printer settings could not be read; set the printer again', error: e, stackTrace: st);
    return const TillPrinterSettings();
  }
}
