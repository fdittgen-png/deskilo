// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1339 — the journey contracts the suite could not answer for.
//
// The rest of the issue's list was already held somewhere: the tap
// budgets in `tap_budget_test.dart` complete a real booking and a real
// decision, `plan_closed_day_test.dart` proves no seat reads as free
// while the opening days are unresolved, and
// `workspace_settings_screen_test.dart` proves a refused Save writes
// nothing and keeps what was typed. Two contracts had nothing behind
// them, and both are about a SECOND action after the first one went
// somewhere unexpected:
//
//   * a creation that was retried must not create a second space — nor
//     a second twin, which is the half nothing looked at;
//   * a workspace the member switched to must not be shown wearing the
//     previous workspace's permissions.
//
// Each drives the product's own screens from the launch state and reads
// the outcome back off the repository or off what is on screen. Neither
// overrides the thing it is testing: the only overrides are
// `standardTestOverrides`, which replaces the network boundary — a test
// that supplies its own version of the behaviour under test proves
// nothing, which is how #1564 hid behind the demo journeys for weeks.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../features/workspace/onboarding_flow_test.dart'
    show pumpWithoutWorkspace;

/// Jumps the create wizard to a named step, the way its stepper header
/// lets a member jump once the first two steps are filled in.
Future<void> goToStep(WidgetTester tester, String label) async {
  await tester.pump(); // Rebuild enabled progress after the field edit.
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Presses Create and lets the snack that may follow leave, so the next
/// press is not swallowed by it.
Future<void> pressCreate(WidgetTester tester) async {
  final create = find.byKey(const ValueKey('onboarding-create'));
  await tester.ensureVisible(create);
  await tester.tap(create);
  await tester.pumpAndSettle();
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
      .hideCurrentSnackBar();
  await tester.pumpAndSettle();
}

void main() {
  group('onboarding: a retry creates one space, and one pair at most', () {
    testWidgets('the twin the member DECLINED stays declined across a lost '
        'response, and no second call makes one behind their back',
        (tester) async {
      final repo = await pumpWithoutWorkspace(tester)
        ..createFailure = StateError('the response was lost');

      await tester.enterText(find.byType(TextFormField).first, 'Kraftwerk');
      await goToStep(tester, 'Where');
      await tester.tap(find.byKey(const ValueKey('onboarding-with-twin')));
      await tester.pumpAndSettle();
      await goToStep(tester, 'Confirm');

      await pressCreate(tester); // the response is lost
      expect(repo.workspaces, isEmpty, reason: 'the first attempt failed');
      await pressCreate(tester); // the member tries again

      expect(repo.createRequests, hasLength(2),
          reason: 'the member really did press Create twice');
      expect({for (final r in repo.createRequests) r.requestId}, hasLength(1),
          reason: 'one creation, one id, so the server answers the replay '
              'with the space it already made');
      expect(repo.workspaces, hasLength(1),
          reason: 'and one space exists at the end of it');
      expect(
        repo.createRequests.map((r) => r.withTwin),
        everyElement(isFalse),
        reason: 'the member unticked the pair. A retry that re-sent the '
            'default would hand them a production twin they refused, and '
            'the confirm step would have said so on neither attempt',
      );
      expect(repo.twinsCreated, isEmpty,
          reason: 'the twin rides the creation itself (#1303). A separate '
              'createWorkspaceTwin call would run once per retry and is '
              'exactly the duplicate this contract forbids');
      expect(find.byType(ShellBottomBar), findsOneWidget,
          reason: 'and the member is in the app, not staring at the error');
    });

    testWidgets('the twin the member KEPT travels with the one creation',
        (tester) async {
      final repo = await pumpWithoutWorkspace(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Kraftwerk');
      await goToStep(tester, 'Confirm');
      await pressCreate(tester);

      expect(repo.createRequests.single.withTwin, isTrue,
          reason: 'the pair is the default and the confirm step shows it');
      expect(repo.twinsCreated, isEmpty,
          reason: 'still one call: the server makes the pair, the client '
              'does not follow up with a second request that can fail on '
              'its own');
      expect(repo.workspaces, hasLength(1));
    });
  });

  testWidgets('settings: switching workspace cannot show the previous '
      'workspace\'s permissions', (tester) async {
    // Tall enough that every section header of the owner list is built.
    tester.view.physicalSize = const Size(800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // One person, two workspaces: owner of the first, plain member of
    // the second. Nothing here overrides the settings screen or the
    // permission matrix — only the repository they both read.
    final repo = FakeWorkspaceRepository(workspaces: const [
      Workspace(
        id: 'ws-1',
        name: 'Kraftwerk',
        countryCode: 'DE',
        currencyCode: 'EUR',
        timezone: 'Europe/Berlin',
        inviteCode: 'CODEONE111',
        environment: 'prod',
      ),
      Workspace(
        id: 'ws-2',
        name: 'Pezenas',
        countryCode: 'FR',
        currencyCode: 'EUR',
        timezone: 'Europe/Paris',
        inviteCode: 'CODETWO222',
        environment: 'prod',
      ),
    ]);
    repo.extraMyMemberships.add(const Member(
      id: 'member-2',
      workspaceId: 'ws-2',
      userId: 'user-1',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    ));

    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(workspace: repo),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // As the owner of ws-1, the workspace sections are there.
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Governance'), findsOneWidget);
    expect(find.text('This workspace'), findsOneWidget);

    // The member switches profile, the way the product offers it.
    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pezenas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();

    // Back on Settings, and it is the NEW workspace's settings. Being a
    // plain member of Pezenas, none of the three workspace sections may
    // be offered — a tile left over from Kraftwerk would open a screen
    // this member has no right to, and the route would bounce them back
    // with no explanation.
    expect(find.text('Administration'), findsNothing,
        reason: 'the settings list follows the ACTIVE workspace; a member '
            'reading of it is what the second workspace grants');
    expect(find.text('Governance'), findsNothing);
    expect(find.text('This workspace'), findsNothing);
    // And the essentials a member always keeps are still there, so the
    // assertions above are about permissions and not about a screen
    // that failed to build.
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });
}
