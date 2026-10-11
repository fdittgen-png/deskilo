// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #875 — the millimetre reader moved into the engine so the CLI `check`
// and the tests measure with ONE implementation. This keeps the tests'
// import path, and holds what only tests need (#2383).
import 'dart:io';
import 'dart:typed_data';

export 'package:deskilo/features/money/domain/report_layout/pdf_geometry.dart';

/// Writes [bytes] beside the test run so a failure can be OPENED rather
/// than argued about, and returns the path.
String saveForInspection(Uint8List bytes, String name) {
  final dir = Directory('build/pdf-conformance')..createSync(recursive: true);
  final file = File('${dir.path}/$name')
    ..writeAsBytesSync(bytes);
  return file.path;
}
