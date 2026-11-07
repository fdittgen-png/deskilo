// SPDX-License-Identifier: AGPL-3.0-or-later

/// One line of a VAT return: what the period's documents add up to at one
/// rate and category, in one direction.
class FilingLine {
  FilingLine({
    required this.percent,
    required this.netCents,
    required this.vatCents,
    required this.grossCents,
    required this.invoiceCount,
    this.category = '',
    this.direction = 'output',
    this.optedNetCents = 0,
    this.corrects = '',
    this.correctsStart,
    this.correctsEnd,
    List<FilingComponent> components = const [],
  }) : components = List.unmodifiable(components);

  final double percent;
  final int netCents;
  final int vatCents;
  final int grossCents;
  final int invoiceCount;

  /// The UNCL5305 category (S, AE, E, Z, G, O); '' when unknown.
  final String category;

  /// `output` (collected on sales) or `input` (deductible).
  final String direction;

  /// The part of [netCents] that is an exempt letting the seller opted to tax.
  final int optedNetCents;

  /// The return a correction line amends ('' on the period's own lines).
  final String corrects;
  final DateTime? correctsStart;
  final DateTime? correctsEnd;

  /// The taxes the line is made of (GST and QST of a Canadian line); not
  /// modifiable.
  final List<FilingComponent> components;
}

/// One tax a [FilingLine] is made of.
class FilingComponent {
  const FilingComponent({
    required this.scheme,
    required this.authority,
    required this.percent,
    required this.baseCents,
    required this.taxCents,
    this.name = '',
    this.level = '',
  });

  final String scheme;
  final String authority;
  final double percent;
  final int baseCents;
  final int taxCents;
  final String name;
  final String level;
}

/// One filled box of the return form, as the host's tax reference fills it for
/// the country: the add-on writes boxes, it does not compute them.
class FilingBox {
  const FilingBox({
    required this.code,
    required this.label,
    required this.netCents,
    required this.vatCents,
    this.hasBase = true,
    this.hasTax = true,
    this.baseKey = '',
    this.taxKey = '',
  });

  final String code;
  final String label;
  final int netCents;
  final int vatCents;
  final bool hasBase;
  final bool hasTax;

  /// The cell's name in a filing file (a CA3 EDI code, an ELSTER Kennzahl).
  final String baseKey;
  final String taxKey;
}

/// Who files: the space as its settings describe it.
class FilingParty {
  const FilingParty({
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
  final String legalId;

  /// Whether the space accounts for VAT on the consideration received.
  final bool onReceipts;
}

/// What a filing states beyond the settings, asked when it is made.
class FilingFacts {
  const FilingFacts({
    this.taxNumber = '',
    this.declarantFiscalCode = '',
    this.declarantRole = '',
    this.monthlyRefund = false,
    this.immediateSupply = false,
    this.cashCriterionRecipient = false,
  });

  final String taxNumber;
  final String declarantFiscalCode;
  final String declarantRole;
  final bool monthlyRefund;
  final bool immediateSupply;
  final bool cashCriterionRecipient;
}

/// Everything one VAT filing reads. Immutable; the moment of generation is
/// passed in, so an implementation reads no clock.
class FilingContext {
  FilingContext({
    required this.periodStart,
    required this.periodEnd,
    required this.currency,
    required List<FilingLine> lines,
    List<FilingBox> boxes = const [],
    Map<String, List<FilingBox>> extraBoxes = const {},
    required this.party,
    required this.generatedAt,
    this.facts = const FilingFacts(),
    this.number = '',
  }) : lines = List.unmodifiable(lines),
       boxes = List.unmodifiable(boxes),
       extraBoxes = Map.unmodifiable({
         for (final e in extraBoxes.entries) e.key: List<FilingBox>.unmodifiable(e.value),
       });

  final DateTime periodStart;
  final DateTime periodEnd;
  final String currency;

  /// The return's lines; not modifiable.
  final List<FilingLine> lines;

  /// The form's filled boxes, in the form's order; not modifiable.
  final List<FilingBox> boxes;

  /// The boxes of a second form filed beside the first, by the form's name
  /// (the Quebec `FPZ-500` beside the federal `GST34`); not modifiable.
  final Map<String, List<FilingBox>> extraBoxes;
  final FilingParty party;
  final FilingFacts facts;

  /// The moment the file is generated at.
  final DateTime generatedAt;

  /// The number the return carries ('' until it has one).
  final String number;
}
