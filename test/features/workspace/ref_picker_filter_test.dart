// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: the reference picker's filter narrows by what a person knows —
// status, person, month, amount — each choice ANDed across facets and ORed
// within one, the counts beside a chip are what tapping it would leave, the
// amount compares by magnitude (a credit note is found like an invoice), and
// the order is stable.
import 'package:deskilo/features/workspace/presentation/widgets/ref_picker_filter.dart';
import 'package:flutter_test/flutter_test.dart';

class _C implements RefFilterable {
  _C(this.id, this.status, this.person, this.month, this.cents, this.at)
      : keywords = '$id $person'.toLowerCase();
  final String id;
  final String status;
  final String person;
  final String month;
  final int cents;
  @override
  final DateTime at;
  @override
  final String keywords;
  @override
  int? get amountCents => cents;
  @override
  Map<String, RefFacetValue> get facets => {
        'status': (id: status, label: status),
        'person': (id: person, label: person),
        'month': (id: month, label: month),
      };
}

const _status = RefFacet(key: 'status', label: 'Status', quick: true);
const _person = RefFacet(key: 'person', label: 'Person');
const _month = RefFacet(key: 'month', label: 'Month');

final _all = [
  _C('i1', 'open', 'ana', '2026-09', 12000, DateTime(2026, 9, 3)),
  _C('i2', 'open', 'ben', '2026-10', 5000, DateTime(2026, 10, 2)),
  _C('i3', 'paid', 'ana', '2026-10', 9000, DateTime(2026, 10, 5)),
  _C('i4', 'paid', 'ben', '2026-09', -3000, DateTime(2026, 9, 20)), // credit note
  _C('i5', 'open', 'ana', '2026-10', 20000, DateTime(2026, 10, 9)),
];

List<String> _ids(RefFilter f) => [for (final c in applyRefFilter(_all, f)) c.id];

void main() {
  test('no filter keeps everything, newest first', () {
    expect(_ids(const RefFilter()), ['i5', 'i3', 'i2', 'i4', 'i1']);
  });

  test('a facet narrows; values inside one facet are ORed', () {
    final open = const RefFilter().toggled(_status, 'open');
    expect(_ids(open), ['i5', 'i2', 'i1']);
    final both = open.toggled(_status, 'paid');
    expect(_ids(both), ['i5', 'i3', 'i2', 'i4', 'i1']);
  });

  test('facets are ANDed: open AND ana', () {
    final f = const RefFilter().toggled(_status, 'open').toggled(_person, 'ana');
    expect(_ids(f), ['i5', 'i1']);
  });

  test('search words all have to match, in any order', () {
    expect(_ids(const RefFilter(query: 'ana i3')), ['i3']);
    expect(_ids(const RefFilter(query: 'zzz')), isEmpty);
  });

  test('the amount compares by magnitude, so a credit note is in range', () {
    const f = RefFilter(minCents: 2500, maxCents: 6000);
    expect(_ids(f), ['i2', 'i4']);
    expect(const RefFilter().copyWith(minCents: 1).copyWith(clearAmount: true).hasAmount,
        isFalse);
  });

  test('sorting by amount ignores the sign and is stable', () {
    expect(_ids(const RefFilter(sort: RefSort.amountHigh)),
        ['i5', 'i1', 'i3', 'i2', 'i4']);
    expect(_ids(const RefFilter(sort: RefSort.amountLow)),
        ['i4', 'i2', 'i3', 'i1', 'i5']);
    expect(_ids(const RefFilter(sort: RefSort.oldest)),
        ['i1', 'i4', 'i2', 'i3', 'i5']);
  });

  test('a single-choice facet replaces its value', () {
    const one = RefFacet(key: 'status', label: 'Status', multi: false);
    final f = const RefFilter().toggled(one, 'open').toggled(one, 'paid');
    expect(f.selected['status'], {'paid'});
  });

  test('the count beside a value is what choosing it would leave', () {
    // With ana chosen, "open" would leave i1 and i5 — not all three.
    final f = const RefFilter().toggled(_person, 'ana');
    final status = refFacetOptions(_all, f, 'status');
    expect({for (final o in status) o.value.id: o.count}, {'open': 2, 'paid': 1});
    // The facet's own choice does not narrow its own counts.
    final withOpen = f.toggled(_status, 'open');
    final again = refFacetOptions(_all, withOpen, 'status');
    expect({for (final o in again) o.value.id: o.count}, {'open': 2, 'paid': 1});
  });

  test('a chosen value that leaves nothing stays listed so it can be unticked',
      () {
    final f = const RefFilter()
        .toggled(_month, '2026-09')
        .toggled(_person, 'ana')
        .toggled(_status, 'paid');
    expect(_ids(f), isEmpty);
    final months = refFacetOptions(_all, f, 'month');
    expect(months.map((o) => o.value.id), contains('2026-09'));
  });

  test('active count and emptiness', () {
    expect(const RefFilter().isEmpty, isTrue);
    final f = const RefFilter(query: 'x').toggled(_status, 'open');
    expect(f.activeCount, 1);
    expect(f.isEmpty, isFalse);
    expect(f.cleared('status').activeCount, 0);
  });

  test('amount bounds are by magnitude', () {
    final b = refAmountBounds(_all)!;
    expect((b.min, b.max), (3000, 20000));
  });
}
