// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — the months a dated change counts for: a change counts from the
// first month whose first day is on or after its date, and a pause frees the
// months whose first day it covers; nothing is prorated.
import 'package:deskilo/features/workspace/domain/member_term_change.dart';
import 'package:flutter_test/flutter_test.dart';

MemberTermChange _status(
  String id,
  String to,
  DateTime on, {
  MemberTermState state = MemberTermState.applied,
  MemberTermSource source = MemberTermSource.immediate,
  String? group,
}) => MemberTermChange(
  id: id,
  memberId: 'm',
  kind: MemberTermKind.status,
  toStatus: to,
  dueOn: on,
  effectiveOn: state == MemberTermState.applied ? on : null,
  state: state,
  source: source,
  groupId: group,
);

void main() {
  test('a change dated on a first counts from that month, else the next', () {
    expect(firstPeriodOf(DateTime(2027, 3)), DateTime(2027, 3));
    expect(firstPeriodOf(DateTime(2027, 3, 15)), DateTime(2027, 4));
    expect(firstPeriodOf(DateTime(2027, 12, 2)), DateTime(2028));
  });

  test('a pause frees the months whose first day it covers', () {
    expect(freeMonthsOfPause(DateTime(2027, 3, 15), DateTime(2027, 6)), [
      DateTime(2027, 4),
      DateTime(2027, 5),
    ]);
    // ending on a first: that month is charged
    expect(freeMonthsOfPause(DateTime(2027, 3), DateTime(2027, 4)), [
      DateTime(2027, 3),
    ]);
    // inside one month: nothing is free
    expect(
      freeMonthsOfPause(DateTime(2027, 3, 2), DateTime(2027, 3, 20)),
      <DateTime>[],
    );
    // open: the first free month
    expect(freeMonthsOfPause(DateTime(2027, 3, 15), null), [DateTime(2027, 4)]);
  });

  test('a pause and its end are one entry; the next is the first to come', () {
    final all = [
      _status(
        'start',
        'paused',
        DateTime(2027, 3, 15),
        state: MemberTermState.scheduled,
        source: MemberTermSource.scheduled,
        group: 'g',
      ),
      _status(
        'end',
        'active',
        DateTime(2027, 5),
        state: MemberTermState.scheduled,
        source: MemberTermSource.scheduled,
        group: 'g',
      ),
      _status('now', 'paused', DateTime(2027, 1, 5)),
    ];
    final entries = memberTermEntries('m', all);
    expect(entries.map((e) => e.change.id), ['start']);
    expect(entries.single.until?.id, 'end');
    expect(nextTermEntry('m', all)?.nextOn, DateTime(2027, 3, 15));
    expect(nextTermEntry('other', all), isNull);
  });

  test('a pause is dated by its last recorded start, never by the day '
      'dated terms began', () {
    expect(
      pausedSince('m', [
        _status(
          'b',
          'paused',
          DateTime(2026, 11, 13),
          source: MemberTermSource.baseline,
        ),
      ]),
      isNull,
    );
    expect(
      pausedSince('m', [
        _status('p', 'paused', DateTime(2027, 1, 5)),
        _status('a', 'active', DateTime(2027, 2)),
      ]),
      isNull,
    );
    expect(
      pausedSince('m', [
        _status('a', 'active', DateTime(2027, 2)),
        _status('p', 'paused', DateTime(2027, 3)),
      ]),
      DateTime(2027, 3),
    );
  });
}
