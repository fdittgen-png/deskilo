// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1373 / #1374 — the space a visitor lands in.
//
// One deterministic set of rooms, people and bookings, built from the
// same in-memory repositories the suite has always driven (ADR 0028).
// Deliberately small here: this is the shape, and #1374 is the full
// cross-domain dataset. What it already settles:
//
//   * **the clock is injected** ([kTestNow]), so a booking "today" never
//     expires out of the demo the way a hard-coded date would;
//   * **the identities are synthetic** — no name, address or e-mail of
//     any real person reaches this file, and none ever may;
//   * **it is a production-looking workspace**, because a visitor should
//     see what the product looks like in use, not a development strip.
import '../../features/profile/domain/profile.dart';
import '../../features/workspace/domain/bi_saved_view.dart';
import 'data/accessory_repository.dart';
import 'data/auth_repository.dart';
import 'data/book_profile_repository.dart';
import 'data/booking_right_reservations.dart';
import 'data/calendar_repository.dart';
import 'data/credit_repository.dart';
import 'data/decision_effects.dart';
import 'data/deployment_repository.dart';
import 'data/device_prefs.dart';
import 'data/event_repository.dart';
import 'data/event_visibility.dart';
import 'data/floor_plan_repository.dart';
import 'data/guest_participation_repository.dart';
import 'data/messenger_repository.dart';
import 'data/money/demo_member_statement.dart';
import 'data/money_repository.dart';
import 'data/notification_service.dart';
import 'data/plan_resource_repository.dart';
import 'data/profile_repository.dart';
import 'data/public_directory_repository.dart';
import 'data/realtime_sync.dart';
import 'data/stores.dart';
import 'data/workspace_fields_repository.dart';
import 'data/workspace_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'demo_clock.dart';
import 'demo_dataset.dart';
import 'demo_london_space.dart';
import 'demo_new_york_space.dart';
import 'demo_outward_edges.dart';
import 'demo_persona.dart';
import 'demo_second_space.dart';
import 'demo_space_listing.dart';
import 'demo_space_pick.dart';
import 'demo_space_stores.dart';
import 'demo_trade_city_space.dart';
import 'demo_twin_space.dart';
import 'seed/demo_booking_seed.dart';
import 'seed/demo_calendar_seed.dart';
import 'seed/demo_city_people_seed.dart';
import 'seed/demo_commerce_seed.dart';
import 'seed/demo_decision_seed.dart';
import 'seed/demo_flags.dart';
import 'seed/demo_history_seed.dart';
import 'seed/demo_money_finish.dart';
import 'seed/demo_money_seed.dart';
import 'seed/demo_network_seed.dart';
import 'seed/demo_people_seed.dart';
import 'seed/demo_reachable_seed.dart';
import 'seed/demo_resource_seed.dart';
import 'seed/demo_room_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_space_seed.dart';
import 'seed/demo_trade_city_seed.dart';
import 'seed/demo_twin_seed.dart';
import 'seed/demo_year_seed.dart';

/// #1565 — who the visitor is acting AS, for the repositories whose
/// subject is implicit.
///
/// One mutable cell rather than a field on each fake: the booking
/// repository and the event repository both have to stamp the same
/// person, and two copies of "the active member" is exactly how they
/// came apart — a persona switch moved the displayed identity and left
/// every booking attributed to the owner.
class DemoActor {
  DemoActor(this.memberId);

  String memberId;
}

/// Everything one Demo session runs on. Built once per session and
/// thrown away when it ends: a reset is a new [DemoFixture], never a
/// cleanup of the old one.
class DemoFixture implements DemoSpaceParts {
  DemoFixture._({
    required this.actor,
    required this.prefs,
    required this.auth,
    required this.workspaces,
    required this.floorPlan,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
    required this.holds,
    required this.credits,
    required this.accessories,
    required this.chargingStations,
    required this.profiles,
    required this.deployments,
    required this.directory,
    required this.guests,
    required this.messenger,
    required this.biViews,
    required this.files,
    required this.imports,
    required this.fields,
    required this.roles,
    required this.realtime,
    required this.notifications,
    required this.badge,
    required this.outward,
    required this.seededAt,
    required this._listings,
    required this._twinSource,
  });

