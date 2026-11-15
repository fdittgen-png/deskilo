// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — a house abroad arrives with the head's services and packages
// inactive and without a rate: nothing is sold in a new country before its
// owner has looked at price and tax. These are the rules of naming them: which
// rows are still to name, which of the house's rates a row's hint proposes,
// and how many are left. Pure Dart: no screen, no feature.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import 'package.dart';
import 'service_item.dart';

/// Which catalogue a row to name belongs to.
enum HouseRowKind {
  services('services'),
  packages('packages');

  const HouseRowKind(this.table);

  /// The table the birth record's hints are keyed by.
  final String table;
}

/// One inactive row the house's owner names: its kind, id, name, price and
/// rate as they stand.
typedef HouseRow = ({
  HouseRowKind kind,
  String id,
  String name,
  int priceCents,
  String vatRateId,
});

/// The services and packages still to name: the inactive ones, services
/// first, each in its catalogue's order.
List<HouseRow> houseRowsToName({
  required Iterable<ServiceItem> services,
  required Iterable<Package> packages,
}) => [
  for (final s in services)
    if (!s.active)
      (
        kind: HouseRowKind.services,
        id: s.id,
        name: s.name,
        priceCents: s.priceCents,
        vatRateId: s.vatRateId,
      ),
  for (final p in packages)
    if (!p.active)
      (
        kind: HouseRowKind.packages,
        id: p.id,
        name: p.name,
        priceCents: p.priceCents,
        vatRateId: p.vatRateId,
      ),
];

/// The rate [row]'s hint proposes among the house's [rates]: the one active
/// rate of the hint's category (EN 16931: S, Z, E, O); none when the head
/// gave no hint, or when the house has no such rate or more than one (a
/// standard and a reduced rate both read S: the owner then chooses).
VatRate? proposedHouseRate(
  HouseRow row,
  Map<String, String> hints,
  List<VatRate> rates,
) {
  final category = hints['${row.kind.table}:${row.name}'];
  if (category == null) return null;
  final matching = [
    for (final r in rates)
      if (r.active && r.category == category) r,
  ];
  return matching.length == 1 ? matching.single : null;
}
