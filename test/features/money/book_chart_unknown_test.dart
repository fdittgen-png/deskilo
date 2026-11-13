// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3884 -- the book chart read with one account or one role mapping of a
// kind this build does not know: the other rows are kept, the row is left
// out (never read as a known type or role), and the count is said.
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _account(String id, String type, {String origin = 'manual'}) => {
      'id': id,
      'workspace_id': 'ws',
      'issuer_site_id': 's1',
      'code': id,
      'name': 'Account $id',
      'account_type': type,
      'is_posting': true,
      'origin': origin,
      'revision': 1,
    };

Map<String, Object?> _mapping(String id, String role) => {
      'id': id,
      'workspace_id': 'ws',
      'issuer_site_id': 's1',
      'role': role,
      'account_id': 'a1',
      'effective_from': '2026-01-01',
      'revision': 1,
    };

void main() {
  test('three mappings, one with a future role: two are read, one is unreadable', () {
    final chart = bookChartFromJson({
      'accounts': [_account('a1', 'asset')],
      'mappings': [
        _mapping('m1', 'bank'),
        _mapping('m2', 'future_role'),
        _mapping('m3', 'revenue:standard'),
      ],
    });
    expect(chart.mappings.map((m) => m.id), ['m1', 'm3']);
    expect(chart.mappings.last.qualifier, 'standard');
    expect(chart.unreadable, ['m2']);
  });

  test('an unknown role with a qualifier is unknown too, not read as its base', () {
    final chart = bookChartFromJson({
      'accounts': const [],
      'mappings': [_mapping('m1', 'future_role:x')],
    });
    expect(chart.mappings, isEmpty);
    expect(chart.unreadable, ['m1']);
  });

  test('an account of a future type or origin is left out, the others stay', () {
    final chart = bookChartFromJson({
      'accounts': [
        _account('a1', 'asset'),
        _account('a2', 'future_type'),
        _account('a3', 'income', origin: 'future_origin'),
        _account('a4', 'expense'),
      ],
      'mappings': const [],
    });
    expect(chart.accounts.map((a) => (a.id, a.type)), [
      ('a1', AccountType.asset),
      ('a4', AccountType.expense),
    ]);
    expect(chart.unreadable, ['a2', 'a3']);
  });

  test('a known chart has nothing unreadable', () {
    final chart = bookChartFromJson({
      'accounts': [_account('a1', 'asset')],
      'mappings': [_mapping('m1', 'bank')],
    });
    expect(chart.unreadable, isEmpty);
    expect(chart.accounts, hasLength(1));
    expect(chart.mappings, hasLength(1));
  });
}
