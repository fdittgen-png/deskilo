// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1333, #4396 -- prints the feature registry ROWS a new migration carries: the rows of the features the Dart manifest
// has added, re-parented or re-defaulted since the migrations last wrote them, and a deletion for each feature it no
// longer has. Nothing is printed to stderr and nothing to stdout when the migrations already match the manifest.
//
//   dart run tool/build_feature_registry_sql.dart
//
// Paste the output into the migration that adds the feature; feature_registry_sql_test fails until the migrations
// accumulate exactly the manifest. `public.feature_registry()` itself is never restated (0949).
import 'dart:io';

import 'package:deskilo/features/workspace/domain/feature_registry_sql.dart';

void main() {
  final files = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final block = featureRegistryRowsSql(accumulatedFeatureRegistry([for (final f in files) f.readAsStringSync()]));
  if (block == null) {
    stderr.writeln('the migrations already carry the feature registry: nothing to add');
  } else {
    stdout.writeln(block);
  }
}
