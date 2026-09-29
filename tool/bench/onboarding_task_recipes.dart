// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1456 — the onboarding recipes that end in a TASK rather than on a
// screen: the owner's suggested creation to a first real booking, the
// pending member who leaves and comes back safely, and the keyboard /
// Back / edit walk through the creation wizard. Same seam, same rules as
// onboarding_entry_recipes.dart: the authorized result is asserted
// before a run can be a success, and every value is reported raw.
import 'dart:async';

import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:deskilo/features/profile/presentation/screens/profiles_screen.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/screens/pending_approval_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/mock_providers.dart';
import 'recipe_fixtures.dart';
import 'recipe_probe.dart';
import 'workload.dart';

final _card = find.byKey(const ValueKey('getting-started-card'));
final _canvas = find.byKey(const ValueKey('reserve-plan-canvas'));
final _name = find.byKey(const ValueKey('onboarding-name'));
final _next = find.byKey(const ValueKey('wizard-next'));
final _create = find.byKey(const ValueKey('onboarding-create'));

/// The id the fake gives the first space it creates.
const kCreatedSpace = 'ws-created-1';

/// Centre of the small plan's only seat, transform-aware.
Offset _seat(WidgetTester tester) {
  final topLeft = tester.getTopLeft(_canvas);
  final scale =
      (tester.getTopRight(_canvas).dx - topLeft.dx) /
      (PlanCanvasMetrics.cells * PlanCanvasMetrics.cellSize);
  return topLeft +
      const Offset(
            5 * PlanCanvasMetrics.cellSize,
            4 * PlanCanvasMetrics.cellSize,
          ) *
          scale;
}

/// Taps the Create button and records its acknowledgement: the busy
/// spinner and its "Submitting" label, then the shell it lands in.
Future<Boundary> _createSpace(RecipeProbe probe) {
  final create = probe.pin(_create);
  return probe.act(
    'create',
    create,
    visible: () => probe.buttonBusy(create),
    semantic: () => probe.announces('Submitting'),
    done: () => probe.shows(find.byType(ShellBottomBar)),
  );
}

/// A new owner takes the suggested set-up, creates the space, and books
/// the first seat through the Get started card's hub. The plan the
/// template sets up server-side is seeded under the id the creation will
/// answer with. [dismiss] swaps the booking for "Not now" — the control
/// that a dismissed card is not a completed task.
Future<RecipeRun> ownerFirstBooking(
  WidgetTester tester, {
  bool dismiss = false,
  MeteredWorkspace Function(BackendMeter)? workspace,
}) async {
  final meter = BackendMeter();
  final run = RecipeRun('owner_first_booking', meter)
    ..stops.addAll(['/onboarding', '/reserve']);
  sizeView(tester, const Size(800, 1400));
  final ws = (workspace ?? MeteredWorkspace.new)(meter)
    ..openWeekdays[kCreatedSpace] = const [1, 2, 3, 4, 5, 6, 7];
  final reservations = MeteredReservations(meter);
  final probe = RecipeProbe(tester, run);
  try {
    await probe.enter(
      recipeApp(
        standardTestOverrides(
          auth: MeteredAuth(meter, userId: 'user-1'),
          workspace: ws,
          floorPlan: smallPlans(meter, const [kCreatedSpace]),
          reservations: reservations,
        ),
      ),
      () => probe.shows(_name),
    );
    await probe.type(_name, 'Kraftwerk', name: 'name');
    await probe.choose(find.byKey(const ValueKey('onboarding-use-suggested')));
    await probe.arrive('confirm', () => probe.shows(_create));
    await _createSpace(probe);
    await probe.arrive(
      'first_usable',
      () => probe.shows(_canvas) && probe.shows(_card),
    );
    probe.authorize(
      'one space, created once, with the typed name',
      ws.createRequests.length == 1 && ws.workspaces.single.name == 'Kraftwerk',
    );
    if (dismiss) {
      await probe.choose(find.byKey(const ValueKey('getting-started-dismiss')));
      await probe.settle();
    } else {
      run.decisions++;
      await tester.tapAt(_seat(tester));
      await probe.arrive('sheet', () => probe.shows(find.byType(BookingSheet)));
      final confirm = probe.pin(find.byKey(const ValueKey('booking-confirm')));
      await probe.act(
        'book',
        confirm,
        visible: () =>
            !probe.shows(find.byType(BookingSheet)) ||
            probe.buttonBusy(confirm),
        semantic: () => probe.semanticallyDisabled(confirm),
        done: () =>
            probe.shows(find.byKey(const ValueKey('getting-started-booking'))),
      );
      await probe.settle();
    }
    final booked = reservations.reservations
        .where((r) => r.workspaceId == kCreatedSpace)
        .toList();
    // The task is the booking the repository holds — not a card that
    // went away, not a sheet that closed.
    probe.authorize('a first booking in the new space', booked.length == 1);
    probe.forbid('more than one booking for one confirm', booked.length > 1);
    run.finalState['bookings'] = '${booked.length}';
  } on RecipeStopped catch (stop) {
    run.stoppedAt = stop.step;
  } finally {
    probe.finish();
  }
  return run;
}

