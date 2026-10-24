// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C4 — the guest visits as their own kind in My reservations, with
// no membership needed; the #2551 card and, on a wide window, the table;
// and the cache identity (principal, installation, query): a host read
// again keeps what it showed, stale, through an outage, and a refusal
// that withdraws it, a host no longer named or another account purges it.
import 'dart:async';

import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/theme/personal_theme.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/domain/my_guest_visits.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/my_reservations_composition.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/my_reservations_body.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/visits/domain/guest_participation.dart';
import 'package:deskilo/features/visits/providers/visits_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_clock.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

const _a = MyReservationsSource(
  installationId: 'inst-a',
  workspaceIds: ['ws-a', 'ws-a2'],
  hostedHere: true,
  labels: ['Pézenas'],
);
const _b = MyReservationsSource(
  installationId: 'inst-b',
  workspaceIds: ['ws-b'],
  labels: ['Leipzig'],
);

MyReservationItem _item(
  String id,
  DateTime start, {
  String workspace = 'ws-a',
}) => MyReservationItem(
  id: id,
  workspaceId: workspace,
  workspaceName: workspace,
  placeKind: MyReservationPlaceKind.desk,
  placeId: 'desk-$id',
  placeLabel: 'Desk $id',
  startsAt: start.toUtc(),
  endsAt: start.add(const Duration(hours: 2)).toUtc(),
  status: ReservationStatus.reserved,
  checkedInAt: null,
  checkedOutAt: null,
);

MyReservationsPage _page(String source, List<MyReservationItem> items) =>
    MyReservationsPage(
      source: source,
      items: items,
      next: null,
      hasMore: false,
    );

GuestParticipation _visit(
  String id,
  DateTime start, {
  GuestVisitStatus status = GuestVisitStatus.requested,
}) => GuestParticipation(
  id: id,
  workspaceId: 'ws-guest',
  workspaceName: 'Kraftwerk',
  status: status,
  startsAt: start.toUtc(),
  endsAt: start.add(const Duration(hours: 3)).toUtc(),
);

/// Hosts that answer what the test set, per host: a page, a failure, or
/// a read held until the test completes it.
class _Hosts implements MyReservationsRepository {
  final Map<String, MyReservationsPage> first = {};
  final Map<String, Exception> failure = {};
  final Map<String, Completer<MyReservationsPage>> held = {};

  /// The next read of the limits waits until the test completes it.
  Completer<void>? limitsHeld;

  @override
  Future<MyReservationsLimits> limits() async {
    final wait = limitsHeld;
    limitsHeld = null;
    if (wait != null) await wait.future;
    return const MyReservationsLimits(
      windowDays: 7,
      maxDays: 60,
      concurrency: 4,
      timeout: Duration(seconds: 5),
    );
  }

  @override
  Future<MyReservationsPage> page(
    MyReservationsSource source,
    MyReservationsQuery query,
  ) async {
    final host = source.installationId;
    final wait = held.remove(host);
    if (wait != null) return wait.future;
    final refused = failure[host];
    if (refused != null) throw refused;
    return first[host] ?? _page(host, const []);
  }
}

List<Override> _overrides(
  _Hosts hosts, {
  required List<MyReservationsSource> Function() sources,
  List<GuestParticipation> visits = const [],
  Stream<String?>? session,
}) => [
  myReservationsRepositoryProvider.overrideWithValue(hosts),
  myReservationsSourcesProvider.overrideWith((ref) async => sources()),
  clockProvider.overrideWithValue(FixedClock(kTestNow)),
  myGuestVisitsProvider.overrideWith((ref) async => visits),
  if (session != null) sessionStateProvider.overrideWith((ref) => session),
];

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _show(
  WidgetTester tester,
  List<Override> overrides, {
  Size size = const Size(800, 1600),
}) async {
  await pumpApp(
    tester,
    const Scaffold(body: MyReservationsBody()),
    overrides: overrides,
    size: size,
  );
  await _frames(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MyReservationsBody)));

