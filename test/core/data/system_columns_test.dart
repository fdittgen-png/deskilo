// SPDX-License-Identifier: 0BSD
//
// #992 — the six system columns as one value: read tolerantly, equal by
// value, never written by the client, and a breach of the server's
// invariant reported rather than trusted.
import 'package:deskilo/core/data/system_columns.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const row = {
    'id': 'r1',
    'workspace_id': 'w1',
    'created_datetime': '2026-09-06T10:00:00+00:00',
    'modified_datetime': '2026-09-07T08:30:00+00:00',
    'company_id': 'w1',
    'site_id': 's1',
    'created_by_user': 'u1',
    'modified_by_user': 'u2',
  };

  test('fromRow reads the six, in UTC, and stays a value', () {
    final a = SystemColumns.fromRow(row);
    final b = SystemColumns.fromRow(row);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.createdAt, DateTime.utc(2026, 9, 6, 10));
    expect(a.modifiedAt, DateTime.utc(2026, 9, 7, 8, 30));
    expect(a.companyId, 'w1');
    expect(a.siteId, 's1');
    expect(a.createdByUser, 'u1');
    expect(a.modifiedByUser, 'u2');
    expect(a.isStamped, isTrue);
    expect(a.isConsistent, isTrue);
    expect(a.belongsTo('w1'), isTrue);
    expect(a.belongsTo('w2'), isFalse);
  });

  test('a row without the columns is the null object, never a crash', () {
    final none = SystemColumns.fromRow(const {'id': 'x', 'name': 'y'});
    expect(none, SystemColumns.none);
    expect(none.isStamped, isFalse);
    expect(none.belongsTo('anything'), isTrue);
    final garbage = SystemColumns.fromRow(const {
      'created_datetime': 42,
      'company_id': ['not', 'a', 'string'],
    });
    expect(garbage.createdAt, isNull);
    expect(garbage.companyId, '');
  });

  test('a breach of the invariant is reported through the observer', () {
    final reports = <String>[];
    SystemColumns.onBreach = reports.add;
    addTearDown(() => SystemColumns.onBreach = null);
    final broken = SystemColumns.fromRow(const {
      'id': 'r9',
      'workspace_id': 'w1',
      'created_datetime': '2026-09-07T08:30:00Z',
      'modified_datetime': '2026-09-06T10:00:00Z',
    });
    expect(broken.isConsistent, isFalse);
    expect(reports, hasLength(1));
    expect(reports.single, contains('r9'));
  });

  test('strip removes the six from an outgoing payload and nothing else', () {
    final out = SystemColumns.strip({
      'label': 'Standard',
      'percent': 20,
      'created_datetime': 'forged',
      'company_id': 'forged',
      'modified_by_user': 'forged',
    });
    expect(out, {'label': 'Standard', 'percent': 20});
    expect(SystemColumns.keys, hasLength(6));
  });

  test('entities mapped from rows carry the stamp and default to none', () {
    final rate = VatRate.fromRow({...row, 'label': 'S', 'percent': 20});
    expect(rate.system.createdByUser, 'u1');
    expect(rate, isA<SystemStamped>());
    expect(const VatRate(label: 'x', percent: 1).system, SystemColumns.none);
    final site = Site.fromRow({...row, 'name': 'HQ'});
    expect(site.system.siteId, 's1');
  });
}
