// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2587 — invariant: a paged read is a bounded TRAVERSAL and never claims a
// snapshot. Closing-count and unique-id agreement detect some instability but
// can agree over a result that omits a live row and holds a deleted one; a
// snapshot exists only as one server response that names its revision.
import 'package:deskilo/core/data/paged_fetch.dart';
import 'package:deskilo/core/data/read_provenance.dart';
import 'package:deskilo/features/money/data/invoice_reminder_fold.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> row(int id, [Object? v]) => {'id': id, 'v': v ?? 0};

void main() {
  test('the counterexample: count 6 and six unique ids, yet 4 is missing and '
      'the deleted 1 is present - still not a snapshot', () async {
    var current = [for (var i = 1; i <= 6; i++) row(i)];
    var calls = 0;
    final read = await fetchPagesRead(
      table: 't',
      pageSize: 3,
      page: (from, to) async {
        calls++;
        final out = current.skip(from).take(to - from + 1).toList();
        if (calls == 1) {
          // delete 1, insert 7 right after the first page was served
          current = [for (var i = 2; i <= 7; i++) row(i)];
        }
        return out;
      },
      count: () async => current.length,
    );
    final ids = [for (final r in read.rows) r['id']];
    expect(ids, [1, 2, 3, 5, 6, 7]);
    expect(ids.toSet(), hasLength(6));
    expect(ids, isNot(contains(4)), reason: 'a live row was omitted');
    expect(read.provenance.completeness, ReadCompleteness.boundedTraversal);
    expect(read.provenance.isSnapshot, isFalse);
  });

  test('repeated count stability and unchanged ids never become a snapshot',
      () async {
    final data = [for (var i = 1; i <= 5; i++) row(i)];
    final read = await fetchPagesRead(
      table: 't',
      pageSize: 2,
      page: (from, to) async => data.skip(from).take(to - from + 1).toList(),
      count: () async => 5,
    );
    expect(read.provenance.completeness, ReadCompleteness.boundedTraversal);
    expect(read.provenance.reason, contains('not a snapshot'));
  });

  test('same ids with changed amounts between pages are still a traversal',
      () async {
    var version = 0;
    final read = await fetchPagesRead(
      table: 't',
      pageSize: 2,
      page: (from, to) async {
        final out = [
          for (var i = from + 1; i <= 4 && i <= to + 1; i++) row(i, version),
        ];
        version++;
        return out;
      },
      count: () async => 4,
    );
    expect({for (final r in read.rows) r['v']}, hasLength(greaterThan(1)));
    expect(read.provenance.isSnapshot, isFalse);
  });

  test('a repeated id (an insert shifted a page) is detected and refused',
      () async {
    var calls = 0;
    await expectLater(
      fetchPagesRead(
        table: 't',
        pageSize: 2,
        attempts: 2,
        page: (from, to) async {
          calls++;
          // every read returns the id 1 twice
          return from == 0 ? [row(1), row(2)] : (from == 2 ? [row(1)] : []);
        },
        count: () async => 3,
      ),
      throwsA(isA<IncompleteReadException>()),
    );
    expect(calls, 6, reason: 'two attempts of three requests, then refused');
  });

  test('a page size above the server cap still reads every row once', () async {
    final data = [for (var i = 1; i <= 7; i++) row(i)];
    final read = await fetchPagesRead(
      table: 't',
      
      page: (from, to) async => data.skip(from).take(2).toList(),
    );
    expect([for (final r in read.rows) r['id']], [1, 2, 3, 4, 5, 6, 7]);
    expect(read.provenance.completeness, ReadCompleteness.boundedTraversal);
  });

  test('zero rows: one empty traversal; a runaway stops with the limit error',
      () async {
    final empty = await fetchPagesRead(table: 't', page: (f, t) async => []);
    expect(empty.rows, isEmpty);
    await expectLater(
      fetchPagesRead(
        table: 't',
        pageSize: 2,
        maxRows: 5,
        page: (from, to) async => [row(from), row(from + 1)],
      ),
      throwsA(isA<ExportTooLargeException>()),
    );
  });

  test('a failing page fails the read, never a shorter list', () async {
    await expectLater(
      fetchPagesRead(
        table: 't',
        pageSize: 2,
        page: (from, to) async =>
            from == 0 ? [row(1), row(2)] : throw StateError('lost'),
      ),
      throwsStateError,
    );
  });

  test('only a named server revision makes a snapshot; targets differ', () {
    expect(
      () => ReadProvenance.snapshot(
          sourceRevision: '', target: 'W-A', principal: 'p', queryFingerprint: 'q'),
      throwsArgumentError,
    );
    final a = ReadProvenance.snapshot(
        sourceRevision: '2026-10-15T10:00:00Z',
        target: 'W-A',
        principal: 'p1',
        queryFingerprint: 'q');
    final b = ReadProvenance.snapshot(
        sourceRevision: '2026-10-15T10:00:00Z',
        target: 'W-B',
        principal: 'p1',
        queryFingerprint: 'q');
    expect(a.isSnapshot, isTrue);
    expect(a.target, isNot(b.target));
    const stopped = ReadProvenance.incomplete(reason: 'cap');
    expect(stopped.completeness, ReadCompleteness.incomplete);
  });

  test('1,501 reminder rows under a cap of 100: the true count and latest',
      () async {
    final rows = [
      for (var i = 0; i < 1501; i++)
        {
          'id': i,
          'invoice_id': i < 1400 ? 'inv-a' : 'inv-b',
          'sent_at': DateTime.utc(2026).add(Duration(days: i)).toIso8601String(),
        },
    ];
    final read = await fetchPagesRead(
      table: 'invoice_reminders',
      
      page: (from, to) async => rows.skip(from).take(100).toList(),
    );
    final folded = foldInvoiceReminders(read.rows);
    expect(folded['inv-a']!.count, 1400);
    expect(folded['inv-b']!.count, 101);
    expect(folded['inv-b']!.last,
        DateTime.utc(2026).add(const Duration(days: 1500)).toLocal());
    // a single capped request would have reported 100 and the wrong date
    expect(foldInvoiceReminders(rows.take(100).toList())['inv-a']!.count, 100);
  });
}
