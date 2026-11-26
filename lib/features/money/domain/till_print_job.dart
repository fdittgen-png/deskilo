// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- what is sent to the printer for one act of the till: the drawer's kick (after a cash tender, when a
// drawer hangs on the printer), the receipt, or both in one send so the drawer opens as the receipt prints.
import 'dart:typed_data';

import 'escpos_receipt.dart';
import 'till_printer_settings.dart';

/// The bytes of one job. With no [receipt] only the drawer kicks; nothing is made up when there is nothing to do.
Uint8List tillPrintJob({ReceiptPrint? receipt, required TillPrinterSettings settings, bool kickDrawer = false}) {
  final out = BytesBuilder();
  if (kickDrawer && settings.drawer) out.add(drawerKick());
  if (receipt != null) out.add(encodeReceipt(receipt, settings.profile));
  return out.toBytes();
}
