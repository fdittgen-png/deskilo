// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 — the My reservations body: the window the personal home's limits
// say (default span, ceiling), the person's bookings grouped by day in one
// column, the next page on Show more, an empty window and each refusal in
// words with the way to try again, and the period changed from the picker —
// cut to the ceiling, never refused by the host. C2: every host my account
// names is read with its own state; one host failing never hides another,
// and Try again asks that host alone.
import 'dart:async';

import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
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

MyReservationItem _item(String id, DateTime start, {String workspace = 'One'}) =>
    MyReservationItem(
      id: id,
      workspaceId: 'ws-$workspace',
      workspaceName: workspace,
      placeKind: MyReservationPlaceKind.seat,
      placeId: 'seat-1',
      placeLabel: 'A1',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 4)),
      status: ReservationStatus.reserved,
      checkedInAt: null,
      checkedOutAt: null,
    );

const _a = MyReservationsSource(installationId: 'inst-a', workspaceIds: ['ws-One'], hostedHere: true, labels: ['One']);

/// Hosts answering from a queue: the first page, then the continuation,
/// per installation. Its limits are a 7-day default and a 60-day ceiling,
/// two hosts at a time and a 5-second wait — not the registry's numbers,
/// so a test proves they are read, not assumed.
class _FakeRepository implements MyReservationsRepository {
  _FakeRepository({this.first, this.continuation, this.failure, this.limitsFailure});

  MyReservationsPage? first;
  MyReservationsPage? continuation;
  Exception? failure;
  Exception? limitsFailure;

  /// Per-host answers that take precedence over the ones above.
  final Map<String, MyReservationsPage> firstOf = {};
  final Map<String, Exception> failureOf = {};
  final Map<String, Completer<MyReservationsPage>> pendingOf = {};
  final List<MyReservationsQuery> asked = [];
  final List<String> askedHosts = [];

  @override
  Future<MyReservationsLimits> limits() async {
    final refused = limitsFailure;
    if (refused != null) throw refused;
    return const MyReservationsLimits(
      windowDays: 7,
      maxDays: 60,
      concurrency: 2,
      timeout: Duration(seconds: 5),
    );
  }

  @override
  Future<MyReservationsPage> page(MyReservationsSource source, MyReservationsQuery query) async {
    asked.add(query);
    askedHosts.add(source.installationId);
    final pending = pendingOf[source.installationId];
    if (pending != null) return pending.future;
    final hostFailure = failureOf[source.installationId];
    if (hostFailure != null) throw hostFailure;
    final refused = failure;
    if (refused != null) throw refused;
    final own = firstOf[source.installationId];
    if (own != null && query.after == null) return own;
    return query.after == null ? first! : continuation!;
  }
}

MyReservationsPage _pageOf(List<MyReservationItem> items, {MyReservationsCursor? next, String source = 'inst-a'}) =>
    MyReservationsPage(source: source, items: items, next: next, hasMore: next != null);

List<Override> _overrides(_FakeRepository repository, {List<MyReservationsSource> sources = const [_a]}) => [
      myReservationsRepositoryProvider.overrideWithValue(repository),
      myReservationsSourcesProvider.overrideWith((ref) async => sources),
      clockProvider.overrideWithValue(FixedClock(kTestNow)),
    ];

