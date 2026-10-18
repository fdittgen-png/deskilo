// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477/#2478/#2479 -- the typed VALUES of the tax reference store: the
// domains and, for each, the shape of its `value` (validated in SQL by
// `tax_reference_valid` and read here through [JsonReader]). A new domain
// adds a case to [TaxDomain] and a class to [TaxValue]; every exhaustive
// `switch` over either must be revisited. `tax_reference.dart` re-exports
// this file.
import '../data/json_reader.dart';
import 'rate_component.dart';
import 'sales_tax_component.dart';

export 'rate_component.dart';
export 'sales_tax_component.dart';

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
  retention('retention');

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

/// The country every country shares: a row for `*` applies where the
/// country has no row of its own for the same key.
const String taxReferenceAnyCountry = '*';

/// One typed `value` of a row. Sealed: a new domain adds a case, and every
/// exhaustive `switch` over it must be revisited.
sealed class TaxValue {
  const TaxValue();

  TaxDomain get domain;

  Map<String, Object?> toJson();

  /// Reads [raw] as the value of [domain]; a wrong shape throws a
  /// [JsonShapeException] naming the row and the field.
  static TaxValue parse(TaxDomain domain, JsonReader r) {
    return switch (domain) {
      TaxDomain.rate => RateValue(
          label: r.string('label'),
          percent: r.number('percent'),
          group: r.string('group'),
          category: r.string('category'),
          exemptionReason: r.stringOr('exemption_reason'),
          position: r.intOrNull('position') ?? 0,
        ),
      TaxDomain.euMember => EuMemberValue(aliasOf: r.stringOr('alias_of')),
      TaxDomain.mention => ExemptionTextValue(
          regime: r.string('regime'),
          text: r.string('text'),
        ),
      TaxDomain.vatIdPattern => VatIdPatternValue(pattern: r.string('pattern')),
      TaxDomain.catalogueNote => CatalogueNoteValue(text: r.string('text')),
      TaxDomain.groupExample => GroupExampleValue(
          group: r.string('group'),
          text: r.string('text'),
          position: r.intOrNull('position') ?? 0,
        ),
      TaxDomain.threshold => ThresholdValue(
          cents: r.integer('cents'),
          effect: r.string('effect'),
          currency: r.string('currency'),
        ),
      TaxDomain.taxPoint => TaxPointValue(
          standard: r.string('standard'),
          invoiceOption: r.boolOr('invoice_option', fallback: false),
          cashOption: r.boolOr('cash_option', fallback: true),
          cashBackstop: r.stringOr('cash_backstop', 'none'),
        ),
      TaxDomain.mandate => MandateValue(
          duty: r.string('duty'),
          from: r.string('from'),
        ),
      TaxDomain.issuingGate => IssuingGateValue(
          supported: r.boolOr('supported', fallback: false),
          requiresTaxNumber: r.boolOr('requires_tax_number', fallback: false),
          nationalChannelRequired: r.boolOr('national_channel_required', fallback: false),
          currency: r.stringOr('currency'),
          taxSystem: r.stringOr('tax_system', 'vat'),
        ),
      TaxDomain.formBox => FormBoxValue(
          label: r.string('label'),
          groups: r.strings('groups'),
          excludeGroups: r.strings('exclude_groups'),
        ),
      TaxDomain.accountMap => AccountMapValue(
          format: r.string('format'),
          role: r.string('role'),
          account: r.stringOr('account'),
          taxCode: r.stringOr('tax_code'),
          label: r.stringOr('label'),
        ),
      TaxDomain.salesTax => SalesTaxValue(
          state: r.string('state'),
          components: r.objects('components', SalesTaxComponent.fromReader),
        ),
      TaxDomain.taxability => TaxabilityValue(status: r.string('status')),
      TaxDomain.rateComponent => RateComponentValue(
          percent: r.number('percent'),
          components: r.objects('components', RateComponent.fromReader),
        ),
      TaxDomain.retention => RetentionValue(years: r.integer('years'), from: r.string('from')),
    };
  }
}

/// `rate`: {label, percent, group, category, exemption_reason?, position?}.
/// [group] is the fiscal group's wire name (`VatGroup.wire`), [category]
/// the EN 16931 code the group carries; [position] orders a country's rates
/// (the first one is the default a workspace starts on).
class RateValue extends TaxValue {
  const RateValue({
    required this.label,
    required this.percent,
    required this.group,
    required this.category,
    this.exemptionReason = '',
    this.position = 0,
  });

  final String label;
  final double percent;
  final String group;
  final String category;
  final String exemptionReason;
  final int position;

  @override
  TaxDomain get domain => TaxDomain.rate;

  @override
  Map<String, Object?> toJson() => {
        'label': label,
        'percent': percent,
        'group': group,
        'category': category,
        if (exemptionReason.isNotEmpty) 'exemption_reason': exemptionReason,
        'position': position,
      };
}

