// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3846 — the Demo builds a space when it is first read, not all at the start.
// What does it: the spaces beside the main one, the stores each keeps for the
// session, and the seeding that makes a space's data the same whenever it is
// built. The fixture delegates to one of these (`DemoFixture.london` ...).
import 'demo_dataset.dart';
import 'demo_fixture.dart';
import 'demo_london_space.dart';
import 'demo_new_york_space.dart';
import 'demo_persona.dart';
import 'demo_practice_space.dart';
import 'demo_second_space.dart';
import 'demo_space_listing.dart';
import 'demo_space_stores.dart';
import 'demo_spaces.dart';
import 'demo_trade_city_space.dart';
import 'demo_twin_space.dart';
import 'seed/demo_trade_city_seed.dart';

/// #3846 — the listings of the spaces beside the main one.
typedef DemoListings = ({
  DemoSpaceListing leipzig,
  DemoSpaceListing london,
  DemoSpaceListing newYork,
  DemoSpaceListing zurich,
  DemoSpaceListing milan,
  DemoSpaceListing practice,
});

class DemoLazySpaces {
  DemoLazySpaces(this._home, this.listings, this._twinSource);

  final DemoFixture _home;
  final DemoListings listings;
  final DemoTwinSource _twinSource;

  final Set<DemoSpaceKey> built = {DemoSpaceKey.home};
  int _seeding = 0;

  /// The persona the session looks through now (set by the fixture).
  DemoPersona persona = initialDemoPersona;

  /// #3846 — the spaces beside this one are built when first read, each on
  /// its own, seeded as it is whenever that is (see [seeded]).
  ///
  /// The second space (Leipzig), with repositories of its own.
  late final DemoSecondSpaceData secondSpace = _space(
    DemoSpaceKey.leipzig,
    listings.leipzig,
    () => DemoSecondSpaceData.build(
      listing: listings.leipzig,
      actor: () => activeMemberId,
      now: _home.seededAt,
    ),
  );
  late final DemoLondonData london = _space(
    DemoSpaceKey.london,
    listings.london,
    () => DemoLondonData.build(
      listing: listings.london,
      actor: () => activeMemberId,
      now: _home.seededAt,
    ),
  );
  late final DemoNewYorkData newYork = _space(
    DemoSpaceKey.newYork,
    listings.newYork,
    () => DemoNewYorkData.build(
      listing: listings.newYork,
      actor: () => activeMemberId,
      now: _home.seededAt,
    ),
  );

  /// #3832 — the trade cities: Zurich (francs) and Milan (euros).
  late final DemoTradeCityData zurich = _space(
    DemoSpaceKey.zurich,
    listings.zurich,
    () => DemoTradeCityData.build(
      city: demoZurich,
      listing: listings.zurich,
      actor: () => activeMemberId,
      now: _home.seededAt,
    ),
  );
  late final DemoTradeCityData milan = _space(
    DemoSpaceKey.milan,
    listings.milan,
    () => DemoTradeCityData.build(
      city: demoMilan,
      listing: listings.milan,
      actor: () => activeMemberId,
      now: _home.seededAt,
    ),
  );

  /// #3863 — the practice in Berlin: the one business without places.
  late final DemoPracticeData practice = _space(
    DemoSpaceKey.practice,
    listings.practice,
    () => DemoPracticeData.build(
      listing: listings.practice,
      actor: () => activeMemberId,
      now: _home.seededAt,
    ),
  );

  /// #3302 — the main space's development twin, with stores of its own.
  late final DemoTwinData twin = _space(
    DemoSpaceKey.twin,
    _twinSource.listing,
    () => DemoTwinData.build(
      source: _twinSource,
      actor: () => activeMemberId,
      now: _home.seededAt,
    ),
  );

