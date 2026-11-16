// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in Spain is written below its street: the postal code and the locality, then the province on its own line (Correos).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const esPostalLayoutImplementationVersion = '1';

/// The postal layout of Spain.
class EsPostalLayout extends PostalLayoutContribution {
  const EsPostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'es.postal_layout',
    implementationVersion: esPostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.ES',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.postalCode, PostalPart.city],
      [PostalPart.region],
    ],
  );
}
