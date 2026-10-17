// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2539 -- one tax inside a combined rate (a component of a `rate_component`
// row of the tax reference store).
import '../data/json_reader.dart';

/// One tax inside a combined rate: its scheme (`GST`, `HST`, `QST`, `PST`),
/// who levies it (`CA`, `CA-QC`, `CA-PST`) and its own percentage.
class RateComponent {
  const RateComponent({
    required this.scheme,
    required this.authority,
    required this.percent,
  });

  final String scheme;
  final String authority;
  final double percent;

  factory RateComponent.fromReader(JsonReader r) => RateComponent(
        scheme: r.string('scheme'),
        authority: r.string('authority'),
        percent: r.number('percent'),
      );

  Map<String, Object?> toJson() =>
      {'scheme': scheme, 'authority': authority, 'percent': percent};
}
