// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — writes the accounting target registry's coverage table into
// docs/domain/ACCOUNTING_EXPORTS.md, between its generated markers.
//
//   dart run tool/build_accounting_coverage.dart
import 'dart:io';

import 'package:deskilo/features/money/domain/accounting_coverage.dart';

const _doc = 'docs/domain/ACCOUNTING_EXPORTS.md';

void main() {
  final file = File(_doc);
  file.writeAsStringSync(withAccountingCoverage(file.readAsStringSync()));
  stdout.writeln('wrote the target table of $_doc');
}
