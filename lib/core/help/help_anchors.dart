// SPDX-License-Identifier: 0BSD

/// #1016 — the identity a help symbol, a guide heading, a screenshot and
/// its crops all share.
///
/// One dotted id, lower case, never translated:
/// `<guide>.<module>.<screen>.<object>`. The guides carry it as an HTML
/// comment on the line above the heading it names — invisible on GitHub
/// and in the app — and `tool/build_help.dart` compiles those comments
/// into `assets/help/<lang>.anchors.json`, so the help screen jumps to
/// the exact paragraph instead of the first heading whose text happens
/// to contain the topic.
///
/// The same id, with the dots turned into dashes, names that object's
/// screenshot in `docs/wiki/images/`.
///
/// `test/lint/help_anchor_test.dart` refuses an anchor that is missing
/// from any of the five guides, a duplicate, and a malformed id.
abstract final class HelpAnchor {
  // ── money · VAT ────────────────────────────────────────────────────
  /// The rate table: names, percentages, groups, the default star.
  static const moneyVatRates = 'user.money.vat.rates';

  /// The fiscal group a rate carries and what falls in each.
  static const moneyVatGroups = 'user.money.vat.groups';

  /// The periodic declaration built from the period's invoices.
  static const moneyVatDeclaration = 'user.money.vat.declaration';

  /// Out of scope, exempt or charging — what the norm then demands.
  static const moneyVatRegime = 'user.money.vat.regime';

  /// The intra-community number, checked for its country's shape.
  static const moneyVatNumber = 'user.money.vat.number';

  /// The account collected VAT is posted to.
  static const moneyVatAccount = 'user.money.vat.account';

  /// The statutory sentence a seller who charges no VAT prints.
  static const moneyVatExemptionReason = 'user.money.vat.exemption-reason';

  // ── money · legal identity and invoice mentions ────────────────────
  /// SIREN, SIRET, HRB, CIF — the seller's registration number.
  static const legalLegalId = 'user.money.legal.legal-id';

  /// Street, post code and city — what the e-invoice carries.
  static const legalAddress = 'user.money.legal.address';

  /// Company or association — which clause defaults a document prints.
  static const legalSellerKind = 'user.money.legal.seller-kind';

  /// What the organisation legally is, printed under its name.
  static const legalForm = 'user.money.legal.legal-form';

  /// The register a reader can check the seller with.
  static const legalRegistration = 'user.money.legal.registration';

  /// When the money is due, and what the reminders count from.
  static const legalPaymentTerms = 'user.money.legal.payment-terms';

  /// The interest a late payment carries.
  static const legalLatePenalty = 'user.money.legal.late-penalty';

  /// The fixed indemnity for collection costs.
  static const legalRecovery = 'user.money.legal.recovery';

  /// Whether paying early earns a discount.
  static const legalEscompte = 'user.money.legal.escompte';

  /// Insurer, policy and geographical cover.
  static const legalInsurance = 'user.money.legal.insurance';

  /// Anything else the trade or the country demands.
  static const legalSpecialMentions = 'user.money.legal.special-mentions';

  /// Every anchor the app points at — the lint's left-hand side.
  static const all = <String>{
    moneyVatRates,
    moneyVatGroups,
    moneyVatDeclaration,
    legalSellerKind,
    legalForm,
    legalRegistration,
    legalPaymentTerms,
    legalLatePenalty,
    legalRecovery,
    legalEscompte,
    legalInsurance,
    moneyVatRegime,
    moneyVatNumber,
    moneyVatAccount,
    moneyVatExemptionReason,
    legalLegalId,
    legalAddress,
    legalSpecialMentions,
  };

  /// The screenshot that documents [anchor], by the naming rule.
  static String imageFor(String anchor) => '${anchor.replaceAll('.', '-')}.jpg';
}