/// A pending member leaves the waiting room for their profiles and comes
/// back; then, by an assistant's link, asks this database for assistant
/// access, gives the request up, and goes back — landing in the waiting
/// room again every time, with no workspace screen shown on the way and
/// nothing asked of the space.
Future<RecipeRun> pendingLeaveReturn(WidgetTester tester) async {
  final meter = BackendMeter();
  final run = RecipeRun('pending_leave_return', meter)
    ..stops.addAll(['/pending', '/profiles', '/assistants'])
    ..allowedReturns.add('/pending');
  sizeView(tester, const Size(800, 1400));
  final ws = MeteredWorkspace(meter)
    ..workspaces.add(kSpaceB)
    ..myMember = kMemberInB.copyWith(status: MemberStatus.pending);
  final identity = MeteredIdentity(meter);
  final waiting = find.byType(PendingApprovalScreen);
  final requested = find.byKey(const ValueKey('mcp-eligibility-requested'));
  final notRequested = find.byKey(
    const ValueKey('mcp-eligibility-notRequested'),
  );
  final probe = RecipeProbe(tester, run);
  var shellSeen = false;
  try {
    await probe.enter(
      recipeApp(
        standardTestOverrides(
          auth: MeteredAuth(meter, userId: 'user-1'),
          workspace: ws,
          identityBinding: identity,
        ),
      ),
      () => probe.shows(waiting),
    );
    await probe.choose(find.byKey(const ValueKey('pending-switch')));
    await probe.arrive(
      'profiles',
      () => probe.shows(find.byType(ProfilesScreen)),
    );
    await probe.back(find.byType(BackButton));
    await probe.arrive('return_from_profiles', () => probe.shows(waiting));
    shellSeen |= probe.shows(find.byType(ShellBottomBar));

    // The link an assistant gives: the only way a pending member reaches
    // it, since Settings is a workspace screen.
    // push's future is the popped result; the recipe pops it itself.
    unawaited(probe.router.push('/assistants'));
    await probe.arrive('assistants', () => probe.shows(notRequested));
    final ask = probe.pin(
      find.byKey(const ValueKey('mcp-eligibility-request')),
    );
    await probe.act(
      'request',
      ask,
      visible: () => probe.buttonBusy(ask),
      semantic: () => probe.semanticallyDisabled(ask),
      done: () => probe.shows(requested),
    );
    // A database administrator would decide; the person does not wait.
    probe.wait(WaitKind.human);
    final giveUp = probe.pin(
      find.byKey(const ValueKey('mcp-eligibility-withdraw')),
    );
    await probe.act(
      'withdraw',
      giveUp,
      visible: () => probe.buttonBusy(giveUp),
      semantic: () => probe.semanticallyDisabled(giveUp),
      done: () => probe.shows(notRequested),
    );
    await probe.back(find.byType(BackButton));
    await probe.arrive('safe_return', () => probe.shows(waiting));
    shellSeen |= probe.shows(find.byType(ShellBottomBar));

    probe.authorize('back in the waiting room', probe.location == '/pending');
    probe.authorize(
      'the request given up at the database',
      identity.capabilities.eligibility.name == 'notRequested',
    );
    probe.forbid('a workspace screen shown to a pending member', shellSeen);
    probe.forbid(
      'the membership changed by leaving',
      ws.myMember.status != MemberStatus.pending,
    );
    run.finalState['eligibility'] = identity.capabilities.eligibility.name;
  } on RecipeStopped catch (stop) {
    run.stoppedAt = stop.step;
  } finally {
    probe.finish();
  }
  return run;
}

