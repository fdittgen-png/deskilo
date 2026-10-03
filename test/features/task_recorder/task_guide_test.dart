// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — a recording becomes a draft guide that expects success without
// claiming it (an observed refusal is dropped, every command gets a
// recovery step); the guide codec refuses hostile, oversized, newer,
// cyclic-by-nesting and inconsistent guides and keeps an unknown action
// readable but not runnable; and the runner advances only on real
// events: a tap is not a booking, a refusal goes through recovery and
// back, a lost answer is uncertain, skipped is never done, and late or
// foreign events change nothing.
import 'dart:convert';

import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/guide/guide_codec.dart';
import 'package:deskilo/features/task_recorder/guide/guide_compiler.dart';
import 'package:deskilo/features/task_recorder/guide/guide_runner.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

void main() {
  late TaskGuide planGuide;
  setUp(() async {
    planGuide = compileGuide(
      (await recordFixture(BookingJourney.planConfirmed)).recording,
    );
  });

  group('compiler', () {
    test(
      'actions become steps; the command expects success, with recovery',
      () {
        final kinds = planGuide.steps.map((s) => s.action).toList();
        expect(kinds, [
          RecorderActions.openReserve,
          RecorderActions.selectDate,
          RecorderActions.selectPeriod,
          RecorderActions.selectResource,
          RecorderActions.changeBookingField,
          RecorderActions.confirmBooking,
          RecorderActions.viewDetails,
          RecorderActions.back,
        ]);
        final confirm = planGuide.steps[5];
        expect(confirm.expectedOutcomes, {
          RecorderOutcomes.bookingConfirmed,
          RecorderOutcomes.bookingRequested,
          RecorderOutcomes.seriesBooked,
        });
        expect(confirm.recovery.single.kind, GuideStepKind.instruction);
        expect(planGuide.sourceDigest, matches(RegExp(r'^[0-9a-f]{64}$')));
      },
    );

    test('an observed refusal is not turned into proof of anything', () async {
      final g = compileGuide(
        (await recordFixture(BookingJourney.listRefused)).recording,
      );
      final text = encodeGuideText(g);
      expect(text, isNot(contains('booking.refused')));
      expect(
        g.steps.last.expectedOutcomes,
        contains(RecorderOutcomes.bookingConfirmed),
        reason: 'the expectation is the author\'s, not the observation',
      );
    });

    test('a note is an editable instruction; no canary anywhere', () async {
      final g = compileGuide(
        (await recordFixture(BookingJourney.cancelledReview)).recording,
      );
      expect(g.steps.last.kind, GuideStepKind.instruction);
      expect(g.steps.last.text, 'I only wanted to look.');
      for (final c in [...privateCanaries, ...canaryFragments]) {
        expect(encodeGuideText(g).contains(c), isFalse, reason: c);
      }
    });
  });

  group('codec', () {
    Map<String, Object?> json() =>
        (jsonDecode(encodeGuideText(planGuide)) as Map).cast<String, Object?>();
    List<Map<String, Object?>> steps(Map<String, Object?> j) =>
        (j['steps']! as List).cast<Map<String, Object?>>();
    GuideIssueCode? refused(Object j) =>
        decodeGuideText(jsonEncode(j)).issues.firstOrNull?.code;

    test('round trip', () {
      final back = decodeGuideText(encodeGuideText(planGuide));
      expect(back.runnable, isTrue);
      expect(encodeGuideText(back.guide!), encodeGuideText(planGuide));
    });

    test('hostile guides are refused', () {
      expect(
        refused(json()..['schema_version'] = 9),
        GuideIssueCode.unsupportedSchema,
      );
      expect(
        refused(json()..['script'] = 'alert(1)'),
        GuideIssueCode.unknownKey,
      );
      final rpc = json();
      steps(rpc)[0]['rpc'] = 'delete_workspace';
      expect(refused(rpc), GuideIssueCode.unknownKey);
      final dup = json();
      steps(dup)[1]['id'] = 'g1';
      expect(refused(dup), GuideIssueCode.duplicateId);
      final nested = json();
      final recovery = (steps(nested)[5]['recovery']! as List)
          .cast<Map<String, Object?>>();
      recovery[0]
        ..['kind'] = 'perform'
        ..['action'] = RecorderActions.confirmBooking
        ..['expected_outcomes'] = [RecorderOutcomes.bookingConfirmed]
        ..['recovery'] = [
          {'id': 'g6r2', 'kind': 'instruction'},
        ];
      expect(
        refused(nested),
        GuideIssueCode.inconsistent,
        reason: 'no recovery inside recovery: no depth, no cycle',
      );
      final claim = json();
      steps(claim)[0]['expected_outcomes'] = [
        RecorderOutcomes.bookingConfirmed,
      ];
      expect(refused(claim), GuideIssueCode.inconsistent);
      final long = json();
      steps(long)[0]['text'] = 'x' * 600;
      expect(refused(long), GuideIssueCode.tooLong);
      expect(
        decodeGuideText(
          encodeGuideText(planGuide),
          limits: const GuideLimits(maxSteps: 3),
        ).issues.first.code,
        GuideIssueCode.tooMany,
      );
    });

    test('an unknown action keeps the words, not the semantics', () {
      final j = json();
      steps(j)[0]['action'] = 'payments.pay_everything';
      final r = decodeGuideText(jsonEncode(j));
      expect(r.accepted, isTrue);
      expect(r.runnable, isFalse);
      expect(r.guide!.steps[0].kind, GuideStepKind.manual);
    });
  });

  group('runner', () {
    late GuideRun run;
    setUp(() => run = GuideRun(planGuide));

    void doPlainSteps() {
      for (final a in [
        RecorderActions.openReserve,
        RecorderActions.selectDate,
        RecorderActions.selectPeriod,
        RecorderActions.selectResource,
        RecorderActions.changeBookingField,
      ]) {
        run.onAction(a);
      }
    }

    test('a tap is not a booking; only the real outcome completes', () {
      doPlainSteps();
      final confirm = run.current!;
      expect(confirm.action, RecorderActions.confirmBooking);
      run.onAction(RecorderActions.confirmBooking);
      expect(run.statusOf(confirm.id), GuideStepStatus.waiting);
      expect(run.current, same(confirm));
      run.onOutcome(RecorderOutcomes.bookingConfirmed);
      expect(run.statusOf(confirm.id), GuideStepStatus.done);
      run
        ..onAction(RecorderActions.viewDetails)
        ..onAction(RecorderActions.back);
      expect(run.state, GuideRunState.completed);
    });

    test('a refusal goes through recovery and back to the same step', () {
      doPlainSteps();
      final confirm = run.current!;
      run
        ..onAction(RecorderActions.confirmBooking)
        ..onOutcome(RecorderOutcomes.bookingRefused);
      expect(run.current!.id, '${confirm.id}r1');
      expect(run.statusOf(confirm.id), GuideStepStatus.pending);
      run.acknowledge();
      expect(run.current, same(confirm));
      run
        ..onAction(RecorderActions.confirmBooking)
        ..onOutcome(RecorderOutcomes.bookingConfirmed);
      expect(run.statusOf(confirm.id), GuideStepStatus.done);
    });

    test('a lost answer is uncertain; a pause does not assume success', () {
      doPlainSteps();
      final confirm = run.current!;
      run
        ..onAction(RecorderActions.confirmBooking)
        ..onOutcome(RecorderOutcomes.bookingUnknown);
      expect(run.uncertain, isTrue);
      expect(run.statusOf(confirm.id), GuideStepStatus.pending);
      run
        ..onAction(RecorderActions.confirmBooking)
        ..pause()
        ..onOutcome(RecorderOutcomes.bookingConfirmed) // arrives while paused
        ..resume();
      expect(run.statusOf(confirm.id), GuideStepStatus.pending);
      expect(run.uncertain, isTrue);
    });

    test('skipped is never done; foreign and late events change nothing', () {
      run.onAction(RecorderActions.confirmBooking); // not the current step
      expect(run.current!.action, RecorderActions.openReserve);
      run.skip();
      expect(run.statusOf('g1'), GuideStepStatus.skipped);
      run.onOutcome(RecorderOutcomes.bookingConfirmed); // nothing waits
      expect(run.statusOf('g6'), GuideStepStatus.pending);
      run.stop();
      run.onAction(RecorderActions.selectDate);
      expect(run.statusOf('g2'), GuideStepStatus.pending);
      expect(run.state, GuideRunState.stopped);
    });

    test('back shows the previous step and undoes nothing', () {
      run
        ..onAction(RecorderActions.openReserve)
        ..onAction(RecorderActions.selectDate)
        ..back();
      expect(run.current!.id, 'g2');
      expect(run.statusOf('g2'), GuideStepStatus.done);
    });
  });

  test('the recording json used by the compiler is the canonical one', () {
    final r = decodeRecordingText(fixtureText('booking_plan_confirmed'))
        .recording!;
    expect(encodeGuideText(compileGuide(r)), encodeGuideText(planGuide));
  });
}
