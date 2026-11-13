// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3846 — the Demo builds a space when it is first read, not all at the start.
// The part of the fixture that does it: the `late final` spaces, the stores
// each keeps for the session, and the seeding that makes a space's data the
// same whenever it is built.
part of 'demo_fixture.dart';

mixin _DemoLazySpaces {
  DemoActor get actor;
  FakeWorkspaceRepository get workspaces;
  FakeFloorPlanRepository get floorPlan;
  DateTime get seededAt;
  _DemoListings get _listings;
  DemoTwinSource get _twinSource;

  final Set<DemoSpaceKey> _built = {DemoSpaceKey.home};
  int _seeding = 0;
  DemoPersona _persona = initialDemoPersona;

  /// #3846 — the spaces beside this one are built when first read, each on
  /// its own, seeded as it is whenever that is (see [seeded]).
  ///
  /// The second space (Leipzig), with repositories of its own.
  late final DemoSecondSpaceData secondSpace = _space(
    DemoSpaceKey.leipzig,
    _listings.leipzig,
    () => DemoSecondSpaceData.build(listing: _listings.leipzig, actor: () => activeMemberId, now: seededAt),
  );
  late final DemoLondonData london = _space(
    DemoSpaceKey.london,
    _listings.london,
    () => DemoLondonData.build(listing: _listings.london, actor: () => activeMemberId, now: seededAt),
  );
  late final DemoNewYorkData newYork = _space(
    DemoSpaceKey.newYork,
    _listings.newYork,
    () => DemoNewYorkData.build(listing: _listings.newYork, actor: () => activeMemberId, now: seededAt),
  );

  /// #3832 — the trade cities: Zurich (francs) and Milan (euros).
  late final DemoTradeCityData zurich = _space(
    DemoSpaceKey.zurich,
    _listings.zurich,
    () => DemoTradeCityData.build(city: demoZurich, listing: _listings.zurich, actor: () => activeMemberId, now: seededAt),
  );
  late final DemoTradeCityData milan = _space(
    DemoSpaceKey.milan,
    _listings.milan,
    () => DemoTradeCityData.build(city: demoMilan, listing: _listings.milan, actor: () => activeMemberId, now: seededAt),
  );

  /// #3302 — the main space's development twin, with stores of its own.
  late final DemoTwinData twin = _space(
    DemoSpaceKey.twin,
    _twinSource.listing,
    () => DemoTwinData.build(source: _twinSource, actor: () => activeMemberId, now: seededAt),
  );

  /// #3865 — what each space keeps for the whole session (purchases,
  /// suppliers, bank, books, lease, register, rooms, guest passes, cost
  /// rules): built when first read, once per space, so a switch of persona
  /// reaches the same stores and a Reset (a new fixture) the seeded ones.
  late final DemoSpaces<DemoSpaceStores> stores = DemoSpaces(
    (key) => seeded(key, () => buildDemoSpaceStores(this as DemoFixture, key)),
  );

  /// The space [key] names, built now if it was not yet.
  DemoSpaceParts space(DemoSpaceKey key) => switch (key) {
    DemoSpaceKey.home => this as DemoFixture,
    DemoSpaceKey.leipzig => secondSpace,
    DemoSpaceKey.london => london,
    DemoSpaceKey.newYork => newYork,
    DemoSpaceKey.zurich => zurich,
    DemoSpaceKey.milan => milan,
    DemoSpaceKey.twin => twin,
  };

  /// #3846 — the spaces built so far: the main space, and each other space
  /// from its first read.
  Set<DemoSpaceKey> get builtSpaces => {..._built};

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

  late final FakePlanResourceRepository _homeResources = FakePlanResourceRepository(floorPlan);

  FakePlanResourceRepository get planResources => _homeResources;

  /// Who the session is currently acting as (#1565); while a space is being
  /// seeded, the persona the session started as.
  String get activeMemberId => _seeding > 0 ? initialDemoPersona.memberId : actor.memberId;

  T _space<T extends DemoSpaceParts>(DemoSpaceKey key, DemoSpaceListing listing, T Function() build) {
    final built = seeded(key, () {
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
        throw StateError('the demo session is not coherent: ${problems.join('; ')}');
      }
      // Once a persona has been taken, every roles store knows its caller.
      if (_persona != initialDemoPersona) space.roles.callerMemberId = actor.memberId;
      return space;
    });
    _built.add(key);
    return built;
  }

  /// #3846 — runs [build], which seeds the space [key] (or its stores), as the
  /// session started: acting as the persona it began with, over the cast as
  /// seeded. A space's data is therefore the same whether it is built first or
  /// last, and whichever persona is being looked through when it is.
  T seeded<T>(DemoSpaceKey key, T Function() build) {
    final outermost = _seeding == 0;
    final swap = outermost && _persona != initialDemoPersona;
    if (swap) viewDemoPeopleAs(workspaces, initialDemoPersona.person);
    _seeding++;
    try {
      final listing = switch (key) {
        DemoSpaceKey.home => null,
        DemoSpaceKey.leipzig => _listings.leipzig,
        DemoSpaceKey.london => _listings.london,
        DemoSpaceKey.newYork => _listings.newYork,
        DemoSpaceKey.zurich => _listings.zurich,
        DemoSpaceKey.milan => _listings.milan,
        DemoSpaceKey.twin => _twinSource.listing,
      };
      return listing == null ? build() : listing.seeded(actor.memberId, build);
    } finally {
      _seeding--;
      if (swap) viewDemoPeopleAs(workspaces, _persona.person);
    }
  }
}
