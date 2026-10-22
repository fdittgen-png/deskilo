// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the accounting target registry: one descriptor per product edition
// an export or a connection reaches. A file target carries the format it
// writes ([AccountingFormat]); an API target (#2370 PR 2) carries none. The
// countries a target is offered in, what it receives, which operations it
// takes, how it codes tax and what its customer ids may look like are facts
// of the TARGET, so the sheet, the coverage table and a future connection
// read the same descriptor. The qualification stays the existing
// [AccountingCapability], keyed by the target id.
import 'accounting_capability.dart';
import 'accounting_format.dart';

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

/// How the target codes tax: a code per rate, per tax component (a US or
/// Canadian component), or not at all (the account carries the rate).
enum TaxCodeModel { perRate, perComponent, none }

/// What a customer id may look like in the target; null fields are free.
class CustomerIdRule {
  const CustomerIdRule({this.maxLength, this.charset, this.numericRange});

  final int? maxLength;

  /// A regular expression every id must match in full.
  final String? charset;

  /// The inclusive range a numeric id must fall in.
  final (int, int)? numericRange;
}

/// The volume a target takes; null is unbounded or unknown.
class TargetLimits {
  const TargetLimits({this.rowsPerFile, this.requestsPerMinute});

  final int? rowsPerFile;
  final int? requestsPerMinute;
}

/// One product edition DesKilo exports to or connects with.
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
  });

  /// Stable wire id: the format id of a file target.
  final String id;
  final String vendor;
  final String product;
  final String edition;

  /// Uppercase ISO country codes the target is offered in. Empty means
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

  bool offeredIn(String countryCode) =>
      countries.isEmpty || countries.contains(countryCode.toUpperCase());

  /// The reviewed qualification of this target; one nobody reviewed is
  /// `unsupported` and blocked, never silently allowed.
  AccountingCapability get capability => switch (format) {
    final f? => capabilityOf(f),
    null => AccountingCapability(
      formatId: id,
      state: QualificationState.unsupported,
    ),
  };
}
