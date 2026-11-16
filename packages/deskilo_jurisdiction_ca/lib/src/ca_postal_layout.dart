// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in Canada is written below its street: the municipality, the province code and the postal code on one line, in capitals (Canada Post).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const caPostalLayoutImplementationVersion = '1';

/// The postal layout of Canada.
class CaPostalLayout extends PostalLayoutContribution {
  const CaPostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ca.postal_layout',
    implementationVersion: caPostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.CA',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.city, PostalPart.region, PostalPart.postalCode],
    ],
    cityInCapitals: true,
    postalCodeInCapitals: true,
  );
}
