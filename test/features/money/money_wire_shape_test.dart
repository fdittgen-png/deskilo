// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2387 — the money rows as the RPCs and tables send them. A full row
// decodes; a row missing a non-null column fails naming the source, the
// key and the expected type.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/domain/member_account.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _missing(String source, String key, String expected) => throwsA(
  isA<JsonShapeException>()
      .having((e) => e.context, 'context', source)
      .having((e) => e.key, 'key', key)
      .having((e) => e.expected, 'expected', expected),
);

const _account = {
  'credit_cents': 500,
  'open_invoices': [
    {
      'invoice_id': 'i1',
      'number': 'F-1',
      'total_cents': 12000,
      'paid_cents': 2000,
      'remaining_cents': 10000,
    },
  ],
  'open_total_cents': 10000,
};

const _activity = {
  'id': 'a1',
  'workspace_id': 'w1',
  'workspace_name': 'Space',
  'occurred_at': '2026-03-04T09:00:00Z',
  'currency': 'EUR',
  'status': 'paid',
  'amount_cents': 1200,
};

const _profile = {
  'id': 'p1',
  'workspace_id': 'w1',
  'issuer_site_id': 's1',
  'authority_mode': 'local_book',
  'functional_currency': 'EUR',
  'fiscal_year_start_month': 1,
  'fiscal_year_start_day': 1,
  'accounting_basis': 'accrual',
  'effective_from': '2026-01-01',
  'revision': 1,
};

void main() {
  test('member_account: a full row decodes, defaults fill the rest', () {
    final a = MemberAccount.fromJson(Map<String, dynamic>.of(_account));
    expect(a.openInvoices.single.remainingCents, 10000);
    expect(a.openInvoices.single.period, '');
    expect(a.netPositionCents, 0);
  });

  test('member_account: an open invoice without its remainder names it', () {
    final row = Map<String, dynamic>.of(_account)
      ..['open_invoices'] = [
        {'invoice_id': 'i1', 'number': 'F-1', 'total_cents': 1},
      ];
    expect(
      () => MemberAccount.fromJson(row),
      _missing('member_account', 'remaining_cents', 'int'),
    );
  });

  test('my_financial_activity: a row without its currency names it', () {
    expect(
      AccountActivity.fromJson(Map<String, dynamic>.of(_activity)).amountCents,
      1200,
    );
    expect(
      () => AccountActivity.fromJson(
        Map<String, dynamic>.of(_activity)..remove('currency'),
      ),
      _missing('my_financial_activity', 'currency', 'String'),
    );
  });

  test('book_profiles: a profile without its revision names it', () {
    final p = BookProfile.fromJson(Map<String, Object?>.of(_profile));
    expect(BookProfile.fromJson(p.toJson()).toJson(), p.toJson());
    expect(
      () => BookProfile.fromJson(
        Map<String, Object?>.of(_profile)..remove('revision'),
      ),
      _missing('book_profiles', 'revision', 'int'),
    );
  });

  test('book_mappings: a mapping without its account names it', () {
    expect(
      () => BookMapping.fromJson({
        'workspace_id': 'w1',
        'issuer_site_id': 's1',
        'role': 'revenue',
        'effective_from': '2026-01-01',
        'revision': 1,
      }),
      _missing('book_mappings', 'account_id', 'String'),
    );
  });
}
