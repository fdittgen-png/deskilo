// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 (ADR 0047 §3) — what the law of the space's country asks, beside
// the plain questions: the e-invoicing duties and the small-business VAT
// limits, as the reviewed tax reference data holds them (`mandate` and
// `threshold` rows), each with its source and whether somebody confirmed
// it. Nothing here knows a country or a date: a country without rows has
// none listed, and the owner is told to ask an accountant, never that
// nothing applies. The answers never change because of these rows; they
// explain the questions they belong to. `web/setup.html` shows the same
// rows, written out from the bundled copy by `tool/build_setup_l10n.dart`.
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';

enum SetupObligationKind {
  /// A dated e-invoicing duty (`mandate`), beside "You issue invoices".
  einvoicing('issue_invoices'),

  /// A turnover that ends the small-business VAT exemption (`threshold`),
  /// beside "The space is registered for VAT".
  vatThreshold('vat_registered');

  const SetupObligationKind(this.question);

  /// The question of `setupQuestions` this obligation explains.
  final String question;
}

/// One row of the reference data, as the setup questions show it.
class SetupObligation {
  const SetupObligation({
    required this.kind,
    required this.detail,
    required this.source,
    required this.confirmed,
    this.from,
    this.cents,
    this.currency,
  });

  final SetupObligationKind kind;

  /// E-invoicing: the duty (`receive_all`, `issue_all`, …); threshold: what
  /// passing it does (`next_year`, `immediate`).
  final String detail;

  /// E-invoicing: the duty's first day, `YYYY-MM-DD`.
  final String? from;

  /// Threshold: the net turnover, in minor units of [currency].
  final int? cents;
  final String? currency;

  /// The law the row cites, as the reference store keeps it.
  final String source;

  /// False until somebody checked the row against its source: the owner is
  /// then told to ask an accountant.
  final bool confirmed;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'question': kind.question,
    'detail': detail,
    'from': ?from,
    'cents': ?cents,
    'currency': ?currency,
    'source': source,
    'confirmed': confirmed,
  };
}

/// [country]'s obligations in the newest version of each row (a planned
/// change nobody confirmed stays behind the version it would close, as
/// everywhere): the e-invoicing duties by date, then the thresholds from
/// the lowest. Empty when the data holds no row for the country, or when
/// no reference data is installed — never a claim that nothing applies.
List<SetupObligation> setupObligations(
  String country, {
  TaxReferenceSet? reference,
}) {
  final set =
      reference ??
      (ActiveTaxReference.isInstalled ? ActiveTaxReference.current : null);
  if (set == null) return const [];
  final mandates = [
    for (final row in set.ownRows(TaxDomain.mandate, country))
      SetupObligation(
        kind: SetupObligationKind.einvoicing,
        detail: (row.value as MandateValue).duty,
        from: (row.value as MandateValue).from,
        source: row.source,
        confirmed: row.confirmed,
      ),
  ]..sort((a, b) => '${a.from}${a.detail}'.compareTo('${b.from}${b.detail}'));
  final thresholds = [
    for (final row in set.ownRows(TaxDomain.threshold, country))
      SetupObligation(
        kind: SetupObligationKind.vatThreshold,
        detail: (row.value as ThresholdValue).effect,
        cents: (row.value as ThresholdValue).cents,
        currency: (row.value as ThresholdValue).currency,
        source: row.source,
        confirmed: row.confirmed,
      ),
  ]..sort((a, b) => a.cents!.compareTo(b.cents!));
  return [...mandates, ...thresholds];
}
