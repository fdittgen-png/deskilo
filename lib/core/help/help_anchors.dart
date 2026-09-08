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

  /// Every anchor the app points at — the lint's left-hand side.
  static const all = <String>{
    moneyVatRates,
    moneyVatGroups,
    moneyVatDeclaration,
  };

  /// The screenshot that documents [anchor], by the naming rule.
  static String imageFor(String anchor) => '${anchor.replaceAll('.', '-')}.jpg';
}
