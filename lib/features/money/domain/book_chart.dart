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

import 'coa_preview.dart';
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
  expenses('expenses', AccountType.expense);

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
const List<BookRole> requiredForLocalBook = [
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

  factory BookAccount.fromJson(Map<String, Object?> json) => BookAccount(
    id: '${json['id']}',
    workspaceId: '${json['workspace_id']}',
    issuerSiteId: '${json['issuer_site_id']}',
    code: '${json['code']}',
    name: '${json['name']}',
    type: AccountType.values.byName('${json['account_type']}'),
    isPosting: json['is_posting'] == true,
    origin: AccountOrigin.values.byName('${json['origin']}'),
    revision: json['revision']! as int,
  );

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
  });

  factory BookMapping.fromJson(Map<String, Object?> json) => BookMapping(
    id: '${json['id']}',
    workspaceId: '${json['workspace_id']}',
    issuerSiteId: '${json['issuer_site_id']}',
    role: BookRole.fromWire(json['role'] as String?),
    accountId: '${json['account_id']}',
    effectiveFrom: DateTime.parse('${json['effective_from']}'),
    revision: json['revision']! as int,
  );

  final String id;
  final String workspaceId;
  final String issuerSiteId;
  final BookRole role;
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
  for (final role in requiredForLocalBook)
    if (mappingOn(mappings, issuerSiteId, role, day) == null) role,
];

/// The country's suggested accounts (#671's preview) as unsaved drafts
/// for one issuer: reviewed and saved one by one, never written for the
/// owner.
List<BookAccount> suggestedAccounts({
  required String workspaceId,
  required String issuerSiteId,
  required String countryCode,
  required VatRegime regime,
}) {
  final chart = coaChartFor(
    countryCode: countryCode,
    regime: regime,
    noteFor: (_) => '',
  );
  return [
    for (final a in chart.accounts)
      BookAccount(
        id: '',
        workspaceId: workspaceId,
        issuerSiteId: issuerSiteId,
        code: a.number,
        name: a.label,
        type: switch (a.role) {
          CoaAccountRole.customers || CoaAccountRole.bank => AccountType.asset,
          CoaAccountRole.revenue => AccountType.income,
          CoaAccountRole.vat => AccountType.liability,
          CoaAccountRole.expenses => AccountType.expense,
        },
        isPosting: true,
        origin: AccountOrigin.suggested,
        revision: 0,
      ),
  ];
}
