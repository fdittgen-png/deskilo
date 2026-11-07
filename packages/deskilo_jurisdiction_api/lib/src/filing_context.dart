// SPDX-License-Identifier: AGPL-3.0-or-later

/// One line of a VAT return: what the period's documents add up to at one
/// rate and category, in one direction.
class FilingLine {
  const FilingLine({
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
    this.components = const [],
  });

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

  /// The taxes the line is made of (GST and QST of a Canadian line).
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
  const FilingContext({
    required this.periodStart,
    required this.periodEnd,
    required this.currency,
    required this.lines,
    required this.party,
    required this.generatedAt,
    this.facts = const FilingFacts(),
    this.number = '',
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final String currency;
  final List<FilingLine> lines;
  final FilingParty party;
  final FilingFacts facts;

  /// The moment the file is generated at.
  final DateTime generatedAt;

  /// The number the return carries ('' until it has one).
  final String number;
}
