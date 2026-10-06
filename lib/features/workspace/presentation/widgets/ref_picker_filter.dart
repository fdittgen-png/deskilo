// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The filter behind the reference picker: a long list of invoices, payments
// or alerts is narrowed by what a person actually knows — who it is about,
// whether it is still open, which month, how much — not only by typing.
//
// Pure Dart on purpose: the picker's sheet draws it, a test drives it with
// plain values.

/// One value of a facet: [id] is what is compared, [label] what is shown.
typedef RefFacetValue = ({String id, String label});

/// A dimension a candidate can be filtered by (status, person, month…).
class RefFacet {
  const RefFacet({
    required this.key,
    required this.label,
    this.quick = false,
    this.multi = true,
  });

  final String key;
  final String label;

  /// Shown as the one-tap chips above the list (at most one facet).
  final bool quick;

  /// Several values may be picked together (OR within a facet, AND across).
  final bool multi;
}

enum RefSort { newest, oldest, amountHigh, amountLow }

/// What is currently narrowing the list.
class RefFilter {
  const RefFilter({
    this.query = '',
    this.selected = const {},
    this.minCents,
    this.maxCents,
    this.sort = RefSort.newest,
  });

  final String query;

  /// facet key → the chosen value ids.
  final Map<String, Set<String>> selected;
  final int? minCents;
  final int? maxCents;
  final RefSort sort;

  RefFilter copyWith({
    String? query,
    Map<String, Set<String>>? selected,
    int? minCents,
    int? maxCents,
    bool clearAmount = false,
    RefSort? sort,
  }) => RefFilter(
    query: query ?? this.query,
    selected: selected ?? this.selected,
    minCents: clearAmount ? null : (minCents ?? this.minCents),
    maxCents: clearAmount ? null : (maxCents ?? this.maxCents),
    sort: sort ?? this.sort,
  );

  /// Toggles [value] of [facet]; a single-choice facet replaces its value.
  RefFilter toggled(RefFacet facet, String value) {
    final next = {
      for (final e in selected.entries) e.key: {...e.value},
    };
    final current = next.putIfAbsent(facet.key, () => <String>{});
    if (current.contains(value)) {
      current.remove(value);
    } else {
      if (!facet.multi) current.clear();
      current.add(value);
    }
    if (current.isEmpty) next.remove(facet.key);
    return copyWith(selected: next);
  }

  RefFilter cleared(String facetKey) {
    final next = {...selected}..remove(facetKey);
    return copyWith(selected: next);
  }

  bool get hasAmount => minCents != null || maxCents != null;

  /// How many narrowing choices are on, the search words not counted.
  int get activeCount =>
      selected.values.fold(0, (n, v) => n + v.length) + (hasAmount ? 1 : 0);

  bool get isEmpty => query.trim().isEmpty && activeCount == 0;
}

/// What the filter needs of a candidate.
abstract interface class RefFilterable {
  String get keywords;
  Map<String, RefFacetValue> get facets;
  int? get amountCents;
  DateTime? get at;
}

/// The candidates [filter] lets through, in its order. Every search word
/// must appear somewhere (any order); a facet passes when the candidate's
/// value is among those chosen; the amount compares by magnitude, so a
/// credit note (negative) is found by the same range as an invoice.
List<T> applyRefFilter<T extends RefFilterable>(
  List<T> all,
  RefFilter filter, {
  String? ignoreFacet,
}) {
  final words = filter.query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  bool passes(T c) {
    if (!words.every(c.keywords.contains)) return false;
    for (final entry in filter.selected.entries) {
      if (entry.key == ignoreFacet || entry.value.isEmpty) continue;
      final value = c.facets[entry.key]?.id;
      if (value == null || !entry.value.contains(value)) return false;
    }
    if (filter.hasAmount) {
      final cents = c.amountCents?.abs();
      if (cents == null) return false;
      if (filter.minCents != null && cents < filter.minCents!) return false;
      if (filter.maxCents != null && cents > filter.maxCents!) return false;
    }
    return true;
  }

  final kept = [
    for (final c in all)
      if (passes(c)) c,
  ];
  int byDate(T a, T b) {
    final x = a.at, y = b.at;
    if (x == null || y == null) return 0;
    return x.compareTo(y);
  }

  int byAmount(T a, T b) =>
      (a.amountCents?.abs() ?? 0).compareTo(b.amountCents?.abs() ?? 0);
  // `sort` is stable: candidates without the sorted quantity keep their
  // incoming order.
  switch (filter.sort) {
    case RefSort.newest:
      kept.sort((a, b) => byDate(b, a));
    case RefSort.oldest:
      kept.sort(byDate);
    case RefSort.amountHigh:
      kept.sort((a, b) => byAmount(b, a));
    case RefSort.amountLow:
      kept.sort(byAmount);
  }
  return kept;
}

/// The values of [facetKey] present in [all], with how many candidates each
/// would leave GIVEN every OTHER choice — so the count next to "Open" is what
/// tapping it would show, not a number that ignores the person already chosen.
List<({RefFacetValue value, int count})> refFacetOptions<
  T extends RefFilterable
>(List<T> all, RefFilter filter, String facetKey) {
  final pool = applyRefFilter(all, filter, ignoreFacet: facetKey);
  final counts = <String, int>{};
  final labels = <String, String>{};
  for (final c in pool) {
    final v = c.facets[facetKey];
    if (v == null) continue;
    counts[v.id] = (counts[v.id] ?? 0) + 1;
    labels[v.id] = v.label;
  }
  // A chosen value that currently leaves nothing is still listed, so it
  // can be unticked.
  for (final id in filter.selected[facetKey] ?? const <String>{}) {
    counts.putIfAbsent(id, () => 0);
    labels.putIfAbsent(id, () {
      for (final c in all) {
        final v = c.facets[facetKey];
        if (v?.id == id) return v!.label;
      }
      return id;
    });
  }
  final entries = [
    for (final id in counts.keys)
      (value: (id: id, label: labels[id]!), count: counts[id]!),
  ];
  return entries;
}

/// The smallest and largest amount (by magnitude) among [all], or null.
({int min, int max})? refAmountBounds(Iterable<RefFilterable> all) {
  int? lo, hi;
  for (final c in all) {
    final cents = c.amountCents?.abs();
    if (cents == null) continue;
    lo = lo == null || cents < lo ? cents : lo;
    hi = hi == null || cents > hi ? cents : hi;
  }
  return lo == null ? null : (min: lo, max: hi!);
}
