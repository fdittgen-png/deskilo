// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- DATEV's EXTF Buchungsstapel declares the chart its
// defaults are rows of: the German Standardkontenrahmen.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this declares.
const deDatevFormatImplementationVersion = '1';

/// The DATEV export.
class DeDatevFormat extends AccountingFormatContribution {
  const DeDatevFormat();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'de.datev_format',
    implementationVersion: deDatevFormatImplementationVersion,
    contractVersion: accountingFormatContractVersion,
    formatVersion: 'extf-700',
    capabilityId: 'accounting_format.datev',
  );

  @override
  String get formatId => 'datev';

  /// SKR03 / SKR04.
  @override
  String get chartCountry => 'DE';
}
