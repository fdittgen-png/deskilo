// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C3 — My reservations by tab and source, each card's times on its
// workspace's wall clock, and View, Check in and Cancel from a row: each
// action goes to the host the row was read from, never the first or the
// selected one; a refused action says why on its row with Try again, and
// a row its host no longer lists leaves the list. Hidden, no read starts;
// on resume each host is read once.
import 'dart:async';

import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/core/lifecycle/app_foreground.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/application/bounded_reads.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/my_reservations_composition.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/my_reservations_body.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/visits/providers/visits_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:timezone/timezone.dart' as tz;

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

MyReservationItem _item(
  String id,
  DateTime start, {
  String workspace = 'ws-a',
  ReservationStatus status = ReservationStatus.reserved,
  Duration length = const Duration(hours: 2),
}) =>
    MyReservationItem(
      id: id,
      workspaceId: workspace,
      workspaceName: workspace,
      placeKind: MyReservationPlaceKind.desk,
      placeId: 'desk-$id',
      placeLabel: 'Desk $id',
      startsAt: start.toUtc(),
      endsAt: start.add(length).toUtc(),
      status: status,
      checkedInAt: status == ReservationStatus.checkedIn ? start.toUtc() : null,
      checkedOutAt: null,
    );

MyReservationsPage _page(
  String source,
  List<MyReservationItem> items, {
  MyReservationsCursor? next,
  Map<String, String> zones = const {},
}) =>
    MyReservationsPage(source: source, items: items, next: next, hasMore: next != null, zones: zones);

/// Hosts answering per installation, recording every question.
class _Hosts implements MyReservationsRepository {
  final Map<String, MyReservationsPage> first = {};
  final Map<String, MyReservationsPage> more = {};
  final List<(String, MyReservationsQuery)> asked = [];

  @override
  Future<MyReservationsLimits> limits() async => const MyReservationsLimits(
        windowDays: 7,
        maxDays: 60,
        concurrency: 2,
        timeout: Duration(seconds: 5),
      );

  @override
  Future<MyReservationsPage> page(MyReservationsSource source, MyReservationsQuery query) async {
    asked.add((source.installationId, query));
    final answer = query.after == null ? first[source.installationId] : more[source.installationId];
    return answer ?? _page(source.installationId, const []);
  }
}

/// Row actions that record which host each one was sent to, answer what
/// the test set, and change the host's rows the way a host would.
class _Actions implements MyReservationActions {
  _Actions(this.hosts);

  final _Hosts hosts;
  final List<(String, String, String)> sent = [];
  final List<Exception> refusals = [];
  Exception? viewFailure;
  final Map<String, MyReservationItem> fresh = {};

  Never _refuse() {
    final error = refusals.removeAt(0);
    throw error;
  }

  void _becomes(MyReservationsSource source, MyReservationItem item, ReservationStatus status) {
    fresh[item.id] = MyReservationItem(
      id: item.id,
      workspaceId: item.workspaceId,
      workspaceName: item.workspaceName,
      placeKind: item.placeKind,
      placeId: item.placeId,
      placeLabel: item.placeLabel,
      startsAt: item.startsAt,
      endsAt: item.endsAt,
      status: status,
      checkedInAt: status == ReservationStatus.checkedIn ? item.startsAt : null,
      checkedOutAt: null,
    );
  }

  @override
  Future<MyReservationItem> view(MyReservationsSource source, MyReservationItem item) async {
    sent.add(('view', source.installationId, item.id));
    final failure = viewFailure;
    if (failure != null) throw failure;
    return fresh[item.id] ?? item;
  }

  @override
  Future<void> cancel(MyReservationsSource source, MyReservationItem item) async {
    sent.add(('cancel', source.installationId, item.id));
    if (refusals.isNotEmpty) _refuse();
    _becomes(source, item, ReservationStatus.cancelled);
  }

  @override
  Future<void> checkIn(MyReservationsSource source, MyReservationItem item) async {
    sent.add(('checkIn', source.installationId, item.id));
    if (refusals.isNotEmpty) _refuse();
    _becomes(source, item, ReservationStatus.checkedIn);
  }
}

/// The app's foreground, set by the test.
class _Foreground extends AppForeground {
  _Foreground({required this.initial});

  final bool initial;

  @override
  bool build() => initial;

  void set({required bool foreground}) => state = foreground;
}

