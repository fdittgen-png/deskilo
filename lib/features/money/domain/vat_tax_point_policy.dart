// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2355/#2479 -- how a country dates the tax on a service: the rules, the
// options a seller may choose and the basis a declaration applies. The
// policy of a country is a `tax_point` row of the tax reference store; the
// SQL twin `vat_tax_point_policy` reads the same rows. `vat_tax_point.dart`
// (the engine that dates amounts) re-exports this file.
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';

/// How a country dates the tax on a service.
enum VatTaxPointRule {
  /// The day the document is issued.
  invoiceDate,

  /// The day each payment is received; an unpaid part is not due yet.
  receipt,

  /// The last day of the month the service is performed (the invoice's
  /// `period`); a payment received before that day is due when received.
  servicePeriod,

  /// The invoice or the payment, whichever comes first.
  earlierOf,
}

/// The workspace's choice, stored as `invoice_legal.vat_tax_point`.
enum VatTaxPointOption {
  /// The country's legal default.
  standard,

  /// The invoice date, where the law lets a seller opt for it (FR débits).
  invoice,

  /// Cash: each payment when received (Ist, criterio de caja, per cassa,
  /// cash accounting, vereinnahmte Entgelte).
  cash;

  /// Null for anything else — a workspace that never chose.
  static VatTaxPointOption? fromWire(String? raw) =>
      values.asNameMap()[raw ?? ''];
}

/// When an unpaid part falls due anyway under a cash scheme.
enum VatCashBackstop {
  none,

  /// ES — 31 December of the year after the service (art. 163 terdecies
  /// LIVA).
  endOfFollowingYear,

  /// IT — one year after the operation (art. 32-bis D.L. 83/2012).
  oneYearAfterIssue,
}

/// The rule a declaration applies, with its backstop.
class VatTaxPointBasis {
  const VatTaxPointBasis(this.rule, [this.backstop = VatCashBackstop.none]);

  static const invoiceDate = VatTaxPointBasis(VatTaxPointRule.invoiceDate);
  static const receipt = VatTaxPointBasis(VatTaxPointRule.receipt);

  final VatTaxPointRule rule;
  final VatCashBackstop backstop;

  /// Whether the tax waits for the money: the invoice then says so.
  bool get onReceipts => rule == VatTaxPointRule.receipt;

  @override
  bool operator ==(Object other) =>
      other is VatTaxPointBasis &&
      other.rule == rule &&
      other.backstop == backstop;

  @override
  int get hashCode => Object.hash(rule, backstop);
}

/// What one country allows.
class VatTaxPointPolicy {
  const VatTaxPointPolicy(
    this.standard, {
    this.invoiceOption = false,
    this.cashOption = true,
    this.cashBackstop = VatCashBackstop.none,
  });

  final VatTaxPointRule standard;

  /// The seller may opt for the invoice date (FR « option pour les
  /// débits »).
  final bool invoiceOption;

  /// The seller may opt for cash, where that differs from [standard].
  final bool cashOption;
  final VatCashBackstop cashBackstop;

  /// The options a settings screen offers, the default first.
  List<VatTaxPointOption> get options => [
    VatTaxPointOption.standard,
    if (invoiceOption) VatTaxPointOption.invoice,
    if (cashOption) VatTaxPointOption.cash,
  ];

  /// [stored] where this country allows it; the default otherwise — a
  /// stored `cash` in France IS the default, a stored `invoice` in
  /// Germany is the Soll rule.
  VatTaxPointOption effective(VatTaxPointOption? stored) => switch (stored) {
    VatTaxPointOption.invoice when invoiceOption => VatTaxPointOption.invoice,
    VatTaxPointOption.cash when cashOption => VatTaxPointOption.cash,
    _ => VatTaxPointOption.standard,
  };

  /// The rule [option] stands for here.
  VatTaxPointRule ruleOf(VatTaxPointOption option) => switch (option) {
    VatTaxPointOption.standard => standard,
    VatTaxPointOption.invoice => VatTaxPointRule.invoiceDate,
    VatTaxPointOption.cash => VatTaxPointRule.receipt,
  };

  /// The basis a workspace that stored [stored] declares on.
  VatTaxPointBasis basisOf(VatTaxPointOption? stored) {
    final option = effective(stored);
    return VatTaxPointBasis(
      ruleOf(option),
      option == VatTaxPointOption.cash ? cashBackstop : VatCashBackstop.none,
    );
  }
}

/// The policy of the seller's [country] (ISO 3166-1 alpha-2): the
/// `tax_point` row of the country in the tax reference store, the shared `*`
/// row where it has none of its own (#2479; the SQL twin
/// `vat_tax_point_policy` reads the same rows).
VatTaxPointPolicy vatTaxPointPolicy(
  String country, {
  String? asOf,
  TaxReferenceSet? reference,
}) {
  final row = (reference ?? ActiveTaxReference.current)
      .resolved(asOf)
      .lookup(TaxDomain.taxPoint, country, 'policy');
  final v = row?.value as TaxPointValue?;
  return VatTaxPointPolicy(
    switch (v?.standard) {
      'receipt' => VatTaxPointRule.receipt,
      'service_period' => VatTaxPointRule.servicePeriod,
      'earlier_of' => VatTaxPointRule.earlierOf,
      _ => VatTaxPointRule.invoiceDate,
    },
    invoiceOption: v?.invoiceOption ?? false,
    cashOption: v?.cashOption ?? true,
    cashBackstop: switch (v?.cashBackstop) {
      'end_of_following_year' => VatCashBackstop.endOfFollowingYear,
      'one_year_after_issue' => VatCashBackstop.oneYearAfterIssue,
      _ => VatCashBackstop.none,
    },
  );
}

/// The basis of a seller in [country] whose stored choice is [option].
VatTaxPointBasis vatTaxPointBasis(String country, VatTaxPointOption? option) =>
    vatTaxPointPolicy(country).basisOf(option);