void main() {
  final today9 = DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 9);
  final tomorrow9 = today9.add(const Duration(days: 1));
  final lastWeek = today9.subtract(const Duration(days: 5));
  final query = MyReservationsQuery(
    from: today9,
    to: today9.add(const Duration(days: 7)),
  );

  group('guest visits, their own kind', () {
    test(
      'a visit\'s tab follows its status and end; a request stays a request',
      () {
        final now = kTestNow;
        expect(
          myVisitTab(_visit('r', tomorrow9), now),
          MyReservationsTab.upcoming,
        );
        expect(
          myVisitTab(
            _visit('c', tomorrow9, status: GuestVisitStatus.confirmed),
            now,
          ),
          MyReservationsTab.upcoming,
        );
        expect(
          myVisitTab(
            _visit('x', tomorrow9, status: GuestVisitStatus.cancelled),
            now,
          ),
          MyReservationsTab.cancelled,
        );
        expect(
          myVisitTab(
            _visit('d', tomorrow9, status: GuestVisitStatus.declined),
            now,
          ),
          MyReservationsTab.past,
          reason: 'a declined request is not upcoming',
        );
        expect(
          myVisitTab(
            _visit('e', lastWeek, status: GuestVisitStatus.confirmed),
            now,
          ),
          MyReservationsTab.past,
          reason: 'an ended visit is past',
        );
      },
    );

    test('a period shows its own visits, the past newest first', () {
      final visits = [
        _visit('old', lastWeek, status: GuestVisitStatus.expired),
        _visit(
          'older',
          lastWeek.subtract(const Duration(days: 1)),
          status: GuestVisitStatus.expired,
        ),
        _visit('soon', tomorrow9),
        _visit('far', tomorrow9.add(const Duration(days: 30))),
      ];
      final upcoming = myVisitsShown(
        visits,
        tab: MyReservationsTab.upcoming,
        from: today9,
        to: today9.add(const Duration(days: 7)),
        now: kTestNow,
      );
      expect(upcoming.map((v) => v.id), [
        'soon',
      ], reason: 'the far one is outside the period');
      final past = myVisitsShown(
        visits,
        tab: MyReservationsTab.past,
        from: today9.subtract(const Duration(days: 7)),
        to: today9.add(const Duration(days: 1)),
        now: kTestNow,
      );
      expect(past.map((v) => v.id), ['old', 'older']);
    });

    testWidgets(
      'visits show without any workspace host: no membership needed',
      (tester) async {
        await _show(
          tester,
          _overrides(
            _Hosts(),
            sources: () => const [],
            visits: [
              _visit('v1', tomorrow9),
              _visit('v2', tomorrow9, status: GuestVisitStatus.cancelled),
            ],
          ),
        );
        expect(_key('my-reservations-empty'), findsNothing);
        expect(_key('my-reservations-visits'), findsOneWidget);
        expect(_key('my-reservations-visit-v1'), findsOneWidget);
        expect(
          _key('my-reservations-visit-v2'),
          findsNothing,
          reason: 'a cancelled visit is not upcoming',
        );
        expect(
          find.text(_l10n.visitStatusRequested),
          findsOneWidget,
          reason: 'a request, never a confirmation',
        );

        await tester.tap(_key('my-reservations-tab-cancelled'));
        await _frames(tester);
        expect(_key('my-reservations-visit-v2'), findsOneWidget);
        expect(_key('my-reservations-visit-v1'), findsNothing);
      },
    );

    testWidgets(
      'one host alone shows that host\'s bookings, not the personal home\'s visits',
      (tester) async {
        final hosts = _Hosts()
          ..first['inst-a'] = _page('inst-a', [_item('a1', tomorrow9)])
          ..first['inst-b'] = _page('inst-b', [
            _item('b1', tomorrow9, workspace: 'ws-b'),
          ]);
        await _show(
          tester,
          _overrides(
            hosts,
            sources: () => const [_a, _b],
            visits: [_visit('v1', tomorrow9)],
          ),
        );
        expect(_key('my-reservations-visit-v1'), findsOneWidget);
        expect(_key('my-reservation-a1'), findsOneWidget);

        await tester.tap(_key('my-reservations-source-inst-b'));
        await _frames(tester);
        expect(_key('my-reservations-visit-v1'), findsNothing);
        expect(_key('my-reservation-b1'), findsOneWidget);
      },
    );

    testWidgets(
      'no booking and no visit in the period is still the empty period',
      (tester) async {
        await _show(
          tester,
          _overrides(
            _Hosts(),
            sources: () => const [_a],
            visits: [_visit('far', tomorrow9.add(const Duration(days: 30)))],
          ),
        );
        expect(_key('my-reservations-empty'), findsOneWidget);
      },
    );
  });

  group('the #2551 card and the wide table', () {
    Future<void> showAt(WidgetTester tester, Size size) async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', tomorrow9)]);
      await _show(
        tester,
        _overrides(hosts, sources: () => const [_a]),
        size: size,
      );
    }

    Iterable<EdgeInsetsGeometry> cardPaddings(WidgetTester tester) => tester
        .widgetList<Padding>(
          find.descendant(
            of: _key('my-reservation-a1'),
            matching: find.byType(Padding),
          ),
        )
        .map((p) => p.padding);

    testWidgets(
      'compact: the card has radius 20 and 16 padding, the time first',
      (tester) async {
        await showAt(tester, const Size(360, 1400));
        final card = tester.widget<Card>(_key('my-reservation-a1'));
        expect(
          (card.shape! as RoundedRectangleBorder).borderRadius,
          PersonalShellMetrics.cardRadiusAll,
        );
        expect(cardPaddings(tester), contains(const EdgeInsets.all(16)));
        expect(cardPaddings(tester), isNot(contains(const EdgeInsets.all(24))));
        expect(
          tester.getTopLeft(_key('my-reservation-times-a1')).dy,
          lessThan(tester.getTopLeft(_key('my-reservation-status-a1')).dy),
          reason: 'a compact card says when first',
        );
        expect(_key('my-reservations-table-header'), findsNothing);
      },
    );

    testWidgets('expanded: 24 padding', (tester) async {
      await showAt(tester, const Size(700, 1400));
      expect(cardPaddings(tester), contains(const EdgeInsets.all(24)));
    });

    testWidgets(
      'wide: one table row per booking under the column titles, with its actions',
      (tester) async {
        await showAt(tester, const Size(1280, 1000));
        expect(_key('my-reservations-table-header'), findsOneWidget);
        for (final title in [
          _l10n.myReservationsColumnWhen,
          _l10n.myReservationsColumnWorkspace,
          _l10n.myReservationsColumnKind,
          _l10n.myReservationsColumnStatus,
          _l10n.myReservationsColumnActions,
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        expect(find.byType(Card), findsNothing, reason: 'a row, not a card');
        final row = tester.getTopLeft(_key('my-reservation-times-a1')).dy;
        expect(
          (tester.getTopLeft(_key('my-reservation-status-a1')).dy - row).abs(),
          lessThan(24),
          reason: 'status on the same row as the time',
        );
        expect(_key('my-reservation-view-a1'), findsOneWidget);
        expect(_key('my-reservation-cancel-a1'), findsOneWidget);
      },
    );
  });

  group('the cache identity', () {
    test(
      'an outage keeps what a host showed, stale; its recovery replaces it',
      () async {
        final hosts = _Hosts()
          ..first['inst-a'] = _page('inst-a', [_item('a1', tomorrow9)]);
        final container = ProviderContainer(
          overrides: _overrides(hosts, sources: () => const [_a]),
        );
        addTearDown(container.dispose);
        final sub = container.listen(
          myReservationsComposerProvider(query),
          (_, _) {},
        );
        addTearDown(sub.close);
        await container.read(myReservationsComposerProvider(query).future);
        await pumpEventQueue();

        hosts.failure['inst-a'] = TimeoutException('network down');
        container.invalidate(myReservationsComposerProvider(query));
        await container.read(myReservationsComposerProvider(query).future);
        await pumpEventQueue();
        var slot = container
            .read(myReservationsComposerProvider(query))
            .value!
            .slotOf('inst-a')!;
        expect(slot.state, MyReservationsSlotState.failed);
        expect(slot.stale, isTrue);
        expect(
          container
              .read(myReservationsComposerProvider(query))
              .value!
              .visible
              .map((e) => e.item.id),
          ['a1'],
        );

        hosts.failure.remove('inst-a');
        hosts.first['inst-a'] = _page('inst-a', [_item('a2', tomorrow9)]);
        container
            .read(myReservationsComposerProvider(query).notifier)
            .retry('inst-a');
        expect(
          container
              .read(myReservationsComposerProvider(query))
              .value!
              .visible
              .map((e) => e.item.id),
          ['a1'],
          reason: 'what it showed stays while it is read again',
        );
        await pumpEventQueue();
        slot = container
            .read(myReservationsComposerProvider(query))
            .value!
            .slotOf('inst-a')!;
        expect((slot.state, slot.stale), (MyReservationsSlotState.read, false));
        expect(slot.items.map((i) => i.id), ['a2']);
      },
    );

    test('a refusal that withdraws the host purges what it showed', () async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', tomorrow9)]);
      final container = ProviderContainer(
        overrides: _overrides(hosts, sources: () => const [_a]),
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        myReservationsComposerProvider(query),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(myReservationsComposerProvider(query).future);
      await pumpEventQueue();

      hosts.failure['inst-a'] = const MyReservationsRefused(
        MyReservationsFailure.forbidden,
      );
      container.invalidate(myReservationsComposerProvider(query));
      await container.read(myReservationsComposerProvider(query).future);
      await pumpEventQueue();
      final composition = container
          .read(myReservationsComposerProvider(query))
          .value!;
      expect(composition.slotOf('inst-a')!.items, isEmpty);
      expect(composition.visible, isEmpty);
      expect(composition.slotOf('inst-a')!.stale, isFalse);
    });

    test(
      'a host no longer named, or a workspace it no longer names, is purged',
      () async {
        var sources = const [_a, _b];
        final hosts = _Hosts()
          ..first['inst-a'] = _page('inst-a', [
            _item('a1', tomorrow9),
            _item('a2', tomorrow9, workspace: 'ws-a2'),
          ])
          ..first['inst-b'] = _page('inst-b', [
            _item('b1', tomorrow9, workspace: 'ws-b'),
          ]);
        final container = ProviderContainer(
          overrides: _overrides(hosts, sources: () => sources),
        );
        addTearDown(container.dispose);
        final sub = container.listen(
          myReservationsComposerProvider(query),
          (_, _) {},
        );
        addTearDown(sub.close);
        await container.read(myReservationsComposerProvider(query).future);
        await pumpEventQueue();
        expect(
          container.read(myReservationsComposerProvider(query)).value!.visible,
          hasLength(3),
        );

        sources = const [
          MyReservationsSource(
            installationId: 'inst-a',
            workspaceIds: ['ws-a'],
          ),
        ];
        hosts.held['inst-a'] = Completer();
        container.invalidate(myReservationsSourcesProvider);
        await container.read(myReservationsComposerProvider(query).future);
        await pumpEventQueue();
        final composition = container
            .read(myReservationsComposerProvider(query))
            .value!;
        expect(composition.slotOf('inst-b'), isNull);
        expect(
          composition.visible.map((e) => e.item.id),
          ['a1'],
          reason: 'only the rows of the workspace still named stay, stale, while A is read again',
        );
        expect(composition.slotOf('inst-a')!.stale, isTrue);
      },
    );

    test(
      'another account never inherits what the first one was shown',
      () async {
        final session = StreamController<String?>.broadcast();
        addTearDown(session.close);
        final hosts = _Hosts()
          ..first['inst-a'] = _page('inst-a', [_item('a1', tomorrow9)]);
        final container = ProviderContainer(
          overrides: _overrides(
            hosts,
            sources: () => const [_a],
            session: session.stream,
          ),
        );
        addTearDown(container.dispose);
        final sub = container.listen(
          myReservationsComposerProvider(query),
          (_, _) {},
        );
        addTearDown(sub.close);
        session.add('person-1');
        await pumpEventQueue();
        await container.read(myReservationsComposerProvider(query).future);
        await pumpEventQueue();
        expect(
          container
              .read(myReservationsComposerProvider(query))
              .value!
              .principal,
          'person-1',
        );
        expect(
          container.read(myReservationsComposerProvider(query)).value!.visible,
          hasLength(1),
        );

        hosts.held['inst-a'] = Completer();
        session.add('person-2');
        await pumpEventQueue();
        await container.read(myReservationsComposerProvider(query).future);
        await pumpEventQueue();
        final composition = container
            .read(myReservationsComposerProvider(query))
            .value!;
        expect(composition.principal, 'person-2');
        expect(composition.visible, isEmpty);
        expect(composition.slotOf('inst-a')!.stale, isFalse);
      },
    );

    testWidgets(
      'pulled again through an outage, the rows stay and the host says they are stale',
      (tester) async {
        final hosts = _Hosts()
          ..first['inst-a'] = _page('inst-a', [_item('a1', tomorrow9)]);
        await _show(tester, _overrides(hosts, sources: () => const [_a]));
        expect(_key('my-reservation-a1'), findsOneWidget);

        hosts.failure['inst-a'] = TimeoutException('network down');
        // What a pull does: the view's own query read again.
        final shown = _container(tester)
            .read(myReservationsWindowControllerProvider)
            .value!;
        _container(tester).invalidate(
          myReservationsComposerProvider(
            MyReservationsQuery(from: shown.from, to: shown.to),
          ),
        );
        await _frames(tester);
        expect(_key('my-reservation-a1'), findsOneWidget);
        expect(_key('my-reservations-source-stale-inst-a'), findsOneWidget);
        expect(find.text(_l10n.myReservationsSourceStale), findsOneWidget);

        hosts.failure.remove('inst-a');
        await tester.tap(_key('my-reservations-source-retry-inst-a'));
        await _frames(tester);
        expect(_key('my-reservations-source-stale-inst-a'), findsNothing);
        expect(_key('my-reservation-a1'), findsOneWidget);
      },
    );

    testWidgets(
      'while another account\'s view is read, nothing of the first one shows',
      (tester) async {
        final session = StreamController<String?>.broadcast();
        addTearDown(session.close);
        final hosts = _Hosts()
          ..first['inst-a'] = _page('inst-a', [_item('a1', tomorrow9)]);
        await _show(
          tester,
          _overrides(hosts, sources: () => const [_a], session: session.stream),
        );
        session.add('person-1');
        await _frames(tester);
        expect(_key('my-reservation-a1'), findsOneWidget);

        // The second account's read waits on its limits: the view is being
        // rebuilt, and what it held was the first account's.
        final limitsHeld = hosts.limitsHeld = Completer<void>();
        hosts.first['inst-a'] = _page('inst-a', [_item('p2', tomorrow9)]);
        session.add('person-2');
        await tester.pump();
        await tester.pump();
        expect(
          _key('my-reservation-a1'),
          findsNothing,
          reason: 'person-1\'s rows are not person-2\'s',
        );
        limitsHeld.complete();
        await _frames(tester);
        expect(_key('my-reservation-p2'), findsOneWidget);
      },
    );
  });
}
