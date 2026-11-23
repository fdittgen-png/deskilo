// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import '../domain/receipt_sender.dart';

/// The browser has no socket: nothing is sent, and the caller offers the system print dialog.
class TcpReceiptSender implements ReceiptSender {
  const TcpReceiptSender({required this.host, this.port = 9100, this.timeout = const Duration(seconds: 5)});

  final String host;
  final int port;
  final Duration timeout;

  @override
  Future<void> send(Uint8List bytes) => Future.error(const ReceiptNotPrinted('no socket in the browser'));
}
