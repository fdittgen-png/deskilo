// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3235 — a signed-in person opens a configuration example in the demo and
// comes back to the same live setup.
//
// The composition is the product's: `DeskiloRoot` over a FAKE AUTHENTICATED
// outer repository, and inside the Demo the production `DemoWorkspace` /
// `demoOverrides` — never the test helper's broad overrides, which would
// hide an isolation gap. What is asserted is what the person can observe:
// the consent, the Demo bar, a real change read back from the Demo
// repository, the live repository untouched, no sign-out, and the way back
// to the same account, workspace and screen with the choices they had not
// applied.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/demo_visit.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/demo/data/demo_no_backend.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/demo/demo_entry.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/core/l10n/context_l10n.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/presentation/screens/features_screen.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_guide_screen.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_levels_screen.dart';
import 'package:deskilo/features/workspace/providers/held_setup_choices.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../helpers/mock_providers.dart';

/// Counts the live session's sign-outs: a visit must cause none.
/// A bounded settle: a fixed number of frames, long enough for a sheet, a
/// route transition and the Demo's first frame, never "until nothing is
/// scheduled" (the Demo keeps timers and streams alive).
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 15; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The live session's global client: it counts every use and refuses it.
class _CountingClient implements SupabaseClient {
  int uses = 0;

  @override
  Object? noSuchMethod(Invocation invocation) {
    uses++;
    throw StateError('a live request: ${invocation.memberName}');
  }
}

/// A demo whose fixture cannot be built.
class _BrokenSession extends DemoSessionController {
  @override
  DemoSession build() => throw StateError('no fixture');
}

class _CountingAuth extends FakeAuthRepository {
  _CountingAuth() : super.signedIn();
  int signOuts = 0;

  @override
  Future<void> signOut() {
    signOuts++;
    return super.signOut();
  }
}

SetupStatus _status(String route) => SetupStatus.fromJson({
  'steps': [
    {
      'step': 'places',
      'milestone': 'bookable',
      'required': true,
      'state': 'needs_configuration',
      'route': route,
      'manual': false,
    },
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 1,
      'ready': 0,
      'reached': false,
    },
  ],
});

class _Live {
  _Live(this.tester, this.container, this.auth, this.workspace);

  final WidgetTester tester;
  final ProviderContainer container;
  final _CountingAuth auth;
  final FakeWorkspaceRepository workspace;

  String get location => container
      .read(routerProvider)
      .routeInformationProvider
      .value
      .uri
      .toString();

  bool get inDemo => container.read(demoEntryProvider);
  DemoOrigin? get origin => container.read(demoVisitProvider);
  DemoSession get demo => container.read(demoSessionControllerProvider);

  Future<void> open(String route) async {
    container.read(routerProvider).go(route);
    await _settle(tester);
  }
}

Future<_Live> _pumpLive(
  WidgetTester tester, {
  String stepRoute = '/features',
  Map<String, dynamic> flags = const {},
  String at = '/setup',
  double height = 1600,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = _CountingAuth();
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        auth: auth,
        workspace: workspace,
        localSetup: FakeLocalSetupRepository(status: _status(stepRoute)),
      ).followedBy(extra).toList(),
      child: const DeskiloRoot(),
    ),
  );
  await _settle(tester);
  final live = _Live(
    tester,
    ProviderScope.containerOf(tester.element(find.byType(DeskiloRoot))),
    auth,
    workspace,
  );
  await live.open(at);
  return live;
}

const _tryDemo = ValueKey('setup-guide-demo-places');
const _start = Key('demo-entry-start');

Future<void> _consent(WidgetTester tester) async {
  await tester.tap(find.byKey(_tryDemo));
  await _settle(tester);
  await tester.tap(find.byKey(_start));
  await _settle(tester);
}

