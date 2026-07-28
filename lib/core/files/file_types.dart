// SPDX-License-Identifier: 0BSD
import 'package:flutter/services.dart';

/// Writes [bytes] to a local file named [fileName] and returns a handle to
/// it (null on failure): a filesystem path on a device, the file name in a
/// browser, where "where it went" is the download folder the browser owns.
/// Deliberately a LOCAL save — the file lands in the user's own storage,
/// never handed to the system share sheet or another app.
typedef FileSaver = Future<String?> Function({
  required Uint8List bytes,
  required String fileName,
});

/// MIME by extension for the Downloads entry (viewers key off it) — and,
/// on the web, for the Blob the browser is handed.
String mimeTypeFor(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.xml')) return 'text/xml';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.log') || lower.endsWith('.txt')) return 'text/plain';
  return 'application/octet-stream';
}
