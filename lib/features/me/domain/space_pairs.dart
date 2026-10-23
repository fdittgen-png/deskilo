// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../workspace/domain/workspace.dart';

/// The key a space's row has in the person's layout: both sides of an
/// environment pair share one.
String spaceRowKeyOf(SpaceSide space) =>
    space.pairId.isEmpty ? 'space:${space.id}' : 'pair:${space.pairId}';

/// [spaces] as rows: one per lone space or environment pair, in the order
/// each row's first side comes in, production first within a row.
List<List<T>> pairSides<T extends SpaceSide>(Iterable<T> spaces) {
  final rows = <String, List<T>>{};
  for (final space in spaces) {
    (rows[spaceRowKeyOf(space)] ??= []).add(space);
  }
  return [
    for (final sides in rows.values)
      sides..sort(
        (a, b) => (b.env.isProduction ? 1 : 0) - (a.env.isProduction ? 1 : 0),
      ),
  ];
}
