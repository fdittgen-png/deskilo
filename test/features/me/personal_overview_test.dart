// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 C2 — the Overview under the personal shell: "Your day, in one
// place" and three sections, each read on its own. Success (the earliest
// standing booking across hosts, my unpaid production documents in their
// own currencies, my unread conversations and undecided requests, each
// record once; the first spaces), refusal (a host, my documents or my
// conversations that cannot be read are said with their own Try again
// while the other sections stay), recovery (Try again reads them), a
// searched period that holds nothing, and the 2:1 layout when wide.
import 'package:deskilo/core/demo/data/account_activity_repository.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/privacy/privacy_policy.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/me/application/personal_overview.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/money/domain/finance_hosts.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/my_reservations_composition.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_profile_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/my_finances_screen.dart' show invoice;
import 'me_app.dart';

const _home = '0ea54888-a3d7-441f-a025-ee4576cf2fa9';
const _pending = '00000000-0000-4000-8000-00002554c201';

const _a = MyReservationsSource(
  installationId: 'inst-a',
  workspaceIds: ['ws-1'],
  hostedHere: true,
  labels: ['Pézenas'],
);
const _b = MyReservationsSource(
  installationId: 'inst-b',
  workspaceIds: ['ws-b'],
  labels: ['Leipzig'],
);

const _lyonDocs = FinanceHost(
  installationId: 'inst-lyon',
  workspaceIds: ['ws-Lyon'],
  labels: ['Lyon'],
);

DateTime _day(int offset, int hour) =>
    DateTime(kTestNow.year, kTestNow.month, kTestNow.day + offset, hour);

MyReservationItem _item(
  String id,
  DateTime start, {
  ReservationStatus status = ReservationStatus.reserved,
  String workspace = 'Pézenas',
}) => MyReservationItem(
  id: id,
  workspaceId: 'ws-1',
  workspaceName: workspace,
  placeKind: MyReservationPlaceKind.desk,
  placeId: 'desk-$id',
  placeLabel: 'Desk $id',
  startsAt: start,
  endsAt: start.add(const Duration(hours: 2)),
  status: status,
  checkedInAt: null,
  checkedOutAt: null,
);

/// Each host answers what the test set: its page, or a failure.
class _Hosts implements MyReservationsRepository, MyReservationActions {
  final Map<String, List<MyReservationItem>> items = {};
  final Map<String, Exception> failures = {};
  Exception? limitsFailure;
  final List<String> checkedIn = [];

  @override
  Future<MyReservationItem> view(
    MyReservationsSource source,
    MyReservationItem item,
  ) async => item;

  @override
  Future<void> cancel(MyReservationsSource source, MyReservationItem item) async {}

  @override
  Future<void> checkIn(
    MyReservationsSource source,
    MyReservationItem item,
  ) async => checkedIn.add(item.id);

  @override
  Future<MyReservationsLimits> limits() async {
    final refused = limitsFailure;
    if (refused != null) throw refused;
    return const MyReservationsLimits(
      windowDays: 7,
      maxDays: 60,
      concurrency: 4,
      timeout: Duration(seconds: 12),
    );
  }

  @override
  Future<MyReservationsPage> page(
    MyReservationsSource source,
    MyReservationsQuery query,
  ) async {
    final refused = failures[source.installationId];
    if (refused != null) throw refused;
    return MyReservationsPage(
      source: source.installationId,
      items: items[source.installationId] ?? const [],
      next: null,
      hasMore: false,
    );
  }
}

Map<String, dynamic> _row(String id, int unread, {bool muted = false}) => {
  'context_kind': 'space',
  'context_id': id,
  'workspace_id': 'ws-1',
  'workspace_name': 'Pézenas',
  'title': 'Thread $id',
  'unread': unread,
  'last_at': '2026-05-13T08:00:00Z',
  if (muted) ...{'pinned': false, 'muted': true, 'archived': false},
};

PersonalWorkspaceRefs _refsWithRequest() => const PersonalWorkspaceRefs(
  homeInstallationId: _home,
  refs: [
    PersonalWorkspaceRef(
      networkId: '$_home:$_pending',
      hostedHere: true,
      freshness: RefFreshness.local,
      status: RefStatus.pending,
      label: 'Leipzig Hub',
    ),
  ],
);

