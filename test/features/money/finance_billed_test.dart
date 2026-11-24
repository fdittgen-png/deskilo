// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- Me reads `my_finance_overview_v2`: the documents of a subject read
// through a billing-access grant are kept APART from what the account owes as a
// member, each row names its financial subject, and two debtors of one seller
// and one currency stay two groups with their own open amount.
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(
  String id, {
  required String subject,
  String access = 'billing_grant',
  String workspace = 'w-1',
  int total = 10000,
  String currency = 'EUR',
  String state = 'open',
  String issued = '2026-11-01T09:00:00Z',
}) => {
  'id': id,
  'workspace_id': workspace,
  'workspace_name': 'Atelier',
  'financial_subject_id': subject,
  'access': access,
  'number': 'N-$id',
  'issued_at': issued,
  'total_cents': total,
  'currency': currency,
  'paid_cents': 0,
  'state': state,
  'still_due_cents': state == 'open' ? total : 0,
};

FinanceOverview _read(
  List<Map<String, dynamic>> invoices, [
  List<Map<String, dynamic>> reminders = const [],
]) => FinanceOverview.fromJson({'invoices': invoices, 'reminders': reminders});

void main() {
  test('a member document stays mine; a granted one is billed apart', () {
    final o = _read([
      _row('m', subject: 'me', access: 'member', total: 5000),
      _row('b', subject: 'acme'),
    ]);
    expect(o.invoices.map((i) => i.id), ['m']);
    expect(o.billed.map((i) => i.id), ['b']);
    expect(o.owedByCurrency, {
      'EUR': 5000,
    }, reason: 'a billed debt is not what I owe as a member');
    expect(o.outstanding.map((i) => i.id), ['m']);
    expect(o.payable.map((i) => i.id), ['m']);
    expect(o.billed.single.financialSubjectId, 'acme');
    expect(o.billed.single.billingOnly, isTrue);
  });

  test('two debtors of one seller and currency are two groups, each with its '
      'own open amount', () {
    final o = _read([
      _row('a1', subject: 'acme'),
      _row('a2', subject: 'acme', total: 2500, issued: '2026-11-05T09:00:00Z'),
      _row('p1', subject: 'personal', total: 4000),
      _row(
        'c1',
        subject: 'personal',
        total: -1500,
        issued: '2026-11-06T09:00:00Z',
      ),
    ]);
    final groups = o.billedGroups;
    expect(groups.map((g) => g.subjectId), ['acme', 'personal']);
    expect(groups[0].openByCurrency, {'EUR': 12500});
    expect(groups[1].openByCurrency, {
      'EUR': 2500,
    }, reason: 'its own credit only');
    expect(groups[0].invoices.map((i) => i.id), [
      'a2',
      'a1',
    ], reason: 'newest first');
  });

  test('one subject in two currencies is never summed across them', () {
    final o = _read([
      _row('e', subject: 's', total: 1000),
      _row('c', subject: 's', total: 900, currency: 'CHF'),
      _row('p', subject: 's', total: 700, state: 'paid'),
    ]);
    expect(o.billedGroups.single.openByCurrency, {'CHF': 900, 'EUR': 1000});
  });

  test('the same subject id in another business is another group', () {
    final o = _read([
      _row('x', subject: 's'),
      _row('y', subject: 's', workspace: 'w-2'),
    ]);
    expect(o.billedGroups, hasLength(2));
  });

  test('a reminder of a billed document never reaches my own reminders', () {
    final o = _read(
      [_row('m', subject: 'me', access: 'member'), _row('b', subject: 'acme')],
      [
        {
          'id': 'r1',
          'invoice_id': 'm',
          'invoice_number': 'N-m',
          'workspace_name': 'A',
          'sent_at': '2026-11-10T09:00:00Z',
          'level': 1,
          'automatic': true,
        },
        {
          'id': 'r2',
          'invoice_id': 'b',
          'invoice_number': 'N-b',
          'workspace_name': 'A',
          'sent_at': '2026-11-10T09:00:00Z',
          'level': 1,
          'automatic': true,
        },
      ],
    );
    expect(o.reminders.map((r) => r.id), ['r1']);
  });

  test(
    'an older host (v1) names no subject: its documents are mine, as before',
    () {
      final row = _row('m', subject: 'x')
        ..remove('financial_subject_id')
        ..remove('access');
      final o = _read([row]);
      expect(o.invoices.single.billingOnly, isFalse);
      expect(o.billed, isEmpty);
    },
  );

  test('merge, installation and filters carry the billed documents', () {
    final a = _read([_row('b', subject: 'acme')]).onInstallation('inst-1');
    final b = _read([_row('b', subject: 'acme', workspace: 'w-2')])
        .onInstallation('inst-2');
    final merged = a.merge(b).merge(a);
    expect(
      merged.billed,
      hasLength(2),
      reason: 'each document once, by its qualified id',
    );
    expect(merged.billed.map((i) => i.installationId).toSet(), {
      'inst-1',
      'inst-2',
    });
    expect(merged.inWorkspace('inst-1:w-1').billed, hasLength(1));
    expect(merged.where((i) => false).billed, isEmpty);
  });

  test('an activity row names its financial subject', () {
    final row = AccountActivity.fromJson({
      'id': 'p',
      'workspace_id': 'w',
      'workspace_name': 'A',
      'occurred_at': '2026-11-10T09:00:00Z',
      'currency': 'EUR',
      'status': 'confirmed',
      'financial_subject_id': 'acme',
    });
    expect(row.financialSubjectId, 'acme');
    expect(row.onInstallation('i').financialSubjectId, 'acme');
  });
}
