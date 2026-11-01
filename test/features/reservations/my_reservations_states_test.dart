// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3061 — the member's own reservations list: loading is not "no bookings";
// a pull to refresh keeps the rows while the hosts are asked again; the write
// the list owns (Cancel on a row) is one command however often it is
// activated. Refusals, empties and Try again are pinned in
// my_reservations_body_test.dart and my_reservations_rows_test.dart.
import 'dart:async';

import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/my_reservations_body.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/visits/providers/visits_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/read_probe.dart';
import '../../helpers/test_clock.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

const _host = MyReservationsSource(
  installationId: 'inst-a',
  workspaceIds: ['ws-a'],
  hostedHere: true,
  labels: ['Pézenas'],
);

MyReservationItem _item(String id, DateTime start) => MyReservationItem(
  id: id,
  workspaceId: 'ws-a',
  workspaceName: 'ws-a',
  placeKind: MyReservationPlaceKind.desk,
  placeId: 'desk-$id',
  placeLabel: 'Desk $id',
  startsAt: start.toUtc(),
  endsAt: start.add(const Duration(hours: 2)).toUtc(),
  status: ReservationStatus.reserved,
  checkedInAt: null,
  checkedOutAt: null,
);

/// One host whose pages the test answers, in order.
class _Host implements MyReservationsRepository {
  final probe = ReadProbe<MyReservationsPage>();

  @override
  Future<MyReservationsLimits> limits() async => const MyReservationsLimits(
    windowDays: 7,
    maxDays: 60,
    concurrency: 2,
    timeout: Duration(seconds: 5),
  );

  @override
  Future<MyReservationsPage> page(
    MyReservationsSource source,
    MyReservationsQuery query,
  ) => probe();
}

/// Row actions the test holds.
class _Actions implements MyReservationActions {
  final List<String> sent = [];
  final Completer<void> hold = Completer<void>();

  @override
  Future<MyReservationItem> view(
    MyReservationsSource source,
    MyReservationItem item,
  ) async => item;

  @override
  Future<void> cancel(MyReservationsSource source, MyReservationItem item) async {
    sent.add(item.id);
    await hold.future;
  }

  @override
  Future<void> checkIn(MyReservationsSource source, MyReservationItem item) async {
    sent.add('checkIn ${item.id}');
  }
}

MyReservationsPage _page(List<MyReservationItem> items) => MyReservationsPage(
  source: 'inst-a',
  items: items,
  next: null,
  hasMore: false,
);

Future<(_Host, _Actions)> _pump(WidgetTester tester) async {
  final host = _Host();
  final actions = _Actions();
  await pumpStateScreen(
    tester,
    const Scaffold(body: MyReservationsBody()),
    overrides: [
      myReservationsRepositoryProvider.overrideWithValue(host),
      myReservationActionsProvider.overrideWithValue(actions),
      myReservationsSourcesProvider.overrideWith((ref) async => const [_host]),
      clockProvider.overrideWithValue(FixedClock(kTestNow)),
      myGuestVisitsProvider.overrideWith((ref) async => const []),
    ],
    size: const Size(800, 1600),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return (host, actions);
}

void main() {
  final tomorrow = DateTime(kTestNow.year, kTestNow.month, kTestNow.day + 1, 9);

  testWidgets('loading is not "no bookings": a spinner, then the rows', (
    tester,
  ) async {
    final (host, _) = await _pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('my-reservations-empty')), findsNothing);

    host.probe.answer(_page([_item('r1', tomorrow)]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('my-reservation-r1')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a pull to refresh keeps the rows while the host is asked '
      'again', (tester) async {
    final (host, _) = await _pump(tester);
    host.probe.answer(_page([_item('r1', tomorrow)]));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(
      find.byKey(const ValueKey('my-reservations-list')),
      const Offset(0, 400),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(host.probe.calls, 2, reason: 'the host was asked once more');
    expect(
      find.byKey(const ValueKey('my-reservation-r1')),
      findsOneWidget,
      reason: 'the rows stay while the new answer is awaited',
    );
    expect(find.byKey(const ValueKey('my-reservations-empty')), findsNothing);

    host.probe.answer(_page([_item('r1', tomorrow), _item('r2', tomorrow)]));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('my-reservation-r2')), findsOneWidget);
  });

  testWidgets('Cancel enters pending at once and is one command however '
      'often it is activated', (tester) async {
    final (host, actions) = await _pump(tester);
    host.probe.answer(_page([_item('r1', tomorrow)]));
    await tester.pump(const Duration(milliseconds: 300));

    final cancel = find.byKey(const ValueKey('my-reservation-cancel-r1'));
    await tester.tap(cancel);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('my-reservation-cancel-confirm')));
    await tester.pump();
    expect(actions.sent, ['r1']);
    expect(tester.widget<TextButton>(cancel).onPressed, isNull);

    await tester.tap(cancel, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(_l10n.myReservationsCancelTitle), findsNothing);
    expect(actions.sent, ['r1'], reason: 'one effective command');
    actions.hold.complete();
    await tester.pump();
  });
}
