// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 B — the one query context every Web-BI module reads.
//
// A context names WHAT is asked, never who may see it: the period (its
// grain, and either an offset from the current period or a fixed one),
// the comparison, the grouping, the sort and the view. It travels in the
// /bi address so Back, Forward, Reload and a shared link restore it, and
// it carries no person, amount, resource id or token — a dimension is a
// name ("level"), and the groups are read again from the server for the
// reader and workspace at hand. An address that does not parse is
// refused with its reason; it never falls back to an unfiltered query.
//
// Pure Dart.
library;

/// How long one period is.
enum BiGrain {
  month(1),
  quarter(3),
  year(12);

  const BiGrain(this.months);

  /// Calendar months in one period.
  final int months;

  /// Periods in one year.
  int get perYear => 12 ~/ months;
}

/// What the current period is compared with.
enum BiComparison {
  none,

  /// The period just before, of the same grain.
  previousPeriod,

  /// The same period one year earlier.
  previousYear,

  /// A period the reader chose, of the same grain.
  custom,
}

/// The order of the grouped rows.
enum BiSort { natural, valueDescending, valueAscending }

/// Chart or table: two renderings of the SAME rows.
enum BiView { table, chart }

/// The dimensions a module may be grouped by. A name, never an id.
const biDimensions = <String>{'level'};

/// One calendar period on the workspace clock: [index] counts from 1
/// within [year] (month 1–12, quarter 1–4, year always 1).
class BiPeriod {
  const BiPeriod(this.grain, this.year, this.index);

  final BiGrain grain;
  final int year;
  final int index;

  /// The period containing the workspace date [today].
  factory BiPeriod.containing(BiGrain grain, DateTime today) =>
      BiPeriod(grain, today.year, (today.month - 1) ~/ grain.months + 1);

  /// [by] periods later (negative: earlier).
  BiPeriod shift(int by) {
    final n = year * grain.perYear + (index - 1) + by;
    return BiPeriod(grain, n ~/ grain.perYear, n % grain.perYear + 1);
  }

  /// How many periods [other] lies after this one.
  int distanceTo(BiPeriod other) =>
      (other.year * grain.perYear + other.index) -
      (year * grain.perYear + index);

  /// The first calendar month (1–12) of the period.
  int get startMonth => (index - 1) * grain.months + 1;

  /// The address form: `2026-03`, `2026-Q1`, `2026`.
  String get wire => switch (grain) {
    BiGrain.month => '$year-${index.toString().padLeft(2, '0')}',
    BiGrain.quarter => '$year-Q$index',
    BiGrain.year => '$year',
  };

  /// Parses [wire] for [grain]; null when it is not that grain's form.
  static BiPeriod? parse(BiGrain grain, String wire) {
    final pattern = switch (grain) {
      BiGrain.month => RegExp(r'^(\d{4})-(\d{2})$'),
      BiGrain.quarter => RegExp(r'^(\d{4})-Q([1-4])$'),
      BiGrain.year => RegExp(r'^(\d{4})$'),
    };
    final m = pattern.firstMatch(wire);
    if (m == null) return null;
    final year = int.parse(m.group(1)!);
    final index = grain == BiGrain.year ? 1 : int.parse(m.group(2)!);
    if (year < 2000 || year > 2999 || index < 1 || index > grain.perYear) {
      return null;
    }
    return BiPeriod(grain, year, index);
  }

  @override
  bool operator ==(Object other) =>
      other is BiPeriod &&
      other.grain == grain &&
      other.year == year &&
      other.index == index;

  @override
  int get hashCode => Object.hash(grain, year, index);

  @override
  String toString() => wire;
}

/// Which period is asked: [offset] periods from the current one
/// (relative — "last month" resolves when it is opened), or a [fixed]
/// one that never moves.
class BiPeriodRef {
  const BiPeriodRef.relative(int this.offset) : fixed = null;
  const BiPeriodRef.fixed(BiPeriod this.fixed) : offset = null;

  final int? offset;
  final BiPeriod? fixed;