/// Keyboard, Back and edit in the creation wizard: the name typed with
/// the soft keyboard up (its Next must stay reachable), a currency on the
/// next step, Escape back, the name edited, forward again — and both
/// answers still there at confirm and in the space created. [motion]
/// false runs it with the platform's reduced motion; [afterBack] is the
/// hook the lost-input control uses to take the name away.
Future<RecipeRun> wizardKeyboardBackEdit(
  WidgetTester tester, {
  bool motion = true,
  Future<void> Function(WidgetTester tester)? afterBack,
}) async {
  final meter = BackendMeter();
  final run = RecipeRun('wizard_keyboard_back_edit', meter)
    ..stops.addAll(['/onboarding', '/reserve']);
  const size = Size(400, 800);
  sizeView(tester, size);
  if (!motion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final ws = MeteredWorkspace(meter);
  final currency = find.byKey(const ValueKey('onboarding-currency'));
  final probe = RecipeProbe(tester, run);
  try {
    await probe.enter(
      recipeApp(
        standardTestOverrides(
          auth: MeteredAuth(meter, userId: 'user-1'),
          workspace: ws,
        ),
      ),
      () => probe.shows(_name),
    );
    // The soft keyboard takes the bottom 300 px while the name is typed.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await probe.type(_name, 'Kraftwerk', name: 'name');
    await probe.settle();
    probe.forbid(
      'Next hidden under the keyboard',
      tester.getRect(_next).bottom > size.height - 300,
    );
    tester.view.resetViewInsets();
    await probe.choose(_next);
    await probe.arrive('where', () => probe.shows(currency));
    await probe.type(currency, 'CHF', name: 'currency');
    // Back from the keyboard, not the button.
    run.backCorrections++;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await probe.arrive('back_to_name', () => probe.shows(_name));
    await afterBack?.call(tester);
    await probe.expectKept(_name, name: 'name');
    await probe.edit(_name, 'Kraftwerk Coworking', name: 'name');
    await probe.choose(_next);
    await probe.arrive('where_again', () => probe.shows(currency));
    await probe.expectKept(currency, name: 'currency');
    await probe.choose(_next);
    await probe.arrive(
      'start_from',
      () => probe.shows(find.byKey(const ValueKey('template-gallery'))),
    );
    await probe.choose(_next);
    await probe.arrive('confirm', () => probe.shows(_create));
    probe.authorize(
      'confirm shows the edited name and the kept currency',
      probe.shows(find.text('Kraftwerk Coworking')) &&
          probe.shows(find.textContaining('CHF')),
    );
    await _createSpace(probe);
    await probe.arrive(
      'first_usable',
      () => probe.shows(find.byType(ShellBottomBar)),
    );
    final created = ws.workspaces;
    probe.authorize(
      'one space with both answers',
      created.length == 1 &&
          created.single.name == 'Kraftwerk Coworking' &&
          created.single.currencyCode == 'CHF',
    );
    probe.forbid(
      'a creation sent before confirm, or twice',
      ws.createRequests.length != 1,
    );
    run.finalState['space'] = created
        .map((w) => '${w.name}/${w.currencyCode}')
        .join(',');
  } on RecipeStopped catch (stop) {
    run.stoppedAt = stop.step;
  } finally {
    probe.finish();
  }
  return run;
}
