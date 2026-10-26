// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the accounting target registry: one descriptor per product edition
// an export or a connection reaches. A file target carries the format it
// writes ([AccountingFormat]); an API target carries none
// and says how an issuer connects to it. The
// countries a target is offered in, what it receives, which operations it
// takes, how it codes tax and what its customer ids may look like are facts
// of the TARGET, so the sheet, the coverage table and a future connection
// read the same descriptor. The qualification stays the existing
// [AccountingCapability], keyed by the target id.

import '../../../core/vat/place_of_supply.dart' show isEuCountry;
import 'accounting_capability.dart';
import 'accounting_format.dart';

/// A member of [AccountingTarget.countries] that stands for every EU member
/// state, resolved against the `eu_member` rows of the tax reference: the
/// list is data, never typed a second time.
const accountingCountriesEu = '@eu';

/// How the target is reached.
enum AccountingTransport { file, api }

/// What the target receives: business documents (invoices, credit notes,
/// payments with their lines and tax components) or balanced postings.
enum AccountingPayload { documents, journal }

/// A business event the target can take.
enum AccountingOperation {
  sale,
  credit,
  receipt,
  refund,
  writeOff,
  expense,
  attachment,
}

/// How an issuer connects to an API target: by signing in to it (OAuth 2.0,
/// the installation's application with the target; the redirect is
/// handled by the `accounting-connect` function) or with an API token the
/// person creates in the target and pastes once.
enum AccountingAuthKind {
  oauth2('oauth2'),
  token('token');

  const AccountingAuthKind(this.wire);
  final String wire;

  static AccountingAuthKind of(String? wire) =>
      values.firstWhere((v) => v.wire == wire, orElse: () => token);
}

/// #2374 — what the person pastes to connect a token target.
enum AccountingTokenShape {
  /// An API token the person creates in the target.
  apiToken,

  /// The client id and secret of the Microsoft Entra application the
  /// company's administrator registered (OAuth 2.0 client credentials),
  /// with the company named by tenant, environment and company id
  /// (`business_central_connection.dart`).
  entraClientCredentials,
}

/// How the target codes tax: a code per rate, per tax component (a US or
/// Canadian component), or not at all (the account carries the rate).
enum TaxCodeModel { perRate, perComponent, none }

/// What a customer id may look like in the target; null fields are free.
class CustomerIdRule {
  const CustomerIdRule({this.maxLength, this.charset});

  final int? maxLength;

  /// A regular expression every id must match in full.
  final String? charset;

  /// [number] as the target's id: in capitals without separators, when the
  /// rule admits it; null otherwise (empty, too long, another charset).
  String? admit(String number) {
    final code = number.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (code.isEmpty) return null;
    if (maxLength case final max? when code.length > max) return null;
    if (charset case final c? when !RegExp('^(?:$c)\$').hasMatch(code)) {
      return null;
    }
    return code;
  }
}

/// The volume a target takes; null is unbounded or unknown.
class TargetLimits {
  const TargetLimits({this.rowsPerFile, this.requestsPerMinute});

  final int? rowsPerFile;
  final int? requestsPerMinute;
}

/// One product edition DesKilo exports to or connects with.
/// The vendor name of the app's own exports (the ledgers, the journals,
/// the archive): files DesKilo writes, never a software the books are kept
/// in.
const String deskiloVendor = 'DesKilo';

class AccountingTarget {
  const AccountingTarget({
    required this.id,
    required this.vendor,
    required this.product,
    required this.edition,
    required this.countries,
    required this.transport,
    required this.payload,
    required this.operations,
    required this.taxCodeModel,
    this.format,
    this.customerIdRule = const CustomerIdRule(),
    this.limits = const TargetLimits(),
    this.connectsBy = const {},
    this.tokenShape = AccountingTokenShape.apiToken,
    this.runnerDelivers = false,
    this.importsTargetId,
    this.authority = false,
  });

  /// Stable wire id: the format id of a file target.
  final String id;
  final String vendor;

  /// #3063 review — this target is a tax authority's or a standard's file
  /// (FEC, SAF-T, FAIA, the KMU journal), not a product a space keeps its
  /// books in; the software picker leaves it out.
  final bool authority;
  final String product;
  final String edition;

  /// Uppercase ISO country codes the target is offered in;
  /// [accountingCountriesEu] stands for every EU member state of the tax
  /// reference. Empty means
  /// everywhere: a target with no national tie is useful to any
  /// accountant, and hiding it behind a country list would only make it
  /// unreachable for the countries that mandate nothing.
  final Set<String> countries;
  final AccountingTransport transport;
  final AccountingPayload payload;
  final Set<AccountingOperation> operations;
  final TaxCodeModel taxCodeModel;

  /// The file a file target writes; null for an API target.
  final AccountingFormat? format;
  final CustomerIdRule customerIdRule;
  final TargetLimits limits;

  /// The ways an issuer connects to an API target; empty for a file target.
  final Set<AccountingAuthKind> connectsBy;

  /// What a [AccountingAuthKind.token] connection is made with.
  final AccountingTokenShape tokenShape;

  /// #2377 — the delivery runner sends documents through this API target's
  /// adapter. Until it does, a connection and its mappings are kept and the
  /// sheet says nothing is sent yet.
  final bool runnerDelivers;

  /// #2373 — a product that imports another target's file rather than one
  /// of its own (Sage 100 France reads the FEC, Sage 50 Germany DATEV): the
  /// id of that target. Such a product writes no format; choosing it is
  /// choosing that target, and the export sheet says so.
  final String? importsTargetId;

  bool offeredIn(String countryCode) {
    final code = countryCode.toUpperCase();
    return countries.isEmpty ||
        countries.contains(code) ||
        (countries.contains(accountingCountriesEu) && isEuCountry(code));
  }

  /// A software a space can keep its books in: neither the app's own
  /// exports nor an authority's file format.
  bool get isSoftware => vendor != deskiloVendor && !authority;

  /// The reviewed qualification of this target; one nobody reviewed is
  /// `unsupported` and blocked, never silently allowed.
  AccountingCapability get capability => switch (format) {
    final f? => capabilityOf(f),
    null => capabilityOfTarget(id),
  };
}