  bool get isRelative => offset != null;

  BiPeriod resolve(BiGrain grain, DateTime today) =>
      fixed ?? BiPeriod.containing(grain, today).shift(offset!);

  @override
  bool operator ==(Object other) =>
      other is BiPeriodRef && other.offset == offset && other.fixed == fixed;

  @override
  int get hashCode => Object.hash(offset, fixed);
}

/// Why an address or a saved definition was refused.
enum BiContextIssue {
  unknownGrain,
  malformedPeriod,
  unknownComparison,
  unknownDimension,
  unknownSort,
  unknownView,
  malformedCards,
  unknownParameter,
}

/// A parse that failed, with every reason.
class BiContextRefused implements Exception {
  const BiContextRefused(this.issues);

  final Set<BiContextIssue> issues;

  @override
  String toString() => 'BiContextRefused($issues)';
}

/// The query context. Immutable; equal contexts are the same query.
class BiQueryContext {
  const BiQueryContext({
    this.grain = BiGrain.month,
    this.period = const BiPeriodRef.relative(0),
    this.comparison = BiComparison.none,
    this.comparedWith,
    this.groupBy,
    this.sort = BiSort.natural,
    this.view = BiView.table,
    this.cards = const [],
  });

  final BiGrain grain;
  final BiPeriodRef period;
  final BiComparison comparison;

  /// The chosen period when [comparison] is [BiComparison.custom].
  final BiPeriod? comparedWith;

  /// A name from [biDimensions], or null for no grouping.
  final String? groupBy;
  final BiSort sort;
  final BiView view;

  /// #1923 C — the modules shown, in order; empty means every module.
  final List<String> cards;

  /// The product default: this month, nothing compared, not grouped.
  static const standard = BiQueryContext();

  /// The asked period on the workspace date [today].
  BiPeriod current(DateTime today) => period.resolve(grain, today);

  /// The period compared with, or null.
  BiPeriod? compared(DateTime today) {
    final p = current(today);
    return switch (comparison) {
      BiComparison.none => null,
      BiComparison.previousPeriod => p.shift(-1),
      BiComparison.previousYear => p.shift(-grain.perYear),
      BiComparison.custom => comparedWith,
    };
  }

  BiQueryContext copyWith({
    BiGrain? grain,
    BiPeriodRef? period,
    BiComparison? comparison,
    BiPeriod? comparedWith,
    String? groupBy,
    bool clearGroupBy = false,
    BiSort? sort,
    BiView? view,
    List<String>? cards,
  }) {
    final g = grain ?? this.grain;
    final c = comparison ?? this.comparison;
    // A fixed period or a chosen comparison of another grain is not the
    // same question: the grain change resets it rather than reshaping it.
    final regrained = g != this.grain;
    return BiQueryContext(
      grain: g,
      period: regrained && !(period ?? this.period).isRelative
          ? const BiPeriodRef.relative(0)
          : period ?? this.period,
      comparison: regrained && c == BiComparison.custom
          ? BiComparison.previousPeriod
          : c,
      comparedWith: c != BiComparison.custom || regrained
          ? null
          : comparedWith ?? this.comparedWith,
      groupBy: clearGroupBy ? null : groupBy ?? this.groupBy,
      sort: sort ?? this.sort,
      view: view ?? this.view,
      cards: cards ?? this.cards,
    );
  }

  /// The address parameters. Defaults are left out.
  Map<String, String> toQuery() => {
    if (grain != BiGrain.month) 'grain': grain.name,
    if (period.fixed case final f?)
      'at': f.wire
    else if (period.offset != 0)
      'at': '${period.offset}',
    if (comparedWith case final w? when comparison == BiComparison.custom)
      'cmp': w.wire
    else
      'cmp': ?_comparisonWire[comparison],
    'by': ?groupBy,
    if (sort != BiSort.natural) 'sort': _sortWire[sort]!,
    if (view != BiView.table) 'view': view.name,
    if (cards.isNotEmpty) 'cards': cards.join(','),
  };

