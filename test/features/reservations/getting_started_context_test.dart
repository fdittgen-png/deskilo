// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1654 — the Get started card keeps its shape and its scope: it lays
// out at 360 dp, sideways, wide, with large text and with motion off;
// its buttons are 48 dp and read as buttons; it speaks the reader's
// language; a dismissal belongs to installation + account + workspace
// and survives a sign-out without leaking to another account or
// another installation; a workspace switched while the first one's
// membership is still loading shows the SECOND workspace's facts and
// never the late answer of the first; and a Demo session's dismissal
// reaches no device store and sends nothing anywhere.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/help/help_hint_providers.dart';
import 'package:deskilo/features/auth/presentation/screens/auth_screen.dart';
import 'package:deskilo/features/reservations/application/getting_started_hint.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/mock_providers.dart';
import 'getting_started_card_test.dart' show kOrdinaryMember, pumpCard;

const _card = ValueKey('getting-started-card');
const _title = ValueKey('getting-started-title');
const _primary = ValueKey('getting-started-primary');
const _dismiss = ValueKey('getting-started-dismiss');

Workspace _space(String id, String name) => Workspace(
      id: id,
      name: name,
      countryCode: 'DE',
      currencyCode: 'EUR',
      timezone: 'Europe/Berlin',
      inviteCode: 'CODE-$id',
      environment: 'prod',
    );

/// Two workspaces; A's membership answers only when the test says so.
class _SlowA extends FakeWorkspaceRepository {
  _SlowA()
      : super(workspaces: [_space('ws-1', 'Space A'), _space('ws-2', 'Space B')]) {
    this.myMember = kOrdinaryMember.copyWith(isOwner: true, isAdmin: true);
    extraMyMemberships.add(
      kOrdinaryMember.copyWith(id: 'member-b', workspaceId: 'ws-2'),
    );
    this.openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7];
    this.openWeekdays['ws-2'] = const [1, 2, 3, 4, 5, 6, 7];
  }

  final a = Completer<Member?>();

  @override
  Future<Member?> fetchMyMember(String workspaceId) =>
      workspaceId == 'ws-1' ? a.future : super.fetchMyMember(workspaceId);
}

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data ?? '';

void _noOverflow(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byKey(_card), findsOneWidget);
  expect(find.byKey(_primary), findsOneWidget);
  expect(find.byKey(_dismiss), findsOneWidget);
}

