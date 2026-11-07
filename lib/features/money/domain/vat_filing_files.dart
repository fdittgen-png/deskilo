// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — filing-ready files of a prepared VAT return, for the owner to
// hand to the channel that files it. The app transmits nothing: an
// ELSTER file goes to transmission software or a tax adviser (ERiC),
// an EDI-TVA file to the owner's EDI partner (partenaire EDI), and the
// owner records the receipt the authority gives back.
//
//  * DE — the UStVA as ELSTER XML (`Elster` / `Anmeldungssteuern art=
//    "UStVA"`): Jahr, Zeitraum (01–12 a month, 41–44 a quarter), the
//    Steuernummer and every Kennzahl the form filled, bases in whole
//    euros, tax amounts with cents, Kz 83 always.
//  * FR — the CA3 as an EDIFACT interchange (UNA/UNB/UNH … UNT/UNZ,
//    message INFENT, syntax UNOC 3): the declarant (SIREN, name,
//    address), the period, and one LIN per CA3 line with its code and
//    its amounts in whole euros — MOA 125 the base, MOA 124 the tax.
//
//  * CH — the MWST-Abrechnung as eCH-0217 XML (#2360), the standard the ESTV
//    ePortal takes for upload, validated against its published XSD. The
//    upload itself needs an ePortal account of the owner and is not done
//    here; the file is the digital link.
//  * GB — Making Tax Digital for VAT through bridging software (#2359):
//    one CSV row of the nine boxes under HMRC's own field names (boxes
//    1–5 in pounds and pence, 6–9 in whole pounds). The file IS the
//    digital link: the bridging software imports it as it is and a person
//    never retypes a figure. Submitting through HMRC's API, with its
//    fraud-prevention headers, needs a developer account and is not done
//    here.
//  * CA — the GST/HST return (GST34, lines 101-109) and, when the QST is
//    charged or claimed, the QST part of Revenu Québec's FPZ-500 (lines
//    203-209), as one CSV of line, label and amount that the owner keys
//    into My Business Account or Mon dossier (#2361). Filing is the
//    owner's: both channels need their own registration and are not used
//    here.
//  * ES — the Modelo 303 in the AEAT's "diseño de registro" (pages 01 and
//    03), the fixed-width text the Sede imports into the form before the
//    owner signs it with a certificate or Cl@ve (`vat_filing_es.dart`).
//  * IT — the LIPE as the XML of the Agenzia delle Entrate's fornitura
//    IVP18, validated against its published XSD, which the owner's
//    intermediary transmits through Entratel (`vat_filing_it.dart`).
//
// Both read the boxes `vatFormBoxes` fills, so the file and the PDF can
// never disagree.
import 'dart:convert' show Encoding, utf8;

import '../../../core/time/date_text.dart';
import 'vat_declaration.dart';
import 'vat_filing_ech0217.dart';
import 'vat_filing_it.dart';
import 'vat_filing_terms.dart';

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

  /// The country whose file this dispatcher still writes: `CH`, `IT`,
  /// else null. The others have their own packages (#3332, #3333) and are
  /// chosen by the resolver, not here.
  String? get fileCountry => switch (countryCode.trim().toUpperCase()) {
    'CH' => 'CH',
    'IT' => 'IT',
    _ => null,
  };
}

/// The filing file of [declaration] for [party]: its name, its text and the
/// encoding its channel reads. [facts] holds what the file asks for beyond
/// the settings (the Steuernummer of a German file, the declarant of an
/// Italian one, the registers a Spanish space is in). Throws
/// [VatFilingFileException] when the period or a number does not fit, and
/// [UnsupportedError] for a country without a file.
({String fileName, String text, Encoding encoding}) vatFilingFile({
  required VatDeclaration declaration,
  required VatFilingParty party,
  required DateTime now,
  VatFilingFacts facts = const VatFilingFacts(),
}) {
  final start = isoDay(declaration.periodStart);
  return switch (party.fileCountry) {
    'CH' => (
      encoding: utf8,
      fileName: 'mwst-abrechnung-$start.xml',
      text: ech0217Xml(
        declaration: declaration,
        uid: party.vatId,
        organisationName: party.name,
        onReceipts: party.onReceipts,
        generatedAt: now,
      ),
    ),
    'IT' => (
      encoding: utf8,
      fileName: 'lipe-$start.xml',
      text: lipeXml(
        declaration: declaration,
        vatId: party.vatId,
        fiscalCode: party.legalId,
        facts: facts,
      ),
    ),
    _ => throw UnsupportedError('no filing file for ${party.countryCode}'),
  };
}
