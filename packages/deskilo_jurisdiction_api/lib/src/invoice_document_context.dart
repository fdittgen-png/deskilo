// SPDX-License-Identifier: AGPL-3.0-or-later

/// One party of an invoice document, as frozen on the document at issue.
class DocumentParty {
  const DocumentParty({
    this.name = '',
    this.street = '',
    this.city = '',
    this.postalCode = '',
    this.subdivision = '',
    this.country = '',
    this.vatId = '',
    this.legalId = '',
    this.endpointScheme = '',
    this.endpointId = '',
  });

  final String name;
  final String street;
  final String city;
  final String postalCode;

  /// The province or state code, '' when none.
  final String subdivision;

  /// ISO 3166-1 alpha-2.
  final String country;
  final String vatId;

  /// The company register number.
  final String legalId;

  /// The electronic address scheme and identifier ('' when none).
  final String endpointScheme;
  final String endpointId;
}

/// One supply position, already worded and priced by the host.
class DocumentLine {
  const DocumentLine({
    required this.text,
    required this.quantity,
    required this.grossMinor,
    required this.netMinor,
    required this.vatPercent,
    this.vatCategory = '',
  });

  /// The localized position wording, as the PDF prints it.
  final String text;
  final int quantity;

  /// The position's total in minor units, VAT included (negative on a
  /// reversal).
  final int grossMinor;

  /// The same total without VAT, split by the host's own exact rule so every
  /// syntax states the same net.
  final int netMinor;
  final double vatPercent;

  /// The UNCL5305 category frozen on the line; '' when none.
  final String vatCategory;
}

/// The VAT of one rate and category, in minor units.
class DocumentVatTotal {
  const DocumentVatTotal({
    required this.percent,
    required this.category,
    required this.netMinor,
    required this.vatMinor,
  });

  final double percent;
  final String category;
  final int netMinor;
  final int vatMinor;
}

/// Everything an invoice profile renders from. The host computes the figures
/// ONCE (the totals rule the other syntaxes read too) and hands them over, so
/// a profile never reaches for the invoice model or the tax reference of the
/// application and the renderings of one invoice cannot disagree. Lists are
/// not modifiable.
class InvoiceDocumentContext {
  InvoiceDocumentContext({
    required this.number,
    required this.issuedAt,
    required this.currency,
    required this.currencyExponent,
    required this.creditNote,
    required this.seller,
    required this.buyer,
    required List<DocumentLine> lines,
    required List<DocumentVatTotal> vatBreakdown,
    required this.payableMinor,
    this.replacesNumber = '',
    this.sellerVatRegistered = true,
    this.category = '',
    this.exemptionText = '',
    this.dueDate,
    this.iban = '',
    this.stampDutyMinor,
    this.transmitterId = '',
    this.progressive = '',
    this.period = '',
    this.correctedIssuedAt,
    Set<String> euMemberStates = const {},
  }) : euMemberStates = Set.unmodifiable(euMemberStates),
       lines = List.unmodifiable(lines),
       vatBreakdown = List.unmodifiable(vatBreakdown);

  final String number;
  final DateTime issuedAt;
  final String currency;

  /// The number of minor-unit decimals of [currency] (2 for EUR, 0 for JPY).
  final int currencyExponent;
  final bool creditNote;

  /// The number of the document this one replaces or credits; '' when none.
  final String replacesNumber;
  final DocumentParty seller;
  final DocumentParty buyer;

  /// The supply positions in document order.
  final List<DocumentLine> lines;

  /// The VAT breakdown of those positions.
  final List<DocumentVatTotal> vatBreakdown;

  /// What is still to pay, in minor units (0 or less: nothing to pay).
  final int payableMinor;

  /// Whether the seller charges VAT under the ordinary regime.
  final bool sellerVatRegistered;

  /// The document's tax category when it has one for the whole ('' else).
  final String category;
  final String exemptionText;
  final DateTime? dueDate;
  final String iban;

  /// The stamp duty the host found owed, in minor units; null when none.
  final int? stampDutyMinor;

  /// The intermediary that transmits the file; '' when the seller sends.
  final String transmitterId;

  /// The sender's own unique id for the file, already resolved by the host.
  final String progressive;

  /// The billing period the document covers as the host states it
  /// ('yyyy-MM'), '' when none.
  final String period;

  /// The issue date of the document this one corrects, when the host knows it
  /// (a correction states it); null otherwise.
  final DateTime? correctedIssuedAt;

  /// The ISO codes of the EU member states of the workspace's tax reference,
  /// so a profile that files a buyer's VAT number as an EU one need not read
  /// the reference itself.
  final Set<String> euMemberStates;
}
