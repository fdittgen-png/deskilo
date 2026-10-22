// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1869 B — one issuer's chart of accounts and the account each posting
// role books to. Small on purpose: the accounts a coworking issuer
// touches, reviewed by someone who manages billing, never a national
// chart library and never a guess written into the book.
//
// An account code is a STRING (leading zeroes are meaningful in more
// than one national chart). Its type and whether it takes postings are
// two facts. A role maps only to a posting account of a type that fits
// it, of the same issuer. Mappings are versioned from a date: a new
// version governs what is booked from then on and rewrites nothing
// booked before. A local book cannot start until customers, revenue and
// bank are mapped for its first day. The server enforces the same rules
// (0338).

import '../../../core/data/json_reader.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'vat_regime.dart';

enum AccountType { asset, liability, equity, income, expense }

/// Where an account came from: typed in, or taken from the suggested
/// national chart and then reviewed.
enum AccountOrigin { manual, suggested }

/// What a posting needs an account for.
enum BookRole {
  customers('customers', AccountType.asset),
  revenue('revenue', AccountType.income),
  bank('bank', AccountType.asset),
  vatOutput('vat_output', AccountType.liability),

  /// #2357 — deductible VAT on expenses (FR 44566, DE 1576/1406).
  vatInput('vat_input', AccountType.asset),
  expenses('expenses', AccountType.expense),

  /// #2365 (0517) — the bases the posting contract adds: what the space
  /// owes its suppliers, output tax not yet due, the written-off rest of a
  /// receivable, a discount granted, money in transit at a payment provider
  /// and that provider's fees.
  suppliers('suppliers', AccountType.liability),
  vatPending('vat_pending', AccountType.liability),
  writeOff('write_off', AccountType.expense),
  cashDiscount('cash_discount', AccountType.expense),
  clearing('clearing', AccountType.asset),
  fees('fees', AccountType.expense);

  const BookRole(this.wire, this.type);
  final String wire;

  /// The only account type this role may book to.
  final AccountType type;

  static BookRole fromWire(String? wire) => values.firstWhere(
    (v) => v.wire == wire,
    orElse: () => throw FormatException('unknown role $wire'),
  );
}

/// The roles a local book cannot start without.
const List<BookRole> _requiredForLocalBook = [
  BookRole.customers,
  BookRole.revenue,
  BookRole.bank,
];

class BookAccount {
  const BookAccount({
    required this.id,
    required this.workspaceId,
    required this.issuerSiteId,
    required this.code,
    required this.name,
    required this.type,
    required this.isPosting,
    required this.origin,
    required this.revision,
  });

  /// #2387 — read through [JsonReader].
  factory BookAccount.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, context: 'book_accounts');
    return BookAccount(
      id: r.stringOr('id'),
      workspaceId: r.string('workspace_id'),
      issuerSiteId: r.string('issuer_site_id'),
      code: r.string('code'),
      name: r.string('name'),
      type: AccountType.values.byName(r.string('account_type')),
      isPosting: r.boolOr('is_posting', fallback: false),
      origin: AccountOrigin.values.byName(r.string('origin')),
      revision: r.integer('revision'),
    );
  }

  /// Empty for an account not saved yet.
  final String id;
  final String workspaceId;
  final String issuerSiteId;
  final String code;
  final String name;
  final AccountType type;

  /// False for a grouping account that only sums its children.
  final bool isPosting;
  final AccountOrigin origin;

  /// What the saver expects to replace; 0 for a new account.
  final int revision;

  Map<String, Object?> toJson() => {
    'id': id,
    'workspace_id': workspaceId,
    'issuer_site_id': issuerSiteId,
    'code': code,
    'name': name,
    'account_type': type.name,
    'is_posting': isPosting,
    'origin': origin.name,
    'revision': revision,
  };
}

class BookMapping {
  const BookMapping({
    required this.id,
    required this.workspaceId,
    required this.issuerSiteId,
    required this.role,
    required this.accountId,
    required this.effectiveFrom,
    required this.revision,
    this.qualifier,
  });

