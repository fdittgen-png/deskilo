// SPDX-License-Identifier: AGPL-3.0-or-later
// #3884 -- a posting with a role, kind or journal this build does not know
// is not guessed and does not fail the answer: the postings the build
// understands are returned, and ONE blocker per unreadable entry stops
// every export and closing, so a total is never shown as complete without it.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:test/test.dart';

Map<String, Object?> _posting(
  String id, {
  String role = 'customers',
  String kind = 'invoice',
  String journal = 'sales',
}) => {
  'journal': journal,
  'kind': kind,
  'date': '2026-05-25',
  'document_id': id,
  'document_number': 'N-$id',
  'currency': 'EUR',
  'lines': [
    {
      'role': role,
      'qualifier': null,
      'account_code': '411',
      'debit_cents': 100,
      'credit_cents': 0,
    },
    {
      'role': 'revenue',
      'qualifier': null,
      'account_code': '706',
      'debit_cents': 0,
      'credit_cents': 100,
    },
  ],
};

PostingSet _set(
  List<Map<String, Object?>> postings, [
  List<Object?> blockers = const [],
]) => PostingSet.fromJson({'postings': postings, 'blockers': blockers});

void main() {
  test(
    'three entries, one with a future role: two are read, one unreadable blocker',
    () {
      final set = _set([
        _posting('a'),
        _posting('b', role: 'future_role'),
        _posting('c'),
      ]);
      expect(set.postings.map((p) => p.documentId), ['a', 'c']);
      expect(set.blockers.map((b) => (b.block, b.subject)), [
        (PostingBlock.unreadable, 'b'),
      ]);
      expect(set.unreadable, 1);
    },
  );

  test('an unknown kind or journal is the same, each entry counted once', () {
    final set = _set([
      _posting('a', kind: 'future_kind'),
      _posting('b', journal: 'future_journal'),
      _posting('c', role: 'future_role', kind: 'future_kind'),
      _posting('d'),
    ]);
    expect(set.postings.single.documentId, 'd');
    expect(set.unreadable, 3);
  });

  test('an unknown blocker of the server still blocks, and is unreadable', () {
    final set = _set(
      [_posting('a')],
      [
        {'block': 'future_block', 'subject': 'x'},
        {'block': 'unmappedRole', 'subject': 'fees'},
      ],
    );
    expect(set.postings, hasLength(1));
    expect(set.blockers.map((b) => b.block), [
      PostingBlock.unreadable,
      PostingBlock.unmappedRole,
    ]);
    expect(set.unreadable, 1);
  });

  test('a malformed entry is still a shape error, not an unknown value', () {
    final bad = _posting('a')..remove('document_number');
    expect(() => _set([bad]), throwsA(isA<JsonShapeException>()));
  });

  test('a known answer has no unreadable entry', () {
    final set = _set([_posting('a')]);
    expect(set.unreadable, 0);
    expect(set.blockers, isEmpty);
  });

  test('a book role reads by wire, null when unknown', () {
    expect(BookRole.tryFromWire('bank'), BookRole.bank);
    expect(BookRole.tryFromWire('future_role'), isNull);
    expect(BookRole.tryFromWire(null), isNull);
  });
}