/// `eu_member`: {} — the row's country is a member state; or
/// {alias_of} — the row's code is another spelling of that member
/// (Greece's VAT prefix `EL` is `GR`), not a member of its own.
class EuMemberValue extends TaxValue {
  const EuMemberValue({this.aliasOf = ''});

  final String aliasOf;

  bool get isAlias => aliasOf.isNotEmpty;

  @override
  TaxDomain get domain => TaxDomain.euMember;

  @override
  Map<String, Object?> toJson() => isAlias ? {'alias_of': aliasOf} : const {};
}

/// `exemption_text`: {regime, text} — the key names the regime too.
class ExemptionTextValue extends TaxValue {
  const ExemptionTextValue({required this.regime, required this.text});

  final String regime;
  final String text;

  @override
  TaxDomain get domain => TaxDomain.mention;

  @override
  Map<String, Object?> toJson() => {'regime': regime, 'text': text};
}

/// `vat_id_pattern`: {pattern} — the identifier body after the prefix.
class VatIdPatternValue extends TaxValue {
  const VatIdPatternValue({required this.pattern});

  final String pattern;

  @override
  TaxDomain get domain => TaxDomain.vatIdPattern;

  @override
  Map<String, Object?> toJson() => {'pattern': pattern};
}

/// `catalogue_note`: {text} — the caveat of a country's rate catalogue.
class CatalogueNoteValue extends TaxValue {
  const CatalogueNoteValue({required this.text});

  final String text;

  @override
  TaxDomain get domain => TaxDomain.catalogueNote;

  @override
  Map<String, Object?> toJson() => {'text': text};
}

/// `group_example`: {group, text, position?} — what falls in a fiscal
/// group; [position] orders a country's examples.
class GroupExampleValue extends TaxValue {
  const GroupExampleValue({
    required this.group,
    required this.text,
    this.position = 0,
  });

  final String group;
  final String text;
  final int position;

  @override
  TaxDomain get domain => TaxDomain.groupExample;

  @override
  Map<String, Object?> toJson() =>
      {'group': group, 'text': text, 'position': position};
}

/// `threshold`: {cents, effect, currency} -- the net turnover (minor units)
/// that ends a small-business exemption; [effect] is `next_year` (it ends
/// with the year) or `immediate` (on the supply that passes it).
class ThresholdValue extends TaxValue {
  const ThresholdValue({
    required this.cents,
    required this.effect,
    required this.currency,
  });

  final int cents;
  final String effect;
  final String currency;

  @override
  TaxDomain get domain => TaxDomain.threshold;

  @override
  Map<String, Object?> toJson() =>
      {'cents': cents, 'effect': effect, 'currency': currency};
}

/// `tax_point`: {standard, invoice_option, cash_option, cash_backstop} --
/// [standard] is `invoice`, `receipt`, `service_period` or `earlier_of`;
/// [cashBackstop] `none`, `end_of_following_year` or `one_year_after_issue`.
class TaxPointValue extends TaxValue {
  const TaxPointValue({
    required this.standard,
    this.invoiceOption = false,
    this.cashOption = true,
    this.cashBackstop = 'none',
  });

  final String standard;
  final bool invoiceOption;
  final bool cashOption;
  final String cashBackstop;

  @override
  TaxDomain get domain => TaxDomain.taxPoint;

  @override
  Map<String, Object?> toJson() => {
        'standard': standard,
        'invoice_option': invoiceOption,
        'cash_option': cashOption,
        'cash_backstop': cashBackstop,
      };
}

/// `mandate`: {duty, from} -- the key names the duty; [from] is the first
/// day (`YYYY-MM-DD`) the duty applies.
class MandateValue extends TaxValue {
  const MandateValue({required this.duty, required this.from});

  final String duty;
  final String from;

  @override
  TaxDomain get domain => TaxDomain.mandate;

  @override
  Map<String, Object?> toJson() => {'duty': duty, 'from': from};
}

/// `issuing_gate`: {supported, requires_tax_number, national_channel_required,
/// currency} -- the terms on which a seller of the row's country may issue.
/// A country without a row is refused; [nationalChannelRequired] refuses
/// whatever [supported] says (the app does not speak that channel yet): the
/// row is an input to the gate, never an override of it.
class IssuingGateValue extends TaxValue {
  const IssuingGateValue({
    required this.supported,
    this.requiresTaxNumber = false,
    this.nationalChannelRequired = false,
    this.currency = '',
    this.taxSystem = 'vat',
  });

  final bool supported;
  final bool requiresTaxNumber;
  final bool nationalChannelRequired;

  /// The currency the VAT must be stated in; '' where any will do.
  final String currency;

  /// `vat` (the tax is inside the price) or `sales_tax` (added to a net
  /// price, per jurisdiction): how a seller of this country issues.
  final String taxSystem;

  /// Whether the seller issues in sales-tax mode.
  bool get salesTaxMode => taxSystem == salesTaxSystem;

  /// Whether the app issues for this country: supported and no national
  /// channel it does not speak.
  bool get issues => supported && !nationalChannelRequired;

  @override
  TaxDomain get domain => TaxDomain.issuingGate;

