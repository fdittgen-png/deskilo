// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step B -- the first visit and the getting-started card. A person with
// no place, no booking and nothing waiting meets the welcome, one hero card
// and the checklist instead of three empty sections; each exit goes where it
// says; the four steps are derived from what the app reads, a source still
// loading or failed never marks one done, and the card leaves when all four
// are done.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/demo/data/profile_repository.dart';
import 'package:deskilo/core/privacy/privacy_policy.dart';
import 'package:deskilo/features/me/domain/getting_started.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/money/domain/finance_hosts.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _home = '0ea54888-a3d7-441f-a025-ee4576cf2fa9';
const _host = MyReservationsSource(
  installationId: 'inst-a',
  workspaceIds: ['ws-1'],
  hostedHere: true,
  labels: ['Pézenas'],
);

class _Hosts implements MyReservationsRepository {
  _Hosts({this.items = const [], this.failing = false});

  final List<MyReservationItem> items;
  final bool failing;

  @override
  Future<MyReservationsLimits> limits() async => const MyReservationsLimits(
    windowDays: 7,
    maxDays: 60,
    concurrency: 4,
    timeout: Duration(seconds: 12),
  );

  @override
  Future<MyReservationsPage> page(
    MyReservationsSource source,
    MyReservationsQuery query,
  ) async {
    if (failing) throw StateError('down');
    return MyReservationsPage(
      source: source.installationId,
      items: items,
      next: null,
      hasMore: false,
    );
  }
}

MyReservationItem _booking() {
  final start = DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1, 9);
  return MyReservationItem(
    id: 'b1',
    workspaceId: 'ws-1',
    workspaceName: 'Pézenas',
    placeKind: MyReservationPlaceKind.desk,
    placeId: 'd1',
    placeLabel: 'Desk 1',
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    status: ReservationStatus.reserved,
    checkedInAt: null,
    checkedOutAt: null,
  );
}

FakeProfileRepository _profile({bool avatar = false, String name = 'Ada Lovelace'}) =>
    FakeProfileRepository(
      profiles: [
        Profile(
          id: 'user-1',
          displayName: name,
          avatarPath: avatar ? 'user-1/avatar' : null,
          privacyAcceptedVersion: kPrivacyPolicyVersion,
          privacyAcceptedAt: DateTime.utc(2026, 8, 30),
        ),
      ],
    );

Future<GoRouter> _pump(
  WidgetTester tester, {
  FakeWorkspaceRepository? workspace,
  _Hosts? hosts,
  FakeProfileRepository? profile,
  FakeMeRepository? me,
  FakeAccountActivityRepository? documents,
  Size size = const Size(420, 2400),
}) => pumpMeApp(
  tester,
  workspace: workspace ?? FakeWorkspaceRepository(workspaces: []),
  profile: profile ?? _profile(),
  me: me,
  accountActivity: documents,
  size: size,
  extraOverrides: <Override>[
    personalShellEnabledProvider.overrideWithValue(true),
    myReservationsRepositoryProvider.overrideWithValue(hosts ?? _Hosts()),
    myReservationsSourcesProvider.overrideWith((ref) async => const [_host]),
  ],
).then((router) async {
  await goTo(tester, router, '/me');
  return router;
});

Finder _key(String k) => find.byKey(ValueKey(k));

/// The state chip text of one getting-started row ('' when it has none).
String _chip(WidgetTester tester, StartedStep step) {
  final row = _key('me-started-${step.name}');
  final texts = tester
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .map((t) => t.data ?? '')
      .toList();
  return ['Done', 'Next'].firstWhere(texts.contains, orElse: () => '');
}

