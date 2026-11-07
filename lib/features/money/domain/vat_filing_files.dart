// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — filing-ready files of a prepared VAT return, for the owner to hand to
// the channel that files it. The app transmits nothing: an ELSTER file goes to
// transmission software or a tax adviser (ERiC), an EDI-TVA file to the owner's
// EDI partner, and the owner records the receipt the authority gives back.
//
// Since #3333 no country is written here: each one is an add-on in its own
// package (`packages/deskilo_jurisdiction_*`) behind the contract of
// `deskilo_jurisdiction_api`, installed in `installed_vat_filings.dart` and
// chosen by the resolver (`lib/core/jurisdiction`). What stays is who files.
export 'vat_filing_terms.dart';

/// Who files: the space as its settings describe it.
class VatFilingParty {
  const VatFilingParty({
    required this.countryCode,
    required this.name,
    required this.street,
    required this.postalCode,
    required this.city,
    required this.vatId,
    required this.legalId,
    this.onReceipts = false,
  });

  final String countryCode;
  final String name;
  final String street;
  final String postalCode;
  final String city;
  final String vatId;

  /// The registration number (SIRET, Handelsregister …).
  final String legalId;

  /// Whether the space accounts for VAT on the consideration received (a
  /// Swiss return says `formOfReporting` 2), not on the invoice.
  final bool onReceipts;
}