  /// #3865 — what each space keeps for the whole session (purchases,
  /// suppliers, bank, books, lease, register, rooms, guest passes, cost
  /// rules): built when first read, once per space, so a switch of persona
  /// reaches the same stores and a Reset (a new fixture) the seeded ones.
  late final DemoSpaces<DemoSpaceStores> stores = DemoSpaces(
    (key) => seeded(key, () => buildDemoSpaceStores(_home, key)),
  );

  /// The space [key] names, built now if it was not yet.
  DemoSpaceParts space(DemoSpaceKey key) => switch (key) {
    DemoSpaceKey.home => _home,
    DemoSpaceKey.leipzig => secondSpace,
    DemoSpaceKey.london => london,
    DemoSpaceKey.newYork => newYork,
    DemoSpaceKey.zurich => zurich,
    DemoSpaceKey.milan => milan,
    DemoSpaceKey.practice => practice,
    DemoSpaceKey.twin => twin,
  };

  /// #3846 — the spaces built so far: the main space, and each other space
  /// from its first read.
  Set<DemoSpaceKey> get builtSpaces => {...built};

  /// Every space's coherence problems (builds the spaces not yet built; a
  /// space is checked as it is built, and refused if it is not coherent).
  List<String> validateAllSpaces() => [
    for (final key in DemoSpaceKey.values)
      ...validateDemoFixture(
        workspaces: space(key).workspaces,
        plan: space(key).floorPlan,
        reservations: space(key).reservations,
        money: space(key).money,
      ),
  ];

  /// Who the session is currently acting as (#1565); while a space is being
  /// seeded, the persona the session started as.
  String get activeMemberId =>
      _seeding > 0 ? initialDemoPersona.memberId : _home.actor.memberId;

  T _space<T extends DemoSpaceParts>(
    DemoSpaceKey key,
    DemoSpaceListing listing,
    T Function() build,
  ) {
    final made = seeded(key, () {
      final space = build();
      // Fails closed, and says what is wrong (#1373): a space that points at a
      // member or a seat that does not exist looks fine until a screen opens it.
      final problems = validateDemoFixture(
        workspaces: space.workspaces,
        plan: space.floorPlan,
        reservations: space.reservations,
        money: space.money,
      );
      if (problems.isNotEmpty) {
        throw StateError(
          'the demo session is not coherent: ${problems.join('; ')}',
        );
      }
      // Once a persona has been taken, every roles store knows its caller.
      if (persona != initialDemoPersona) {
        space.roles.callerMemberId = _home.actor.memberId;
      }
      return space;
    });
    built.add(key);
    return made;
  }

  /// #3846 — runs [build], which seeds the space [key] (or its stores), as the
  /// session started: acting as the persona it began with, over the cast as
  /// seeded. A space's data is therefore the same whether it is built first or
  /// last, and whichever persona is being looked through when it is.
  T seeded<T>(DemoSpaceKey key, T Function() build) {
    final outermost = _seeding == 0;
    final swap = outermost && persona != initialDemoPersona;
    if (swap) viewDemoPeopleAs(_home.workspaces, initialDemoPersona.person);
    _seeding++;
    try {
      final listing = switch (key) {
        DemoSpaceKey.home => null,
        DemoSpaceKey.leipzig => listings.leipzig,
        DemoSpaceKey.london => listings.london,
        DemoSpaceKey.newYork => listings.newYork,
        DemoSpaceKey.zurich => listings.zurich,
        DemoSpaceKey.milan => listings.milan,
        DemoSpaceKey.practice => listings.practice,
        DemoSpaceKey.twin => _twinSource.listing,
      };
      return listing == null
          ? build()
          : listing.seeded(_home.actor.memberId, build);
    } finally {
      _seeding--;
      if (swap) viewDemoPeopleAs(_home.workspaces, persona.person);
    }
  }

  /// Every listing of a space beside the main one.
  List<DemoSpaceListing> get everyListing => [
    listings.leipzig,
    listings.london,
    listings.newYork,
    listings.zurich,
    listings.milan,
    listings.practice,
    _twinSource.listing,
  ];
}
