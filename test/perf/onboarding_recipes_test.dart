// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1456 — the onboarding recipes' own red controls. The recipes live in
// tool/bench/ and run nightly with the journeys; what runs here, on every
// pull request, is the proof that their MEASUREMENT cannot be fooled:
// every recipe still completes and asserts its authorized result; a held
// provider moves completion and not the acknowledgement; a refused one is
// refused, not fast; lost input, a route shown twice and another space's
// answer are incorrect even when they are quicker; reduced motion ends
// where normal motion ends; a dismissed card is not a task done; and one
// extra request or one extra rebuild on a fixed recipe shows up as
// exactly that, with no wall clock involved.
//
// Every fault below is a test fake's subclass or a wrapper around the
// app — none is a hook in lib/.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/bench/onboarding_entry_recipes.dart';
import '../../tool/bench/onboarding_task_recipes.dart';
import '../../tool/bench/recipe_fixtures.dart';
import '../../tool/bench/recipe_probe.dart';

/// A membership cache keyed by the person instead of the space, primed
/// in A: B's hub is served A's row, and saves the round trip doing it.
class _StaleMembership extends MeteredWorkspace {
  _StaleMembership(super.meter);
  @override
  Future<Member?> fetchMyMember(String workspaceId) async => kOwnerInA;
}

/// Every read of the membership list asked twice.
class _DoubleRead extends MeteredWorkspace {
  _DoubleRead(super.meter);
  @override
  Future<List<Workspace>> fetchMyWorkspaces() async {
    await super.fetchMyWorkspaces();
    return super.fetchMyWorkspaces();
  }
}

/// A MediaQuery above the app that, when [extra], changes once after the
/// first frame in a way nothing on screen shows — so every widget that
/// reads the whole MediaQuery builds once more. The baseline wears the
/// same wrapper with [extra] off: the only difference is that rebuild.
class _Wrapper extends StatefulWidget {
  const _Wrapper(this.child, {required this.extra});
  final Widget child;
  final bool extra;
  @override
  State<_Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<_Wrapper> {
  var _changed = false;
  @override
  void initState() {
    super.initState();
    if (!widget.extra) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _changed = true);
    });
  }

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQueryData.fromView(View.of(context))
        .copyWith(onOffSwitchLabels: _changed),
    child: widget.child,
  );
}

void expectSuccess(RecipeRun run) =>
    expect(run.outcome, RecipeOutcome.success, reason: run.why);