  @override
  Map<String, Object?> toJson() => {
        'supported': supported,
        'requires_tax_number': requiresTaxNumber,
        'national_channel_required': nationalChannelRequired,
        if (currency.isNotEmpty) 'currency': currency,
        if (taxSystem != 'vat') 'tax_system': taxSystem,
      };
}

/// The `tax_system` of an issuing gate whose sellers add the tax to a net price.
const String salesTaxSystem = 'sales_tax';

/// `sales_tax`: {state, components} -- the tax a postal code carries (the key
/// is its five digits, the country `US`). A ZIP code only approximates a
/// jurisdiction; the row's source says how it was checked. Rates change by
/// jurisdiction constantly: none is shipped, the platform owner enters them.
class SalesTaxValue extends TaxValue {
  const SalesTaxValue({required this.state, required this.components});

  final String state;
  final List<SalesTaxComponent> components;

  /// The combined percent of every component.
  double get percent => components.fold(0, (sum, c) => sum + c.percent);

  @override
  TaxDomain get domain => TaxDomain.salesTax;

  @override
  Map<String, Object?> toJson() => {
    'state': state,
    'components': [for (final c in components) c.toJson()],
  };
}

/// The three answers about a kind of line in a state.
const List<String> taxabilityStatuses = ['taxable', 'exempt', 'not_applicable'];

/// `taxability`: {status} -- whether a kind of line is taxed in a state (the
/// key is `<STATE>:<kind>` or `<STATE>:<supply>`, the country `US`). No row for
/// anything but a licence to occupy space means nobody has said: such an
/// invoice is refused, never guessed.
class TaxabilityValue extends TaxValue {
  const TaxabilityValue({required this.status});

  final String status;

  @override
  TaxDomain get domain => TaxDomain.taxability;

  @override
  Map<String, Object?> toJson() => {'status': status};
}

/// `form_box`: {label, groups?, exclude_groups?} -- a rated box of a return
/// form (the key is `<form>/<box code>`, e.g. `ustva/Kz 81`). The box adds up
/// the taxed lines whose fiscal group (`VatGroup.wire`) is in [groups], or --
/// for a catch-all box -- is in none of [excludeGroups]; never a percent, so a
/// change of a country's rate needs no change here. Which boxes exist and how
/// they total stays in the form's code; the printed [label] is the form's own
/// wording, in its language.
class FormBoxValue extends TaxValue {
  const FormBoxValue({
    required this.label,
    this.groups = const [],
    this.excludeGroups = const [],
  });

  final String label;
  final List<String> groups;
  final List<String> excludeGroups;

  @override
  TaxDomain get domain => TaxDomain.formBox;

  @override
  Map<String, Object?> toJson() => {
        'label': label,
        if (groups.isNotEmpty) 'groups': groups,
        if (excludeGroups.isNotEmpty) 'exclude_groups': excludeGroups,
      };
}

/// `account_map`: {format, role, account?, tax_code?, label?} -- a default an
/// accounting export or the chart-of-accounts preview proposes. [format] is
/// `coa` (the country's suggested chart: [role] is `chart` for its code and
/// name, else the account's role, the key's number orders them), `fec`,
/// `datev`, `sage` or `saf_t` (what that file asks for beyond the chart).
/// The workspace's own chart stays its `book_profile`; the accountant's
/// correction at export time always wins over these.
class AccountMapValue extends TaxValue {
  const AccountMapValue({
    required this.format,
    required this.role,
    this.account = '',
    this.taxCode = '',
    this.label = '',
  });

  final String format;
  final String role;

  /// The account number (or, for the `chart` role, the chart's code).
  final String account;

  /// The export's own tax code (`T1`).
  final String taxCode;

  /// The account's name in the chart's own language.
  final String label;

  @override
  TaxDomain get domain => TaxDomain.accountMap;

  @override
  Map<String, Object?> toJson() => {
        'format': format,
        'role': role,
        if (account.isNotEmpty) 'account': account,
        if (taxCode.isNotEmpty) 'tax_code': taxCode,
        if (label.isNotEmpty) 'label': label,
      };
}

/// `rate_component`: {percent, components} -- the taxes a combined [percent]
/// is made of (the key is the percent as text, the country the seller's); SQL
/// (`tax_reference_valid`) refuses components that do not add up to it.
class RateComponentValue extends TaxValue {
  const RateComponentValue({required this.percent, required this.components});

  final double percent;
  final List<RateComponent> components;

  @override
  TaxDomain get domain => TaxDomain.rateComponent;

  @override
  Map<String, Object?> toJson() => {
        'percent': percent,
        'components': [for (final c in components) c.toJson()],
      };
}

/// `retention`: {years, from}; the key is the class, [from] where the clock starts.
class RetentionValue extends TaxValue {
  const RetentionValue({required this.years, required this.from});

  final int years;
  final String from;

  @override
  TaxDomain get domain => TaxDomain.retention;

  @override
  Map<String, Object?> toJson() => {'years': years, 'from': from};
}
