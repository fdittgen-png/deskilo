// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- the Demo's receipt printer: it keeps what it was sent, so a printed receipt can be read back and the
// golden bytes compared. A Demo till prints to it; nothing leaves the device.
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/receipt_sender.dart';

class DemoReceiptPrinter implements ReceiptSender {
  DemoReceiptPrinter({this.reachable = true});

  /// False answers as a printer that cannot be reached (the cashier's "not printed" case).
  bool reachable;

  /// Every job sent, in order.
  final jobs = <Uint8List>[];

  @override
  Future<void> send(Uint8List bytes) async {
    if (!reachable) throw const ReceiptNotPrinted('the Demo printer is switched off');
    jobs.add(bytes);
  }
}