  /// Seeds the session. [now] is the instant the demo believes it is,
  /// so "today" is always a working day inside the opening hours.
  factory DemoFixture.build({DateTime? now}) {
    // #2327 — 10:00 in the space's own zone, on any device.
    final today = now ?? demoSeedNow;
    // #2313 — the features a fresh space keeps off are on in the demo.
    final workspaces =
        FakeWorkspaceRepository.withWorkspace(featureFlags: demoFeatureFlags);
    final floorPlan = FakeFloorPlanRepository();
    seedDemoPlan(floorPlan);
    seedDemoSpace(floorPlan);
    // #1565 — the ONE actor the implicit-subject repositories read. They
    // are built with a reader rather than a captured id, so a persona
    // switch moves both of them at once and neither can drift.
    final actor = DemoActor(initialDemoPersona.memberId);
    final reservations = RightsCheckedReservationRepository(actor: () => actor.memberId);
    final events = FakeEventRepository(
      actor: () => actor.memberId,
      clock: () => today,
      decider: () => workspaces.memberOf(actor.memberId),
    );
    // #2313 — a service charge or an expense recorded in the demo files
    // its event, as on a server.
    final money = FakeMoneyRepository(events: events, clock: () => today);
    // #2571 — legal holds; books under retention refuse a reset.
    final holds = seedDemoRetentionHolds(workspaces.workspaces.first.id, today);
    workspaces.booksKept = (id) => demoBooksKept(
      id,
      workspaces.workspaces.firstWhere((w) => w.id == id).countryCode,
      ledger: money.ledger,
      holds: holds,
      today: today,
    );
    final calendar = FakeCalendarRepository(actor: () => actor.memberId);
    final credits = FakeCreditRepository();
    seedDemoCarnets(credits);
    final fields = FakeWorkspaceFields();
    final roles = FakeWorkspaceRoles();
    seedDemoFields(fields);
    seedDemoRoles(roles);
    events.viewerPermissions = demoViewerPermissions(workspaces, roles, 'ws-1', () => actor.memberId);
    final accessories = FakeAccessoryRepository();
    final chargingStations = FakeChargingStationRepository(); // #2631
    // The cast first: everything below points at it (#1374).
    seedDemoPeople(workspaces);
    seedDemoReservations(reservations, floorPlan, today);
    seedDemoBookings(reservations, floorPlan, today);
    // #2313 — four years, from January three years back to the end of
    // this year: holidays first, so no booking falls on one.
    seedDemoClosures(workspaces, today);
    seedDemoHolidays(workspaces, today);
    seedDemoHistoryBookings(reservations, floorPlan, workspaces, today);
    seedDemoResources(floorPlan, chargingStations, reservations, today); // #2631
    seedDemoAnnex(floorPlan, reservations, today); // #2568
    seedDemoMoney(money, today);
    // #3305 — each member reads their own statement.
    money.accountQueries.statementSource =
        demoStatementSource(workspaces, reservations, 'ws-1',
            actor: () => actor.memberId, credits: credits);
    seedDemoHistoryMoney(money, today);
    seedDemoMoneyStory(money, today, reservations.reservations);
    seedDemoYearOfResources(reservations, workspaces, today);
    finishDemoMoney(money, today);
    seedDemoSites(workspaces, floorPlan);
    seedDemoEvents(events, today);
    seedDemoDecisions(events, today);
    seedDemoHistoryDecisions(events, today);
    seedDemoAccessories(accessories, floorPlan);
    seedDemoIdentity(workspaces);
    seedDemoBadges(workspaces, today);
    seedDemoDocuments(workspaces);
    seedDemoConversations(workspaces, today);
    seedDemoNegotiations(money, today);
    seedDemoVatDeclarations(money, today);
    seedDemoCalendar(calendar,
        reservations: reservations, money: money, events: events);
    wireDecisionEffects(events,
        reservations: reservations, workspaces: workspaces, money: money, now: () => today);
    // #2327 — the processes that reach beyond the space: its twin, the
    // directory, guest visits, message requests, saved analyses.
    final deployments = FakeDeploymentRepository(
      actor: () => workspaces.memberNames[actor.memberId] ?? '',
      clock: () => today,
    );
    seedDemoTwin(workspaces, deployments, today,
        actorName: demoCast.first.name);
    final directory = FakeDirectoryRepository();
    seedDemoDirectory(directory);
    // #3846 — the spaces beside this one are listed now (the switcher and
    // the profiles need their rows and people) and built when first read.
    final listings = (
      leipzig: DemoSecondSpaceData.list(home: workspaces, now: today),
      london: DemoLondonData.list(home: workspaces),
      newYork: DemoNewYorkData.list(home: workspaces),
      zurich: DemoTradeCityData.list(city: demoZurich, home: workspaces),
      milan: DemoTradeCityData.list(city: demoMilan, home: workspaces),
    );
    final twinSource = DemoTwinData.list(home: workspaces, productionPlan: floorPlan, productionRoles: roles);
    for (final listing in [listings.leipzig, listings.london, listings.newYork, listings.zurich, listings.milan, twinSource.listing]) {
      listing.viewAs(actor.memberId);
    }
    // The wall tablet greets the member whose badge it read.
    reservations
      ..kioskUserId = demoCast[1].userId
      ..kioskMemberId = demoCast[1].memberId // #3293: their own booking is no conflict
      ..kioskName = demoCast[1].name;
    final problems = validateDemoFixture(workspaces: workspaces, plan: floorPlan,
        reservations: reservations, money: money);
    if (problems.isNotEmpty) {
      // Fails closed, and says what is wrong: a session that points at a
      // member or a seat that does not exist looks fine until a screen
      // opens it (#1373's "missing context fails closed").
      throw StateError('the demo session is not coherent: '
          '${problems.join('; ')}');
    }
    return DemoFixture._(
      actor: actor,
      prefs: DemoDevicePrefs(),
      auth: FakeAuthRepository(userId: initialDemoPersona.userId),
      workspaces: workspaces,
      floorPlan: floorPlan,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
      credits: credits,
      accessories: accessories,
      chargingStations: chargingStations,
      profiles: _profilesForSpaces(listings, today),
      deployments: deployments,
      directory: directory,
      guests: demoGuestVisits(today),
      messenger: withDemoGroup(
        demoMessenger(
          today,
          actingMember: () => actor.memberId,
          actingName: () => workspaces.memberNames[actor.memberId] ?? '',
        ),
        today,
      ),
      biViews: demoBiViews(),
      files: FakeWorkspaceFiles(),
      imports: InMemoryWorkspaceImport(),
      fields: fields,
      roles: roles,
      realtime: FakeRealtimeSync(),
      notifications: FakeNotificationService(),
      badge: FakeAppBadge(),
      outward: DemoOutwardEdges(),
      seededAt: today,
      holds: holds,
      listings: listings,
      twinSource: twinSource,
    );
  }

