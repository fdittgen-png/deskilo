// SPDX-License-Identifier: 0BSD
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import 'file_types.dart';

/// The browser implementation of the local save.
///
/// A web page cannot write to a folder, so "save" means what it means in a
/// browser: hand the bytes to the download machinery and let the user's own
/// settings decide where they land. The returned handle is the file NAME —
/// there is no path to report, and inventing one would only produce a
/// snackbar pointing at nothing.
Future<String?> saveToDownloads({
  required Uint8List bytes,
  required String fileName,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeTypeFor(fileName)),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    // Off-layout: the anchor exists only to be clicked.
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // The object URL pins the blob in memory until it is revoked.
  web.URL.revokeObjectURL(url);
  return fileName;
}

/// Nothing to migrate: no build of this app ever wrote a file into a
/// browser's storage, so there is no hidden directory to rescue exports
/// from (see the device implementation for what this repairs there).
Future<int> migrateLegacyExports() async => 0;