Finder _key(String key) => find.byKey(ValueKey(key));

Future<GoRouter> _pump(
  WidgetTester tester, {
  _Hosts? hosts,
  List<MyReservationsSource> sources = const [_a],
  FakeAccountActivityRepository? documents,
  FakeMessengerRepository? messenger,
  FakeMeRepository? me,
  FakeWorkspaceRepository? workspace,
  Size size = const Size(420, 2600),
  bool shell = true,
}) async {
  final host = hosts ?? _Hosts();
  final router = await pumpMeApp(
    tester,
    workspace: workspace ?? twoSpaces(),
    me: me,
    accountActivity: documents,
    messenger: messenger,
    size: size,
    extraOverrides: <Override>[
      personalShellEnabledProvider.overrideWithValue(shell),
      myReservationsRepositoryProvider.overrideWithValue(host),
      myReservationActionsProvider.overrideWithValue(host),
      myReservationsSourcesProvider.overrideWith((ref) async => sources),
    ],
  );
  await goTo(tester, router, '/me');
  return router;
}

/// The Home greeting at [hour] for a person named [name] ('' = none yet).
Future<void> _greeting(WidgetTester tester, int hour, String name) async {
  final profile = FakeProfileRepository(
    profiles: [
      Profile(
        id: 'user-1',
        displayName: name,
        privacyAcceptedVersion: kPrivacyPolicyVersion,
        privacyAcceptedAt: DateTime.utc(2026, 8, 30),
      ),
    ],
  );
  final router = await pumpMeApp(
    tester,
    workspace: twoSpaces(),
    size: const Size(420, 2600),
    profile: profile,
    timeZoneMode: TimeZoneMode.device,
    clock: FixedClock(DateTime(kTestNow.year, kTestNow.month, kTestNow.day, hour)),
    extraOverrides: <Override>[personalShellEnabledProvider.overrideWithValue(true)],
  );
  await goTo(tester, router, '/me');
}

