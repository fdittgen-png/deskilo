// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the fiscal source of an export is accepted only as the answer to
// the question asked: its own workspace, period and principal, a version it
// knows, and control totals that equal the sums of the rows it delivered
// (worked out here by hand, not by the code under test). Anything else
// stops the export with a named failure, never a smaller file. The export
// consumer takes its ledger and repartitions from that one answer and
// refuses when the invoice list the person holds has moved.
import 'package:deskilo/core/data/read_provenance.dart';
import 'package:deskilo/features/money/domain/accounting_source_queries.dart';
import 'package:deskilo/features/money/domain/accounting_source_snapshot.dart';
import 'package:deskilo/features/money/domain/audit_trail.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/datev_profile.dart';
import 'package:deskilo/features/money/presentation/export_year_books.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

const _ws = 'ws-1';
const _me = 'user-1';

Map<String, Object?> _ledger(String id, String kind, String category, int cents) => {
      'id': id,
      'workspace_id': _ws,
      'member_id': 'm-1',
      'kind': kind,
      'category': category,
      'amount_cents': cents,
      'description': 'd',
      'period': '2026-03',
      'created_at': '2026-03-13T08:00:00+00:00',
      'occurred_on': '2026-03-12',
    };

Map<String, Object?> _profile(String id, String site, int month, String from, int rev) => {
      'id': id,
      'workspace_id': _ws,
      'issuer_site_id': site,
      'authority_mode': 'pre_accounting',
      'external_system': '',
      'functional_currency': 'EUR',
      'fiscal_year_start_month': month,
      'fiscal_year_start_day': 1,
      'accounting_basis': 'accrual',
      'effective_from': from,
      'revision': rev,
    };

/// 12000 payment + 3000 service charge + 3000 expense credit = 18000 (credit
/// 15000, charge 3000); invoices 12000 + 7000 = 19000; one match of 12000;
/// one repartition of 6000.
Map<String, Object?> _answer() => {
      'version': 1,
      'status': 'ok',
      'workspace_id': _ws,
      'from': '2026-01-01',
      'to': '2026-12-31',
      'principal': _me,
      'cutoff': '100:110:',
      // #2564: the revisions the books were read with, from the same statement.
      'revisions': <String, Object?>{
        'settings': 's-1',
        'tax_reference': 't-1',
        'book_profile': 'b-1',
        'calendar': 'c-1',
      },
      'invoices': [
        {'id': 'i-a', 'number': 'A', 'total_cents': 12000},
        {'id': 'i-c', 'number': 'C', 'total_cents': 7000},
      ],
      'matches': [
        {'id': 'm-a', 'paid_cents': 12000},
      ],
      'ledger': [
        _ledger('l-1', 'credit', 'payment', 12000),
        _ledger('l-2', 'charge', 'service', 3000),
        _ledger('l-3', 'credit', 'expense', 3000),
      ],
      'repartitions': [
        {
          'id': 'r-1',
          'title': 'rent',
          'amount_cents': 6000,
          'method': 'equal',
          'period': '2026-04',
          'shares': <Object?>[],
          'status': 'confirmed',
          'created_at': '2026-03-30T08:00:00+00:00',
          'applied_at': '2026-04-01T08:00:00+00:00',
        },
      ],
      // two versions of one issuer (revisions 1 and 2): sum 3.
      'book_profiles': [
        _profile('p-1', 's-1', 1, '2025-01-01', 1),
        _profile('p-2', 's-1', 4, '2026-01-01', 2),
      ],
      // #2587: one approved bill of 1.20 + 0.60, in the same snapshot.
      'purchases': [
        {
          'id': 'pd-1',
          'kind': 'bill',
          'currency': 'EUR',
          'original_date': '2026-03-10',
          'received_on': null,
          'lines': [
            {'line_no': 1, 'gross_cents': 120, 'net_cents': 100, 'tax_cents': 20,
             'recognition_kind': 'operating'},
            {'line_no': 2, 'gross_cents': 60, 'net_cents': 50, 'tax_cents': 10,
             'recognition_kind': 'operating'},
          ],
        },
      ],
      'totals': {
        'purchases': {'count': 1, 'line_count': 2, 'gross_cents': 180},
        'book_profiles': {'count': 2, 'revision_sum': 3},
        'invoices': {'count': 2, 'total_cents': 19000},
        'matches': {'count': 1, 'paid_cents': 12000},
        'ledger': {
          'count': 3,
          'sum_cents': 18000,
          'credit_cents': 15000,
          'charge_cents': 3000,
        },
        'repartitions': {'count': 1, 'amount_cents': 6000},
      },
    };

