// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../domain/receipt_sender.dart';

/// Sends the bytes to [host]:[port] over a plain TCP socket and closes it.
class TcpReceiptSender implements ReceiptSender {
  const TcpReceiptSender({required this.host, this.port = 9100, this.timeout = const Duration(seconds: 5)});

  final String host;
  final int port;
  final Duration timeout;

  @override
  Future<void> send(Uint8List bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      await (socket..add(bytes)).flush().timeout(timeout);
      await socket.close().timeout(timeout);
    } on SocketException catch (e) {
      throw ReceiptNotPrinted('socket: ${e.message}');
    } on TimeoutException {
      throw const ReceiptNotPrinted('timeout');
    } finally {
      socket?.destroy();
    }
  }
}
