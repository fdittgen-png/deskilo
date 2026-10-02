// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1870 — a tax component as an accountant reads it: which scheme and
// authority, which legal treatment, the exact rate and its version, the
// basis it applies to and the amount it yields. Zero-rated, exempt,
// out of scope and reverse charge are four different facts that all
// print as "0", so they stay four different values here; and a
// treatment nobody classified is a blocker, never a silent zero.
//
// This projects; it does not determine. Which treatment applies to a
// supply is #1917's question, answered elsewhere and handed in.

import 'accounting_amount.dart';

enum TaxTreatment {
  /// Taxed at a positive rate (standard or reduced).
  taxed,

  /// Taxable at a rate of zero.
  zeroRated,

  /// Exempt from the tax.
  exempt,

  /// Outside the tax's scope.
  outOfScope,

  /// The customer accounts for the tax (reverse charge).
  reverseCharge,

  /// Nobody classified it: the document cannot be projected.
  unknown,
}

/// When the tax becomes due.
enum TaxPointBasis {
  /// On the invoice date (debit/accrual basis).
  invoice,

  /// Only when the payment is received (cash basis).
  payment,
}

/// One tax on one basis.
class TaxComponent {
  const TaxComponent({
    required this.scheme,
    required this.authority,
    required this.treatment,
    required this.ratePercent,
    required this.rateVersion,
    required this.basis,
    required this.amount,
  });

  /// The tax (`VAT`, `GST`, `QST`).
  final String scheme;

  /// Who levies it (`FR`, `CA`, `CA-QC`).
  final String authority;
  final TaxTreatment treatment;

  /// The exact percentage (`9.975`); zero for every untaxed treatment.
  final ExactDecimal ratePercent;
  final String rateVersion;
  final AccountingAmount basis;
  final AccountingAmount amount;

  /// The key a report groups by: two authorities at the same rate, or a
  /// zero rate and an exemption, never share one.
  String get reportKey =>
      '$scheme|$authority|${treatment.name}|$ratePercent|$rateVersion';
}

/// Why a component could not be projected.
class TaxBlocker implements Exception {
  const TaxBlocker(this.reason);
  final String reason;

  @override
  String toString() => 'TaxBlocker($reason)';
}

/// The component for [basis] under [treatment], rounded once by
/// [policy]. A taxed component needs a positive rate; every other
/// treatment yields zero and takes no rate.
TaxComponent projectTax({
  required AccountingAmount basis,
  required String scheme,
  required String authority,
  required TaxTreatment treatment,
  required String rateVersion,
  required RoundingPolicy policy,
  String? ratePercent,
}) {
  if (treatment == TaxTreatment.unknown) {
    throw TaxBlocker('$scheme/$authority: the treatment is not classified');
  }
  if (scheme.trim().isEmpty || authority.trim().isEmpty) {
    throw const TaxBlocker('a tax component names its scheme and authority');
  }
  final zero = AccountingAmount(basis.currency, 0);
  if (treatment != TaxTreatment.taxed) {
    if (ratePercent != null &&
        ExactDecimal.parse(ratePercent).units != BigInt.zero) {
      throw TaxBlocker(
        '$scheme/$authority: ${treatment.name} with a rate of $ratePercent',
      );
    }
    return TaxComponent(
      scheme: scheme,
      authority: authority,
      treatment: treatment,
      ratePercent: ExactDecimal.parse('0'),
      rateVersion: rateVersion,
      basis: basis,
      amount: zero,
    );
  }
  if (ratePercent == null) {
    throw TaxBlocker('$scheme/$authority: taxed without a rate');
  }
  final rate = ExactDecimal.parse(ratePercent);
  if (rate.units <= BigInt.zero) {
    throw TaxBlocker('$scheme/$authority: a taxed rate must be positive');
  }
  return TaxComponent(
    scheme: scheme,
    authority: authority,
    treatment: treatment,
    ratePercent: rate,
    rateVersion: rateVersion,
    basis: basis,
    amount: basis.times(rate.percentAsFraction, policy),
  );
}

/// Purchase tax split into the part that may be deducted and the part
/// that may not, by an exact [deductiblePercent]; the two always add up
/// to [tax].
({AccountingAmount deductible, AccountingAmount nonDeductible}) splitDeductible(
  AccountingAmount tax,
  String deductiblePercent,
  RoundingPolicy policy,
) {
  final share = ExactDecimal.parse(deductiblePercent);
  if (share.units.isNegative || share > ExactDecimal.parse('100')) {
    throw TaxBlocker('deductible share $deductiblePercent is not 0–100 %');
  }
  final deductible = tax.times(share.percentAsFraction, policy);
  return (deductible: deductible, nonDeductible: tax - deductible);
}

/// When [component] is due: on the invoice date under the invoice
/// basis; under the payment basis only once paid — null until then.
DateTime? taxDueOn(
  TaxPointBasis basis, {
  required DateTime issuedOn,
  DateTime? paidOn,
}) => switch (basis) {
  TaxPointBasis.invoice => issuedOn,
  TaxPointBasis.payment => paidOn,
};