List<Override> _overrides(
  _Hosts hosts, {
  _Actions? actions,
  List<MyReservationsSource> sources = const [_a, _b],
  bool foreground = true,
}) =>
    [
      myReservationsRepositoryProvider.overrideWithValue(hosts),
      myReservationActionsProvider.overrideWithValue(actions ?? _Actions(hosts)),
      myReservationsSourcesProvider.overrideWith((ref) async => sources),
      clockProvider.overrideWithValue(FixedClock(kTestNow)),
      // #2553 C4: the guest visits beside the bookings; none here.
      myGuestVisitsProvider.overrideWith((ref) async => const []),
      appForegroundProvider.overrideWith(() => _Foreground(initial: foreground)),
    ];

Finder _card(String id) => find.byKey(ValueKey('my-reservation-$id'));

/// A few frames, enough for a chip, a dialog or a sheet route to finish
/// and for the fakes' answers to land; nothing here animates forever.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _show(WidgetTester tester, List<Override> overrides) async {
  await pumpApp(tester, const Scaffold(body: MyReservationsBody()),
      overrides: overrides, size: const Size(800, 1600));
  await tester.pumpAndSettle();
}

void main() {
  final today9 = DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 9);
  final tomorrow9 = today9.add(const Duration(days: 1));
  final yesterday9 = today9.subtract(const Duration(days: 1));

  group('tabs and sources', () {
    testWidgets('Upcoming, Past and Cancelled follow the actual status; Past has its own period, newest first',
        (tester) async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [
          _item('soon', tomorrow9),
          _item('gone', tomorrow9.add(const Duration(hours: 3)), status: ReservationStatus.cancelled),
          _item('now', today9, status: ReservationStatus.checkedIn),
        ]);
      await _show(tester, _overrides(hosts, sources: const [_a]));

      expect(_card('soon'), findsOneWidget);
      expect(_card('now'), findsOneWidget, reason: 'checked in and not ended: still upcoming');
      expect(_card('gone'), findsNothing, reason: 'a cancelled booking is not upcoming');

      await tester.tap(find.byKey(const ValueKey('my-reservations-tab-cancelled')));
      await _frames(tester);
      expect(_card('gone'), findsOneWidget);
      expect(_card('soon'), findsNothing);

      hosts.first['inst-a'] = _page('inst-a', [
        _item('last-week', yesterday9.subtract(const Duration(days: 6))),
        _item('yesterday', yesterday9, status: ReservationStatus.completed),
      ]);
      await tester.tap(find.byKey(const ValueKey('my-reservations-tab-past')));
      await _frames(tester);
      final (_, past) = hosts.asked.last;
      expect(past.direction, MyReservationsDirection.descending, reason: 'the past is read newest first');
      expect(past.to, DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1),
          reason: 'the past period ends with today');
      expect(past.to.difference(past.from), const Duration(days: 7), reason: 'the setting\'s span');
      expect(tester.getTopLeft(_card('yesterday')).dy, lessThan(tester.getTopLeft(_card('last-week')).dy),
          reason: 'newest first');
    });

    testWidgets('one source alone: the other host\'s rows and notices leave, the choice stays',
        (tester) async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', today9)])
        ..first['inst-b'] = _page('inst-b', [_item('b1', tomorrow9, workspace: 'ws-b')]);
      await _show(tester, _overrides(hosts));
      expect(_card('a1'), findsOneWidget);
      expect(_card('b1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('my-reservations-source-inst-b')));
      await _frames(tester);
      expect(_card('a1'), findsNothing);
      expect(_card('b1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('my-reservations-tab-cancelled')));
      await _frames(tester);
      await tester.tap(find.byKey(const ValueKey('my-reservations-tab-upcoming')));
      await _frames(tester);
      expect(_card('a1'), findsNothing, reason: 'the source filter survives a tab change');

      await tester.tap(find.byKey(const ValueKey('my-reservations-source-all')));
      await _frames(tester);
      expect(_card('a1'), findsOneWidget);
    });

    testWidgets('a tab with nothing in it is empty only once its hosts answered everything',
        (tester) async {
      final hosts = _Hosts()..first['inst-a'] = _page('inst-a', [_item('soon', tomorrow9)]);
      await _show(tester, _overrides(hosts, sources: const [_a]));
      await tester.tap(find.byKey(const ValueKey('my-reservations-tab-cancelled')));
      await _frames(tester);
      expect(find.byKey(const ValueKey('my-reservations-empty')), findsOneWidget);
    });
  });

  group('the zone of a card', () {
    testWidgets('times are the workspace\'s wall clock, and its zone is named when it differs',
        (tester) async {
      // +14:00 all year: no device a test runs on shares it.
      const far = 'Pacific/Kiritimati';
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('far', tomorrow9)], zones: {'ws-a': far})
        ..first['inst-b'] = _page('inst-b', [_item('here', tomorrow9, workspace: 'ws-b')]);
      await _show(tester, _overrides(hosts));

      expect(find.byKey(const ValueKey('my-reservation-zone-far')), findsOneWidget);
      expect(find.text(_l10n.myReservationsTimesIn(far)), findsOneWidget);
      expect(find.byKey(const ValueKey('my-reservation-zone-here')), findsNothing,
          reason: 'no zone known: the device\'s clock, nothing to name');

      final container = ProviderScope.containerOf(tester.element(find.byType(MyReservationsBody)));
      final format = container.read(appFormatProvider);
      final there = tz.TZDateTime.from(tomorrow9, tz.getLocation(far));
      final times = tester.widget<Text>(find.byKey(const ValueKey('my-reservation-times-far'))).data!;
      expect(times, contains(format.wallTime(there)), reason: 'the start on the workspace\'s clock');
      expect(times, isNot(contains(format.wallTime(tomorrow9))));
    });
  });

  group('row actions', () {
    testWidgets('Check in goes to the row\'s own host, not the first or selected one', (tester) async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', today9)])
        ..first['inst-b'] = _page('inst-b', [_item('b1', today9.add(const Duration(minutes: 30)), workspace: 'ws-b')]);
      final actions = _Actions(hosts);
      await _show(tester, _overrides(hosts, actions: actions));

      await tester.tap(find.byKey(const ValueKey('my-reservation-checkin-b1')));
      await _frames(tester);
      expect(actions.sent.first, ('checkIn', 'inst-b', 'b1'),
          reason: 'the source the row was read from; inst-a is the selected one');
      expect(actions.sent.last, ('view', 'inst-b', 'b1'), reason: 'read again on the same host');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('my-reservation-status-b1'))).data,
        _l10n.myReservationsStatusCheckedIn,
      );
      expect(find.text(_l10n.myReservationsCheckInDone), findsOneWidget);
      expect(actions.sent.where((s) => s.$2 == 'inst-a'), isEmpty);
    });

    testWidgets('a refused Cancel says the host\'s reason on its row; Try again cancels it',
        (tester) async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', today9)])
        ..first['inst-b'] = _page('inst-b', [_item('b1', tomorrow9, workspace: 'ws-b')]);
      final actions = _Actions(hosts)
        ..refusals.add(const MyReservationsRefused(MyReservationsFailure.hostUnavailable));
      await _show(tester, _overrides(hosts, actions: actions));

      await tester.tap(find.byKey(const ValueKey('my-reservation-cancel-b1')));
      await _frames(tester);
      await tester.tap(find.byKey(const ValueKey('my-reservation-cancel-confirm')));
      await _frames(tester);

      expect(find.byKey(const ValueKey('my-reservation-failed-b1')), findsOneWidget);
      expect(find.text(_l10n.myReservationsHostUnavailable), findsOneWidget);
      expect(_card('b1'), findsOneWidget, reason: 'the row stays as its host still holds it');
      expect(_card('a1'), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('my-reservation-failed-b1')),
        matching: find.text(_l10n.commonRetry),
      ));
      await _frames(tester);
      expect(actions.sent.where((s) => s.$1 == 'cancel'), [('cancel', 'inst-b', 'b1'), ('cancel', 'inst-b', 'b1')]);
      expect(_card('b1'), findsNothing, reason: 'cancelled: it left Upcoming');
      expect(find.text(_l10n.myReservationsCancelDone), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('my-reservations-tab-cancelled')));
      await _frames(tester);
      expect(_card('b1'), findsOneWidget);
    });

    testWidgets('a host\'s own refusal of Check in is its reason, never a generic one', (tester) async {
      final hosts = _Hosts()..first['inst-b'] = _page('inst-b', [_item('b1', today9, workspace: 'ws-b')]);
      final actions = _Actions(hosts)
        ..refusals.add(const PostgrestException(message: 'reservation is outside the bookable window'));
      await _show(tester, _overrides(hosts, actions: actions, sources: const [_b]));
      await tester.tap(find.byKey(const ValueKey('my-reservation-checkin-b1')));
      await _frames(tester);
      expect(find.byKey(const ValueKey('my-reservation-failed-b1')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('my-reservation-status-b1'))).data,
        _l10n.myReservationsStatusReserved,
      );
    });

    testWidgets('Cancel asked and kept changes nothing', (tester) async {
      final hosts = _Hosts()..first['inst-b'] = _page('inst-b', [_item('b1', tomorrow9, workspace: 'ws-b')]);
      final actions = _Actions(hosts);
      await _show(tester, _overrides(hosts, actions: actions, sources: const [_b]));
      await tester.tap(find.byKey(const ValueKey('my-reservation-cancel-b1')));
      await _frames(tester);
      await tester.tap(find.text(_l10n.myReservationsKeep));
      await _frames(tester);
      expect(actions.sent, isEmpty);
      expect(_card('b1'), findsOneWidget);
    });

    testWidgets('View reads the row again on its host; a row it no longer lists leaves, '
        'and a lost answer can be asked again', (tester) async {
      final hosts = _Hosts()
        ..first['inst-a'] = _page('inst-a', [_item('a1', today9)])
        ..first['inst-b'] = _page('inst-b', [_item('b1', tomorrow9, workspace: 'ws-b')]);
      final actions = _Actions(hosts)..viewFailure = TimeoutException('slow');
      await _show(tester, _overrides(hosts, actions: actions));

      await tester.tap(find.byKey(const ValueKey('my-reservation-view-b1')));
      await _frames(tester);
      expect(actions.sent.single, ('view', 'inst-b', 'b1'));
      expect(find.byKey(const ValueKey('my-reservation-sheet-failed')), findsOneWidget);
      expect(find.text(_l10n.myReservationsTimedOut), findsOneWidget);

      actions.viewFailure = null;
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('my-reservation-sheet-failed')),
        matching: find.text(_l10n.commonRetry),
      ));
      await _frames(tester);
      expect(find.byKey(const ValueKey('my-reservation-sheet-failed')), findsNothing);
      expect(
        find.descendant(of: find.byKey(const ValueKey('my-reservation-sheet')), matching: find.text('Desk b1')),
        findsOneWidget,
      );
      Navigator.of(tester.element(find.byKey(const ValueKey('my-reservation-sheet')))).pop();
      await _frames(tester);

      actions.viewFailure = const MyReservationsRefused(MyReservationsFailure.gone);
      await tester.tap(find.byKey(const ValueKey('my-reservation-view-a1')));
      await _frames(tester);
      expect(actions.sent.last, ('view', 'inst-a', 'a1'));
      expect(find.text(_l10n.myReservationsGone), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const ValueKey('my-reservation-sheet')))).pop();
      await _frames(tester);
      expect(_card('a1'), findsNothing, reason: 'its host no longer lists it');
      expect(_card('b1'), findsOneWidget);
    });
  });

  group('the composer', () {
    final query = MyReservationsQuery(from: today9, to: today9.add(const Duration(days: 3)));

    test('a done action whose echo fails reads the whole view again', () async {
      final hosts = _Hosts()..first['inst-b'] = _page('inst-b', [_item('b1', tomorrow9, workspace: 'ws-b')]);
      final actions = _Actions(hosts)..viewFailure = Exception('lost');
      final container = ProviderContainer(overrides: _overrides(hosts, actions: actions, sources: const [_b]));
      addTearDown(container.dispose);
      final sub = container.listen(myReservationsComposerProvider(query), (_, _) {});
      addTearDown(sub.close);
      await container.read(myReservationsComposerProvider(query).future);
      await pumpEventQueue();
      final before = hosts.asked.length;

      await container.read(myReservationsComposerProvider(query).notifier).cancel('inst-b', 'b1');
      await container.read(myReservationsComposerProvider(query).future);
      await pumpEventQueue();
      expect(actions.sent.first, ('cancel', 'inst-b', 'b1'));
      expect(hosts.asked.length, before + 1, reason: 'the host is read again instead of showing the old row');
    });

    test('an action on a row the view does not hold is refused, and nothing is sent', () async {
      final hosts = _Hosts();
      final actions = _Actions(hosts);
      final container = ProviderContainer(overrides: _overrides(hosts, actions: actions, sources: const [_b]));
      addTearDown(container.dispose);
      final sub = container.listen(myReservationsComposerProvider(query), (_, _) {});
      addTearDown(sub.close);
      await container.read(myReservationsComposerProvider(query).future);
      await expectLater(
        container.read(myReservationsComposerProvider(query).notifier).checkIn('inst-a', 'b1'),
        throwsA(isA<MyReservationsRefused>().having((e) => e.failure, 'failure', MyReservationsFailure.gone)),
      );
      expect(actions.sent, isEmpty);
    });

    test('hidden, no host is read; on resume each host is read once, however often it was asked',
        () async {
      final hosts = _Hosts();
      final container = ProviderContainer(overrides: _overrides(hosts, foreground: false));
      addTearDown(container.dispose);
      final sub = container.listen(myReservationsComposerProvider(query), (_, _) {});
      addTearDown(sub.close);
      await container.read(myReservationsComposerProvider(query).future);
      await pumpEventQueue();
      expect(hosts.asked, isEmpty, reason: 'nobody sees the view: nothing is read');

      container.read(myReservationsComposerProvider(query).notifier)
        ..retry('inst-a')
        ..retry('inst-b')
        ..loadMore();
      await pumpEventQueue();
      expect(hosts.asked, isEmpty);

      (container.read(appForegroundProvider.notifier) as _Foreground).set(foreground: true);
      await pumpEventQueue();
      expect(hosts.asked.map((a) => a.$1).toList()..sort(), ['inst-a', 'inst-b'],
          reason: 'one read per host, not one per ask');
      expect(container.read(myReservationsComposerProvider(query)).value!.empty, isTrue);
    });
  });

  group('the pure rules', () {
    test('a tab follows the status and the end', () {
      expect(MyReservationsTab.of(_item('x', tomorrow9), kTestNow), MyReservationsTab.upcoming);
      expect(MyReservationsTab.of(_item('x', yesterday9), kTestNow), MyReservationsTab.past);
      expect(
        MyReservationsTab.of(_item('x', tomorrow9, status: ReservationStatus.cancelled), kTestNow),
        MyReservationsTab.cancelled,
      );
      expect(
        MyReservationsTab.of(_item('x', tomorrow9, status: ReservationStatus.released), kTestNow),
        MyReservationsTab.past,
      );
    });

    test('a past composition merges newest first and holds the horizon the other way', () {
      final cursor = MyReservationsCursor(afterStart: yesterday9.toUtc(), afterId: 'a2');
      final composition = MyReservationsComposition(
        [
          MyReservationsSlot.firstPage(
            _a,
            _page('inst-a', [_item('a1', today9), _item('a2', yesterday9)], next: cursor),
          ),
          MyReservationsSlot.firstPage(_b, _page('inst-b', [
            _item('b1', today9.add(const Duration(hours: 1)), workspace: 'ws-b'),
            _item('b2', yesterday9.subtract(const Duration(days: 1)), workspace: 'ws-b'),
          ])),
        ],
        direction: MyReservationsDirection.descending,
      );
      expect(composition.visible.map((e) => e.item.id), ['b1', 'a1', 'a2'],
          reason: 'b2 is older than A\'s last row: A may still hold rows between');
    });

    test('a row is replaced in place, or leaves when its host no longer lists it', () {
      final composition = MyReservationsComposition([
        MyReservationsSlot.firstPage(_a, _page('inst-a', [_item('a1', today9), _item('a2', tomorrow9)])),
      ]);
      final cancelled = _item('a1', today9, status: ReservationStatus.cancelled);
      expect(composition.withItem('inst-a', 'a1', cancelled).visible.first.item.status,
          ReservationStatus.cancelled);
      expect(composition.withItem('inst-a', 'a1', null).visible.map((e) => e.item.id), ['a2']);
      expect(composition.withItem('inst-x', 'a1', null).visible, hasLength(2));
    });

    test('the foreground is resumed or inactive', () {
      expect(isForeground(AppLifecycleState.resumed), isTrue);
      expect(isForeground(AppLifecycleState.inactive), isTrue);
      expect(isForeground(AppLifecycleState.hidden), isFalse);
      expect(isForeground(AppLifecycleState.paused), isFalse);
    });

    test('paused reads wait; resume starts them within the bound', () async {
      final reads = BoundedReads(1)..pause();
      final started = <int>[];
      final blocker = Completer<void>();
      final a = reads.run(() async {
        started.add(1);
        await blocker.future;
      });
      final b = reads.run(() async => started.add(2));
      await pumpEventQueue();
      expect(started, isEmpty);
      expect(reads.waiting, 2);
      reads.resume();
      await pumpEventQueue();
      expect(started, [1], reason: 'one at a time, as the limit says');
      blocker.complete();
      await a;
      await b;
      expect(started, [1, 2]);
      expect(reads.running, 0);
    });
  });
}
