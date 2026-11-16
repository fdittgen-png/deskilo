// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- how an address in Romania is written below its street: the postal
// code and the locality, then the county by name. The county is required in
// the address form and on the invoice: CIUS-RO names it (BT-39, BT-54).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

import 'ro_regions.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const roPostalLayoutImplementationVersion = '1';

/// The postal layout of Romania.
class RoPostalLayout extends PostalLayoutContribution {
  const RoPostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ro.postal_layout',
    implementationVersion: roPostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.RO',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.postalCode, PostalPart.city],
      [PostalPart.region],
    ],
    region: RegionField(
      kind: RegionKind.county,
      requiredInForm: true,
      requiredOnInvoice: RegionOnInvoice.everyParty,
      names: roRegions,
      printsName: true,
    ),
  );
}
