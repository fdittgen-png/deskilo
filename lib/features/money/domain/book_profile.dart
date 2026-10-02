// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1869 — who keeps the official books of one issuer, and on which
// terms. A profile belongs to an issuer (a site with its own legal
// identity), never to a workspace name or a locale: two issuers that
// share a workspace and a name keep two books.
//
// It states one authority mode. Pre-accounting is what DesKilo has
// always been (member balances and invoices, nothing posted); a local
// book makes DesKilo the book; an external book names the system that
// stays authoritative, and everything DesKilo derives is labelled as
// derived. Versions are prospective: a new profile takes effect from a
// date and never rewrites what an older one governed.
//
// Pure Dart; the server enforces the same rules in save_book_profile
// (0335).

import 'accounting_amount.dart';

/// Who keeps the official books.
enum BookAuthority {
  preAccounting('pre_accounting'),
  localBook('local_book'),
  externalBook('external_book');

  const BookAuthority(this.wire);
  final String wire;

  static BookAuthority fromWire(String? wire) => values.firstWhere(
    (v) => v.wire == wire,
    orElse: () => throw FormatException('unknown authority $wire'),
  );
}

/// When income and charges are recognised.
enum AccountingBasis {
  accrual,
  cash;

  static AccountingBasis fromWire(String? wire) => values.firstWhere(
    (v) => v.name == wire,
    orElse: () => throw FormatException('unknown basis $wire'),
  );
}

class BookProfile {
  const BookProfile({
    required this.id,
    required this.workspaceId,
    required this.issuerSiteId,
    required this.authority,
    required this.externalSystem,
    required this.functionalCurrency,
    required this.fiscalYearStartMonth,
    required this.fiscalYearStartDay,
    required this.basis,
    required this.effectiveFrom,
    required this.revision,
  });

  factory BookProfile.fromJson(Map<String, Object?> json) => BookProfile(
    id: '${json['id']}',
    workspaceId: '${json['workspace_id']}',
    issuerSiteId: '${json['issuer_site_id']}',
    authority: BookAuthority.fromWire(json['authority_mode'] as String?),
    externalSystem: (json['external_system'] as String?) ?? '',
    functionalCurrency: '${json['functional_currency']}',
    fiscalYearStartMonth: json['fiscal_year_start_month']! as int,
    fiscalYearStartDay: json['fiscal_year_start_day']! as int,
    basis: AccountingBasis.fromWire(json['accounting_basis'] as String?),
    effectiveFrom: DateTime.parse('${json['effective_from']}'),
    revision: json['revision']! as int,
  );

  /// Empty for a profile not saved yet.
  final String id;
  final String workspaceId;

  /// The issuing site whose books these are.
  final String issuerSiteId;
  final BookAuthority authority;

  /// The authoritative system's name; required for an external book.
  final String externalSystem;
  final String functionalCurrency;
  final int fiscalYearStartMonth;
  final int fiscalYearStartDay;
  final AccountingBasis basis;

  /// The first day this version governs (a calendar date).
  final DateTime effectiveFrom;

  /// What the saver expects to replace; 0 for a new version.
  final int revision;

  Map<String, Object?> toJson() => {
    'id': id,
    'workspace_id': workspaceId,
    'issuer_site_id': issuerSiteId,
    'authority_mode': authority.wire,
    'external_system': externalSystem,
    'functional_currency': functionalCurrency,
    'fiscal_year_start_month': fiscalYearStartMonth,
    'fiscal_year_start_day': fiscalYearStartDay,
    'accounting_basis': basis.name,
    'effective_from': bookDate(effectiveFrom),
    'revision': revision,
  };
}

/// A calendar date on the wire: `2026-07-01`.
String bookDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum BookProfileProblem {
  externalSystemMissing,
  unsupportedCurrency,
  invalidFiscalStart,
}

/// What keeps [p] from being saved; empty when it may be.
List<BookProfileProblem> validateBookProfile(BookProfile p) => [
  if (p.authority == BookAuthority.externalBook &&
      p.externalSystem.trim().isEmpty)
    BookProfileProblem.externalSystemMissing,
  if (!supportedCurrencies.contains(p.functionalCurrency.toUpperCase()))
    BookProfileProblem.unsupportedCurrency,
  // A fiscal year starts on a day EVERY year has: never 29 February.
  if (p.fiscalYearStartMonth < 1 ||
      p.fiscalYearStartMonth > 12 ||
      p.fiscalYearStartDay < 1 ||
      p.fiscalYearStartDay > DateTime(2026, p.fiscalYearStartMonth + 1, 0).day)
    BookProfileProblem.invalidFiscalStart,
];

/// The fiscal year of [p] that contains the calendar date of [day].
({DateTime start, DateTime end, String label}) fiscalYearOf(
  BookProfile p,
  DateTime day,
) {
  final date = DateTime(day.year, day.month, day.day);
  var start = DateTime(date.year, p.fiscalYearStartMonth, p.fiscalYearStartDay);
  if (date.isBefore(start)) {
    start = DateTime(
      date.year - 1,
      p.fiscalYearStartMonth,
      p.fiscalYearStartDay,
    );
  }
  final next = DateTime(
    start.year + 1,
    p.fiscalYearStartMonth,
    p.fiscalYearStartDay,
  );
  final end = DateTime(next.year, next.month, next.day - 1);
  final label = start.year == end.year
      ? '${start.year}'
      : '${start.year}/${(end.year % 100).toString().padLeft(2, '0')}';
  return (start: start, end: end, label: label);
}

/// The version of [issuerSiteId]'s profile in force on [day]: the latest
/// one effective by then; null before the first, or for another issuer.
BookProfile? profileOn(
  List<BookProfile> versions,
  String issuerSiteId,
  DateTime day,
) {
  final date = DateTime.utc(day.year, day.month, day.day);
  BookProfile? best;
  for (final v in versions) {
    if (v.issuerSiteId != issuerSiteId) continue;
    final from = DateTime.utc(
      v.effectiveFrom.year,
      v.effectiveFrom.month,
      v.effectiveFrom.day,
    );
    if (from.isAfter(date)) continue;
    if (best == null || from.isAfter(best.effectiveFrom)) best = v;
  }
  return best;
}

/// Who keeps [issuerSiteId]'s books on [day]. With no profile — every
/// workspace from before #1869, an imported configuration, a new one —
/// the answer is pre-accounting: DesKilo as it always was, nothing
/// posted and nothing written to decide it.
BookAuthority authorityOn(
  List<BookProfile> versions,
  String issuerSiteId,
  DateTime day,
) =>
    profileOn(versions, issuerSiteId, day)?.authority ??
    BookAuthority.preAccounting;