void main() {
  group('every recipe completes and asserts its authorized result', () {
    final recipes = <String, Future<RecipeRun> Function(WidgetTester)>{
      'returning_entry': returningEntry,
      'first_signup': firstSignup,
      'invitation_join': invitationJoin,
      'owner_first_booking': ownerFirstBooking,
      'byo_signin': byoSignIn,
      'pending_leave_return': pendingLeaveReturn,
      'wizard_keyboard_back_edit': wizardKeyboardBackEdit,
    };
    for (final MapEntry(key: name, value: recipe) in recipes.entries) {
      testWidgets(name, (tester) async {
        final run = await recipe(tester);
        expectSuccess(run);
        expect(run.recipe, name);
        expect(
          run.metrics['trips'],
          greaterThan(0),
          reason: 'a recipe that reaches no provider lost its seam',
        );
      });
    }
  });

  testWidgets('the counts are deterministic: the same recipe twice moves '
      'nothing, once the binding is warm', (tester) async {
    // The first mount in a fresh test binding rebuilds the root focus
    // scope once more than any later one (the FocusManager is global),
    // so the first sample is a warm-up for the counts — the bench does
    // the same.
    final cold = await returningEntry(tester);
    final a = await returningEntry(tester);
    final b = await returningEntry(tester);
    expectSuccess(a);
    expect(diffRuns(a, b), isEmpty);
    expect(diffRuns(cold, a).keys, everyElement('rebuilds'));
  });

  group('a held provider moves completion, not the acknowledgement', () {
    testWidgets('sign-up', (tester) async {
      final quick = await firstSignup(tester);
      final held = await firstSignup(tester, holdFrames: 30);
      expectSuccess(held);
      final ack = held.metrics['sign_up_ack_frames']!;
      final done = held.metrics['sign_up_done_frames']!;
      expect(
        ack,
        lessThanOrEqualTo(2),
        reason: 'the tap is acknowledged at once',
      );
      expect(
        held.metrics['sign_up_ack_semantic_frames'],
        ack,
        reason: 'and the semantics tree says so in the same frame',
      );
      expect(
        done,
        greaterThanOrEqualTo(30),
        reason: 'completion waits for the answer',
      );
      expect(quick.metrics['sign_up_ack_frames'], ack);
      expect(quick.metrics['sign_up_done_frames'], lessThan(done));
    });

    testWidgets('server verification', (tester) async {
      final held = await byoSignIn(tester, holdFrames: 30);
      expectSuccess(held);
      expect(held.metrics['verify_ack_frames'], lessThanOrEqualTo(2));
      expect(held.metrics['verify_done_frames'], greaterThanOrEqualTo(30));
    });
  });

  group('a refused provider is refused, never a fast success', () {
    testWidgets('sign-up', (tester) async {
      final run = await firstSignup(
        tester,
        answer: const AuthResult.refused(AuthRefusal.credentials),
        holdFrames: 10,
      );
      expect(run.outcome, RecipeOutcome.refused, reason: run.why);
      expect(run.metrics['success'], 0);
      expect(
        run.metrics['sign_up_ack_frames'],
        lessThanOrEqualTo(2),
        reason: 'the tap was still acknowledged at once',
      );
      expect(
        run.metrics.containsKey('sign_up_done_frames'),
        isFalse,
        reason: 'a refusal is not a completion, however soon it came',
      );
    });

    testWidgets('server verification', (tester) async {
      final run = await byoSignIn(
        tester,
        probeResult: BackendProbeResult.unreachable,
        holdFrames: 10,
      );
      expect(run.outcome, RecipeOutcome.refused, reason: run.why);
      expect(run.metrics['verify_ack_frames'], lessThanOrEqualTo(2));
      expect(run.metrics.containsKey('verify_done_frames'), isFalse);
    });
  });

  testWidgets('lost field input is incorrect, not one more field typed', (
    tester,
  ) async {
    final run = await wizardKeyboardBackEdit(
      tester,
      afterBack: (tester) =>
          tester.enterText(find.byKey(const ValueKey('onboarding-name')), ''),
    );
    expect(run.outcome, RecipeOutcome.incorrect, reason: run.why);
    expect(run.why, contains('lost input: name'));
    expect(run.metrics['fields_reentered'], 1);
    // The space was still created: counted as a success, this would be a
    // completed task with one extra field.
    expect(run.finalState['space'], 'Kraftwerk Coworking/CHF');
  });

  testWidgets('a route shown twice is a detour, and incorrect', (tester) async {
    // A session that drops and comes back — a refresh answered as
    // signed out, then the session restored: the hub, the sign-in
    // screen, the hub again. The person was sent where they had been.
    final run = await returningEntry(
      tester,
      afterEntry: (probe, auth) async {
        await auth.signOut();
        await probe.settle();
        auth.signInAs('user-1');
      },
    );
    expect(run.trail, ['/reserve', '/auth', '/reserve']);
    expect(run.outcome, RecipeOutcome.incorrect, reason: run.why);
    expect(run.why, contains('duplicate route detour: /reserve'));
    expect(
      run.metrics['route_flashes'],
      1,
      reason: 'the sign-in screen flashed',
    );
  });

  testWidgets("another space's answer rendered here is incorrect, though "
      'it is faster', (tester) async {
    final base = await returningEntry(tester);
    final stale = await returningEntry(tester, workspace: _StaleMembership.new);
    expectSuccess(base);
    expect(stale.outcome, RecipeOutcome.incorrect, reason: stale.why);
    expect(stale.why, contains("A's owner role rendered in B"));
    expect(
      stale.metrics['trips'],
      lessThan(base.metrics['trips']!),
      reason: 'the stale cache saved a round trip — and is still wrong',
    );
  });

  testWidgets('normal and reduced motion end in the same state', (
    tester,
  ) async {
    final normal = await wizardKeyboardBackEdit(tester);
    final reduced = await wizardKeyboardBackEdit(tester, motion: false);
    expectSuccess(normal);
    expectSuccess(reduced);
    expect(reduced.finalState, normal.finalState);
    expect(
      reduced.metrics['frames'],
      lessThan(normal.metrics['frames']!),
      reason: 'reduced motion was actually in force',
    );
  });

  testWidgets('a dismissed card is not a completed task', (tester) async {
    final run = await ownerFirstBooking(tester, dismiss: true);
    expect(run.outcome, RecipeOutcome.incomplete, reason: run.why);
    expect(run.why, contains('a first booking in the new space'));
    expect(run.finalState['bookings'], '0');
    expect(
      find.byKey(const ValueKey('getting-started-card')),
      findsNothing,
      reason: 'the card is gone, which is exactly what must not read as done',
    );
  });

  group('one extra unit of work on a fixed recipe is caught exactly', () {
    testWidgets('an extra request', (tester) async {
      final base = await returningEntry(tester);
      final more = await returningEntry(tester, workspace: _DoubleRead.new);
      expectSuccess(more);
      final diff = diffRuns(base, more);
      expect(diff.keys, containsAll(['trips', 'trips.workspace.fetchMine']));
      final (before, after) = diff['trips']!;
      final (readBefore, readAfter) = diff['trips.workspace.fetchMine']!;
      expect(after - before, readAfter - readBefore);
      expect(readAfter, 2 * readBefore);
    });

    // A lone setState on one element was tried first and is NOT caught:
    // the frame it schedules coalesces another element's two rebuilds
    // into one, and the totals came out equal (15 798 both). What the
    // count holds is rebuilt WORK — a subtree building again.
    testWidgets('an extra rebuild of the app', (tester) async {
      final base = await returningEntry(
        tester,
        wrap: (app) => _Wrapper(app, extra: false),
      );
      final more = await returningEntry(
        tester,
        wrap: (app) => _Wrapper(app, extra: true),
      );
      expectSuccess(more);
      final diff = diffRuns(base, more);
      expect(diff.keys, contains('rebuilds'));
      final (before, after) = diff['rebuilds']!;
      expect(after, greaterThan(before));
      expect(
        diff.containsKey('trips'),
        isFalse,
        reason: 'a rebuild is not a request',
      );
    });
  });
}
