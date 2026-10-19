// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2454 -- a feature can be available in only some countries. The country is
// the workspace's; the stored flag is never touched (a space whose country
// matches again gets the feature back exactly as configured). SQL twin:
// `feature_available_in` (0486), generated from the same manifest.
import '../../../core/vat/tax_reference_active.dart';
import 'workspace_feature.dart';

/// A member of the list that stands for "every EU member state", resolved
/// against the `eu_member` rows of the tax reference store: the list is data
/// (#2476), never typed a second time.
const featureCountriesEu = '@eu';

/// Whether a feature declared available in [availableIn] (null = everywhere)
/// is available in [country] (an ISO 3166-1 alpha-2 code; null or empty
/// means the country is not known, which restricts nothing).
bool featureAvailableIn(Set<String>? availableIn, String? country) {
  if (availableIn == null) return true;
  final code = (country ?? '').trim().toUpperCase();
  if (code.isEmpty) return true;
  return availableIn.contains(code) ||
      (availableIn.contains(featureCountriesEu) &&
          ActiveTaxReference.current.isEu(code));
}

/// The features among [enabled] that [country] does not offer: what switching
/// to that country would turn off (the stored switches are kept).
List<WorkspaceFeature> featuresLostInCountry(
  Iterable<WorkspaceFeature> enabled,
  String country,
) => [
  for (final f in enabled)
    if (!featureAvailableIn(featureManifest[f]?.availableIn, country)) f,
];
