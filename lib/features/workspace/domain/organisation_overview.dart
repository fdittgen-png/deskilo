// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4007 — an organisation's houses side by side (decision 0052, point 6):
// each house with the figures its own analysis shows, in its own currency,
// and totals per currency. Nothing is converted and nothing is added across
// currencies. A house whose figures the reader may not read is named
// without them, with the reason.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

/// Why a house shows no figures.
enum OverviewWithheld {
  /// The reader may not read this house's finances.
  notPermitted('not_permitted'),

  /// The house's analysis is off.
  notEnabled('not_enabled');

  const OverviewWithheld(this.wire);

  /// The server's word for it.
  final String wire;

  /// The reason [wire] names; a word this app does not know reads as not
  /// permitted, the reason that promises nothing.
  static OverviewWithheld? of(String? wire) => wire == null
      ? null
      : values.where((w) => w.wire == wire).firstOrNull ?? notPermitted;
}

/// One amount, in minor units of its house's currency: a period figure for
/// the months asked, or a state as of a moment.
class HouseFigure {
  const HouseFigure({required this.minor, this.asOf});

  /// The figure in [raw], or none when the house's analysis gave none.
  static HouseFigure? fromJson(Object? raw) {
    if (raw == null) return null;
    final row = JsonReader.of(raw, context: 'overview figure');
    final minor = row.intOrNull('minor');
    if (minor == null) return null;
    return HouseFigure(minor: minor, asOf: row.dateTimeOrNull('as_of'));
  }

  final int minor;

  /// When a state was read; null for a period figure.
  final DateTime? asOf;

  /// Whether this is a state as of a moment rather than a period figure.
  bool get isState => asOf != null;
}

/// One house as the overview shows it.
class OverviewHouse {
  const OverviewHouse({
    required this.workspaceId,
    required this.name,
    required this.countryCode,
    required this.currencyCode,
    required this.isHead,
    this.invoiced,
    this.collected,
    this.overdue,
    this.withheld,
    this.unavailable = false,
  });

  factory OverviewHouse.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'overview house');
    final figures = row.objectOrNull('figures');
    return OverviewHouse(
      workspaceId: row.string('workspace_id'),
      name: row.stringOr('name'),
      countryCode: row.stringOr('country'),
      currencyCode: row.stringOr('currency'),
      isHead: row.isTrue('is_head'),
      invoiced: HouseFigure.fromJson(figures?.raw('invoiced')),
      collected: HouseFigure.fromJson(figures?.raw('collected')),
      overdue: HouseFigure.fromJson(figures?.raw('overdue')),
      withheld: OverviewWithheld.of(row.stringOrNull('withheld')),
      unavailable:
          figures?.listOrAbsent('quality').contains('unavailable') ?? false,
    );
  }

  final String workspaceId;
  final String name;
  final String countryCode;
  final String currencyCode;
  final bool isHead;
  final HouseFigure? invoiced;
  final HouseFigure? collected;
  final HouseFigure? overdue;

  /// Why the house shows no figures; null when it shows them.
  final OverviewWithheld? withheld;

  /// The house's own analysis marks a figure as not to be trusted (it
  /// counts in more than one currency).
  final bool unavailable;
}

/// The total of one currency: the houses that count in it, never another.
class OverviewTotal {
  const OverviewTotal({
    required this.currencyCode,
    required this.houses,
    required this.invoiced,
    required this.collected,
    required this.overdue,
    required this.incomplete,
  });

  factory OverviewTotal.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'overview total');
    int minorOf(String key) => row.objectOrNull(key)?.intOrNull('minor') ?? 0;
    return OverviewTotal(
      currencyCode: row.stringOr('currency'),
      houses: row.intOrNull('houses') ?? 0,
      invoiced: minorOf('invoiced'),
      collected: minorOf('collected'),
      overdue: minorOf('overdue'),
      incomplete: row.isTrue('incomplete'),
    );
  }

  final String currencyCode;
  final int houses;
  final int invoiced;
  final int collected;
  final int overdue;

  /// A house of this currency gave no figures, or one it marks unavailable.
  final bool incomplete;
}

/// The organisation's houses for one period, and a total per currency.
class OrganisationOverview {
  const OrganisationOverview({
    required this.organisationId,
    required this.from,
    required this.to,
    required this.houses,
    required this.totals,
  });

  /// [houses] with their totals as the server makes them (0780): per
  /// currency, a house without figures or with one it marks unavailable
  /// makes its currency's total incomplete and adds nothing to it.
  factory OrganisationOverview.ofHouses({
    required String organisationId,
    required String month,
    required List<OverviewHouse> houses,
  }) {
    final totals = <String, OverviewTotal>{};
    for (final h in houses) {
      final t = totals[h.currencyCode];
      final counted = h.withheld == null && !h.unavailable;
      totals[h.currencyCode] = OverviewTotal(
        currencyCode: h.currencyCode,
        houses: (t?.houses ?? 0) + 1,
        invoiced: (t?.invoiced ?? 0) + (counted ? h.invoiced?.minor ?? 0 : 0),
        collected:
            (t?.collected ?? 0) + (counted ? h.collected?.minor ?? 0 : 0),
        overdue: (t?.overdue ?? 0) + (h.overdue?.minor ?? 0),
        incomplete:
            (t?.incomplete ?? false) ||
            !counted ||
            h.invoiced == null ||
            h.overdue == null,
      );
    }
    return OrganisationOverview(
      organisationId: organisationId,
      from: month,
      to: month,
      houses: houses,
      totals: totals.values.toList()
        ..sort((a, b) => a.currencyCode.compareTo(b.currencyCode)),
    );
  }

  factory OrganisationOverview.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'organisation overview');
    return OrganisationOverview(
      organisationId: row.string('organisation_id'),
      from: row.stringOr('from'),
      to: row.stringOr('to'),
      houses: [
        for (final h in row.listOrAbsent('houses')) OverviewHouse.fromJson(h),
      ],
      totals: [
        for (final t in row.listOrAbsent('totals')) OverviewTotal.fromJson(t),
      ],
    );
  }

  final String organisationId;

  /// The months asked, `YYYY-MM`.
  final String from;
  final String to;
  final List<OverviewHouse> houses;
  final List<OverviewTotal> totals;

  /// The houses of [currencyCode] that gave no figures, by name: what an
  /// incomplete total is missing.
  List<String> missingIn(String currencyCode) => [
    for (final h in houses)
      if (h.currencyCode == currencyCode &&
          (h.withheld != null || h.unavailable))
        h.name,
  ];
}