void main() {
  group('the derivation of the four steps', () {
    test('the first one not done is the next, the rest are later', () {
      final rows = startedRows({
        StartedStep.account: true,
        StartedStep.space: false,
        StartedStep.booking: null,
        StartedStep.profile: false,
      });
      expect(rows.map((r) => r.state), [
        StartedState.done,
        StartedState.next,
        StartedState.later,
        StartedState.later,
      ]);
      expect(startedComplete({for (final s in StartedStep.values) s: true}), isTrue);
      expect(
        startedComplete({
          StartedStep.account: true,
          StartedStep.space: true,
          StartedStep.booking: true,
          StartedStep.profile: null,
        }),
        isFalse,
        reason: 'a fact still unknown is not done',
      );
    });
  });

  group('a new account', () {
    testWidgets('meets the welcome, one hero card and the checklist', (tester) async {
      await _pump(tester);
      expect(_key('me-first-visit'), findsOneWidget);
      expect(find.text('Welcome, Ada'), findsOneWidget);
      expect(find.text('What are you looking for?'), findsOneWidget);
      expect(_key('me-overview-next'), findsNothing);
      expect(_key('me-overview-attention'), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(_key('me-first-visit-browse'), findsOneWidget);
      expect(_chip(tester, StartedStep.account), 'Done');
      expect(_chip(tester, StartedStep.space), 'Next');
      expect(_chip(tester, StartedStep.booking), '');
      expect(_chip(tester, StartedStep.profile), '');
    });

    // #3682 — a connected installation whose documents could not be read
    // leaves "nothing waits" undecided: no welcome over an unread debt.
    testWidgets('a connected host whose documents failed: no first visit', (
      tester,
    ) async {
      final documents = FakeAccountActivityRepository()
        ..financeOverview = const FinanceOverview(
          hosts: [
            FinanceHostRead(
              FinanceHost(installationId: 'inst-b', workspaceIds: ['ws-b']),
              FinanceHostStatus.failed,
            ),
          ],
        );
      await _pump(tester, documents: documents);
      expect(_key('me-first-visit'), findsNothing);
      expect(_key('me-overview-documents-partial'), findsOneWidget);
    });

    testWidgets('the search field opens Discover with the search focused; Browse places opens it plain', (tester) async {
      var router = await _pump(tester);
      await tester.tap(_key('me-first-visit-search'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), contains('discover'));
      expect(router.state.uri.queryParameters['focus'], 'search');
      router = await _pump(tester);
      await tester.tap(_key('me-first-visit-browse'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), contains('discover'));
      expect(router.state.uri.queryParameters['focus'], isNull);
    });

    testWidgets('the hint is not cut off at 320 px', (tester) async {
      // The app's own font: the test font is far wider than any real text.
      final font = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      await font.load();
      await _pump(tester, size: const Size(320, 2400));
      final hint = find.text('Yoga, a desk, a massage…');
      expect(hint, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(hint);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the invitation card and the business link lead to onboarding', (tester) async {
      var router = await _pump(tester);
      await tester.tap(_key('me-first-visit-invitation'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/onboarding?join=1');
      router = await _pump(tester);
      await tester.tap(_key('me-first-visit-run'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/onboarding');
    });
  });

  group('after the first steps', () {
    testWidgets('a pending request is a step done; Home is the normal one with one line at its end', (tester) async {
      final me = FakeMeRepository()
        ..workspaceRefs = const PersonalWorkspaceRefs(
          homeInstallationId: _home,
          refs: [
            PersonalWorkspaceRef(
              networkId: '$_home:00000000-0000-4000-8000-00002554c201',
              hostedHere: true,
              freshness: RefFreshness.local,
              status: RefStatus.pending,
              label: 'Leipzig Hub',
            ),
          ],
        );
      await _pump(tester, me: me);
      expect(_key('me-first-visit'), findsNothing);
      expect(_key('me-getting-started'), findsNothing);
      expect(
        find.descendant(
          of: _key('me-first-steps-row'),
          matching: find.text('2 steps left · Make your first booking'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the line sits at the end of Home, below the sections', (tester) async {
      await _pump(
        tester,
        workspace: twoSpaces(),
        hosts: _Hosts(items: [_booking()]),
      );
      final row = tester.getTopLeft(_key('me-first-steps-row')).dy;
      expect(row, greaterThan(tester.getTopLeft(_key('me-overview-next')).dy));
      expect(row, greaterThan(tester.getTopLeft(_key('me-overview-attention')).dy));
      expect(
        find.descendant(
          of: _key('me-first-steps-row'),
          matching: find.text('One step left · Add your name and photo'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('all four done: nothing is left to say', (tester) async {
      await _pump(
        tester,
        workspace: twoSpaces(),
        hosts: _Hosts(items: [_booking()]),
        profile: _profile(avatar: true),
      );
      expect(_key('me-first-visit'), findsNothing);
      expect(_key('me-first-steps-row'), findsNothing);
    });

    testWidgets('a host that fails never marks the booking done', (tester) async {
      await _pump(tester, workspace: twoSpaces(), hosts: _Hosts(failing: true));
      expect(_key('me-first-visit'), findsNothing);
      expect(
        find.descendant(
          of: _key('me-first-steps-row'),
          matching: find.textContaining('Make your first booking'),
        ),
        findsNothing,
      );
    });
  });
}
