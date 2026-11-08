// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Which registers of issued invoices a country's law asks for in a file
// the app writes (`vat_register_es.dart`, `vat_register_es_sii.dart`,
// `vat_register_it.dart`).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart'
    show VatFilingContribution;

import '../../../core/jurisdiction/jurisdiction_resolver.dart';
import '../application/jurisdiction/installed_vat_filings.dart';

/// A register the declarations screen offers beside the return.
enum VatRegisterKind {
  /// The Spanish libro registro de facturas expedidas, AEAT XLSX layout,
  /// from the 1st of January to the end of the period.
  esLibro,

  /// The same documents of the period as the SII message.
  esSii,

  /// The modelo 347 list of the period's year.
  es347,

  /// The Italian registro delle fatture emesse of the period.
  itRegistro,
}

/// The registers a space of [country] can save: the ones the installed VAT
/// filing add-on of that country declares (`VatFilingContribution.registers`),
/// in the order the kinds are listed here. A country with no add-on, or whose
/// add-on declares none, offers none. [installed] defaults to the build's own
/// composition.
List<VatRegisterKind> vatRegistersFor(
  String country, [
  List<VatFilingContribution>? installed,
]) {
  final resolution = resolveCapability(
    JurisdictionOperation.vatFiling,
    LegalContext(countryCode: country),
    installed ?? installedVatFilings,
  );
  if (resolution is! Resolved) return const [];
  final declared = resolution.contribution.registers;
  return [
    for (final kind in VatRegisterKind.values)
      if (declared.contains(kind.name)) kind,
  ];
}