  /// Parses address parameters (or a saved definition's). Throws
  /// [BiContextRefused] naming every problem; nothing is guessed.
  static BiQueryContext parse(Map<String, String> query) {
    final issues = <BiContextIssue>{};
    for (final k in query.keys) {
      if (!_keys.contains(k)) issues.add(BiContextIssue.unknownParameter);
    }
    final grainWire = query['grain'];
    final grain = grainWire == null
        ? BiGrain.month
        : BiGrain.values.where((g) => g.name == grainWire).firstOrNull;
    if (grain == null) {
      throw const BiContextRefused({BiContextIssue.unknownGrain});
    }
    BiPeriodRef period = const BiPeriodRef.relative(0);
    if (query['at'] case final at?) {
      final offset = RegExp(r'^-?\d{1,3}$').hasMatch(at) ? int.parse(at) : null;
      final fixed = BiPeriod.parse(grain, at);
      if (offset != null) {
        period = BiPeriodRef.relative(offset);
      } else if (fixed != null) {
        period = BiPeriodRef.fixed(fixed);
      } else {
        issues.add(BiContextIssue.malformedPeriod);
      }
    }
    var comparison = BiComparison.none;
    BiPeriod? comparedWith;
    if (query['cmp'] case final cmp?) {
      final named = _comparisonWire.entries
          .where((e) => e.value == cmp)
          .firstOrNull;
      if (named != null) {
        comparison = named.key;
      } else if (BiPeriod.parse(grain, cmp) case final p?) {
        comparison = BiComparison.custom;
        comparedWith = p;
      } else {
        issues.add(BiContextIssue.unknownComparison);
      }
    }
    final by = query['by'];
    if (by != null && !biDimensions.contains(by)) {
      issues.add(BiContextIssue.unknownDimension);
    }
    var sort = BiSort.natural;
    if (query['sort'] case final s?) {
      final named = _sortWire.entries.where((e) => e.value == s).firstOrNull;
      if (named == null) {
        issues.add(BiContextIssue.unknownSort);
      } else {
        sort = named.key;
      }
    }
    var view = BiView.table;
    if (query['view'] case final v?) {
      final named = BiView.values.where((x) => x.name == v).firstOrNull;
      if (named == null) {
        issues.add(BiContextIssue.unknownView);
      } else {
        view = named;
      }
    }
    var cards = const <String>[];
    if (query['cards'] case final c?) {
      cards = c.split(',');
      if (cards.length > 20 || !cards.every(_cardId.hasMatch)) {
        issues.add(BiContextIssue.malformedCards);
      }
    }
    if (issues.isNotEmpty) throw BiContextRefused(issues);
    return BiQueryContext(
      grain: grain,
      period: period,
      comparison: comparison,
      comparedWith: comparedWith,
      groupBy: by,
      sort: sort,
      view: view,
      cards: cards,
    );
  }

  /// [parse], or null when the parameters are refused.
  static BiQueryContext? tryParse(Map<String, String> query) {
    try {
      return parse(query);
    } on BiContextRefused {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BiQueryContext &&
      other.grain == grain &&
      other.period == period &&
      other.comparison == comparison &&
      other.comparedWith == comparedWith &&
      other.groupBy == groupBy &&
      other.sort == sort &&
      other.view == view &&
      _sameList(other.cards, cards);

  @override
  int get hashCode => Object.hash(
    grain,
    period,
    comparison,
    comparedWith,
    groupBy,
    sort,
    view,
    Object.hashAll(cards),
  );

  @override
  String toString() => 'BiQueryContext(${toQuery()})';
}

const _keys = {'grain', 'at', 'cmp', 'by', 'sort', 'view', 'cards'};

final _cardId = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$');

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const _comparisonWire = {
  BiComparison.previousPeriod: 'previous',
  BiComparison.previousYear: 'year',
};

const _sortWire = {
  BiSort.valueDescending: 'value_desc',
  BiSort.valueAscending: 'value_asc',
};
