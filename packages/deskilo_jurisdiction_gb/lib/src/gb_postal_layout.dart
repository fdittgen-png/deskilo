// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in the United Kingdom is written below its street: the post town in capitals, the county when given, then the postcode on its own line (Royal Mail).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const gbPostalLayoutImplementationVersion = '1';

/// The postal layout of the United Kingdom.
class GbPostalLayout extends PostalLayoutContribution {
  const GbPostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'gb.postal_layout',
    implementationVersion: gbPostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.GB',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.city],
      [PostalPart.region],
      [PostalPart.postalCode],
    ],
    cityInCapitals: true,
    postalCodeInCapitals: true,
  );
}
