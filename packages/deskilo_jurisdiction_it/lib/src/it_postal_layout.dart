// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in Italy is written below its street: the postal code, the locality in capitals, then the province code (Poste Italiane: 20121 MILANO MI).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

import 'it_regions.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const itPostalLayoutImplementationVersion = '2';

/// The postal layout of Italy.
class ItPostalLayout extends PostalLayoutContribution {
  const ItPostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'it.postal_layout',
    implementationVersion: itPostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.IT',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.postalCode, PostalPart.city, PostalPart.region],
    ],
    cityInCapitals: true,
    region: RegionField(
      kind: RegionKind.province,
      required: true,
      names: itRegions,
    ),
  );
}
