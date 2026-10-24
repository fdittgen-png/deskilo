// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C2 — My reservations across every host my account names. Each
// host is read with its own state: a host that is still read, that failed,
// that cannot be reached or that did not answer in time is said beside the
// others' bookings, never instead of them, and its own Try again asks it
// alone. The pages merge by start, a slower host's later page never lands
// above what is shown, the reads are bounded by the personal setting, and
// a page that arrives after the account changed is dropped.
import 'dart:async';

import 'package:deskilo/core/backend/bounded_reads.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/my_reservations_composition.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/my_reservations_body.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
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
  workspaceIds: ['ws-a'],
  hostedHere: true,
  labels: ['Pézenas'],
);
const _b = MyReservationsSource(
  installationId: 'inst-b',
  workspaceIds: ['ws-b'],
  labels: ['Leipzig'],
);
const _c = MyReservationsSource(installationId: 'inst-c', workspaceIds: ['ws-c']);

MyReservationItem _item(String id, DateTime start, {String workspace = 'ws-a'}) =>
    MyReservationItem(
      id: id,
      workspaceId: workspace,
      workspaceName: workspace,
      placeKind: MyReservationPlaceKind.desk,
      placeId: 'desk-$id',
      placeLabel: 'Desk $id',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 2)),
      status: ReservationStatus.reserved,
      checkedInAt: null,
      checkedOutAt: null,
    );

MyReservationsPage _page(
  String source,
  List<MyReservationItem> items, {
  MyReservationsCursor? next,
  Map<String, String> zones = const {},
}) =>
    MyReservationsPage(
      source: source,
      items: items,
      next: next,
      hasMore: next != null,
      zones: zones,
    );

/// Hosts that answer what the test set, explicitly per host: a page, a
/// failure, or a read that waits for the test to complete it.
class _Hosts implements MyReservationsRepository {
  _Hosts({this.concurrency = 4});

  final int concurrency;
  final Map<String, MyReservationsPage> first = {};
  final Map<String, MyReservationsPage> more = {};
  final Map<String, Exception> failure = {};
  final Map<String, List<Completer<MyReservationsPage>>> waiting = {};
  final List<String> asked = [];

  /// The next read of [host] waits until the test completes it.
  Completer<MyReservationsPage> hold(String host) {
    final c = Completer<MyReservationsPage>();
    (waiting[host] ??= []).add(c);
    return c;
  }

  @override
  Future<MyReservationsLimits> limits() async => MyReservationsLimits(
        windowDays: 7,
        maxDays: 60,
        concurrency: concurrency,
        timeout: const Duration(seconds: 5),
      );

  @override
  Future<MyReservationsPage> page(MyReservationsSource source, MyReservationsQuery query) async {
    final host = source.installationId;
    asked.add(host);
    final held = waiting[host];
    if (held != null && held.isNotEmpty) return held.removeAt(0).future;
    final refused = failure[host];
    if (refused != null) throw refused;
    final answer = query.after == null ? first[host] : more[host];
    return answer ?? _page(host, const []);
  }
}

List<Override> _overrides(_Hosts hosts, List<MyReservationsSource> sources) => [
      myReservationsRepositoryProvider.overrideWithValue(hosts),
      myReservationsSourcesProvider.overrideWith((ref) async => sources),
      clockProvider.overrideWithValue(FixedClock(kTestNow)),
    ];

Finder _card(String id) => find.byKey(ValueKey('my-reservation-$id'));

