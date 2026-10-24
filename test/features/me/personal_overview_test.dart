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
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/me/application/personal_overview.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/my_reservations_composition.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
class _Hosts implements MyReservationsRepository {
  final Map<String, List<MyReservationItem>> items = {};
  final Map<String, Exception> failures = {};
  Exception? limitsFailure;

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
  final router = await pumpMeApp(
    tester,
    workspace: workspace ?? twoSpaces(),
    me: me,
    accountActivity: documents,
    messenger: messenger,
    size: size,
    extraOverrides: <Override>[
      personalShellEnabledProvider.overrideWithValue(shell),
      myReservationsRepositoryProvider.overrideWithValue(hosts ?? _Hosts()),
      myReservationsSourcesProvider.overrideWith((ref) async => sources),
    ],
  );
  await goTo(tester, router, '/me');
  return router;
}

void main() {
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
      expect(next.entry?.item.id, 'soon');
      expect(next.entry?.source, 'inst-b');
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
      expect(next.entry?.item.id, 'now');
    });

    test('a host that failed or is still read keeps the answer from being '
        'complete', () {
      final failed = nextCommitmentOf(
        composed(const [], bFailed: true),
        kTestNow,
      );
      expect(failed.entry, isNull);
      expect(failed.complete, isFalse);
      expect(failed.failed.single.installationId, 'inst-b');
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

      expect(find.text('Your day, in one place'), findsOneWidget);
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
      await tapIn(tester, 'me-home-list', _key('me-overview-next-view'));
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
      expect(find.textContaining('Nothing booked from'), findsOneWidget);
      expect(_key('me-overview-attention-none'), findsOneWidget);
      expect(_key('me-overview-next-view'), findsNothing);
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

    testWidgets('with the shell off, the Overview is the legacy home', (
      tester,
    ) async {
      await _pump(tester, shell: false);
      expect(_key('me-overview-header'), findsNothing);
      expect(_key('me-header'), findsOneWidget);
    });
  });
}
