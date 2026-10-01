// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1848 — a read is complete whatever the server's row cap is. A server
// capped at 2 rows answers a 500-row page with 2: under "a short page is
// the end" the third reservation — the one that occupies the seat — was
// never read, and the seat drew as free. Now only an empty page ends the
// read, every row arrives exactly once, a second-page failure fails the
// read (never a shorter list), and the ceiling still stops a runaway.
import 'package:deskilo/core/data/paged_fetch.dart';
import 'package:flutter_test/flutter_test.dart';

/// A server holding [rows] in their (total) order, answering at most
/// [cap] rows per request, recording each request.
class _CappedServer {
  _CappedServer(this.rows, {this.cap = 2, this.failAtCall});
  final List<Map<String, dynamic>> rows;
  final int cap;
  final int? failAtCall;
  final requests = <(int, int)>[];

  Future<List<Map<String, dynamic>>> page(int from, int to) async {
    requests.add((from, to));
    if (failAtCall == requests.length) throw StateError('connection lost');
    final end = [
      to + 1,
      from + cap,
      rows.length,
    ].reduce((a, b) => a < b ? a : b);
    return from >= rows.length ? const [] : rows.sublist(from, end);
  }
}

List<Map<String, dynamic>> _reservations(int n) => [
  // Equal starts on purpose: the order is total only with the id.
  for (var i = 0; i < n; i++)
    {'id': 'r$i', 'starts_at': '2026-10-01T09:00:00Z'},
];

void main() {
  test(
    'cap 2, page 500, three overlapping reservations: all three, once',
    () async {
      final server = _CappedServer(_reservations(3));
      final rows = await fetchPages(table: 'reservations', page: server.page);
      expect([for (final r in rows) r['id']], ['r0', 'r1', 'r2']);
      expect(server.requests, [
        (0, 499),
        (2, 501),
        (3, 502),
      ], reason: 'each page starts after the rows actually returned');
    },
  );

  test('no rows: one request, an empty read', () async {
    final server = _CappedServer(const []);
    expect(await fetchPages(table: 't', page: server.page), isEmpty);
    expect(server.requests, hasLength(1));
  });

  test('a cap above the page size: full pages, then the empty end', () async {
    final server = _CappedServer(_reservations(4), cap: 1000);
    final rows = await fetchPages(table: 't', page: server.page, pageSize: 2);
    expect(rows, hasLength(4));
    expect(server.requests, [(0, 1), (2, 3), (4, 5)]);
  });

  test(
    'a failure on a later page fails the read, never a shorter list',
    () async {
      final server = _CappedServer(_reservations(3), failAtCall: 2);
      await expectLater(
        fetchPages(table: 't', page: server.page),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('the ceiling stops a read that never ends', () async {
    final server = _CappedServer(_reservations(10));
    await expectLater(
      fetchPages(table: 'reservations', page: server.page, maxRows: 4),
      throwsA(isA<ExportTooLargeException>()),
    );
  });
}
