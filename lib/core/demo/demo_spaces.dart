// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3867 — the one list of the Demo's spaces. The fixture's per-space data
// (below), both routers (demo_space_routing.dart, demo_space_pick.dart),
// Me's finances and the data-truth guards all iterate [DemoSpaceKey.values]:
// a space is added here once, and every `switch` over the key stops
// compiling until it answers for the new space.
import 'data/booking_right_reservations.dart';
import 'data/floor_plan_repository.dart';
import 'data/money_repository.dart';
import 'data/workspace_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_ids.dart';
import 'seed/demo_twin_seed.dart';

/// The Demo's spaces: the id its workspace row carries, a name for people and
/// tests, and the currency every figure of the space is in.
enum DemoSpaceKey {
  home(demoFirstSpaceId, 'Pézenas', 'EUR'),
  leipzig(demoSecondSpaceId, 'Leipzig', 'EUR'),
  london(demoLondonSpaceId, 'London', 'GBP'),
  newYork(demoNewYorkSpaceId, 'New York', 'USD'),
  zurich(demoZurichSpaceId, 'Zurich', 'CHF'),
  milan(demoMilanSpaceId, 'Milan', 'EUR'),
  twin(demoTwinSpaceId, 'the development twin', 'EUR');

  const DemoSpaceKey(this.id, this.label, this.currency);

  final String id;
  final String label;
  final String currency;

  /// The space the workspace id [id] names: the main space while none is
  /// open yet (null or empty). An id no space owns throws: it never borrows
  /// another space's data.
  static DemoSpaceKey of(String? id) {
    if (id == null || id.isEmpty) return home;
    for (final key in values) {
      if (key.id == id) return key;
    }
    throw StateError('unknown demo space: $id');
  }
}

/// One value for each of the Demo's spaces.
typedef DemoSpaces<T> = ({
  T home,
  T leipzig,
  T london,
  T newYork,
  T zurich,
  T milan,
  T twin,
});

extension DemoSpacesAt<T> on DemoSpaces<T> {
  /// The value of [key]'s space (a `switch` the compiler holds complete).
  T at(DemoSpaceKey key) => switch (key) {
    DemoSpaceKey.home => home,
    DemoSpaceKey.leipzig => leipzig,
    DemoSpaceKey.london => london,
    DemoSpaceKey.newYork => newYork,
    DemoSpaceKey.zurich => zurich,
    DemoSpaceKey.milan => milan,
    DemoSpaceKey.twin => twin,
  };
}

/// The value of every space, each made from the one it came from.
DemoSpaces<R> demoMapSpaces<T, R>(DemoSpaces<T> spaces, R Function(T) f) => (
  home: f(spaces.home),
  leipzig: f(spaces.leipzig),
  london: f(spaces.london),
  newYork: f(spaces.newYork),
  zurich: f(spaces.zurich),
  milan: f(spaces.milan),
  twin: f(spaces.twin),
);

/// A value for each space, made from its key.
DemoSpaces<T> demoSpacesOf<T>(T Function(DemoSpaceKey key) f) => (
  home: f(DemoSpaceKey.home),
  leipzig: f(DemoSpaceKey.leipzig),
  london: f(DemoSpaceKey.london),
  newYork: f(DemoSpaceKey.newYork),
  zurich: f(DemoSpaceKey.zurich),
  milan: f(DemoSpaceKey.milan),
  twin: f(DemoSpaceKey.twin),
);

/// What the fixture holds for each space.
extension DemoFixtureSpaces on DemoFixture {
  DemoSpaces<FakeWorkspaceRepository> get spaceWorkspaces => (
    home: workspaces,
    leipzig: secondSpace.workspaces,
    london: london.workspaces,
    newYork: newYork.workspaces,
    zurich: zurich.workspaces,
    milan: milan.workspaces,
    twin: twin.workspaces,
  );

  DemoSpaces<FakeMoneyRepository> get spaceMoney => (
    home: money,
    leipzig: secondSpace.money,
    london: london.money,
    newYork: newYork.money,
    zurich: zurich.money,
    milan: milan.money,
    twin: twin.money,
  );

  DemoSpaces<FakeFloorPlanRepository> get spaceFloorPlans => (
    home: floorPlan,
    leipzig: secondSpace.floorPlan,
    london: london.floorPlan,
    newYork: newYork.floorPlan,
    zurich: zurich.floorPlan,
    milan: milan.floorPlan,
    twin: twin.floorPlan,
  );

  DemoSpaces<RightsCheckedReservationRepository> get spaceReservations => (
    home: reservations,
    leipzig: secondSpace.reservations,
    london: london.reservations,
    newYork: newYork.reservations,
    zurich: zurich.reservations,
    milan: milan.reservations,
    twin: twin.reservations,
  );
}
