// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- where the receipt's bytes go: a printer on the local network. The sale is final before anything is
// sent; a printer that cannot be reached or is out of paper is [ReceiptNotPrinted], never a failed sale.
import 'dart:typed_data';

import '../../../core/failure/app_failure.dart' show TypedRefusal;

/// The printer did not take the receipt: the sale stands, the receipt can be printed again (a reprint) or shared.
/// How long a receipt printer may take to accept a job before it is said to be unreachable.
const receiptPrinterTimeout = Duration(seconds: 5);

class ReceiptNotPrinted implements TypedRefusal {
  const ReceiptNotPrinted(this.reason);

  /// What went wrong, for the trace; the cashier is told the sentence of the screen, not this.
  final String reason;

  @override
  String toString() => 'ReceiptNotPrinted: $reason';
}

abstract interface class ReceiptSender {
  /// Sends [bytes] to the printer and returns once it has them; [ReceiptNotPrinted] when it did not take them.
  Future<void> send(Uint8List bytes);
}
