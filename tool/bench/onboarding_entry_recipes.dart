// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1456 — the onboarding recipes that END at the first usable screen:
// the returning person, the first sign-up with its e-mail, the
// organisation's own server, and the invitation. Each drives the real
// app through the real router with the suite's fakes behind the
// repositories, asserts the authorized screen or domain result BEFORE
// the run can count as a success, and returns the raw run.
//
// The optional arguments are the deliberate faults the measurement tests
// in test/perf/onboarding_recipes_test.dart inject: a held or refused
// provider, a stale cache. Left out, each recipe is the plain task.
import 'dart:async';

import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/backend_uri.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/core/ui/inline_banner.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/workspace/presentation/screens/pending_approval_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/fake_profile_repository.dart';
import '../../test/helpers/mock_providers.dart';
import 'recipe_fixtures.dart';
import 'recipe_probe.dart';
import 'workload.dart';

final _signIn = find.widgetWithText(FilledButton, 'Sign in');
final _pending = find.byKey(const ValueKey('auth-pending'));
final _card = find.byKey(const ValueKey('getting-started-card'));
final _canvas = find.byKey(const ValueKey('reserve-plan-canvas'));
final _banner = find.byType(InlineBanner);

Finder _field(int i) => find.byType(TextFormField).at(i);

/// A returning person with two spaces opens the app on B, where they are
/// an ordinary member, and must land on B's Reserve hub — B's name, B's
/// role. [workspace] swaps the membership provider, [wrap] the tree
/// around the app and [afterEntry] runs once the hub is up — the faults
/// the measurement tests inject.
Future<RecipeRun> returningEntry(
  WidgetTester tester, {
  MeteredWorkspace Function(BackendMeter)? workspace,
  Widget Function(Widget app)? wrap,
  Future<void> Function(RecipeProbe probe, FakeAuthRepository auth)? afterEntry,
}) async {
  final meter = BackendMeter();
  final run = RecipeRun('returning_entry', meter)..stops.add('/reserve');
  sizeView(tester, const Size(800, 1400));
  final ws = (workspace ?? MeteredWorkspace.new)(meter)..seedTwoSpaces();
  final probe = RecipeProbe(tester, run);
  try {
    final auth = MeteredAuth(meter, userId: 'user-1');
    final app = recipeApp(
      standardTestOverrides(
        auth: auth,
        workspace: ws,
        floorPlan: smallPlans(meter, const ['ws-a', 'ws-b']),
        reservations: MeteredReservations(meter),
        activeWorkspace: InMemoryActiveWorkspaceStore()..value = 'ws-b',
      ),
    );
    await probe.enter(
      wrap == null ? app : wrap(app),
      () => probe.shows(_canvas) && probe.shows(_card),
    );
    if (afterEntry != null) {
      await afterEntry(probe, auth);
      await probe.arrive(
        'settled',
        () => probe.shows(_canvas) && probe.shows(_card),
      );
    }
    probe.authorize('the Reserve hub', probe.location == '/reserve');
    probe.authorize(
      'scoped to the active space, Kraftwerk',
      probe.shows(find.text('Get started in Kraftwerk')),
    );
    probe.authorize(
      "B's role: a member of Kraftwerk",
      probe.shows(find.textContaining('You are a member here.')),
    );
    probe.forbid(
      "A's owner role rendered in B",
      probe.shows(find.textContaining('You are an owner')),
    );
  } on RecipeStopped catch (stop) {
    run.stoppedAt = stop.step;
  } finally {
    probe.finish();
  }
  return run;
}