void main() {
  testWidgets('the example opens while signed in; a change lands in the demo '
      'only; Return brings the person back to the same setup screen, still '
      'signed in', (tester) async {
    final live = await _pumpLive(tester);
    expect(find.byType(SetupGuideScreen), findsOneWidget);
    final flagsBefore = Map.of(live.workspace.workspaces.first.featureFlags);

    await tester.tap(find.byKey(_tryDemo));
    await _settle(tester);
    // The explanation says the login stays, before anything starts.
    expect(find.text(englishL10n.demoEntryBodySignedIn), findsOneWidget);
    expect(live.inDemo, isFalse, reason: 'reading is not consenting');
    expect(live.origin, isNull);

    await tester.tap(find.byKey(_start));
    await _settle(tester);

    expect(live.inDemo, isTrue);
    expect(live.origin?.route, '/setup');
    expect(live.origin?.identity.userId, 'user-1');
    expect(find.byType(FeaturesScreen), findsOneWidget,
        reason: 'the example opened at the step\'s own screen');
    final leave = find.byKey(DemoControls.leaveKey);
    expect(
      find.descendant(
        of: leave,
        matching: find.text(englishL10n.demoSessionReturn),
      ),
      findsOneWidget,
      reason: 'a signed-in visit offers the way back to the workspace',
    );

    // A real change through the real UI, read back from the Demo repository.
    final switchTile = find.byKey(const ValueKey('feature-seriesBooking'));
    // The switches view, filtered to the one row (the list builds lazily).
    await tester.tap(find.byKey(const ValueKey('features-view-switches')));
    await _settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('features-search')),
      'Series booking',
    );
    await _settle(tester);
    final demoSpace = live.demo.fixture.workspaces.workspaces.first;
    final before = demoSpace.featureFlags['seriesBooking'];
    await tester.tap(switchTile);
    await _settle(tester);
    expect(
      live.demo.fixture.workspaces.workspaces.first.featureFlags['seriesBooking'],
      isNot(before),
      reason: 'the demo repository took the change',
    );

    // Isolation: the live repository and the live session are untouched.
    expect(live.workspace.workspaces.first.featureFlags, flagsBefore);
    expect(live.auth.signOuts, 0);
    expect(live.auth.currentUserId, 'user-1');

    await tester.tap(leave);
    await _settle(tester);

    expect(live.inDemo, isFalse);
    expect(live.origin, isNull, reason: 'the next visit starts fresh');
    expect(live.demo.generation, 0, reason: 'and on canonical data');
    expect(live.location, '/setup');
    expect(find.byType(SetupGuideScreen), findsOneWidget);
    expect(live.auth.signOuts, 0, reason: 'no sign-in was needed to return');
    expect(live.workspace.workspaces.first.featureFlags, flagsBefore);
  });

  testWidgets('cancelling the explanation changes nothing', (tester) async {
    final live = await _pumpLive(tester);
    await tester.tap(find.byKey(_tryDemo));
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byKey(_start), findsNothing);
    expect(live.inDemo, isFalse);
    expect(live.origin, isNull);
    expect(live.location, '/setup');
    expect(find.byType(SetupGuideScreen), findsOneWidget);
  });

  testWidgets('a second start never overwrites the first return target, and '
      'the demo is not nested', (tester) async {
    final live = await _pumpLive(tester);
    await _consent(tester);
    final first = live.origin;
    expect(first, isNotNull);

    final visit = live.container.read(demoVisitProvider.notifier);
    final other = DemoOrigin(identity: first!.identity, route: '/members');
    expect(visit.begin(other), isFalse);
    expect(live.origin?.route, '/setup');
    // Inside the demo the guide offers no example at all.
    await live.open('/setup');
    expect(find.byKey(_tryDemo), findsNothing);
  });

  testWidgets('a different account while the demo is open: the origin is '
      'dropped and the previous account\'s screen is not restored', (
    tester,
  ) async {
    final live = await _pumpLive(tester);
    await _consent(tester);
    expect(live.origin, isNotNull);

    live.auth.signInAs('user-2');
    await _settle(tester);
    expect(live.origin, isNull, reason: 'dropped the moment the user changed');

    await tester.tap(find.byKey(DemoControls.leaveKey));
    await _settle(tester);
    expect(live.inDemo, isFalse);
    expect(live.location, isNot('/setup'),
        reason: 'the other account lands where the guards send it');
    expect(live.auth.currentUserId, 'user-2');
  });

  testWidgets('the session ends while the demo is open: leaving asks for '
      'sign-in and restores nothing', (tester) async {
    final live = await _pumpLive(tester);
    await _consent(tester);
    await live.auth.signOut();
    await _settle(tester);
    expect(live.origin, isNull);

    await tester.tap(find.byKey(DemoControls.leaveKey));
    await _settle(tester);
    expect(live.inDemo, isFalse);
    expect(live.location, startsWith('/auth'));
  });

  testWidgets('a late "start" after the account changed enters nothing', (
    tester,
  ) async {
    final live = await _pumpLive(tester);
    await tester.tap(find.byKey(_tryDemo));
    await _settle(tester);
    live.auth.signInAs('user-2');
    await _settle(tester);
    await tester.tap(find.byKey(_start));
    await _settle(tester);
    expect(live.inDemo, isFalse);
    expect(live.origin, isNull);
  });

  testWidgets('the unsubmitted choices of "Set up by level" survive the visit '
      'and nothing is applied', (tester) async {
    final live = await _pumpLive(tester, at: '/setup/levels', height: 8000);
    expect(find.byType(SetupLevelsScreen), findsOneWidget);
    final flagsBefore = Map.of(live.workspace.workspaces.first.featureFlags);

    // Choices, not applied: a quick start, then one answer on top.
    await tester.tap(
      find.byKey(ValueKey('setup-preset-${SetupPreset.values.last.name}')),
    );
    await _settle(tester);
    String choices() => [
      for (final p in SetupProcess.values)
        '${p.name}='
            '${tester.widget<DropdownButton<String>>(find.byKey(ValueKey('setup-level-${p.name}'))).value}',
      for (final tile in tester.widgetList<SwitchListTile>(
        find.descendant(
          of: find.byKey(const ValueKey('setup-levels')),
          matching: find.byType(SwitchListTile),
        ),
      ))
        '${tile.value}',
    ].join(',');
    final chosen = choices();

    final example = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('setup-level-demo-'),
    );
    expect(example, findsWidgets, reason: 'a level that adds something has one');
    await tester.ensureVisible(example.first);
    await tester.tap(example.first);
    await _settle(tester);
    await tester.tap(find.byKey(_start));
    await _settle(tester);
    expect(live.inDemo, isTrue);
    expect(find.byType(SetupLevelsScreen), findsNothing,
        reason: 'the live screen is replaced while the demo runs');

    await tester.tap(find.byKey(DemoControls.leaveKey));
    await _settle(tester);
    expect(live.location, '/setup/levels');
    expect(find.byType(SetupLevelsScreen), findsOneWidget);
    expect(choices(), chosen, reason: 'the choices came back as they were');
    expect(live.workspace.workspaces.first.featureFlags, flagsBefore,
        reason: 'the visit applied nothing');
    expect(live.container.read(heldSetupChoicesControllerProvider), isNull,
        reason: 'the held choices are given back once');
  });

  testWidgets('/demo while signed in offers the same visit and returns to '
      'the app\'s home, not to a screen it never had', (tester) async {
    final live = await _pumpLive(tester, at: '/reserve');
    await live.open('/demo?space=pezenas&persona=owner&to=%2Ffeatures');
    expect(find.byKey(_start), findsOneWidget,
        reason: 'the explanation opens by itself');
    await tester.tap(find.byKey(_start));
    await _settle(tester);
    expect(live.inDemo, isTrue);
    expect(live.origin?.route, isNull);
    expect(find.byType(FeaturesScreen), findsOneWidget);

    await tester.tap(find.byKey(DemoControls.leaveKey));
    await _settle(tester);
    expect(live.location, '/reserve');
  });

  testWidgets('the older /auth?demo=1 link opens the same entry for a '
      'signed-in person', (tester) async {
    final live = await _pumpLive(tester, at: '/reserve');
    await live.open('/auth?demo=1&space=pezenas&persona=owner&to=/features');
    expect(live.location, startsWith('/demo'));
    expect(find.byKey(_start), findsOneWidget);
  });

  testWidgets('with the demo switched off, /demo says so and offers no '
      'start', (tester) async {
    final live = await _pumpLive(
      tester,
      at: '/reserve',
      flags: {'demoMode': false},
    );
    await live.open('/demo');
    expect(find.text(englishL10n.demoEntryUnavailable), findsOneWidget);
    expect(find.byKey(_start), findsNothing);
    expect(live.inDemo, isFalse);
  });

  testWidgets('a demo that cannot start says so and leaves the workspace '
      'exactly as it was', (tester) async {
    final live = await _pumpLive(
      tester,
      extra: [demoSessionControllerProvider.overrideWith(_BrokenSession.new)],
    );
    await tester.tap(find.byKey(_tryDemo));
    await _settle(tester);
    await tester.tap(find.byKey(_start));
    await _settle(tester);

    expect(find.text(englishL10n.demoEntryFailed), findsOneWidget);
    expect(live.inDemo, isFalse);
    expect(live.origin, isNull, reason: 'no visit began');
    expect(live.location, '/setup');
    expect(find.byType(SetupGuideScreen), findsOneWidget,
        reason: 'never a real workspace under Demo chrome');
    expect(live.auth.signOuts, 0);
  });

  testWidgets('inside the demo no provider can reach the live backend: the '
      'clients are a refusal, and a whole visit sends the live client '
      'nothing', (tester) async {
    final counting = _CountingClient();
    final live = await _pumpLive(
      tester,
      extra: [
        contextClientsProvider.overrideWith((ref) => ContextClients(counting)),
      ],
    );
    await _consent(tester);
    expect(live.inDemo, isTrue);

    // The Demo container's own clients are the stand-in, never the global
    // client that carries the live session.
    final inside = ProviderScope.containerOf(
      tester.element(find.byType(FeaturesScreen)),
    );
    final clients = inside.read(contextClientsProvider);
    expect(clients.personal, isA<DemoNoBackendClient>());
    expect(clients.legacyActive, isA<DemoNoBackendClient>());
    expect(
      () => clients.personal.from('invoices'),
      throwsA(isA<DemoHasNoBackend>()),
    );
    expect(
      () => inside.read(workspaceClientProvider('any-installation')),
      throwsA(anything),
    );

    await tester.tap(find.byKey(DemoControls.resetKey));
    await _settle(tester);
    await tester.tap(find.byKey(DemoControls.leaveKey));
    await _settle(tester);
    expect(live.inDemo, isFalse);
    expect(counting.uses, 0, reason: 'the live client was never used');
  });
}
