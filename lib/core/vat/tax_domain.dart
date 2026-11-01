// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The domains of the tax reference store (#2477): which kind of value a row
// holds. Split from `tax_value.dart`, which types each domain's value.
import '../data/json_reader.dart';

/// The kinds of reference value the store holds. A domain's `value` shape
/// is validated in SQL (`tax_reference_valid`) and read here into a typed
/// [TaxValue]; a domain joins this enum when its checkpoint (C2–C5) moves
/// its consumer onto the store.
enum TaxDomain {
  /// A rate a country charges: label, percent, group, EN 16931 category.
  rate('rate'),

  /// The country is a member state of the EU (an empty value).
  euMember('eu_member'),

  /// A statutory text a document prints for a regime.
  mention('exemption_text'),

  /// The shape of a national VAT identification number.
  vatIdPattern('vat_id_pattern'),

  /// The caveat shown beside the seed button of a country's rates.
  catalogueNote('catalogue_note'),

  /// What falls in a fiscal group, a starting point for the owner.
  groupExample('group_example'),

  /// A turnover figure that ends a small-business exemption.
  threshold('threshold'),

  /// How a country dates the tax on a service, and what it lets a seller opt for.
  taxPoint('tax_point'),

  /// A dated e-invoicing duty of a country.
  mandate('mandate'),

  /// Whether, and on what terms, DesKilo issues for a seller of a country.
  issuingGate('issuing_gate'),

  /// Which fiscal groups a rated box of a return form adds up, and its label.
  formBox('form_box'),

  /// An account number or a tax code an accounting export proposes.
  accountMap('account_map'),

  /// The sales tax a US postal code carries, one component per jurisdiction.
  salesTax('sales_tax'),

  /// Whether a kind of line is taxed in a state.
  taxability('taxability'),

  /// #2539 -- the taxes inside a combined rate, keyed by the combined percent.
  rateComponent('rate_component'),

  /// #2571 -- how long a space must keep a class of record.
  retention('retention'),

  /// #2488 -- a country a workspace can be created in: its currency, the
  /// zone its capital keeps and how its banks identify an account. Creation
  /// defaults only; what DesKilo issues for is `issuing_gate`.
  country('country');

  const TaxDomain(this.wire);
  final String wire;

  static TaxDomain? tryWire(String wire) {
    for (final d in values) {
      if (d.wire == wire) return d;
    }
    return null;
  }

  static TaxDomain fromWire(String wire, {String context = 'tax_reference'}) =>
      tryWire(wire) ??
      (throw JsonShapeException(context, 'domain', 'a known domain', wire));
}
