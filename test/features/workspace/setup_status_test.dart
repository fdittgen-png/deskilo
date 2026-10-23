// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 (ADR 0047 §4–§6) — the setup status groups its steps the way the
// guide shows them: the next milestone's open steps first, the one next
// action among them, then what waits, what a later milestone needs, what
// is optional, set aside or done.
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _step(
  String step,
  String milestone,
  String state, {
  bool required = true,
  List<String> blockedBy = const [],
}) => {
  'step': step,
  'milestone': milestone,
  'required': required,
  'state': state,
  'route': '/$step',
  'blocked_by': blockedBy,
  'estimate_minutes': 3,
};

final status = SetupStatus.fromJson({
  'steps': [
    _step('basics', 'bookable', 'ready'),
    _step('places', 'bookable', 'needs_configuration'),
    _step('first_booking', 'live', 'blocked', blockedBy: ['places']),
    _step('member_rights', 'bookable', 'needs_configuration'),
    _step('pricing', 'money', 'needs_configuration'),
    _step('online_payments', 'money', 'needs_operator'),
    _step('services', 'money', 'needs_configuration', required: false),
    _step('recovery', 'live', 'deferred', required: false),
    _step('vat', 'invoice', 'not_applicable'),
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 3,
      'ready': 1,
      'reached': false,
    },
    {
      'milestone': 'money',
      'applies': true,
      'required': 5,
      'ready': 1,
      'reached': false,
    },
    {
      'milestone': 'invoice',
      'applies': false,
      'required': 0,
      'ready': 0,
      'reached': true,
    },
    {
      'milestone': 'live',
      'applies': true,
      'required': 6,
      'ready': 1,
      'reached': false,
    },
  ],
});

List<String> _ids(List<SetupStepStatus> steps) => [
  for (final s in steps) s.step,
];

void main() {
  test('the next milestone is the first chosen and not reached', () {
    expect(status.nextMilestone?.milestone, 'bookable');
  });

  test('the next action is the first open step of the next milestone', () {
    expect(status.nextStep?.step, 'places');
    expect(_ids(status.toDo), ['places', 'member_rights']);
  });

  test('the other groups', () {
    expect(_ids(status.waiting), ['first_booking', 'online_payments']);
    expect(_ids(status.later), ['pricing']);
    expect(_ids(status.optional), ['services']);
    expect(_ids(status.deferred), ['recovery']);
    expect(_ids(status.done), ['basics']);
  });

  test('a step whose feature is off is outside the plan: no group lists '
      'it, it waits under Add more', () {
    expect(_ids(status.addable), ['vat']);
    for (final group in [
      status.toDo,
      status.waiting,
      status.later,
      status.optional,
      status.deferred,
      status.done,
    ]) {
      expect(_ids(group), isNot(contains('vat')));
    }
  });

  test('a time is a range: the estimate to twice it, summed for the '
      'next milestone', () {
    expect(status.steps.first.estimate, (low: 3, high: 6));
    // places and member_rights, 3 min each.
    expect(status.toNextMilestone, (low: 6, high: 12));
  });

  test('a step the instance observed says its observed range; the others '
      'keep the catalogue rule, and the milestone sums them end to end', () {
    final observed = status.withObserved({'places': (low: 4, high: 7)});
    final places = observed.steps.singleWhere((s) => s.step == 'places');
    final rights = observed.steps.singleWhere(
      (s) => s.step == 'member_rights',
    );
    expect(places.estimate, (low: 4, high: 7));
    expect(places.estimateMinutes, 3, reason: 'the catalogue figure stays');
    expect(rights.estimate, (low: 3, high: 6));
    expect(observed.toNextMilestone, (low: 7, high: 13));
    expect(_ids(observed.toDo), _ids(status.toDo), reason: 'nothing moved');
  });

  test('a route that is not in the app is never followed', () {
    final s = SetupStatus.fromJson({
      'steps': [
        {
          'step': 'x',
          'milestone': 'live',
          'state': 'ready',
          'route': 'https://evil',
        },
      ],
    });
    expect(s.steps.single.route, '/workspace-settings');
  });

  test('every chosen milestone reached: nothing is next', () {
    final s = SetupStatus.fromJson({
      'steps': [_step('basics', 'bookable', 'ready')],
      'milestones': [
        {
          'milestone': 'bookable',
          'applies': true,
          'required': 1,
          'ready': 1,
          'reached': true,
        },
      ],
    });
    expect(s.nextMilestone, isNull);
    expect(s.nextStep, isNull);
  });
}
