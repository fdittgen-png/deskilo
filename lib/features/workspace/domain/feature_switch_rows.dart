// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Which switches the Features screen lists for what the owner typed and
// chose, and how many switches differ from their default.
//
// Pure Dart.
library;

import 'workspace_feature.dart';

/// The words a switch row is found by: its name, its description and its
/// "Requires" line, already in the reader's language.
typedef FeatureRowText = ({String name, String description, String? requires});

/// The rows of [manifest] the list shows, in manifest order, and how many
/// of ALL rows differ from their default: the "Changed" count is what the
/// space has moved, so no filter narrows it.
///
/// A row is shown when it passes "Changed" ([changedOnly]: stored state is
/// not the default), the maturity filter ([maturityMatches]) and [query].
/// [textOf] is read only for rows the first two filters keep.
({List<FeatureManifestEntry> rows, int changedCount}) featureSwitchRows(
  Iterable<FeatureManifestEntry> manifest, {
  required Set<WorkspaceFeature> raw,
  required String query,
  required bool changedOnly,
  required bool Function(FeatureManifestEntry entry) maturityMatches,
  required FeatureRowText Function(FeatureManifestEntry entry) textOf,
}) {
  final rows = <FeatureManifestEntry>[];
  var changedCount = 0;
  for (final entry in manifest) {
    final changed = raw.contains(entry.feature) != entry.defaultOn;
    if (changed) changedCount++;
    if (changedOnly && !changed) continue;
    if (!maturityMatches(entry)) continue;
    if (!_matches(query, textOf(entry))) continue;
    rows.add(entry);
  }
  return (rows: rows, changedCount: changedCount);
}

/// Does [query] find a row? Name AND description, because an owner who
/// does not know a feature's name searches for what it does ("reminder"
/// finds *Payment reminders*), and the "Requires" line, case-insensitively.
/// An empty query finds every row.
bool _matches(String query, FeatureRowText text) {
  if (query.isEmpty) return true;
  final needle = query.toLowerCase();
  return text.name.toLowerCase().contains(needle) ||
      text.description.toLowerCase().contains(needle) ||
      (text.requires ?? '').toLowerCase().contains(needle);
}