  /// #1565 — the member every implicit-subject write is attributed to.
  final DemoActor actor;

  /// #1564 — the per-device preferences this session owns, so nothing a
  /// visitor changes reaches the real app's.
  final DemoDevicePrefs prefs;

  final FakeAuthRepository auth;
  @override
  final FakeWorkspaceRepository workspaces;
  @override
  final FakeFloorPlanRepository floorPlan;
  @override
  final RightsCheckedReservationRepository reservations;
  @override
  final FakeEventRepository events;
  @override
  final FakeCalendarRepository calendar;
  @override
  final FakeMoneyRepository money;

  /// #2571 — the space's legal holds.
  final FakeRetentionHoldRepository holds;
  @override
  final FakeCreditRepository credits;
  @override
  final FakeAccessoryRepository accessories;

  /// #2631 — the chargers of the demo's EV parking slots.
  @override
  final FakeChargingStationRepository chargingStations;
  final FakeProfileRepository profiles;
  final FakeDeploymentRepository deployments;

  /// #2327 — the public directory, the guest's visits, this server's
  /// messenger and the saved analyses, seeded so a Reset reseeds them.
  final FakeDirectoryRepository directory;
  final FakeGuestParticipationRepository guests;
  final FakeMessengerRepository messenger;
  final InMemoryBiViewRepository biViews;
  final FakeWorkspaceFiles files;
  final InMemoryWorkspaceImport imports;

