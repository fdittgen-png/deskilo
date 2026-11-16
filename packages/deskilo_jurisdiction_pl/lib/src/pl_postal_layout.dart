// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- how an address in Poland is written below its street: the postal code, then the locality as written (Poczta Polska: 00-950 Warszawa).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of how this layout writes an address.
const plPostalLayoutImplementationVersion = '1';

/// The postal layout of Poland.
class PlPostalLayout extends PostalLayoutContribution {
  const PlPostalLayout();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'pl.postal_layout',
    implementationVersion: plPostalLayoutImplementationVersion,
    contractVersion: postalLayoutContractVersion,
    formatVersion: '1',
    capabilityId: 'postal_layout.PL',
  );

  @override
  PostalLayout get layout => const PostalLayout(
    lines: [
      [PostalPart.postalCode, PostalPart.city],
    ],
  );
}