  /// #2387 — read through [JsonReader].
  factory BookMapping.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, context: 'book_mappings');
    // #2365 (0517) — `revenue:standard` is the base and its qualifier.
    final wire = r.stringOrNull('role');
    final colon = wire?.indexOf(':') ?? -1;
    return BookMapping(
      id: r.stringOr('id'),
      workspaceId: r.string('workspace_id'),
      issuerSiteId: r.string('issuer_site_id'),
      role: BookRole.fromWire(colon < 0 ? wire : wire!.substring(0, colon)),
      qualifier: colon < 0 ? null : wire!.substring(colon + 1),
      accountId: r.string('account_id'),
      effectiveFrom: r.dateTime('effective_from'),
      revision: r.integer('revision'),
    );
  }

  final String id;
  final String workspaceId;
  final String issuerSiteId;
  final BookRole role;

  /// The rate group or provider a qualified mapping is for (`revenue:<group>`,
  /// `clearing:<provider>`), or null for the base itself.
  final String? qualifier;
  final String accountId;
  final DateTime effectiveFrom;
  final int revision;
}

enum BookAccountProblem { invalidCode, nameMissing }

final _code = RegExp(r'^[0-9A-Za-z][0-9A-Za-z._-]{0,19}$');

List<BookAccountProblem> validateBookAccount(BookAccount a) => [
  if (!_code.hasMatch(a.code)) BookAccountProblem.invalidCode,
  if (a.name.trim().isEmpty) BookAccountProblem.nameMissing,
];

enum BookMappingProblem { otherIssuer, notPosting, typeMismatch }

/// Why [account] cannot take [role] for [issuerSiteId]; null if it can.
BookMappingProblem? mappingProblem(
  BookRole role,
  BookAccount account,
  String issuerSiteId,
) {
  if (account.issuerSiteId != issuerSiteId) {
    return BookMappingProblem.otherIssuer;
  }
  if (!account.isPosting) return BookMappingProblem.notPosting;
  if (account.type != role.type) return BookMappingProblem.typeMismatch;
  return null;
}

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// The mapping of [role] for [issuerSiteId] in force on [day].
BookMapping? mappingOn(
  List<BookMapping> versions,
  String issuerSiteId,
  BookRole role,
  DateTime day,
) {
  BookMapping? best;
  for (final m in versions) {
    if (m.issuerSiteId != issuerSiteId || m.role != role) continue;
    // A qualified mapping answers for its qualifier only (#2365).
    if (m.qualifier != null) continue;
    if (_day(m.effectiveFrom).isAfter(_day(day))) continue;
    if (best == null ||
        _day(m.effectiveFrom).isAfter(_day(best.effectiveFrom))) {
      best = m;
    }
  }
  return best;
}

/// The required roles [issuerSiteId] has no mapping for on [day].
List<BookRole> missingForLocalBook(
  List<BookMapping> mappings,
  String issuerSiteId,
  DateTime day,
) => [
  for (final role in _requiredForLocalBook)
    if (mappingOn(mappings, issuerSiteId, role, day) == null) role,
];

/// #2365 — one account of the country's suggested chart, with the role
/// (and rate group) it is proposed for.
typedef SuggestedAccount = ({
  BookAccount account,
  BookRole role,
  String? qualifier,
});

const _taxRoles = {BookRole.vatOutput, BookRole.vatInput, BookRole.vatPending};

/// The country's suggested chart (the tax reference's `coa` rows, #671) as
/// unsaved drafts for one issuer, each with the role it is proposed for:
/// saved only when someone asks for it, then reviewed and re-pointed like
/// any other. No tax account where no VAT is charged.
List<SuggestedAccount> suggestedAccounts({
  required String workspaceId,
  required String issuerSiteId,
  required String countryCode,
  required VatRegime regime,
}) {
  final charging = regime == VatRegime.vatRegistered;
  return [
    for (final r in ActiveTaxReference.current.chartOf(countryCode))
      if (_suggestedRole(r.role) case (final role, final qualifier)
          when charging || !_taxRoles.contains(role))
        (
          account: BookAccount(
            id: '',
            workspaceId: workspaceId,
            issuerSiteId: issuerSiteId,
            code: r.account,
            name: r.label,
            type: role.type,
            isPosting: true,
            origin: AccountOrigin.suggested,
            revision: 0,
          ),
          role: role,
          qualifier: qualifier,
        ),
  ];
}

/// The role a chart row is proposed for: a base with an optional rate
/// group (`vat_output:reduced`); the rows name output tax `vat` (#671).
/// Null for the chart's own row.
(BookRole, String?)? _suggestedRole(String wire) {
  final colon = wire.indexOf(':');
  final base = colon < 0 ? wire : wire.substring(0, colon);
  final role = BookRole.values
      .where((v) => v.wire == (base == 'vat' ? 'vat_output' : base))
      .firstOrNull;
  return role == null ? null : (role, colon < 0 ? null : wire.substring(colon + 1));
}
