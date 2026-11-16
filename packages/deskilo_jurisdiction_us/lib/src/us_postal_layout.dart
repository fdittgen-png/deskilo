// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in the United States is written below its street: the city, the state code and the ZIP code on one line, in capitals (USPS Publication 28).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

import 'us_regions.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const usPostalLayoutImplementationVersion = '2';

/// The postal layout of the United States.
class UsPostalLayout extends PostalLayoutContribution {
  const UsPostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'us.postal_layout',
    implementationVersion: usPostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.US',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.city, PostalPart.region, PostalPart.postalCode],
    ],
    cityInCapitals: true,
    region: RegionField(
      kind: RegionKind.state,
      requiredInForm: true,
      requiredOnInvoice: RegionOnInvoice.seller,
      names: usRegions,
    ),
  );
}
