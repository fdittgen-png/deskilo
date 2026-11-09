// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the FEC (the regulatory accounting file, art. A47 A-1
// LPF) declares the chart its defaults are rows of and the journals it writes.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this declares.
const frFecFormatImplementationVersion = '1';

/// The French FEC.
class FrFecFormat extends AccountingFormatContribution {
  const FrFecFormat();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'fr.fec_format',
    implementationVersion: frFecFormatImplementationVersion,
    contractVersion: accountingFormatContractVersion,
    formatVersion: 'a47-a-1-lpf',
    capabilityId: 'accounting_format.fec',
  );

  @override
  String get formatId => 'fec';

  /// The plan comptable général.
  @override
  String get chartCountry => 'FR';

  @override
  Map<String, AccountingJournal> get journals => const {
    'sales': AccountingJournal(code: 'VE', label: 'Ventes'),
    'bank': AccountingJournal(code: 'BQ', label: 'Banque'),
    'purchases': AccountingJournal(code: 'HA', label: 'Achats'),
    'misc': AccountingJournal(code: 'OD', label: 'Opérations diverses'),
  };
}
