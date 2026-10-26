// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The terms every filing file shares (see `vat_filing_files.dart`): why
// one cannot be written, what the person is asked beyond the settings,
// and the month or quarter a periodic return covers.
import 'vat_declaration.dart';

/// Why a filing file cannot be written for a declaration.
enum VatFilingFileProblem {
  /// A UStVA covers a calendar month or quarter.
  period,

  /// The declarant's tax number (Steuernummer, SIREN) is missing.
  taxNumber,

  /// A UK return names the VAT registration number (nine digits).
  vatNumber,

  /// A Swiss return names the UID (CHE-123.456.789 and its check digit).
  uid,

  /// A Canadian return names the business number with its RT account.
  businessNumber,

  /// An Italian return names the codice fiscale of the taxpayer (the
  /// workspace's registration number).
  fiscalCode,

  /// The declarant who signs for a company names their own codice fiscale
  /// and a codice carica of the Agenzia's table.
  declarant,

  /// A box holds an amount the national file has no field for (a Spanish
  /// sale at a rate outside 4, 10 and 21 %), so the file would drop it.
  unmappedBox,

  /// A field of the national file takes no negative amount and the
  /// declaration holds one (a period of credit notes only).
  negativeAmount,

  /// A Spanish space that keeps its books through SII is exonerated from
  /// the annual summary and states the year's volume on the last 303, a
  /// page this file does not write.
  annualVolume,

  /// A Spanish space that keeps its books through SII files no modelo 347:
  /// the AEAT has its invoices already.
  exoneratedBySii,
}

class VatFilingFileException implements Exception {
  const VatFilingFileException(this.problem);
  final VatFilingFileProblem problem;

  @override
  String toString() => 'VatFilingFileException: ${problem.name}';
}

/// What a filing file states that the workspace's settings do not hold:
/// asked when the file is saved, never stored.
class VatFilingFacts {
  const VatFilingFacts({
    this.taxNumber = '',
    this.declarantFiscalCode = '',
    this.declarantRole = '',
    this.monthlyRefund = false,
    this.immediateSupply = false,
    this.cashCriterionRecipient = false,
  });

  /// The German Steuernummer.
  final String taxNumber;

  /// The Italian declarant who signs for the taxpayer: their codice
  /// fiscale and their codice carica (empty for a person filing alone).
  final String declarantFiscalCode;
  final String declarantRole;

  /// Spain: registered for monthly refunds (REDEME, art. 30 RIVA).
  final bool monthlyRefund;

  /// Spain: keeps its VAT books through SII (Suministro Inmediato).
  final bool immediateSupply;

  /// Spain: receives supplies taxed under the cash criterion.
  final bool cashCriterionRecipient;
}

/// The calendar month (1-12) or quarter (1-4) a return covers; anything
/// else is not the period of a monthly or quarterly return.
({int? month, int? quarter}) monthOrQuarterOf(VatDeclaration declaration) {
  final start = declaration.periodStart;
  final end = declaration.periodEnd;
  final months = (end.year - start.year) * 12 + end.month - start.month + 1;
  if (start.day != 1 || end != DateTime(end.year, end.month + 1, 0)) {
    throw const VatFilingFileException(VatFilingFileProblem.period);
  }
  if (months == 1) return (month: start.month, quarter: null);
  if (months == 3 && (start.month - 1) % 3 == 0) {
    return (month: null, quarter: 1 + (start.month - 1) ~/ 3);
  }
  throw const VatFilingFileException(VatFilingFileProblem.period);
}
