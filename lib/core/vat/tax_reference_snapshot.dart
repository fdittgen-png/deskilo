// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L4 -- the tax reference dataset a workspace operation runs on, as
// captured into the `WorkspaceContext` from the workspace's own
// installation. A [TaxReferenceSet] is a list of rows; this names its
// revision, so two contexts can tell whether they ran on the same data, and
// refuses an empty dataset: "no rows" would read as "no country is in the
// EU", never as the configuration failure it is.
import 'dart:convert';

import 'package:meta/meta.dart';

import '../cache/cache_scope.dart';
import 'tax_reference.dart';

@immutable
class TaxReferenceSnapshot {
  TaxReferenceSnapshot(this.set) {
    if (set.isEmpty) {
      throw const TaxReferenceUnavailable('the installation holds no tax reference rows');
    }
  }

  final TaxReferenceSet set;

  TaxReferenceOrigin get origin => set.origin;

  /// The digest of every row as stored: equal revisions are the same data.
  late final String revision = cacheDigest('tax-reference', [
    set.origin.name,
    for (final row in set.rows) jsonEncode(row.toJson()),
  ], 24);

  @override
  bool operator ==(Object other) =>
      other is TaxReferenceSnapshot && other.revision == revision;

  @override
  int get hashCode => revision.hashCode;

  @override
  String toString() => 'TaxReferenceSnapshot(${set.origin.name}, $revision)';
}
