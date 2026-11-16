// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in Germany is written below its street: the postal code, then the locality, in capitals as the French form prints it.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const dePostalLayoutImplementationVersion = '1';

/// The postal layout of Germany.
class DePostalLayout extends PostalLayoutContribution {
  const DePostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'de.postal_layout',
    implementationVersion: dePostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.DE',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.postalCode, PostalPart.city],
    ],
    cityInCapitals: true,
  );
}
