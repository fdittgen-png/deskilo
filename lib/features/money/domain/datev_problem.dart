// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What stops a DATEV export before a file is written, and the fixed limits
// of the DATEV format (EXTF 700, Buchungsstapel and Debitoren/Kreditoren)
// the checks apply. The limits are the format's own, not choices: an
// accountant cannot import a longer Bezeichnung or a Debitor outside its
// range, whatever the space would like.

/// The fixed limits of the DATEV format this export writes to.
abstract final class DatevFormatRules {
  /// Header field 17, `Bezeichnung`.
  static const batchNameLength = 30;

  /// `Belegfeld 1`, which DATEV matches open items on.
  static const documentRefLength = 36;

  /// `Buchungstext`.
  static const textLength = 60;

  /// `KOST1 - Kostenstelle`.
  static const costCentreLength = 36;

  /// `Beleginfo - Inhalt`.
  static const documentInfoLength = 210;

  /// The rows one Buchungsstapel may hold.
  static const rowsPerBatch = 99999;

  /// `Beraternummer`: 1001 to 9999999.
  static const consultantRange = (1001, 9999999);

  /// `Mandantennummer`: 1 to 99999.
  static const clientRange = (1, 99999);

  /// The Sachkontenlänge a header may declare.
  static const accountLengths = (4, 8);

  /// The first digit of a Debitor, 1 to 6: a Personenkonto is one digit
  /// longer than the Sachkonten.
  static const debtorLeadingDigits = (1, 6);

  /// The fields a Buchungsstapel row of format 700, version 13 holds.
  static const rowFields = 125;

  /// The inclusive range of a Debitor for Sachkonten of [accountLength]
  /// digits: 10000 to 69999 for four.
  static (int, int) debtorRange(int accountLength) {
    var unit = 1;
    for (var i = 0; i < accountLength; i++) {
      unit *= 10;
    }
    return (
      debtorLeadingDigits.$1 * unit,
      (debtorLeadingDigits.$2 + 1) * unit - 1,
    );
  }
}

/// One reason the DATEV export was not written.
sealed class DatevProblem {
  const DatevProblem();
}

/// The Beraternummer is not a number DATEV accepts.
final class DatevConsultantNumber extends DatevProblem {
  const DatevConsultantNumber(this.given);
  final String given;
}

/// The Mandantennummer is not a number DATEV accepts.
final class DatevClientNumber extends DatevProblem {
  const DatevClientNumber(this.given);
  final String given;
}

/// The Sachkontenlänge is not one DATEV knows.
final class DatevSachkontenlaenge extends DatevProblem {
  const DatevSachkontenlaenge(this.length);
  final int length;
}

/// The amounts are not in the currency the format writes.
final class DatevCurrency extends DatevProblem {
  const DatevCurrency(this.given);
  final String given;
}

/// A reference DATEV matches on (Belegfeld 1) or groups by (KOST1) is
/// longer than its field: cutting it would merge or orphan it.
final class DatevReferenceTooLong extends DatevProblem {
  const DatevReferenceTooLong(this.field, this.value);
  final String field;
  final String value;
}

/// The issuers' book profiles start the fiscal year on different days.
final class DatevFiscalYearStarts extends DatevProblem {
  const DatevFiscalYearStarts();
}

/// An account typed for the export is not as long as the header's
/// Sachkontenlänge says.
final class DatevAccountLength extends DatevProblem {
  const DatevAccountLength(this.account, this.length);
  final String account;
  final int length;
}

/// A member's number gives no Debitor in DATEV's range.
final class DatevMemberNumber extends DatevProblem {
  const DatevMemberNumber(this.member, this.number);
  final String member;
  final String number;
}

/// Two members would share one Debitor.
final class DatevDebtorClash extends DatevProblem {
  const DatevDebtorClash(this.account, this.members);
  final String account;
  final List<String> members;
}

/// A rate booked to a non-automatic account has no BU-Schlüssel in the
/// reference data.
final class DatevTaxKeyMissing extends DatevProblem {
  const DatevTaxKeyMissing(this.percent, this.account);
  final double percent;
  final String account;
}

/// A rate is booked to the automatic account of another rate, where DATEV
/// would compute the wrong tax and accepts no key.
final class DatevAutomaticClash extends DatevProblem {
  const DatevAutomaticClash(this.percent, this.account);
  final double percent;
  final String account;
}