void main() {
  final day1 = DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 9);
  final day2 = day1.add(const Duration(days: 1));
  final day3 = day1.add(const Duration(days: 2));

  group('the view', () {
    testWidgets('two hosts merge by start time into one list', (tester) async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', day1), _item('a2', day3)])
        ..first['inst-b'] = _page('inst-b', [_item('b1', day2, workspace: 'ws-b')]);
      await pumpApp(tester, const Scaffold(body: MyReservationsBody()),
          overrides: _overrides(hosts, [_a, _b]));
      await tester.pumpAndSettle();

      expect(hosts.asked.toSet(), {'inst-a', 'inst-b'}, reason: 'each host is asked for itself');
      final ys = [for (final id in ['a1', 'b1', 'a2']) tester.getTopLeft(_card(id)).dy];
      expect(ys, [...ys]..sort(), reason: 'merged by start: a1, b1, a2');
      expect(find.byKey(const ValueKey('my-reservations-empty')), findsNothing);
    });

    testWidgets('one host failing never hides the other, and its Try again asks it alone',
        (tester) async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', day1)])
        ..failure['inst-b'] = const MyReservationsRefused(MyReservationsFailure.hostUnavailable);
      await pumpApp(tester, const Scaffold(body: MyReservationsBody()),
          overrides: _overrides(hosts, [_a, _b]));
      await tester.pumpAndSettle();

      expect(_card('a1'), findsOneWidget, reason: 'the host that answered is shown');
      expect(
        find.text(_l10n.myReservationsSourceProblem('Leipzig', _l10n.myReservationsHostUnavailable)),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('my-reservations-empty')), findsNothing,
          reason: 'a period is empty only when every host answered');

      // Recovery: the host answers now; only it is asked again.
      hosts
        ..failure.remove('inst-b')
        ..first['inst-b'] = _page('inst-b', [_item('b1', day2, workspace: 'ws-b')]);
      final before = hosts.asked.length;
      // The notice leads the list: on screen without scrolling.
      await tester.tap(find.byKey(const ValueKey('my-reservations-source-retry-inst-b')));
      await tester.pumpAndSettle();
      expect(hosts.asked.sublist(before), ['inst-b']);
      expect(_card('b1'), findsOneWidget);
      expect(_card('a1'), findsOneWidget, reason: 'the other host\'s bookings stayed');
      expect(find.byKey(const ValueKey('my-reservations-source-failed-inst-b')), findsNothing);
    });

    testWidgets('a slow host is said as being read while the other is already shown',
        (tester) async {
      final hosts = _Hosts()..first['inst-a'] = _page('inst-a', [_item('a1', day1)]);
      final slow = hosts.hold('inst-b');
      await pumpApp(tester, const Scaffold(body: MyReservationsBody()),
          overrides: _overrides(hosts, [_a, _b]));
      await tester.pumpAndSettle();

      expect(_card('a1'), findsOneWidget, reason: 'no barrier on the slowest host');
      expect(find.text(_l10n.myReservationsSourceReading('Leipzig')), findsOneWidget);

      slow.complete(_page('inst-b', [_item('b1', day2, workspace: 'ws-b')]));
      await tester.pump();
      await tester.pump();
      expect(_card('b1'), findsOneWidget);
      expect(find.text(_l10n.myReservationsSourceReading('Leipzig')), findsNothing);
    });

    testWidgets('a host that does not answer in time is said so; the other stays', (tester) async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', day1)])
        ..hold('inst-b'); // never answers
      await pumpApp(tester, const Scaffold(body: MyReservationsBody()),
          overrides: _overrides(hosts, [_a, _b]));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.myReservationsSourceReading('Leipzig')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(_card('a1'), findsOneWidget);
      expect(
        find.text(_l10n.myReservationsSourceProblem('Leipzig', _l10n.myReservationsTimedOut)),
        findsOneWidget,
        reason: 'the setting\'s five seconds, not a literal',
      );
    });

    testWidgets('an unnamed host is named as a workspace server', (tester) async {
      final hosts = _Hosts()
        ..failure['inst-c'] = const MyReservationsRefused(MyReservationsFailure.unsupported);
      await pumpApp(tester, const Scaffold(body: MyReservationsBody()),
          overrides: _overrides(hosts, [_c]));
      await tester.pumpAndSettle();
      expect(
        find.text(_l10n.myReservationsSourceProblem(
            _l10n.myReservationsSourceUnnamed, _l10n.myReservationsUnsupported)),
        findsOneWidget,
      );
    });

    testWidgets('a later page of one host never lands above what is shown', (tester) async {
      final cursor = MyReservationsCursor(afterStart: day1, afterId: 'a1');
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', day1)], next: cursor)
        ..more['inst-a'] = _page('inst-a', [_item('a2', day2)])
        ..first['inst-b'] = _page('inst-b', [_item('b1', day3, workspace: 'ws-b')]);
      await pumpApp(tester, const Scaffold(body: MyReservationsBody()),
          overrides: _overrides(hosts, [_a, _b]));
      await tester.pumpAndSettle();

      expect(_card('a1'), findsOneWidget);
      expect(_card('b1'), findsNothing,
          reason: 'host A may still hold bookings before b1: it waits for A\'s next page');

      await tester.tap(find.byKey(const ValueKey('my-reservations-load-more')));
      await tester.pump();
      await tester.pump();
      final ys = [for (final id in ['a1', 'a2', 'b1']) tester.getTopLeft(_card(id)).dy];
      expect(ys, [...ys]..sort(), reason: 'a2 came before b1, in order');
      expect(find.byKey(const ValueKey('my-reservations-load-more')), findsNothing);
    });

    testWidgets('no host at all is an empty period', (tester) async {
      await pumpApp(tester, const Scaffold(body: MyReservationsBody()),
          overrides: _overrides(_Hosts(), const []));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-reservations-empty')), findsOneWidget);
    });
  });

  group('the composer', () {
    final query = MyReservationsQuery(from: day1, to: day3);

    test('reads at most the configured number of hosts at once', () async {
      final hosts = _Hosts(concurrency: 2);
      final held = [for (final h in ['inst-a', 'inst-b', 'inst-c']) hosts.hold(h)];
      final container = ProviderContainer(overrides: _overrides(hosts, [_a, _b, _c]));
      addTearDown(container.dispose);
      final sub = container.listen(myReservationsComposerProvider(query), (_, _) {});
      addTearDown(sub.close);
      await container.read(myReservationsComposerProvider(query).future);
      await pumpEventQueue();
      expect(hosts.asked, ['inst-a', 'inst-b'], reason: 'personal.read_concurrency is 2');

      held[0].complete(_page('inst-a', const []));
      await pumpEventQueue();
      expect(hosts.asked, ['inst-a', 'inst-b', 'inst-c'], reason: 'a finished read frees its place');
      held[1].complete(_page('inst-b', const []));
      held[2].complete(_page('inst-c', const []));
      await pumpEventQueue();
      expect(container.read(myReservationsComposerProvider(query)).value!.empty, isTrue);
    });

    test('a page that arrives after the account changed is dropped', () async {
      final session = StreamController<String?>.broadcast();
      addTearDown(session.close);
      final hosts = _Hosts();
      final stale = hosts.hold('inst-b');
      final container = ProviderContainer(overrides: [
        ..._overrides(hosts, [_b]),
        sessionStateProvider.overrideWith((ref) => session.stream),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(myReservationsComposerProvider(query), (_, _) {});
      addTearDown(sub.close);
      session.add('person-1');
      await pumpEventQueue();
      await container.read(myReservationsComposerProvider(query).future);
      await pumpEventQueue();

      // Another account signs in; its read of the same host waits.
      final fresh = hosts.hold('inst-b');
      session.add('person-2');
      await pumpEventQueue();
      await container.read(myReservationsComposerProvider(query).future);
      await pumpEventQueue();

      stale.complete(_page('inst-b', [_item('old', day1, workspace: 'ws-b')]));
      await pumpEventQueue();
      final afterStale = container.read(myReservationsComposerProvider(query)).value!;
      expect(afterStale.slotOf('inst-b')!.state, MyReservationsSlotState.reading,
          reason: 'the first account\'s page never fills the second account\'s view');
      expect(afterStale.visible, isEmpty);

      fresh.complete(_page('inst-b', [_item('new', day1, workspace: 'ws-b')]));
      await pumpEventQueue();
      final now = container.read(myReservationsComposerProvider(query)).value!;
      expect(now.visible.map((e) => e.item.id), ['new']);
    });
  });

  group('the composition', () {
    test('groups each booking by its own workspace\'s day', () {
      // 23:30 UTC is the next day in Auckland and the same day in New York.
      final instant = DateTime.utc(2031, 3, 2, 23, 30);
      final composition = MyReservationsComposition([
        MyReservationsSlot.firstPage(
          _a,
          _page('inst-a', [_item('nz', instant)], zones: {'ws-a': 'Pacific/Auckland'}),
        ),
        MyReservationsSlot.firstPage(
          _b,
          _page('inst-b', [_item('ny', instant, workspace: 'ws-b')], zones: {'ws-b': 'America/New_York'}),
        ),
      ]);
      final days = {for (final e in composition.visible) e.item.id: e.day};
      expect(days['nz'], DateTime(2031, 3, 3));
      expect(days['ny'], DateTime(2031, 3, 2));
    });

    test('equal starts order by host then id, the same every time', () {
      final at = DateTime.utc(2031, 3, 2, 8);
      final composition = MyReservationsComposition([
        MyReservationsSlot.firstPage(_b, _page('inst-b', [_item('x', at, workspace: 'ws-b')])),
        MyReservationsSlot.firstPage(_a, _page('inst-a', [_item('z', at), _item('y', at)])),
      ]);
      expect(composition.visible.map((e) => e.item.id), ['y', 'z', 'x']);
    });

    test('a failed host keeps the period from being called empty', () {
      final composition = MyReservationsComposition([
        MyReservationsSlot.firstPage(_a, _page('inst-a', const [])),
        const MyReservationsSlot.failed(_b, MyReservationsRefused(MyReservationsFailure.forbidden)),
      ]);
      expect(composition.empty, isFalse);
      expect(composition.failed.single.installationId, 'inst-b');
    });
  });

  group('the bounded reads', () {
    test('hold the bound across a hand-over and refuse waiting reads once closed', () async {
      final reads = BoundedReads(1);
      final first = Completer<int>();
      final a = reads.run(() => first.future);
      var secondStarted = false;
      final b = reads.run(() async {
        secondStarted = true;
        return 2;
      });
      final c = reads.run(() async => 3);
      await pumpEventQueue();
      expect(secondStarted, isFalse);
      expect(reads.running, 1);
      first.complete(1);
      expect(await a, 1);
      expect(await b, 2);
      expect(await c, 3);
      expect(reads.running, 0);

      final blocker = Completer<void>();
      final held = reads.run(() => blocker.future);
      final queued = reads.run(() async => 4);
      reads.close();
      await expectLater(queued, throwsA(isA<BoundedReadsClosed>()));
      blocker.complete();
      await held;
      await expectLater(reads.run(() async => 5), throwsA(isA<BoundedReadsClosed>()));
    });

    test('a limit below one is one', () {
      expect(BoundedReads(0).limit, 1);
    });
  });
}
