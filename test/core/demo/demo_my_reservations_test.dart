// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C1 — the Demo's own-reservations read answers like a workspace
// host: the acting member's bookings of both spaces of the one fixture
// installation that overlap the window, nobody else's, in start order,
// paged by a keyset cursor without a duplicate or a gap.
import 'package:deskilo/core/demo/data/my_reservations_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MyReservationsQuery wide(DemoFixture fixture, {MyReservationsDirection? direction}) =>
      MyReservationsQuery(
        from: fixture.seededAt.subtract(const Duration(days: 400)),
        to: fixture.seededAt.add(const Duration(days: 400)),
        direction: direction ?? MyReservationsDirection.ascending,
      );

  /// The rows a host would answer: the member's own, overlapping the window.
  List<Reservation> own(Iterable<Reservation> rows, String member, MyReservationsQuery q) => [
        for (final r in rows)
          if (r.memberId == member && r.startsAt.isBefore(q.to) && r.endsAt.isAfter(q.from)) r,
      ]..sort((a, b) {
          final byStart = a.startsAt.compareTo(b.startsAt);
          return byStart != 0 ? byStart : a.id.compareTo(b.id);
        });

  test('the scope answers the acting member\'s bookings of both spaces, nobody else\'s', () async {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);

    final query = wide(fixture);
    final page = await container.read(myReservationsRepositoryProvider).page(query);
    // Both spaces' own rows, merged the way one host orders them.
    final expected = own([
      ...fixture.reservations.reservations.where((r) => r.memberId == fixture.activeMemberId),
      ...fixture.secondSpace.reservations.reservations
          .where((r) => r.memberId == fixture.secondSpace.reservations.myMemberId),
    ], fixture.activeMemberId, query);
    expect(page.items, isNotEmpty, reason: 'the demo persona has bookings');
    expect(page.items.map((i) => i.id).toList(), expected.take(50).map((r) => r.id).toList(),
        reason: 'exactly the acting member\'s rows, in start order, one page of the registry\'s size');
    expect(page.hasMore, expected.length > 50);
    expect(expected.map((r) => r.workspaceId).toSet(), contains(demoSecondSpaceId),
        reason: 'the second space of the one installation is read too');
    expect(page.items.every((i) => i.placeLabel.isNotEmpty), isTrue,
        reason: 'the plan names every booked place');
  });

  test('pages walk the keyset forward and backward without a duplicate or a gap', () async {
    final fixture = DemoFixture.build();
    final repository = DemoMyReservationsRepository(
      installationId: 'demo',
      pageSize: 2,
      spaces: [(floorPlan: fixture.floorPlan, reservations: fixture.reservations)],
      workspaceName: (id) => id,
    );
    final all = own(fixture.reservations.reservations, fixture.activeMemberId, wide(fixture))
        .map((r) => r.id)
        .toList();
    expect(all.length, greaterThan(2), reason: 'enough rows to page');

    Future<List<String>> walk(MyReservationsDirection direction) async {
      final ids = <String>[];
      var query = wide(fixture, direction: direction);
      while (true) {
        final page = await repository.page(query);
        expect(page.items.length, lessThanOrEqualTo(2));
        expect(page.source, 'demo');
        ids.addAll(page.items.map((i) => i.id));
        final next = page.next;
        if (!page.hasMore || next == null) return ids;
        query = query.continuedAfter(next);
      }
    }

    final forward = await walk(MyReservationsDirection.ascending);
    expect(forward, all);
    expect(forward.toSet().length, forward.length, reason: 'no duplicate');
    final backward = await walk(MyReservationsDirection.descending);
    expect(backward, all.reversed.toList());
  });
}
