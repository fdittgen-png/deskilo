// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- the raw-TCP sender (port 9100 on most receipt printers). The browser cannot open a socket: the web
// build says so, and the screen falls back to the system print dialog.
export 'tcp_receipt_sender_io.dart' if (dart.library.js_interop) 'tcp_receipt_sender_web.dart';
