// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — the months a dated change counts for, the server's rule: a change
// counts from the first month whose first day is on or after its date and
// that is not yet invoiced; a pause leaves the month it starts in and every
// invoiced month charged in full, and frees the months whose first day it
// covers; nothing is prorated.
import 'package:deskilo/features/workspace/domain/member_term_change.dart';
import 'package:flutter_test/flutter_test.dart';

MemberTermChange _status(
  String id,
  String to,
  DateTime on, {
  MemberTermState state = MemberTermState.applied,
  bool scheduled = false,
  String? group,
}) => MemberTermChange(
  id: id,
  memberId: 'm',
  kind: MemberTermKind.status,
  toStatus: to,
  dueOn: on,
  state: state,
  scheduled: scheduled,
  groupId: group,
);

void main() {
  test('a change dated on a first counts from that month, else the next, '
      'past the invoiced months', () {
    expect(firstPeriodOf(DateTime(2027, 3)), DateTime(2027, 3));
    expect(firstPeriodOf(DateTime(2027, 3, 15)), DateTime(2027, 4));
    expect(firstPeriodOf(DateTime(2027, 12, 2)), DateTime(2028));
    expect(
      firstPeriodOf(DateTime(2027, 3, 15), invoiced: {DateTime(2027, 4)}),
      DateTime(2027, 5),
    );
  });

  test('a pause from the 15th charges that month and frees the next', () {
    final money = pauseMoneyOf(DateTime(2027, 3, 15), DateTime(2027, 6));
    expect(money.charged, [DateTime(2027, 3)]);
    expect(money.free, [DateTime(2027, 4), DateTime(2027, 5)]);
  });

  test('a pause ending on a first charges that month', () {
    final money = pauseMoneyOf(DateTime(2027, 3), DateTime(2027, 4));
    expect(money.charged, isEmpty);
    expect(money.free, [DateTime(2027, 3)]);
  });

  test('a pause inside one month frees nothing', () {
    final money = pauseMoneyOf(DateTime(2027, 3, 2), DateTime(2027, 3, 20));
    expect(money.charged, [DateTime(2027, 3)]);
    expect(money.free, isEmpty);
  });

  test('an invoiced month stays charged; an open pause names its first '
      'free month', () {
    final money = pauseMoneyOf(
      DateTime(2027, 3),
      null,
      invoiced: {DateTime(2027, 3)},
    );
    expect(money.charged, [DateTime(2027, 3)]);
    expect(money.free, [DateTime(2027, 4)]);
  });

  test('a pause and its end are one entry; the next is the first to come', () {
    final all = [
      _status(
        'start',
        'paused',
        DateTime(2027, 3, 15),
        state: MemberTermState.scheduled,
        scheduled: true,
        group: 'g',
      ),
      _status(
        'end',
        'active',
        DateTime(2027, 5),
        state: MemberTermState.scheduled,
        scheduled: true,
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

  test('a share written at once that waits for its month is listed', () {
    final waiting = MemberTermChange(
      id: 'w',
      memberId: 'm',
      kind: MemberTermKind.share,
      toPct: 50,
      dueOn: DateTime(2027, 4),
      state: MemberTermState.scheduled,
      scheduled: false,
    );
    expect(memberTermEntries('m', [waiting]).single.change.id, 'w');
  });

  test('a pause is dated by the last status change in force', () {
    expect(pausedSince('m', const []), isNull);
    expect(
      pausedSince('m', [
        MemberTermChange(
          id: 'c',
          memberId: 'm',
          kind: MemberTermKind.status,
          toStatus: 'paused',
          dueOn: DateTime(2026, 11),
          state: MemberTermState.applied,
          scheduled: false,
          carried: true,
        ),
      ]),
      isNull,
      reason: 'a pause carried from before dated terms has no day it began',
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