void main() {
  group('the greeting', () {
    for (final (hour, wording) in [
      (8, 'Good morning, Ada'),
      (14, 'Good afternoon, Ada'),
      (20, 'Good evening, Ada'),
    ]) {
      testWidgets('at $hour:00 says "$wording" and the date', (tester) async {
        await _greeting(tester, hour, 'Ada Lovelace');
        expect(find.text(wording), findsOneWidget);
        expect(_key('me-overview-date'), findsOneWidget);
      });
    }

    testWidgets('without a name it welcomes', (tester) async {
      await _greeting(tester, 8, '');
      expect(find.text('Welcome'), findsOneWidget);
    });
  });

  group('the next commitment', () {
    MyReservationsComposition composed(
      List<MyReservationItem> a, {
      List<MyReservationItem> b = const [],
      bool bFailed = false,
      bool bReading = false,
    }) => MyReservationsComposition([
      MyReservationsSlot.firstPage(
        _a,
        MyReservationsPage(
          source: 'inst-a',
          items: a,
          next: null,
          hasMore: false,
        ),
      ),
      if (bFailed)
        MyReservationsSlot.failed(_b, StateError('down'))
      else if (bReading)
        const MyReservationsSlot.reading(_b)
      else
        MyReservationsSlot.firstPage(
          _b,
          MyReservationsPage(
            source: 'inst-b',
            items: b,
            next: null,
            hasMore: false,
          ),
        ),
    ]);

    test('is the earliest standing booking still to come, across hosts', () {
      final next = nextCommitmentOf(
        composed(
          [
            _item('over', _day(0, 6)),
            _item('cancelled', _day(1, 9), status: ReservationStatus.cancelled),
            _item('later', _day(3, 9)),
          ],
          b: [_item('soon', _day(2, 9))],
        ),
        kTestNow,
      );
      expect(next.commitment?.id, 'soon');
      expect(next.commitment?.source, 'inst-b');
      expect(next.complete, isTrue);
      expect(next.failed, isEmpty);
    });

    test('a booking under way still counts; released and completed ones '
        'do not', () {
      final next = nextCommitmentOf(
        composed([
          _item('released', _day(0, 9), status: ReservationStatus.released),
          _item('done', _day(0, 9), status: ReservationStatus.completed),
          _item('now', _day(0, 9), status: ReservationStatus.checkedIn),
        ]),
        kTestNow,
      );
      expect(next.commitment?.id, 'now');
    });

    test('a host that failed or is still read keeps the answer from being '
        'complete', () {
      final failed = nextCommitmentOf(
        composed(const [], bFailed: true),
        kTestNow,
      );
      expect(failed.commitment, isNull);
      expect(failed.complete, isFalse);
      expect(failed.failed.single.sourceId, 'inst-b');
      final reading = nextCommitmentOf(
        composed(const [], bReading: true),
        kTestNow,
      );
      expect(reading.reading, isTrue);
      expect(reading.complete, isFalse);
    });
  });

  group('what needs attention', () {
    test('my unpaid documents, overdue first, each once and in its own '
        'currency; a request of mine the host itself holds; a conversation '
        'with unread messages that I did not mute', () {
      const eur = OwedDocument(
        id: 'eur',
        workspaceId: 'ws-One',
        workspaceName: 'One',
        number: 'INV-eur',
        remainingCents: 10000,
        currency: 'EUR',
      );
      const chf = OwedDocument(
        id: 'chf',
        workspaceId: 'ws-Two',
        workspaceName: 'Two',
        number: 'INV-chf',
        remainingCents: 8000,
        currency: 'CHF',
        overdue: true,
      );
      final items = attentionItems(
        documents: const [eur, chf, eur],
        refs: PersonalWorkspaceRefs(
          homeInstallationId: _home,
          refs: [
            ..._refsWithRequest().refs,
            const PersonalWorkspaceRef(
              networkId: '$_home:00000000-0000-4000-8000-00002554c202',
              hostedHere: false,
              freshness: RefFreshness.stale,
              status: RefStatus.pending,
            ),
          ],
        ),
        inbox: UnifiedInbox([
          InboxEntry.fromRow(_row('c1', 2))!,
          InboxEntry.fromRow(_row('c1', 2))!,
          InboxEntry.fromRow(_row('c2', 3, muted: true))!,
          InboxEntry.fromRow(_row('c3', 0))!,
        ]),
      );
      expect(items.map((i) => i.key), [
        'document|ws-Two|chf',
        'document|ws-One|eur',
        'application|$_home:$_pending',
        'conversation||space|c1',
      ]);
      expect(items.first.overdue, isTrue);
      expect(items.first.document?.currency, 'CHF');
      expect(items[1].document?.currency, 'EUR');
    });

    test('a source that was not read adds nothing', () {
      expect(attentionItems(), isEmpty);
    });
  });

  group('the Overview', () {
    testWidgets('HOME-01: the header, the next booking across hosts, what '
        'waits for me and my spaces; each action leads to its record', (
      tester,
    ) async {
      final hosts = _Hosts()
        ..items['inst-a'] = [_item('later', _day(3, 9))]
        ..items['inst-b'] = [_item('soon', _day(2, 9), workspace: 'Leipzig')];
      final documents = FakeAccountActivityRepository()
        ..financeOverview = FinanceOverview(
          invoices: [
            invoice('paid', ws: 'One', state: FinanceState.paid),
            invoice('test', ws: '2', due: DateTime(2000)),
            invoice('eur', ws: 'One', due: DateTime(2999)),
            invoice(
              'chf',
              ws: 'Two',
              total: 8000,
              currency: 'CHF',
              due: DateTime(2999),
            ),
          ],
        );
      final messenger = FakeMessengerRepository()..inboxRows.add(_row('c1', 2));
      final me = FakeMeRepository()..workspaceRefs = _refsWithRequest();
      // ws-2 is a development space: its test document never counts.
      final spaces = twoSpaces();
      spaces.workspaces[1] = spaces.workspaces[1].copyWith(environment: 'dev');
      final router = await _pump(
        tester,
        hosts: hosts,
        sources: const [_a, _b],
        documents: documents,
        messenger: messenger,
        me: me,
        workspace: spaces,
      );

      expect(_key('me-overview-greeting'), findsOneWidget);
      expect(_key('me-overview-expanded'), findsNothing);
      expect(_key('me-overview-next-inst-b-soon'), findsOneWidget);
      expect(find.text('Desk soon'), findsOneWidget);
      expect(find.text('Desk later'), findsNothing);
      expect(_key('me-overview-document|ws-One|eur'), findsOneWidget);
      expect(_key('me-overview-document|ws-Two|chf'), findsOneWidget);
      expect(
        find.textContaining('CHF'),
        findsOneWidget,
        reason: 'each currency is said on its own, never summed',
      );
      expect(_key('me-overview-application|$_home:$_pending'), findsOneWidget);
      expect(
        find.text('Your request to join Leipzig Hub is pending.'),
        findsOneWidget,
      );
      expect(_key('me-overview-conversation||space|c1'), findsOneWidget);
      expect(find.text('2 unread messages'), findsOneWidget);
      expect(_key('me-overview-attention-none'), findsNothing);
      // One row per document: what and where in the title, the due day on its
      // second line, a chip for its state; the whole row is one named button.
      expect(find.text('Invoice INV-eur · One'), findsOneWidget);
      expect(find.text('Invoice INV-chf · Two'), findsOneWidget);
      expect(find.text('To pay'), findsNWidgets(2));
      expect(find.textContaining('Due '), findsNWidgets(2));
      final named = tester.getSemantics(
        _key('me-overview-action-document|ws-One|eur'),
      );
      expect(named.label, 'Invoice INV-eur · One. Due Jan 1, 2999');
      expect(named.getSemanticsData().flagsCollection.isButton, isTrue);
      // My places: compact rows say where I stand, never the server.
      expect(find.text('Request sent · waiting for an answer'), findsOneWidget);
      expect(find.text('On this server'), findsNothing);
      expect(find.textContaining('Membership verified'), findsNothing);
      expect(
        _key('my-space-open-$_home:$_pending'),
        findsNothing,
        reason: 'a pending request has no Book',
      );

      // Compact: Next commitment, then Needs attention, then My spaces.
      final next = tester.getTopLeft(_key('me-overview-next')).dy;
      final attention = tester.getTopLeft(_key('me-overview-attention')).dy;
      final mine = tester.getTopLeft(_key('me-overview-spaces')).dy;
      expect(next < attention && attention < mine, isTrue);

      await tapIn(
        tester,
        'me-home-list',
        _key('me-overview-action-document|ws-One|eur'),
      );
      expect(
        router.state.uri.toString(),
        '/me/data?view=finances&workspace=ws-One',
      );
      await goTo(tester, router, '/me');
      expect(
        find.descendant(
          of: _key('me-overview-next-action'),
          matching: find.text('Details'),
        ),
        findsOneWidget,
        reason: 'a booking days away is not checked into: Details',
      );
      await tapIn(tester, 'me-home-list', _key('me-overview-next-action'));
      expect(router.state.uri.toString(), '/me/data?view=reservations');
    });

    testWidgets('wide, the sections stand 2:1: Next commitment and My spaces '
        'on the left, Needs attention on the right', (tester) async {
      final hosts = _Hosts()..items['inst-a'] = [_item('soon', _day(1, 9))];
      await _pump(tester, hosts: hosts, size: const Size(1600, 1400));
      expect(_key('me-overview-expanded'), findsOneWidget);
      final next = tester.getRect(_key('me-overview-next'));
      final attention = tester.getRect(_key('me-overview-attention'));
      final spaces = tester.getRect(_key('me-overview-spaces'));
      expect(attention.left, greaterThan(next.right));
      expect(attention.width, greaterThanOrEqualTo(290));
      expect(next.width, closeTo(attention.width * 2, 1));
      expect(spaces.left, next.left);
      expect(spaces.top, greaterThan(next.bottom));
    });

    testWidgets('every host answered and none holds a booking: the period '
        'is said, not "nothing ever"; nothing waits', (tester) async {
      await _pump(tester);
      expect(_key('me-overview-next-none'), findsOneWidget);
      expect(find.text('Nothing booked this week.'), findsOneWidget);
      expect(_key('me-overview-attention-none'), findsOneWidget);
      expect(_key('me-overview-next-view'), findsNothing);
      expect(
        find.descendant(
          of: _key('me-overview-next'),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
        reason: 'Next up has one filled action: Book',
      );
    });

    testWidgets('inside the check-in window the one filled action is '
        'Check in, and it checks in', (tester) async {
      final hosts = _Hosts()
        ..items['inst-a'] = [
          _item('now', kTestNow.add(const Duration(minutes: 5))),
        ];
      await _pump(tester, hosts: hosts);
      expect(
        find.descendant(
          of: _key('me-overview-next-action'),
          matching: find.text('Check in'),
        ),
        findsOneWidget,
      );
      await tapIn(tester, 'me-home-list', _key('me-overview-next-action'));
      await tester.pumpAndSettle();
      expect(hosts.checkedIn, ['now']);
    });

    testWidgets('a host that cannot be read is said with its own Try again; '
        'the other host\'s booking and the other sections stay; Try again '
        'reads it', (tester) async {
      final hosts = _Hosts()
        ..items['inst-a'] = [_item('later', _day(3, 9))]
        ..items['inst-b'] = [_item('soon', _day(2, 9))]
        ..failures['inst-b'] = Exception('down');
      final messenger = FakeMessengerRepository()..inboxRows.add(_row('c1', 1));
      await _pump(
        tester,
        hosts: hosts,
        sources: const [_a, _b],
        messenger: messenger,
      );
      expect(_key('me-overview-next-failed-inst-b'), findsOneWidget);
      expect(
        find.text('The bookings of Leipzig could not be read.'),
        findsOneWidget,
      );
      expect(_key('me-overview-next-inst-a-later'), findsOneWidget);
      expect(_key('me-overview-conversation||space|c1'), findsOneWidget);
      expect(_key('me-home-all-spaces'), findsOneWidget);

      hosts.failures.clear();
      await tapIn(
        tester,
        'me-home-list',
        find.descendant(
          of: _key('me-overview-next-failed-inst-b'),
          matching: find.text('Try again'),
        ),
      );
      expect(_key('me-overview-next-failed-inst-b'), findsNothing);
      expect(_key('me-overview-next-inst-b-soon'), findsOneWidget);
    });

    testWidgets('bookings that cannot be read at all are unavailable, never '
        'empty; Try again reads them', (tester) async {
      final hosts = _Hosts()
        ..items['inst-a'] = [_item('soon', _day(1, 9))]
        ..limitsFailure = Exception('no settings');
      await _pump(tester, hosts: hosts);
      expect(_key('me-overview-next-unavailable'), findsOneWidget);
      expect(_key('me-overview-next-none'), findsNothing);
      expect(_key('me-overview-attention'), findsOneWidget);

      hosts.limitsFailure = null;
      await tapIn(
        tester,
        'me-home-list',
        find.descendant(
          of: _key('me-overview-next-unavailable'),
          matching: find.text('Try again'),
        ),
      );
      expect(_key('me-overview-next-inst-a-soon'), findsOneWidget);
    });

    testWidgets('my documents that cannot be read are unavailable with Try '
        'again, never "nothing to pay"; my conversations still show', (
      tester,
    ) async {
      final documents = FakeAccountActivityRepository()
        ..unavailable = true
        ..financeOverview = FinanceOverview(
          invoices: [invoice('eur', ws: 'One', due: DateTime(2999))],
        );
      final messenger = FakeMessengerRepository()..inboxRows.add(_row('c1', 1));
      await _pump(tester, documents: documents, messenger: messenger);
      expect(_key('me-overview-documents-unavailable'), findsOneWidget);
      expect(_key('me-overview-attention-none'), findsNothing);
      expect(_key('me-overview-conversation||space|c1'), findsOneWidget);

      documents.unavailable = false;
      await tapIn(
        tester,
        'me-home-list',
        find.descendant(
          of: _key('me-overview-documents-unavailable'),
          matching: find.text('Try again'),
        ),
      );
      expect(_key('me-overview-documents-unavailable'), findsNothing);
      expect(_key('me-overview-document|ws-One|eur'), findsOneWidget);
    });

    testWidgets('a messenger that does not answer is said, not counted as '
        'nothing waiting', (tester) async {
      final messenger = FakeMessengerRepository()..fail = true;
      await _pump(tester, messenger: messenger);
      expect(_key('me-overview-messages-partial'), findsOneWidget);
      expect(_key('me-overview-attention-none'), findsNothing);
    });

    testWidgets('my spaces that cannot be read are unavailable; the other '
        'sections stay; Try again reads them', (tester) async {
      final me = FakeMeRepository()..refsFailure = Exception('down');
      final hosts = _Hosts()..items['inst-a'] = [_item('soon', _day(1, 9))];
      await _pump(tester, me: me, hosts: hosts);
      expect(_key('me-overview-spaces-unavailable'), findsOneWidget);
      expect(_key('me-overview-applications-unavailable'), findsOneWidget);
      expect(_key('me-overview-next-inst-a-soon'), findsOneWidget);

      me.refsFailure = null;
      await tapIn(
        tester,
        'me-home-list',
        find.descendant(
          of: _key('me-overview-spaces-unavailable'),
          matching: find.text('Try again'),
        ),
      );
      expect(_key('me-overview-spaces-unavailable'), findsNothing);
      expect(_key('me-home-all-spaces'), findsOneWidget);
    });

    // #3682 — a connected installation's documents not read yet, or not at
    // all, never let the section say that nothing needs me.
    testWidgets('a connected host whose documents failed: partial, never '
        '"nothing needs you"', (tester) async {
      final documents = FakeAccountActivityRepository()
        ..financeOverview = const FinanceOverview(
          hosts: [FinanceHostRead(_lyonDocs, FinanceHostStatus.failed)],
        );
      await _pump(tester, documents: documents);
      expect(_key('me-overview-documents-partial'), findsOneWidget);
      expect(_key('me-overview-attention-none'), findsNothing);
    });

    testWidgets('a connected host whose documents are still read: reading, '
        'never "nothing needs you"', (tester) async {
      final documents = FakeAccountActivityRepository()
        ..financeOverview = const FinanceOverview(
          hosts: [FinanceHostRead(_lyonDocs, FinanceHostStatus.reading)],
        );
      final router = await pumpMeApp(
        tester,
        workspace: twoSpaces(),
        accountActivity: documents,
        size: const Size(420, 2600),
        extraOverrides: <Override>[
          personalShellEnabledProvider.overrideWithValue(true),
          myReservationsRepositoryProvider.overrideWithValue(_Hosts()),
          myReservationActionsProvider.overrideWithValue(_Hosts()),
          myReservationsSourcesProvider.overrideWith((ref) async => const [_a]),
        ],
      );
      router.go('/me');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_key('me-overview-attention-loading'), findsOneWidget);
      expect(_key('me-overview-attention-none'), findsNothing);
    });

    testWidgets('an invoice whose payment is being validated is not to pay '
        'and never overdue', (tester) async {
      final documents = FakeAccountActivityRepository()
        ..financeOverview = FinanceOverview(
          invoices: [
            invoice(
              'paid',
              ws: 'One',
              state: FinanceState.awaitingValidation,
              due: DateTime(2000),
            ),
          ],
        );
      await _pump(tester, documents: documents);
      expect(_key('me-overview-document|ws-One|paid'), findsNothing);
      expect(find.text('Overdue'), findsNothing);
      expect(find.text('To pay'), findsNothing);
      expect(_key('me-overview-attention-none'), findsOneWidget);
    });

    testWidgets('with the shell off, the Overview is the legacy home', (
      tester,
    ) async {
      await _pump(tester, shell: false);
      expect(_key('me-overview-header'), findsNothing);
      expect(_key('me-header'), findsOneWidget);
    });
  });
}