AccountingSourceSnapshot _parse(Object? raw) => AccountingSourceSnapshot.fromRpc(
      raw,
      workspaceId: _ws,
      from: '2026-01-01',
      to: '2026-12-31',
      principal: _me,
    );

void _refused(Map<String, Object?> a, AccountingSourceFailure failure) {
  expect(
    () => _parse(a),
    throwsA(
      isA<AccountingSourceException>().having((e) => e.failure, 'failure', failure),
    ),
  );
}

class _Source implements AccountingSourceQueries {
  _Source(this.answer);
  final Map<String, Object?> answer;
  int calls = 0;

  @override
  Future<AccountingSourceSnapshot> fetchAccountingSource({
    required String workspaceId,
    required int year,
  }) async {
    calls++;
    return _parse(answer);
  }
}

void main() {
  test('the answer to the question asked is accepted and is a snapshot', () {
    final s = _parse(_answer());
    expect(s.provenance.completeness, ReadCompleteness.snapshot);
    expect(s.provenance.sourceRevision, '100:110:');
    expect(s.provenance.target, _ws);
    expect(s.invoices.map((i) => i.number), ['A', 'C']);
    expect(s.ledger.fold<int>(0, (a, e) => a + e.amountCents), 18000);
    expect(s.repartitions.single.amountCents, 6000);
    expect(s.matchedCents, 12000);
    expect(s.bookProfiles.map((p) => p.id), ['p-1', 'p-2']);
  });

  test('the book profiles of the source drive the DATEV fiscal-year start', () {
    final s = _parse(_answer());
    // The April-2026 version is in force at 31 December 2026: the year that
    // contains 1 January 2026 began on 1 April 2025.
    final accounts = datevAccountsFor(s.bookProfiles, const DatevAccounts(), 2026);
    expect(accounts.fiscalYearStart, DateTime(2025, 4));
    expect(
      datevAccountsFor(const [], const DatevAccounts(), 2026).fiscalYearStart,
      isNull,
    );
  });

  test('profiles missing, of another workspace or off their totals stop', () {
    _refused(_answer()..remove('book_profiles'), AccountingSourceFailure.inconsistent);
    final a = _answer();
    ((a['book_profiles']! as List)[0]! as Map)['workspace_id'] = 'ws-2';
    _refused(a, AccountingSourceFailure.inconsistent);
    final b = _answer();
    ((b['totals']! as Map)['book_profiles']! as Map)['revision_sum'] = 2;
    _refused(b, AccountingSourceFailure.inconsistent);
    final c = _answer();
    (c['book_profiles']! as List).removeLast();
    _refused(c, AccountingSourceFailure.inconsistent);
  });

  test('#2587: the purchases come with their lines; missing or off their '
      'totals stops', () {
    final ok = _parse(_answer());
    expect(ok.purchases.single.id, 'pd-1');
    expect(ok.purchases.single.lines.map((l) => l.grossCents), [120, 60]);
    expect(ok.purchases.single.dated, DateTime(2026, 3, 10));
    _refused(_answer()..remove('purchases'), AccountingSourceFailure.inconsistent);
    final a = _answer();
    ((a['totals']! as Map)['purchases']! as Map)['gross_cents'] = 170;
    _refused(a, AccountingSourceFailure.inconsistent);
    final b = _answer();
    (((b['purchases']! as List)[0]! as Map)['lines']! as List).removeLast();
    _refused(b, AccountingSourceFailure.inconsistent);
  });

  test('#2564: the four revisions are read beside the cutoff; an answer '
      'without them, or with one unnamed, stops', () {
    final s = _parse(_answer());
    expect(s.revisions,
        (settings: 's-1', taxReference: 't-1', bookProfile: 'b-1', calendar: 'c-1'));
    // An older producer names no revisions: the export cannot say which
    // settings, tax reference, profile and calendar it was made with.
    _refused(_answer()..remove('revisions'), AccountingSourceFailure.inconsistent);
    _refused(_answer()..['revisions'] = 'abc', AccountingSourceFailure.inconsistent);
    final a = _answer();
    (a['revisions']! as Map).remove('calendar');
    _refused(a, AccountingSourceFailure.inconsistent);
    final b = _answer();
    (b['revisions']! as Map)['settings'] = '';
    _refused(b, AccountingSourceFailure.inconsistent);
    final c = _answer();
    (c['revisions']! as Map)['tax_reference'] = 7;
    _refused(c, AccountingSourceFailure.inconsistent);
  });

  test('#2564: the export carries the revisions of its one source and the '
      'audit trail states them; without them its header is as before', () async {
    final source = _Source(_answer());
    final loaded = <Invoice>[
      SeededExportYear.invoices.first.copyWith(id: 'i-a', number: 'A', totalCents: 12000),
      SeededExportYear.invoices.first.copyWith(id: 'i-c', number: 'C', totalCents: 7000),
    ];
    final books = (await exportYearBooks(source, _ws, 2026, loaded, loaded: loaded))!;
    expect(books.revisions.bookProfile, 'b-1');
    String trail({AccountingSourceRevisions? source}) => buildAuditTrailCsv(
          events: const [],
          generatedAt: DateTime.utc(2026, 5),
          workspaceName: 'W',
          source: source,
        );
    expect(
      trail(source: books.revisions),
      contains('# made with: settings s-1; tax reference t-1; '
          'book profile b-1; calendar c-1\n'),
    );
    expect(trail(), isNot(contains('made with')));
    expect(
      trail(source: books.revisions).split('\n').length,
      trail().split('\n').length + 1,
    );
  });

  test('an over-budget scope is a named refusal with no rows', () {
    _refused({
      'version': 1,
      'status': 'refused',
      'reason': 'over_budget',
      'action': 'narrow_period',
    }, AccountingSourceFailure.overBudget);
  });

  test('an answer for another workspace, period, principal or version stops', () {
    _refused(_answer()..['workspace_id'] = 'ws-2', AccountingSourceFailure.inconsistent);
    _refused(_answer()..['to'] = '2026-06-30', AccountingSourceFailure.inconsistent);
    _refused(_answer()..['principal'] = 'user-2', AccountingSourceFailure.inconsistent);
    _refused(_answer()..['version'] = 2, AccountingSourceFailure.inconsistent);
    _refused(_answer()..['cutoff'] = '', AccountingSourceFailure.inconsistent);
  });

  test('a control total that is not the sum of its rows stops', () {
    final a = _answer();
    ((a['totals']! as Map)['ledger']! as Map)['sum_cents'] = 17999;
    _refused(a, AccountingSourceFailure.inconsistent);
    final b = _answer();
    ((b['totals']! as Map)['ledger']! as Map)['charge_cents'] = 2000;
    _refused(b, AccountingSourceFailure.inconsistent);
    final c = _answer();
    (c['ledger']! as List).removeLast();
    _refused(c, AccountingSourceFailure.inconsistent);
    final d = _answer();
    ((d['totals']! as Map)['repartitions']! as Map)['count'] = 2;
    _refused(d, AccountingSourceFailure.inconsistent);
  });

  test('a ledger kind or category this build does not know stops, never skipped', () {
    final a = _answer();
    (a['ledger']! as List)[1] = _ledger('l-2', 'charge', 'carbon_credit', 3000);
    _refused(a, AccountingSourceFailure.inconsistent);
  });

  test('the invoices held must be the invoices of the source, at their value', () {
    final s = _parse(_answer())
      ..requireInvoicesHeld([
        (id: 'i-a', number: 'A', totalCents: 12000),
        (id: 'i-c', number: 'C', totalCents: 7000),
        (id: 'i-z', number: 'Z', totalCents: 1),
      ]);
    expect(
      () => s.requireInvoicesHeld([(id: 'i-a', number: 'A', totalCents: 12000)]),
      throwsA(isA<AccountingSourceException>()
          .having((e) => e.failure, 'f', AccountingSourceFailure.invoicesMoved)),
    );
    expect(
      () => s.requireInvoicesHeld([
        (id: 'i-a', number: 'A', totalCents: 12001),
        (id: 'i-c', number: 'C', totalCents: 7000),
      ]),
      throwsA(isA<AccountingSourceException>()),
    );
  });

  test('the export consumer takes the year books from the one source response', () async {
    final source = _Source(_answer());
    final loaded = <Invoice>[
      SeededExportYear.invoices.first.copyWith(id: 'i-a', number: 'A', totalCents: 12000),
      SeededExportYear.invoices.first.copyWith(id: 'i-c', number: 'C', totalCents: 7000),
    ];
    final books = (await exportYearBooks(source, _ws, 2026, loaded, loaded: loaded))!;
    expect(source.calls, 1);
    expect(books.ledger.map((e) => e.id), ['l-1', 'l-2', 'l-3']);
    expect(books.ledger.fold<int>(0, (a, e) => a + e.amountCents), 18000);
    expect(books.repartitions.single.id, 'r-1');
    expect(books.bookProfiles, hasLength(2));
  });

  test('the consumer stops (null) when an invoice moved since the list was loaded', () {
    final source = _Source(_answer());
    final loaded = <Invoice>[
      SeededExportYear.invoices.first.copyWith(id: 'i-a', number: 'A', totalCents: 12000),
    ];
    expect(exportYearBooks(source, _ws, 2026, loaded, loaded: loaded), completion(isNull));
  });
}
