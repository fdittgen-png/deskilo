// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3867 — the one list of the Demo's spaces. The fixture's per-space data
// (below), both routers (demo_space_routing.dart, demo_space_pick.dart),
// Me's finances and the data-truth guards all iterate [DemoSpaceKey.values]:
// a space is added here once, and every `switch` over the key stops
// compiling until it answers for the new space.
//
// #3846 — a space is built when it is first read, not all at the start:
// [DemoSpaces] makes the value of a space on its first [DemoSpaces.at] and
// keeps it, and [DemoSpaceParts] is what every space answers with.
import 'data/accessory_repository.dart';
import 'data/booking_right_reservations.dart';
import 'data/calendar_repository.dart';
import 'data/credit_repository.dart';
import 'data/event_repository.dart';
import 'data/floor_plan_repository.dart';
import 'data/money_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/workspace_fields_repository.dart';
import 'data/workspace_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_ids.dart';
import 'seed/demo_twin_seed.dart' show demoTwinSpaceId;

/// The Demo's spaces: the id its workspace row carries, a name for people and
/// tests, and the currency every figure of the space is in.
enum DemoSpaceKey {
  home(demoFirstSpaceId, 'Pézenas', 'EUR'),
  leipzig(demoSecondSpaceId, 'Leipzig', 'EUR'),
  london(demoLondonSpaceId, 'London', 'GBP'),
  newYork(demoNewYorkSpaceId, 'New York', 'USD'),
  zurich(demoZurichSpaceId, 'Zurich', 'CHF'),
  milan(demoMilanSpaceId, 'Milan', 'EUR'),
  // #3863 — the one Demo business without places (Berlin, a practice).
  practice(demoPracticeSpaceId, 'the Berlin practice', 'EUR'),
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

/// What every Demo space holds, whichever space it is: the main space (the
/// fixture itself) and each of the others answer with the same parts.
abstract interface class DemoSpaceParts {
  FakeWorkspaceRepository get workspaces;
  FakeFloorPlanRepository get floorPlan;
  RightsCheckedReservationRepository get reservations;
  FakeEventRepository get events;
  FakeCalendarRepository get calendar;
  FakeMoneyRepository get money;
  FakeCreditRepository get credits;
  FakeAccessoryRepository get accessories;
  FakeChargingStationRepository get chargingStations;
  FakeWorkspaceFields get fields;
  FakeWorkspaceRoles get roles;
  FakePlanResourceRepository get planResources;
}

/// One value for each of the Demo's spaces, each made when it is first asked
/// for ([at], or the named getters) and kept: asking for one space never
/// makes another's.
class DemoSpaces<T> {
  DemoSpaces(this._make);

  final T Function(DemoSpaceKey key) _make;
  final Map<DemoSpaceKey, T> _made = {};

  /// The value of [key]'s space.
  T at(DemoSpaceKey key) {
    if (_made.containsKey(key)) return _made[key] as T;
    final value = _make(key);
    _made[key] = value;
    return value;
  }

  /// The spaces whose value has been made so far.
  Set<DemoSpaceKey> get made => {..._made.keys};

  T get home => at(DemoSpaceKey.home);
  T get leipzig => at(DemoSpaceKey.leipzig);
  T get london => at(DemoSpaceKey.london);
  T get newYork => at(DemoSpaceKey.newYork);
  T get zurich => at(DemoSpaceKey.zurich);
  T get milan => at(DemoSpaceKey.milan);
  T get practice => at(DemoSpaceKey.practice);
  T get twin => at(DemoSpaceKey.twin);
}

/// The value of every space, each made (when first asked for) from the one it
/// came from.
DemoSpaces<R> demoMapSpaces<T, R>(DemoSpaces<T> spaces, R Function(T) f) =>
    DemoSpaces((key) => f(spaces.at(key)));

/// A value for each space, made from its key when first asked for.
DemoSpaces<T> demoSpacesOf<T>(T Function(DemoSpaceKey key) f) => DemoSpaces(f);

/// What the fixture holds for each space.
extension DemoFixtureSpaces on DemoFixture {
  DemoSpaces<FakeWorkspaceRepository> get spaceWorkspaces =>
      DemoSpaces((key) => space(key).workspaces);

  DemoSpaces<FakeMoneyRepository> get spaceMoney =>
      DemoSpaces((key) => space(key).money);

  DemoSpaces<FakeFloorPlanRepository> get spaceFloorPlans =>
      DemoSpaces((key) => space(key).floorPlan);

  DemoSpaces<RightsCheckedReservationRepository> get spaceReservations =>
      DemoSpaces((key) => space(key).reservations);
}

/// #3863 — whether the space [workspaces] looks at books places: a business
/// without them (the practice) has no seat, and is whole so.
bool demoHasPlaces(FakeWorkspaceRepository workspaces) =>
    workspaces.workspaces
        .where((w) => w.id == workspaces.myMember.workspaceId)
        .firstOrNull
        ?.featureFlags['placeBooking'] !=
    false;
