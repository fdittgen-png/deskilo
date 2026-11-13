// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — each Demo space sells its own guest passes: Pézenas a day pass
// (its network page says so), London day passes and a drop-in hour, New
// York by the hour (the owner's choice for the city). Leipzig carries a
// new space's defaults, so the passes are off there and it lists none.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/domain/guest_pass.dart';
import '../../features/money/providers/guest_pass_providers.dart';
import '../../features/plan/domain/seat.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import 'data/guest_pass_repository.dart';
import 'data/money_repository.dart';
import 'data/reservation_repository.dart';
import 'data/workspace_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_pick.dart';
import 'seed/demo_commerce_country_seed.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_twin_seed.dart';

const _pezenasPasses = [
  GuestPassOffer(id: 'demo-pass-pezenas-day', name: 'Pass journée', unit: GuestPassUnit.day, priceCents: 1800),
];
const _londonPasses = [
  GuestPassOffer(id: 'demo-pass-london-day', name: 'Day pass', unit: GuestPassUnit.day, priceCents: 2500),
  GuestPassOffer(id: 'demo-pass-london-hour', name: 'Drop-in hour', unit: GuestPassUnit.hour, priceCents: 600),
];
const _newYorkPasses = [
  GuestPassOffer(id: 'demo-pass-ny-hour', name: 'Hourly pass', unit: GuestPassUnit.hour, priceCents: 900),
];

/// The persona's rights where the pass is sold, read when it is sold.
class _Rights {
  Set<WorkspacePermission> Function() held = () => const {};
  bool has(WorkspacePermission p) => held().contains(p);
}

List<Override> demoGuestPassOverrides(DemoFixture fixture) {
  final rights = _Rights();
  FakeGuestPassRepository space(
    String id,
    String currency,
    ({FakeReservationRepository reservations, FakeWorkspaceRepository workspaces, FakeMoneyRepository money, List<Seat> Function() seats}) stores,
    List<GuestPassOffer> offers,
  ) =>
      FakeGuestPassRepository(
        workspaceId: id,
        currency: currency,
        reservations: stores.reservations,
        workspaces: stores.workspaces,
        money: stores.money,
        now: () => fixture.seededAt,
        maySell: () => rights.has(WorkspacePermission.issueInvoices),
        mayPrice: () => rights.has(WorkspacePermission.manageServices),
        floorPlanSeats: stores.seats,
        offers: offers,
      );
  final home = space(demoFirstSpaceId, 'EUR',
      (reservations: fixture.reservations, workspaces: fixture.workspaces, money: fixture.money, seats: () => fixture.floorPlan.seats), _pezenasPasses);
  final leipzig = space(demoSecondSpaceId, 'EUR',
      (reservations: fixture.secondSpace.reservations, workspaces: fixture.secondSpace.workspaces,
       money: fixture.secondSpace.money, seats: () => fixture.secondSpace.floorPlan.seats), const []);
  final london = space(demoLondonSpaceId, 'GBP',
      (reservations: fixture.london.reservations, workspaces: fixture.london.workspaces,
       money: fixture.london.money, seats: () => fixture.london.floorPlan.seats), _londonPasses);
  final newYork = space(demoNewYorkSpaceId, 'USD',
      (reservations: fixture.newYork.reservations, workspaces: fixture.newYork.workspaces,
       money: fixture.newYork.money, seats: () => fixture.newYork.floorPlan.seats), _newYorkPasses);
  final zurich = space(demoZurichSpaceId, 'CHF',
      (reservations: fixture.zurich.reservations, workspaces: fixture.zurich.workspaces,
       money: fixture.zurich.money, seats: () => fixture.zurich.floorPlan.seats), const []);
  final milan = space(demoMilanSpaceId, 'EUR',
      (reservations: fixture.milan.reservations, workspaces: fixture.milan.workspaces,
       money: fixture.milan.money, seats: () => fixture.milan.floorPlan.seats), const []);
  final twin = space(demoTwinSpaceId, 'EUR',
      (reservations: fixture.twin.reservations, workspaces: fixture.twin.workspaces,
       money: fixture.twin.money, seats: () => fixture.twin.floorPlan.seats), const []);
  return [
    guestPassRepositoryProvider.overrideWith((ref) {
      rights.held = () => ref.read(myPermissionsProvider).toSet();
      return demoPickSpace(ref, (home: home, leipzig: leipzig, london: london,
        newYork: newYork, zurich: zurich, milan: milan, twin: twin));
    }),
  ];
}
