// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in France is written below its street: the postal code, then the locality in capitals (NF Z 10-011).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const frPostalLayoutImplementationVersion = '1';

/// The postal layout of France.
class FrPostalLayout extends PostalLayoutContribution {
  const FrPostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'fr.postal_layout',
    implementationVersion: frPostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.FR',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.postalCode, PostalPart.city],
    ],
    cityInCapitals: true,
  );
}
