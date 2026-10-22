// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C2 — a shared operating cost spread over the resources that use it,
// by weights a person entered: never a bill to a member, never a posting,
// never a rewritten document. The SERVER allocates (`kpi_cost_allocation`);
// this is the same arithmetic for the editor's preview, pinned to the same
// figures as the database test.
//
//   * integer minor units by largest remainder: every share is the floor of
//     its exact part, and the units left go one each to the largest
//     remainders, a tie to the resource that sorts first (kind, then id);
//     the shares always add up to the amount;
//   * no weight, or weights that add up to 0, allocate nothing: the cost
//     stays unallocated, never spread evenly or set to 0;
//   * a credit (a negative amount) is spread like a cost, with its sign.
//
// Pure Dart: no Flutter, no l10n.
library;

/// One resource's weight in an allocation rule.
class AllocationWeight {
  const AllocationWeight({
    required this.resourceKind,
    required this.resourceId,
    required this.weight,
  });

  final String resourceKind;
  final String resourceId;

  /// A nonnegative whole number, as entered.
  final int weight;
}

/// What one resource received, in minor units.
class AllocationShare {
  const AllocationShare({
    required this.resourceKind,
    required this.resourceId,
    required this.minor,
  });

  final String resourceKind;
  final String resourceId;
  final int minor;

  @override
  bool operator ==(Object other) =>
      other is AllocationShare &&
      other.resourceKind == resourceKind &&
      other.resourceId == resourceId &&
      other.minor == minor;

  @override
  int get hashCode => Object.hash(resourceKind, resourceId, minor);

  @override
  String toString() => '$resourceKind:$resourceId=$minor';
}

int _byResource(AllocationWeight a, AllocationWeight b) {
  final kind = a.resourceKind.compareTo(b.resourceKind);
  return kind != 0 ? kind : a.resourceId.compareTo(b.resourceId);
}

/// Spreads [amountMinor] over [weights] by largest remainder, in resource
/// order. Null when nothing can be allocated: no positive weight, a negative
/// weight, or the same resource twice.
List<AllocationShare>? allocateByLargestRemainder(
  int amountMinor,
  List<AllocationWeight> weights,
) {
  final seen = <String>{};
  for (final w in weights) {
    if (w.weight < 0 || !seen.add('${w.resourceKind}:${w.resourceId}')) {
      return null;
    }
  }
  final total = weights.fold<int>(0, (sum, w) => sum + w.weight);
  if (total == 0) return null;
  final sorted = [...weights]..sort(_byResource);
  final sign = amountMinor < 0 ? -1 : 1;
  final amount = amountMinor.abs();
  final floors = [for (final w in sorted) amount * w.weight ~/ total];
  final remainders = [for (final w in sorted) amount * w.weight % total];
  var left = amount - floors.fold<int>(0, (sum, f) => sum + f);
  // The largest remainders first; a tie keeps the resource order.
  final order = [for (var i = 0; i < sorted.length; i++) i]
    ..sort((a, b) {
      final r = remainders[b].compareTo(remainders[a]);
      return r != 0 ? r : a.compareTo(b);
    });
  for (final i in order) {
    if (left == 0) break;
    floors[i] += 1;
    left -= 1;
  }
  return [
    for (var i = 0; i < sorted.length; i++)
      AllocationShare(
        resourceKind: sorted[i].resourceKind,
        resourceId: sorted[i].resourceId,
        minor: sign * floors[i],
      ),
  ];
}
