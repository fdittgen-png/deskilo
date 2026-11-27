// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- how this till prints: the printer on the local network, the paper, the code page, whether a cash drawer
// hangs on it and whether a sale prints by itself. A setting of the DEVICE the till runs on (the printer is wired to
// it), so it lives on the device, not in the business's settings.
import 'escpos_receipt.dart';

/// Whether a finished sale prints without being asked.
enum TillPrintMode {
  /// Only when the cashier asks.
  never,

  /// The sale is finished, the cashier is offered the print.
  ask,

  /// The receipt prints as the sale is made.
  always,
}

class TillPrinterSettings {
  const TillPrinterSettings({
    this.host = '',
    this.port = defaultPort,
    this.paperMm = 80,
    this.codePage = EscposCodePage.cp858,
    this.drawer = false,
    this.mode = TillPrintMode.ask,
  });

  /// The port receipt printers listen on for raw ESC/POS (JetDirect).
  static const defaultPort = 9100;

  /// The printer's address (a name or an IP on the local network); empty until one is set.
  final String host;
  final int port;

  /// 58 or 80.
  final int paperMm;
  final EscposCodePage codePage;

  /// Whether a drawer is attached to the printer: it is kicked open after a cash tender.
  final bool drawer;
  final TillPrintMode mode;

  /// Whether a printer is named: nothing prints, and no drawer opens, before it is.
  bool get configured => host.trim().isNotEmpty;

  EscposProfile get profile => EscposProfile(paperMm: paperMm, codePage: codePage);

  TillPrinterSettings copyWith({String? host, int? port, int? paperMm, EscposCodePage? codePage, bool? drawer, TillPrintMode? mode}) =>
      TillPrinterSettings(
        host: host ?? this.host,
        port: port ?? this.port,
        paperMm: paperMm ?? this.paperMm,
        codePage: codePage ?? this.codePage,
        drawer: drawer ?? this.drawer,
        mode: mode ?? this.mode,
      );
}