void main() {
  group('layout', () {
    testWidgets('360 dp: the card fits and both targets keep 48 dp',
        (tester) async {
      await pumpCard(tester, size: const Size(360, 640));
      _noOverflow(tester);
      for (final key in [_primary, _dismiss]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$key');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$key');
      }
      final width = tester.getSize(find.byKey(_card)).width;
      expect(width, lessThanOrEqualTo(360));
    });

    testWidgets('short landscape: the card sits in the side panel',
        (tester) async {
      await pumpCard(tester, size: const Size(640, 360));
      _noOverflow(tester);
    });

    testWidgets('wide: nothing stretches out of shape', (tester) async {
      await pumpCard(tester, size: const Size(1400, 1000));
      _noOverflow(tester);
    });

    testWidgets('large text at 360 dp: the buttons wrap, nothing overflows',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpCard(tester, size: const Size(360, 640));
      _noOverflow(tester);
      // Stacked rather than side by side: the primary is BELOW Not now.
      final dismiss = tester.getRect(find.byKey(_dismiss));
      final primary = tester.getRect(find.byKey(_primary));
      expect(primary.top, greaterThanOrEqualTo(dismiss.bottom - 1));
      await tester.ensureVisible(find.byKey(_primary));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_primary));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('reduced motion (uiAnimations off): the card renders at once',
        (tester) async {
      await pumpCard(tester, featureFlags: {'uiAnimations': false});
      _noOverflow(tester);
    });
  });

  group('semantics', () {
    testWidgets('Tab moves from Not now to the suggestion and Enter opens it',
        (tester) async {
      await pumpCard(tester);
      final dismiss = find.descendant(of: find.byKey(_dismiss),
        matching: find.byType(GestureDetector)).first;
      Focus.of(tester.element(dismiss)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final primary = find.descendant(of: find.byKey(_primary),
        matching: find.byType(GestureDetector)).first;
      expect(Focus.of(tester.element(primary)).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('the title is a header, the actions are buttons, and the '
        'reading order is Not now then the suggestion', (tester) async {
      await pumpCard(tester);
      expect(
        tester.getSemantics(find.byKey(_title)),
        matchesSemantics(isHeader: true, label: 'Get started in Test Space'),
      );
      expect(
        tester.getSemantics(find.byKey(_primary)),
        matchesSemantics(
          label: 'Choose a time to book',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_dismiss)),
        matchesSemantics(
          label: 'Not now',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
        ),
      );
      // Secondary before primary, left to right: the destructive-looking
      // choice is never the one a hurried thumb lands on last.
      expect(
        tester.getRect(find.byKey(_dismiss)).right,
        lessThanOrEqualTo(tester.getRect(find.byKey(_primary)).left),
      );
    });
  });

  group('languages', () {
    for (final code in const ['en', 'fr', 'de', 'es', 'it']) {
      testWidgets('$code: title, suggestion and Not now in the language',
          (tester) async {
        final l = lookupAppLocalizations(Locale(code));
        await pumpCard(tester, languageCode: code);
        expect(_text(tester, _title), l.gettingStartedTitle('Test Space'));
        expect(find.text(l.gettingStartedActionChooseTime), findsOneWidget);
        expect(find.text(l.gettingStartedNotNow), findsOneWidget);
        expect(find.textContaining(l.gettingStartedStandingMember),
            findsOneWidget);
      });
    }
  });

  group('scope of a dismissal', () {
    for (final endpoint in ['https://b.example.org', 'https://a.example.org:8443']) {
    testWidgets('the same workspace id at $endpoint has its own dismissal', (tester) async {
      final hub = await pumpCard(
        tester,
        backendSettings: InMemoryBackendSettingsStore()
          ..value = const BackendEndpoint('https://a.example.org', 'k'),
      );
      await tester.tap(find.byKey(_dismiss));
      await tester.pumpAndSettle();
      expect(hub.hints.dismissed.single, contains(':https://a.example.org:'));
      await pumpCard(
        tester,
        hints: hub.hints,
        backendSettings: InMemoryBackendSettingsStore()
          ..value = BackendEndpoint(endpoint, 'k'),
      );
      expect(find.byKey(_card), findsOneWidget,
          reason: 'B never heard of A\'s answer, whatever the ids say');
      expect(hub.hints.dismissed, hasLength(1));
    });

    }

    testWidgets('a sign-out keeps the device answer for that account, and '
        'the next account gets its own card', (tester) async {
      final auth = FakeAuthRepository.signedIn();
      final hub = await pumpCard(tester, auth: auth);
      await tester.tap(find.byKey(_dismiss));
      await tester.pumpAndSettle();
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(hub.hints.dismissed, hasLength(1),
          reason: 'signing out is not a reset of the device preference');

      // Same account again: nothing to show.
      await pumpCard(tester, hints: hub.hints, auth: FakeAuthRepository.signedIn());
      expect(find.byKey(_card), findsNothing);
      // Another account on this phone: its own card.
      await pumpCard(
        tester,
        hints: hub.hints,
        auth: FakeAuthRepository(userId: 'user-2'),
        member: kOrdinaryMember.copyWith(id: 'member-2', userId: 'user-2'),
      );
      expect(find.byKey(_card), findsOneWidget);
    });
  });

  group('a switch while the first workspace is still loading', () {
    testWidgets('the card shows B, and A\'s late answer never marks B',
        (tester) async {
      final repo = _SlowA();
      final plans = FakeFloorPlanRepository()
        ..seedSmallPlan()
        ..seedSmallPlan(workspaceId: 'ws-2');
      await pumpCard(tester, workspace: repo, plans: plans);
      // A's membership is still in flight: nothing is suggested yet.
      expect(find.byKey(_card), findsNothing);

      final container =
          ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
      await container.read(activeWorkspaceIdProvider.notifier).select('ws-2');
      await tester.pumpAndSettle();
      expect(_text(tester, _title), 'Get started in Space B');
      expect(find.textContaining('You are a member here.'), findsOneWidget);

      // A answers late, and as an OWNER: B's card must not change.
      repo.a.complete(kOrdinaryMember.copyWith(isOwner: true, isAdmin: true));
      await tester.pumpAndSettle();
      expect(_text(tester, _title), 'Get started in Space B');
      expect(find.textContaining('You are a member here.'), findsOneWidget);
      expect(find.textContaining('owner'), findsNothing);
    });
  });

  group('Demo', () {
    testWidgets('a dismissal inside a demonstration reaches no device store '
        'and sends nothing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fixture = DemoFixture.build();
      final container = ProviderContainer(overrides: demoOverrides(fixture));
      addTearDown(container.dispose);
      final key = gettingStartedSeenKey(
        installation: 'demo',
        accountId: 'demo-visitor',
        workspaceId: 'demo-space',
      )!;
      await container.read(dismissedHelpHintsProvider.future);
      await container.read(dismissedHelpHintsProvider.notifier).dismiss(key);
      expect(fixture.prefs.helpHints.dismissed, contains(key));
      final device = await SharedPreferences.getInstance();
      expect(device.getKeys(), isEmpty,
          reason: 'the demonstration writes to its own copy, never the phone');
      expect(fixture.outward.nothingLeft, isTrue,
          reason: 'no network, no share, no file left the demonstration');
    });
  });
}