void main() {
  final day1 = DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 9);
  final day2 = day1.add(const Duration(days: 1));

  testWidgets('the window the host allows, bookings grouped by day, one more page on Show more',
      (tester) async {
    final cursor = MyReservationsCursor(afterStart: day2, afterId: 'r-3');
    final repository = _FakeRepository(
      first: _pageOf([
        _item('r-1', day1),
        _item('r-2', day1.add(const Duration(hours: 5)), workspace: 'Two'),
        _item('r-3', day2),
      ], next: cursor),
      continuation: _pageOf([_item('r-4', day2.add(const Duration(hours: 6)))]),
    );
    await pumpApp(tester, const Scaffold(body: MyReservationsBody()), overrides: _overrides(repository));
    await tester.pumpAndSettle();

    final asked = repository.asked.single;
    expect(asked.from, DateTime(kTestNow.year, kTestNow.month, kTestNow.day));
    expect(asked.to.difference(asked.from), const Duration(days: 7),
        reason: 'the default span is the personal home\'s setting');
    expect(find.text(_l10n.myReservationsPeriodLimit(60)), findsOneWidget);
    for (final id in ['r-1', 'r-2', 'r-3']) {
      expect(find.byKey(ValueKey('my-reservation-$id')), findsOneWidget);
    }
    expect(find.textContaining('One'), findsNWidgets(2));
    expect(find.textContaining('Two'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-reservations-load-more')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('my-reservations-load-more')));
    await tester.pumpAndSettle();
    expect(repository.asked.last.after, cursor, reason: 'the next page continues after the cursor');
    expect(find.byKey(const ValueKey('my-reservation-r-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-reservation-r-1')), findsOneWidget, reason: 'the first page stays');
    expect(find.byKey(const ValueKey('my-reservations-load-more')), findsNothing,
        reason: 'the host said it was the last page');
  });

  testWidgets('an empty window says so and still offers another period', (tester) async {
    final repository = _FakeRepository(first: _pageOf(const []));
    await pumpApp(tester, const Scaffold(body: MyReservationsBody()), overrides: _overrides(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my-reservations-empty')), findsOneWidget);
    expect(find.text(_l10n.myReservationsEmpty), findsOneWidget);
    expect(find.byKey(const ValueKey('my-reservations-window')), findsOneWidget);
  });

  testWidgets('a refusal is said in its own words, and Try again asks the host again',
      (tester) async {
    final repository = _FakeRepository(
      failure: const MyReservationsRefused(MyReservationsFailure.forbidden),
    );
    await pumpApp(tester, const Scaffold(body: MyReservationsBody()), overrides: _overrides(repository));
    await tester.pumpAndSettle();
    expect(
      find.text(_l10n.myReservationsSourceProblem('One', _l10n.myReservationsForbidden)),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('my-reservations-empty')), findsNothing,
        reason: 'a refusal is never shown as an empty window');
    expect(repository.asked, hasLength(1), reason: 'a refusal is final: no retry of its own');

    repository
      ..failure = null
      ..first = _pageOf([_item('r-1', day1)]);
    await tester.tap(find.byKey(const ValueKey('my-reservations-source-retry-inst-a')));
    await tester.pumpAndSettle();
    expect(repository.asked, hasLength(2));
    expect(find.byKey(const ValueKey('my-reservation-r-1')), findsOneWidget);
  });

  test('every typed failure has its own sentence', () {
    final sentences = {
      for (final f in MyReservationsFailure.values)
        problemWords(_l10n, MyReservationsRefused(f)),
    };
    expect(sentences, hasLength(MyReservationsFailure.values.length - 1),
        reason: 'malformed and incompatible share one sentence; the rest differ');
    expect(problemWords(_l10n, StateError('x')), _l10n.myReservationsFailed);
    expect(problemWords(_l10n, TimeoutException('slow')), _l10n.myReservationsTimedOut);
  });

  testWidgets('a host whose registry lacks the personal rows is said so, and no read is made',
      (tester) async {
    final repository = _FakeRepository(
      first: _pageOf(const []),
      limitsFailure: const MyReservationsRefused(MyReservationsFailure.misconfigured),
    );
    await pumpApp(tester, const Scaffold(body: MyReservationsBody()), overrides: _overrides(repository));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.myReservationsMisconfigured), findsOneWidget);
    expect(find.byKey(const ValueKey('my-reservations-retry')), findsOneWidget);
    expect(repository.asked, isEmpty, reason: 'no window, no read');
  });

  testWidgets('one column at 360 px: three bookings, nothing overflows', (tester) async {
    final repository = _FakeRepository(
      first: _pageOf([
        _item('r-1', day1),
        _item('r-2', day1.add(const Duration(hours: 5)), workspace: 'A space with a long name'),
        _item('r-3', day2),
      ]),
    );
    await pumpApp(tester, const Scaffold(body: MyReservationsBody()),
        overrides: _overrides(repository), size: const Size(360, 640));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final cards = find.byType(Card);
    expect(cards, findsNWidgets(3));
    final lefts = {for (final e in cards.evaluate()) tester.getTopLeft(find.byWidget(e.widget)).dx};
    expect(lefts, hasLength(1), reason: 'one column: every card starts at the same x');
  });

  testWidgets('the period picker opens from its button, and a chosen period is cut to the ceiling',
      (tester) async {
    final repository = _FakeRepository(first: _pageOf(const []));
    await pumpApp(tester, const Scaffold(body: MyReservationsBody()), overrides: _overrides(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('my-reservations-window')));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DateRangePickerDialog), findsNothing);

    final container = ProviderScope.containerOf(tester.element(find.byType(MyReservationsBody)));
    final first = DateTime(kTestNow.year, kTestNow.month + 1);
    container
        .read(myReservationsWindowControllerProvider.notifier)
        .cover(first, DateTime(first.year, first.month + 6));
    await tester.pump();
    await tester.pump();
    final asked = repository.asked.last;
    expect(asked.from, first);
    expect(asked.to, DateTime(first.year, first.month, first.day + 60),
        reason: 'the ceiling of 60 days, from the settings, cuts the chosen period');
    expect(repository.asked, hasLength(2), reason: 'a new window is a new read');
  });
}
