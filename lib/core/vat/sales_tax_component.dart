// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- one jurisdiction's share of what a US postal code carries (a
// component of a `sales_tax` row of the tax reference store).
import '../data/json_reader.dart';

/// One jurisdiction's share of what a postal code carries: its level
/// (`state`, `county`, `city`, `district`), its name and its percent.
class SalesTaxComponent {
  const SalesTaxComponent({
    required this.level,
    required this.label,
    required this.percent,
  });

  final String level;
  final String label;
  final double percent;

  factory SalesTaxComponent.fromReader(JsonReader r) => SalesTaxComponent(
    level: r.string('level'),
    label: r.string('label'),
    percent: r.number('percent'),
  );

  Map<String, Object?> toJson() => {
    'level': level,
    'label': label,
    'percent': percent,
  };
}
