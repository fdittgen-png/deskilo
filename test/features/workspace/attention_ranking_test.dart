// SPDX-License-Identifier: 0BSD
//
// #1247 — the ranking is the design, so it is the thing to pin.
//
// `docs/ux/DECISION_SURFACE.md` ranks by what the DELAY COSTS, never by
// recency. That ordering is the whole argument of the surface: an
// administrator's entry point should be a list of decisions, and the
// order is what makes it a list rather than a pile.
//
// These run on pure Dart, so the order can be argued with in review
// without pumping a screen — and so a later screen cannot quietly
// reorder it.
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 9, 19, 12);

Attention _item(AttentionKind kind, {int daysWaiting = 0, int count = 1}) =>
    Attention(
      kind: kind,
      subject: kind.name,
      decision: 'decide',
      waitingSince: _now.subtract(Duration(days: daysWaiting)),
      count: count,
    );

void main() {
  test('money that leaves comes before a person waiting, and so on down',
      () {
    // Deliberately handed in backwards: if the sort did nothing, this
    // test would pass on the input order, which is the mistake worth
    // not making.
    final ranked = rankAttention([
      _item(AttentionKind.configuration),
      _item(AttentionKind.instance),
      _item(AttentionKind.month),
      _item(AttentionKind.person),
      _item(AttentionKind.money),
    ]);

    expect(
      ranked.map((a) => a.kind),
      [
        AttentionKind.money,
        AttentionKind.person,
        AttentionKind.month,
        AttentionKind.instance,
        AttentionKind.configuration,
      ],
      reason: 'by what the delay costs: cash, then somebody blocked on '
          'an answer, then a month that closes, then the instance, then '
          'configuration that is not doing what it says',
    );
  });

  test('within a rank the oldest is first', () {
    final ranked = rankAttention([
      _item(AttentionKind.person, daysWaiting: 0),
      _item(AttentionKind.person, daysWaiting: 3),
      _item(AttentionKind.person, daysWaiting: 1),
    ]);

    expect(
      ranked.map((a) => _now.difference(a.waitingSince).inDays),
      [3, 1, 0],
      reason: 'a request that has waited three days outranks one that '
          'arrived this morning — and "since when" is the only part of '
          'the ranking a reader can check for themselves',
    );
  });

  test('cost beats age: a reminder due today outranks a week-old '
      'configuration warning', () {
    final ranked = rankAttention([
      _item(AttentionKind.configuration, daysWaiting: 7),
      _item(AttentionKind.money, daysWaiting: 0),
    ]);

    expect(ranked.first.kind, AttentionKind.money,
        reason: 'never by recency — that is what the document says and '
            'it is the easy thing to get wrong');
  });

  test('the order is stable, so equal lines do not shuffle', () {
    final ranked = rankAttention([
      _item(AttentionKind.money, count: 1),
      _item(AttentionKind.money, count: 2),
      _item(AttentionKind.money, count: 3),
    ]);

    expect(ranked.map((a) => a.count), [1, 2, 3],
        reason: 'a list that reorders itself between builds is a list '
            'nobody can learn');
  });

  test('one line stands for its whole decision', () {
    // *issue for 7 members* is one decision and one line — not seven.
    final one = _item(AttentionKind.month, count: 7);
    expect(one.count, 7);
    expect(rankAttention([one]), hasLength(1));
  });

  test('nothing waiting is an answer, not an empty list', () {
    expect(nothingNeedsYou(const []), isTrue);
    expect(nothingNeedsYou([_item(AttentionKind.money)]), isFalse);
  });

  test('every kind the document lists has a rank', () {
    // The enum IS the ranking, so a signal added to the design without
    // a place in the order fails here rather than landing at the end by
    // accident.
    expect(AttentionKind.values, hasLength(5));
    expect(AttentionKind.values.first, AttentionKind.money);
    expect(AttentionKind.values.last, AttentionKind.configuration);
  });
}