/// A new person creates an account, the server answers with an e-mail,
/// the link in it confirms the address, consent is given once, and the
/// first usable screen is onboarding. [answer] scripts the auth
/// provider's answer; [holdFrames] holds it back for that many frames
/// after the tap, the way a slow provider would.
Future<RecipeRun> firstSignup(
  WidgetTester tester, {
  AuthResult answer = const AuthResult.verificationRequired(),
  int holdFrames = 0,
}) async {
  final gate = holdFrames > 0 ? Completer<void>() : null;
  final meter = BackendMeter();
  final run = RecipeRun('first_signup', meter)
    ..stops.addAll(['/auth', '/consent', '/onboarding']);
  sizeView(tester, const Size(800, 1600));
  final auth = MeteredAuth(meter)
    ..signUpResult = answer
    ..gate = gate;
  final profile = FakeProfileRepository(
    profiles: [const Profile(id: 'user-1', displayName: kRecipeName)],
    accepted: false,
  );
  final probe = RecipeProbe(tester, run);
  try {
    await probe.enter(
      recipeApp(
        standardTestOverrides(
          auth: auth,
          profile: profile,
          workspace: MeteredWorkspace(meter),
        ),
      ),
      () => probe.shows(_signIn),
    );
    await probe.choose(find.text('New here? Create an account'));
    await probe.settle();
    await probe.type(_field(0), kRecipeName, name: 'name');
    await probe.type(_field(1), kRecipeEmail, name: 'email');
    await probe.type(_field(2), kRecipePassword, name: 'password');
    final create = probe.pin(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    final b = await probe.act(
      'sign_up',
      create,
      // A refusal answers too: its banner is the acknowledgement then.
      visible: () => probe.buttonBusy(create) || probe.shows(_banner),
      semantic: () =>
          probe.semanticallyDisabled(create) || probe.readable(_banner),
      done: () => probe.shows(_pending),
      max: holdFrames + 60,
      onFrame: (n) {
        if (n == holdFrames) gate?.complete();
      },
    );
    await probe.settle();
    if (b.done == null) {
      probe.refused('the sign-up was not accepted: ${answer.outcome.name}');
      probe.authorize('a pending sign-up', false);
      return run;
    }
    // The e-mail: sent by the server, opened by the person. Its duration
    // is theirs and the provider's, not the app's.
    probe.wait(WaitKind.email);
    auth.signInAs('user-1');
    await probe.arrive(
      'verified',
      () => probe.shows(find.byKey(const ValueKey('consent-accept'))),
    );
    await probe.choose(find.byKey(const ValueKey('consent-checkbox')));
    await probe.settle();
    await probe.confirm(
      find.byKey(const ValueKey('consent-accept')),
      what: 'privacy consent',
      required: true,
    );
    await probe.arrive(
      'first_usable',
      () => probe.shows(find.byKey(const ValueKey('onboarding-name'))),
    );
    probe.authorize(
      'onboarding, the native first screen of a new account',
      probe.location?.startsWith('/onboarding') ?? false,
    );
    probe.authorize(
      'exactly one sign-up for one press',
      auth.signUps.length == 1,
    );
    probe.authorize(
      'consent recorded',
      profile.acceptedPolicyVersions.length == 1,
    );
  } on RecipeStopped catch (stop) {
    run.stoppedAt = stop.step;
  } finally {
    probe.finish();
  }
  return run;
}

const kRecipeServer = BackendEndpoint(
  'https://org.supabase.co',
  'sb_publishable_0123456789abcdefghij',
);

/// The server probe, answered when the recipe says: every probe of the
/// candidate is a provider round trip.
class RecipeProbes {
  RecipeProbes(this.meter, {this.result = BackendProbeResult.ok, this.gate});
  final BackendMeter meter;
  final BackendProbeResult result;
  final Completer<void>? gate;

  BackendProbeTransport call(BackendEndpoint endpoint) =>
      _RecipeTransport(this);
}

class _RecipeTransport implements BackendProbeTransport {
  _RecipeTransport(this.owner);
  final RecipeProbes owner;

  Future<void> _held() async => owner.gate?.future;

  @override
  Future<void> readOneWorkspace() =>
      owner.meter.trip('backend.probe', () async {
        await _held();
        if (owner.result != BackendProbeResult.ok) {
          throw TimeoutException('refused by the recipe');
        }
      });

  @override
  Future<int?> readVersion() => owner.meter.trip('backend.version', () async {
    await _held();
    return requiredSchemaVersion;
  });

  @override
  Future<void> dispose() async {}
}

/// Somebody with an organisation's server code: from the sign-in screen
/// to its server, the code pasted, verified by a probe, saved, the app
/// restarted onto it (a human step), and a native sign-in there that
/// reaches the organisation's space. [probeResult] and [holdFrames]
/// script the server being probed.
Future<RecipeRun> byoSignIn(
  WidgetTester tester, {
  BackendProbeResult probeResult = BackendProbeResult.ok,
  int holdFrames = 0,
}) async {
  final meter = BackendMeter();
  final run = RecipeRun('byo_signin', meter)
    ..stops.addAll(['/auth', '/server', '/reserve'])
    ..allowedReturns.add('/auth');
  sizeView(tester, const Size(800, 1600));
  final store = InMemoryBackendSettingsStore();
  final probe = RecipeProbe(tester, run);
  final transport = RecipeProbes(
    meter,
    result: probeResult,
    gate: holdFrames > 0 ? Completer<void>() : null,
  );
  try {
    await probe.enter(
      recipeApp([
        ...standardTestOverrides(
          auth: MeteredAuth(meter),
          backendSettings: store,
        ),
        bootedBackendUrlProvider.overrideWithValue(''),
        backendProbeTransportProvider.overrideWithValue(transport.call),
      ]),
      () => probe.shows(_signIn),
    );
    await probe.choose(find.byKey(const ValueKey('auth-server')));
    await probe.arrive(
      'server',
      () => probe.shows(find.byKey(const ValueKey('backend-descriptor-field'))),
    );
    await probe.type(
      find.byKey(const ValueKey('backend-descriptor-field')),
      BackendUriCodec.encode(kRecipeServer, label: 'Our coworking'),
      name: 'server code',
    );
    final test = probe.pin(find.byKey(const ValueKey('backend-test')));
    final result = find.byKey(const ValueKey('backend-test-result'));
    final save = find.byKey(const ValueKey('backend-save'));
    final b = await probe.act(
      'verify',
      test,
      visible: () => probe.buttonBusy(test),
      semantic: () => probe.semanticallyDisabled(test),
      done: () =>
          probe.shows(result) &&
          probe.shows(save) &&
          tester.widget<FilledButton>(save).onPressed != null,
      max: holdFrames + 60,
      onFrame: (n) {
        if (n == holdFrames) transport.gate?.complete();
      },
    );
    await probe.settle();
    if (b.done == null) {
      probe.refused('the server could not be verified');
      probe.authorize('a verified server', false);
      return run;
    }
    await probe.confirm(save, what: 'save the verified server');
    await probe.settle();
    probe.authorize(
      'the verified server is what was saved',
      store.value?.url == kRecipeServer.url,
    );
    // The restart is the person's: the saved server takes effect on the
    // next start, which is simulated by a fresh mount booted onto it.
    probe.wait(WaitKind.human);
    final auth = MeteredAuth(meter);
    await probe.enter(
      recipeApp([
        ...standardTestOverrides(
          auth: auth,
          backendSettings: store,
          // #1823 — the account's server default: the space it was last
          // in there, which a sign-in on a new device returns to.
          workspace: MeteredWorkspace(meter)
            ..seedTwoSpaces()
            ..serverDefaultWorkspaceId = 'ws-a',
          floorPlan: smallPlans(meter, const ['ws-a', 'ws-b']),
          reservations: MeteredReservations(meter),
        ),
        bootedBackendUrlProvider.overrideWithValue(kRecipeServer.url),
        backendProbeTransportProvider.overrideWithValue(transport.call),
      ]),
      () => probe.shows(_signIn),
    );
    await probe.type(_field(0), kRecipeEmail, name: 'email');
    await probe.type(_field(1), kRecipePassword, name: 'password');
    final submit = probe.pin(_signIn);
    await probe.act(
      'sign_in',
      submit,
      visible: () => probe.buttonBusy(submit),
      semantic: () => probe.semanticallyDisabled(submit),
      done: () => probe.shows(find.byType(ShellBottomBar)),
    );
    await probe.arrive('first_usable', () => probe.shows(_canvas));
    probe.authorize(
      'signed in on the organisation\'s server, in its space',
      auth.currentUserId == 'user-1' && probe.location == '/reserve',
    );
    probe.authorize(
      'still pointed at the verified server',
      store.value?.url == kRecipeServer.url,
    );
  } on RecipeStopped catch (stop) {
    run.stoppedAt = stop.step;
  } finally {
    probe.finish();
  }
  return run;
}

/// An invitation link opened from outside: the code arrives in the field
/// (nothing re-typed), is reviewed read-only, joined by ONE explicit
/// press, waits for the space's approval (a human), and the approved
/// member lands in the space.
Future<RecipeRun> invitationJoin(WidgetTester tester) async {
  final meter = BackendMeter();
  final run = RecipeRun('invitation_join', meter)
    ..stops.addAll(['/reserve', '/onboarding', '/pending']);
  sizeView(tester, const Size(800, 1400));
  final ws = MeteredWorkspace(meter)..joinsArePending = true;
  final probe = RecipeProbe(tester, run);
  try {
    await probe.enter(
      recipeApp(
        standardTestOverrides(
          auth: MeteredAuth(meter, userId: 'user-1'),
          workspace: ws,
          backendSettings: InMemoryBackendSettingsStore()
            ..value = kRecipeServer,
        ),
      ),
      () => probe.shows(find.byKey(const ValueKey('onboarding-name'))),
    );
    // The link, opened from a message outside the app.
    await probe.router.routeInformationProvider.didPushRouteInformation(
      RouteInformation(
        uri: Uri.parse('deskilo://join?role=user&code=GOODCODE22'),
      ),
    );
    await probe.arrive(
      'invitation',
      () => probe.shows(find.byKey(const ValueKey('invitation-input'))),
    );
    await probe.choose(find.byKey(const ValueKey('invitation-review-button')));
    await probe.arrive(
      'review',
      () => probe.shows(find.byKey(const ValueKey('invitation-join'))),
    );
    final join = probe.pin(find.byKey(const ValueKey('invitation-join')));
    await probe.act(
      'join',
      join,
      visible: () => probe.buttonBusy(join),
      semantic: () => probe.semanticallyDisabled(join),
      done: () => probe.shows(find.byType(PendingApprovalScreen)),
    );
    probe.authorize('one Join for one press', ws.joinByInvitationCalls == 1);
    // The space's validators decide; the person checks again.
    probe.wait(WaitKind.human);
    ws.myMember = ws.myMember.copyWith(status: MemberStatus.active);
    await probe.choose(find.byKey(const ValueKey('pending-refresh')));
    await probe.arrive(
      'first_usable',
      () => probe.shows(find.byType(ShellBottomBar)),
    );
    probe.authorize(
      'in the joined space',
      probe.location == '/reserve' &&
          ws.workspaces.single.name == 'Joined Space',
    );
  } on RecipeStopped catch (stop) {
    run.stoppedAt = stop.step;
  } finally {
    probe.finish();
  }
  return run;
}
