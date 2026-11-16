// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in Ireland is written below its street: the town, the county, then the Eircode on its own line (An Post).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const iePostalLayoutImplementationVersion = '1';

/// The postal layout of Ireland.
class IePostalLayout extends PostalLayoutContribution {
  const IePostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ie.postal_layout',
    implementationVersion: iePostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.IE',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.city],
      [PostalPart.region],
      [PostalPart.postalCode],
    ],
    postalCodeInCapitals: true,
  );
}