  /// #1288 — the workspace's own questions, and the answers.
  @override
  final FakeWorkspaceFields fields;

  /// #1528 — the roles this space defined itself.
  @override
  final FakeWorkspaceRoles roles;
  final FakeRealtimeSync realtime;
  final FakeNotificationService notifications;
  final FakeAppBadge badge;

  /// #1377 — what a demo session TRIED to send outwards, and never did.
  final DemoOutwardEdges outward;

  /// The instant this session believes it is.
  final DateTime seededAt;

  final _DemoListings _listings;
  List<DemoSpaceListing> get _everyListing => [
    _listings.leipzig, _listings.london, _listings.newYork, _listings.zurich, _listings.milan, _twinSource.listing,
  ];
  final DemoTwinSource _twinSource;
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
    (key) => seeded(key, () => buildDemoSpaceStores(this, key)),
  );

  /// The space [key] names, built now if it was not yet.
  DemoSpaceParts space(DemoSpaceKey key) => switch (key) {
    DemoSpaceKey.home => this,
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

  @override
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

  /// Looks at the same space through [persona] (#1376).
  ///
  /// The DATA is untouched: only who the fixture answers `fetchMyMember`
  /// with, and the signed-in user beside it, change. Everything above
  /// reads permissions the way it does in live mode, so a member sees a
  /// member's product because `effectivePermissions` says so and not
  /// because a Demo branch hid anything.
  ///
  /// #1565 made both halves of that promise true. The viewpoint MOVES
  /// over the cast the session has — it no longer reseeds it, which used
  /// to throw away an edited subscription, a changed status and any
  /// member created during the session — and the actor moves with it, so
  /// a booking made as Bruno belongs to Bruno rather than to the owner
  /// whose id the repositories had captured at build time.
  void becomePersona(DemoPersona persona) {
    viewDemoPeopleAs(workspaces, persona.person);
    _persona = persona;
    actor.memberId = persona.memberId;
    // #3293 — a self-assignment is refused for whoever the persona is.
    roles.callerMemberId = persona.memberId;
    // A space not built yet takes the caller when it is (demo_fixture `_space`).
    for (final key in _built) {
      if (key != DemoSpaceKey.home) space(key).roles.callerMemberId = persona.memberId;
    }
    for (final listing in _everyListing) {
      listing.viewAs(persona.memberId);
    }
    // The profile rows stay; the "mine" pointer moves with the persona,
    // so Settings shows that person's own name and contact block
    // instead of the first member's (#1514).
    profiles.myUserId = persona.userId;
    auth.signInAs(persona.userId);
  }
}

/// #3846 — the listings of the spaces beside the main one.
typedef _DemoListings = ({
  DemoSpaceListing leipzig,
  DemoSpaceListing london,
  DemoSpaceListing newYork,
  DemoSpaceListing zurich,
  DemoSpaceListing milan,
});

FakeProfileRepository _profilesForSpaces(_DemoListings spaces, DateTime today) =>
    demoProfiles(today: today)..profiles.addAll([
      for (final p in demoSecondCast)
        if (p.userId.startsWith('user-de-'))
          Profile(id: p.userId, displayName: p.name, countryCode: 'DE'),
      ...demoCityProfiles(spaces.london.workspaces, 'uk'),
      ...demoCityProfiles(spaces.newYork.workspaces, 'ny'),
      for (final (city, listing) in [(demoZurich, spaces.zurich), (demoMilan, spaces.milan)])
        ...demoCityProfiles(listing.workspaces, city.prefix),
    ]);
