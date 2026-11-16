// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in Switzerland is written below its street: the postal code, then the locality as written (Swiss Post).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const chPostalLayoutImplementationVersion = '1';

/// The postal layout of Switzerland.
class ChPostalLayout extends PostalLayoutContribution {
  const ChPostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ch.postal_layout',
    implementationVersion: chPostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.CH',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.postalCode, PostalPart.city],
    ],
  );
}
