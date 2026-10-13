// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 — the tax reference seed, generated from the Dart constants.
//
//   dart run tool/build_tax_reference_seed.dart                 # writes assets/instance/tax_reference.json
//   dart run tool/build_tax_reference_seed.dart --migration supabase/migrations/NNNN_tax_reference.sql
//                                                               # also replaces the migration's seed block
//   dart run tool/build_tax_reference_seed.dart --sql           # prints the insert
//
// `test/tool/tax_reference_seed_test.dart` fails when the asset or the
// migration's block differs from what the constants produce.
import 'dart:io';

import 'tax_reference/seed.dart';

void main(List<String> args) {
  final rows = buildTaxReferenceSeed();
  if (args.contains('--sql')) {
    stdout.writeln(taxReferenceSeedSql(rows));
    return;
  }
  final out = File('assets/instance/tax_reference.json')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(taxReferenceBundleJson(rows));
  stdout.writeln('wrote ${out.path}: ${rows.length} rows');
  final i = args.indexOf('--migration');
  if (i >= 0 && i + 1 < args.length) {
    final file = File(args[i + 1]);
    file.writeAsStringSync(withTaxReferenceSeed(file.readAsStringSync(), rows));
    stdout.writeln('rewrote the seed block of ${file.path}');
  }
}
