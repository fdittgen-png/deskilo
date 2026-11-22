// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's checklist: every feature of the registry, in every process
// of the catalogue, has a scenario a visitor can perform or watch — the
// state that makes it demonstrable, and the persona who acts on it.
//
// A feature added to the registry fails the first test until it is given a
// scenario here (and the data that makes it true in the seeds), or is
// listed in `demoFeaturesLeftOff` with the reason it cannot work without a
// live server. Three kinds of scenario:
//   * a STATE the seeds hold (a bill waiting for approval, a lease
//     difference to accept), checked against the fixture;
//   * an ACTION the persona starts from the seeded data (book for someone
//     else, block a seat), checked for its precondition;
//   * a SWITCH that changes how the app behaves everywhere (animations,
//     regional formats), demonstrated by being on.
import 'dart:async';

import 'package:deskilo/core/demo/data/asset_valuation_repository.dart';
import 'package:deskilo/core/demo/data/bank_statement_demo_seed.dart';
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/core/demo/data/demo_item_groups.dart';
import 'package:deskilo/core/demo/data/demo_kiosk_devices.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_cycle_counts.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_operations.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_receiving_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_registry.dart';
import 'package:deskilo/core/demo/data/demo_stock_reorder.dart';
import 'package:deskilo/core/demo/data/demo_stock_reversals.dart';
import 'package:deskilo/core/demo/data/fake_organisation_repository.dart';
import 'package:deskilo/core/demo/data/kpi_repositories.dart';
import 'package:deskilo/core/demo/data/lease_commitment_repository.dart';
import 'package:deskilo/core/demo/data/premises_lease_repository.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/room_rental_repository.dart';
import 'package:deskilo/core/demo/data/workspace_asset_repository.dart';
import 'package:deskilo/core/demo/demo_dataset.dart' show demoKioskDevice;
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_london_space.dart';
import 'package:deskilo/core/demo/demo_new_york_space.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_space_fulfilments.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/demo_space_stores.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/core/demo/seed/demo_asset_seed.dart';
import 'package:deskilo/core/demo/seed/demo_book_period_seed.dart';
import 'package:deskilo/core/demo/seed/demo_flags.dart';
import 'package:deskilo/core/demo/seed/demo_lease_seed.dart';
import 'package:deskilo/core/demo/seed/demo_organisation_seed.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_order_seed.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/core/demo/seed/demo_room_seed.dart';
import 'package:deskilo/core/demo/seed/demo_setup_seed.dart';
import 'package:deskilo/core/demo/seed/demo_valuation_seed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/accounting_connection.dart';
import 'package:deskilo/features/money/domain/asset_valuation.dart';
import 'package:deskilo/features/money/domain/bank/bank_match.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/einvoice_inbox.dart';
import 'package:deskilo/features/money/domain/lease_commitment.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/service_fulfilment.dart';
import 'package:deskilo/features/money/domain/workspace_asset.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_cycle_counts.dart';
import 'package:deskilo/features/stock/domain/stock_operations.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/demo_assistant_journeys.dart';
import '../../helpers/demo_documents_journeys.dart';
import '../../helpers/demo_house_journeys.dart';
import '../../helpers/demo_outbox_journeys.dart';
import '../../helpers/demo_pass_einvoice_journeys.dart';
import '../../helpers/demo_payment_journeys.dart';
import '../../helpers/demo_plan_booking_journeys.dart';
import '../../helpers/demo_settings_shell_journeys.dart';
import '../../helpers/demo_standalone_journey.dart';
import '../../helpers/demo_vies_export_journeys.dart';
import '../../helpers/demo_whatsapp_journeys.dart';

/// One house of the reference organisation, as a check reads it: the parts
/// the Demo scope seeds for it and the stores it keeps for the session.
class _House {
  _House(this.f, this.key);

  final DemoFixture f;
  final DemoSpaceKey key;

  DemoSpaceParts get parts => f.space(key);
  DemoSpaceStores get stores => f.stores.at(key);

  /// London's own parts, with its HMRC door.
  DemoLondonData get london => f.london;

  /// New York's own parts.
  DemoNewYorkData get newYork => f.newYork;

  /// The Demo's providers over the session, for a journey that reads through
  /// them; the caller disposes it.
  ProviderContainer container() =>
      ProviderContainer(overrides: demoOverrides(f));

  DateTime get now => f.seededAt;
}

/// Everything a scenario may look at: the session and the repositories
/// the Demo scope seeds beside it. A world belongs to ONE business
/// ([business]): it hands out that business and no other, so a check cannot
/// read a business its scenario does not name (#4009). The head's parts
/// (`f`, `purchasing`, `bookings` ...) are the default and are refused to a
/// scenario that happens in a house, which reads its house through [house].
class _World {
  _World(DemoFixture f)
    : business = demoFirstSpaceId,
      _f = f,
      _purchasing = seedDemoPurchasing(f.seededAt, money: f.money),
      _lease = seedDemoLease(f.seededAt),
      _commitments = seedDemoCommitments(f.seededAt),
      _assets = seedDemoAssets(f.seededAt),
      _valuations = seedDemoValuations(f.seededAt),
      _books = seedDemoBookPeriods(f.seededAt),
      _rooms = seedDemoRooms(f.seededAt);

  _World._within(_World base, this.business)
    : _f = base._f,
      _purchasing = base._purchasing,
      _lease = base._lease,
      _commitments = base._commitments,
      _assets = base._assets,
      _valuations = base._valuations,
      _books = base._books,
      _rooms = base._rooms;

  /// The business this world hands out.
  final String business;

  final DemoFixture _f;
  final DemoPurchasing _purchasing;
  final FakePremisesLeaseRepository _lease;
  final FakeLeaseCommitmentRepository _commitments;
  final FakeWorkspaceAssetRepository _assets;
  final FakeAssetValuationRepository _valuations;
  final FakeBookPeriodRepository _books;
  final FakeRoomRentalRepository _rooms;

  /// The same session, looking at [business] only.
  _World within(String business) => _World._within(this, business);

  T _head<T>(T value) {
    if (business != demoFirstSpaceId) {
      throw StateError(
        'a scenario in $business reads its house through house(), not the '
        'head',
      );
    }
    return value;
  }

  /// The house [key] names: only the business of this world.
  _House house(DemoSpaceKey key) {
    if (key.id != business) {
      throw StateError('a scenario in $business may not read ${key.id}');
    }
    return _House(_f, key);
  }

  DemoFixture get f => _head(_f);
  DemoPurchasing get purchasing => _head(_purchasing);
  FakePremisesLeaseRepository get lease => _head(_lease);
  FakeLeaseCommitmentRepository get commitments => _head(_commitments);
  FakeWorkspaceAssetRepository get assets => _head(_assets);
  FakeAssetValuationRepository get valuations => _head(_valuations);
  FakeBookPeriodRepository get books => _head(_books);
  FakeRoomRentalRepository get rooms => _head(_rooms);

  DateTime get now => _f.seededAt;
  List<Reservation> get bookings => f.reservations.reservations;
  List<Member> get members => [
    f.workspaces.myMember,
    ...f.workspaces.otherMembers,
  ];
  bool pending(EventType type) => f.events.events.any(
    (e) => e.type == type && e.status == EventStatus.pending,
  );
  bool settled(EventType type) => f.events.events.any(
    (e) => e.type == type && e.status != EventStatus.pending,
  );
  bool today(Reservation r) =>
      r.startsAt.year == now.year &&
      r.startsAt.month == now.month &&
      r.startsAt.day == now.day;
  Future<List<PurchaseSummary>> purchases() =>
      purchasing.purchases.fetchPurchases('ws-1');
}

typedef _Check = FutureOr<bool> Function(_World w);

enum _Kind { state, action, toggle }

class _Scenario {
  const _Scenario(
    this.kind,
    this.persona,
    this.story,
    this.check, {
    this.business = demoFirstSpaceId,
  });

  final _Kind kind;
  final DemoPersona persona;
  final String story;
  final _Check check;

  /// The Demo business the scenario happens in: the reference business
  /// (Atelier du Marché, `ws-1`) unless the use case cannot be held there.
  final String business;
}

const _owner = DemoPersona.owner;
const _admin = DemoPersona.admin;
const _member = DemoPersona.member;
const _kiosk = DemoPersona.kiosk;

_Scenario _state(DemoPersona p, String story, _Check check) =>
    _Scenario(_Kind.state, p, story, check);
_Scenario _action(
  DemoPersona p,
  String story,
  _Check check, {
  String business = demoFirstSpaceId,
}) => _Scenario(_Kind.action, p, story, check, business: business);
_Scenario _toggle(String story) =>
    _Scenario(_Kind.toggle, _owner, story, (_) => true);

/// #4009 — the Demo's reference is an ORGANISATION: the head, Atelier du
/// Marché (`ws-1`), and its houses in London, New York, Zurich, Milan and
/// Leipzig. The Berlin practice (`ws-7`) is a business of its own outside it.
const List<String> _organisation = [
  demoFirstSpaceId,
  demoSecondSpaceId,
  demoLondonSpaceId,
  demoNewYorkSpaceId,
  demoZurichSpaceId,
  demoMilanSpaceId,
];

/// #3959, #4009 — a scenario happens in the head, where every feature is on
/// with seeded data and a process a persona can perform, or in a HOUSE when
/// its feature is tied to that house's country; the entry says which country
/// and why. The list only shrinks: an entry whose scenario is back in the head
/// is removed. A scenario in a business outside the organisation fails.
const Map<WorkspaceFeature, String> _elsewhere = {
  WorkspaceFeature.mtdSubmission:
      "the United Kingdom's tax submission: on in the London house (GB) only, "
          'off in the head and the other houses',
  WorkspaceFeature.salesTax:
      "the United States' sales tax: stated by the New York house (US, "
          'dollars), where a state and a city levy it',
};

/// The switch-only scenarios (kind toggle) the file holds today. It only
/// falls: a feature gets a state or an action, not another switch. #4009 —
/// what is left is not a house's to perform, each with its reason at the
/// entry: uiAnimations (a per-device motion preference) and personalShell (an
/// installation default that shapes Me, which stands above every business).
/// #3997 retired siteDocuments, the third.
const int _switchOnlyBudget = 2;

/// The scenarios outside the reference organisation, the ones in a house
/// not named in [elsewhere], and the entries of [elsewhere] that are stale.
List<String> _businessProblems(
  Map<WorkspaceFeature, _Scenario> scenarios,
  Map<WorkspaceFeature, String> elsewhere,
) => [
  for (final e in scenarios.entries)
    if (!_organisation.contains(e.value.business))
      '${e.key.name} happens in ${e.value.business}, outside the organisation'
    else if (e.value.business != demoFirstSpaceId &&
        !elsewhere.containsKey(e.key))
      '${e.key.name} happens in ${e.value.business}: name the reason',
  for (final f in elsewhere.keys)
    if ((scenarios[f]?.business ?? demoFirstSpaceId) == demoFirstSpaceId)
      '${f.name} is listed as elsewhere but happens in the head',
];

int _switchOnlyCount(Iterable<_Scenario> scenarios) =>
    scenarios.where((s) => s.kind == _Kind.toggle).length;

/// One scenario per feature, grouped as the process catalogue groups them.
final Map<WorkspaceFeature, _Scenario> _scenarios = {
  // ── workspaceAccess / people ──────────────────────────────────────────
  WorkspaceFeature.membersDirectory: _state(
    _member,
    'the directory lists '
    'the cast with names',
    (w) => w.f.workspaces.memberNames.length >= 5,
  ),
  WorkspaceFeature.coOwner: _action(
    _owner,
    'Ada makes Chiara a co-owner',
    (w) => w.members.any((m) => m.isAdmin && !m.isOwner),
  ),
  WorkspaceFeature.roleManagement: _state(
    _owner,
    'an owner and an '
    'administrator hold different rights',
    (w) =>
        w.members.any((m) => m.isOwner) &&
        w.members.any((m) => m.isAdmin && !m.isOwner),
  ),
  WorkspaceFeature.roleAssignment: _state(
    _owner,
    'the Host role is held by '
    'somebody',
    (w) => w.f.roles.assignments.values.any((v) => v.isNotEmpty),
  ),
  WorkspaceFeature.customRoles: _state(
    _owner,
    'the space defines its own '
    'roles',
    (w) => w.f.roles.roles.isNotEmpty,
  ),
  WorkspaceFeature.customFields: _state(
    _admin,
    'the space asks its own '
    'questions and members answered',
    (w) => w.f.fields.fields.isNotEmpty && w.f.fields.answers.isNotEmpty,
  ),
  WorkspaceFeature.personalInfo: _state(
    _member,
    'members have an address '
    'and a telephone',
    (w) => w.f.profiles.profiles.any(
      (p) => p.address.isNotEmpty && p.whatsapp.isNotEmpty,
    ),
  ),
  WorkspaceFeature.managedProfiles: _action(
    _admin,
    'Chiara adds a member '
    'without an account (a visiting intern)',
    (w) => w.members.isNotEmpty,
  ),
  WorkspaceFeature.managedProfileAccess: _action(
    _owner,
    'Ada narrows what '
    'a managed member may do',
    (w) => w.members.isNotEmpty,
  ),
  WorkspaceFeature.memberPage: _state(
    _admin,
    'each member has a page with '
    'bookings and bills',
    (w) => w.bookings.isNotEmpty,
  ),
  WorkspaceFeature.memberOrigin: _state(
    _admin,
    'Dov joined by a request',
    (w) => w.pending(EventType.memberJoin),
  ),
  WorkspaceFeature.memberEnvironments: _action(
    _owner,
    'an invitation '
    'chooses the production side or its twin',
    (w) => w.f.workspaces.workspaces.any((x) => x.environment == 'dev'),
  ),
  WorkspaceFeature.guestParticipation: _state(
    _member,
    'visits paid to '
    'other spaces as a guest',
    (w) => w.f.guests.visits.isNotEmpty,
  ),
  // #3963 — a day pass sold at the desk in the reference business and used:
  // the seat is booked and checked in, the pass invoiced in euros.
  WorkspaceFeature.guestPasses: _action(
    _owner,
    'a day pass sold to a guest, who uses it',
    (_) => dayPassJourney(),
  ),
  // ── workspaceAccess / physicalAccess ─────────────────────────────────
  WorkspaceFeature.kioskMode: _state(
    _kiosk,
    'the front-desk tablet greets '
    'Bruno',
    (w) => w.members.any((m) => m.isKiosk),
  ),
  WorkspaceFeature.nfcBadges: _state(
    _kiosk,
    'Bruno carries a card',
    (w) => w.f.workspaces.badges.any((b) => b.kind == BadgeKind.nfc),
  ),
  WorkspaceFeature.nfcSeatTags: _action(
    _admin,
    'Chiara writes a tag to a '
    'seat',
    (w) => w.f.floorPlan.seats.isNotEmpty,
  ),
  WorkspaceFeature.qrBadges: _state(
    _kiosk,
    'Ada and Chiara carry a QR '
    'badge; one old card is revoked',
    (w) =>
        w.f.workspaces.badges.any((b) => b.kind == BadgeKind.qr) &&
        w.f.workspaces.badges.any((b) => b.revokedAt != null),
  ),
  WorkspaceFeature.kioskMemberPhotos: _state(_kiosk, 'the wall tablet greets Bruno, whose photo is on his profile and in the store', (_) => kioskPhotoState()),
  WorkspaceFeature.badgeSignIn: _state(
    _kiosk,
    "Ada's badge signs her in",
    (w) => w.f.workspaces.badges.any((b) => b.authEnabled),
  ),
  // #3675 — the front-desk tablet is an enrolled kiosk of the business.
  WorkspaceFeature.kioskEnrolment: _state(
    _owner,
    'the front-desk tablet is an enrolled kiosk',
    (w) => DemoKioskDevices(
      workspaceId: w.f.workspaces.workspaces.first.id,
      today: w.f.seededAt,
    ).held.any((d) => d.name == demoKioskDevice.name && !d.revoked),
  ),
  WorkspaceFeature.spaceQrCodes: _action(_member, 'a place\'s QR code is read and brings the member to that place', (_) => spaceQrAction()),
  // ── spaceManagement ──────────────────────────────────────────────────
  WorkspaceFeature.placeBooking: _state(
    _member,
    'the plan has places to book',
    (w) => w.f.floorPlan.levels.isNotEmpty,
  ),
  WorkspaceFeature.multiSite: _state(
    _owner,
    'the studio and the garage are '
    'two sites',
    (w) => w.f.workspaces.sites.length >= 2,
  ),
  WorkspaceFeature.planObjectDelete: _action(_owner, 'Ada deletes a drawn object of the plan; it is gone and the seats stay', (_) => planDeleteAction()),
  WorkspaceFeature.planDecor: _state(_owner, 'the ground floor carries a couch and a table drawn under its seats', (_) => planDecorState()),
  WorkspaceFeature.adminSeatBlocking: _action(
    _admin,
    'Chiara blocks a seat '
    'for maintenance',
    (w) => w.f.floorPlan.seats.length > 1,
  ),
  WorkspaceFeature.workingHours: _state(_owner, 'the working day runs eight to six, an hour longer than the product\'s', (_) => workingHoursState()),
  WorkspaceFeature.publicHolidays: _state(
    _member,
    'public holidays close '
    'the space',
    (w) => w.f.workspaces.closureDays.length > 10,
  ),
  WorkspaceFeature.holidayImport: _action(
    _owner,
    "Ada imports next year's "
    'holidays',
    (w) => w.f.workspaces.closureDays.isNotEmpty,
  ),
  WorkspaceFeature.capacityKpi: _state(
    _owner,
    'the capacity tile shows how '
    'full the seats were',
    (w) async {
      final kpi =
          await DemoCapacityKpiRepository(
            plan: w.f.floorPlan,
            reservations: w.f.reservations,
            now: w.now,
          ).seatCapacity(
            'ws-1',
            from: w.now.subtract(const Duration(days: 30)),
            to: w.now,
          );
      return kpi.reservedSeatHours > 0 && kpi.offeredSeatHours > 0;
    },
  ),
  WorkspaceFeature.planMemberPhotos: _state(_member, 'a held seat of the plan shows its occupant\'s photo', (_) => planPhotoState()),
  WorkspaceFeature.uniqueMonograms: _state(
    _member,
    'every avatar has its '
    'own letters',
    (w) => w.f.workspaces.memberNames.length > 1,
  ),
  WorkspaceFeature.singleRoomLevelNames: _state(_member, 'the ground floor has one room only, read by the level\'s name', (_) => singleRoomState()),
  WorkspaceFeature.workspaceVocabulary: _action(
    _owner,
    'Ada renames '
    '"seat" to "desk"',
    (w) => w.f.floorPlan.seats.isNotEmpty,
  ),
  WorkspaceFeature.workspaceBranding: _state(
    _owner,
    'the space wears its '
    'own colour and symbol',
    (w) => w.f.workspaces.workspaces
        .firstWhere((x) => x.id == 'ws-1')
        .branding
        .isNotEmpty,
  ),
  WorkspaceFeature.publicListings: _state(
    _owner,
    'the space is listed in '
    'the directory',
    (w) => w.f.directory.cards.any((c) => c.id == 'ws-1'),
  ),
  // ── reservationsUsage ────────────────────────────────────────────────
  WorkspaceFeature.seriesBooking: _state(
    _member,
    "Bruno's weekly seat",
    (w) => w.bookings.any((r) => r.seriesId != null),
  ),
  WorkspaceFeature.bookForOthers: _action(
    _admin,
    'Chiara books a seat for '
    'Bruno',
    (w) => w.members.length > 2,
  ),
  WorkspaceFeature.levelBooking: _state(
    _member,
    'the first floor is '
    'bookable as a whole',
    (w) => w.f.floorPlan.levels.any((l) => l.bookableAsWhole),
  ),
  WorkspaceFeature.meetingRooms: _state(
    _member,
    'the boardroom is booked '
    'by the hour',
    (w) => w.f.floorPlan.seats.any((s) => s.resourceKind == ResourceKind.room),
  ),
  WorkspaceFeature.parking: _state(
    _member,
    'the garage: standard, '
    'electric and accessible slots',
    (w) =>
        w.f.floorPlan.seats.any((s) => s.resourceKind == ResourceKind.parking),
  ),
  WorkspaceFeature.externalRooms: _state(
    _owner,
    'the rented Studio next '
    'door, and Ada booked it',
    (w) => w.bookings.any((r) => r.officeId == 'demo-room-studio'),
  ),
  WorkspaceFeature.adminLevelAssign: _action(
    _admin,
    'Chiara gives a member '
    'a whole level',
    (w) => w.f.floorPlan.levels.any((l) => l.bookableAsWhole),
  ),
  WorkspaceFeature.bookingPolicies: _state(_owner, 'the booking rules are the workspace\'s own: two places, ten hours, walk-up outside the day', (_) => bookingPoliciesState()),
  WorkspaceFeature.bookingGate: _state(
    _member,
    'a closed day refuses a '
    'booking before it is asked',
    (w) => w.f.workspaces.closureDays.any((c) => c.day.isAfter(w.now)),
  ),
  WorkspaceFeature.seatDayTimeline: _state(
    _admin,
    "today's bookings on a "
    'seat, hour by hour',
    (w) => w.bookings.any(w.today),
  ),
  WorkspaceFeature.calendarFileExport: _state(
    _owner,
    "Ada exports "
    "tomorrow's booking to her calendar",
    (w) => w.bookings.any(
      (r) => r.memberId == 'member-1' && r.startsAt.isAfter(w.now),
    ),
  ),
  WorkspaceFeature.autoCheckInOut: _state(
    _admin,
    'yesterday ended with '
    'nobody checked out by hand',
    (w) => w.bookings.any((r) => r.status == ReservationStatus.completed),
  ),
  WorkspaceFeature.usageRecords: _state(
    _admin,
    'what each booking counted',
    (w) => w.f.money.usageRecords.isNotEmpty,
  ),
  // ── coordination ─────────────────────────────────────────────────────
  WorkspaceFeature.calendarTab: _state(
    _member,
    'the calendar has the '
    "month's events",
    (w) => w.f.calendar.items.isNotEmpty,
  ),
  WorkspaceFeature.calendarHub: _state(
    _member,
    'bookings, bills and '
    'decisions on one calendar',
    (w) => w.f.calendar.items.length > 10,
  ),
  WorkspaceFeature.calendarViews: _action(_member, 'Bruno finds the same booking in the day, the week and the month', (_) => calendarViewsAction()),
  WorkspaceFeature.calendarValidations: _state(
    _admin,
    'pending decisions on '
    'the calendar',
    (w) => w.f.events.events.any((e) => e.status == EventStatus.pending),
  ),
  WorkspaceFeature.eventsTab: _state(
    _admin,
    'requests waiting for a '
    'validator',
    (w) => w.pending(EventType.expense),
  ),
  WorkspaceFeature.validationScopes: _state(
    _owner,
    'who validates what: '
    'expenses, whole rooms, negotiations',
    (w) => w.f.events.policies.length >= 3,
  ),
  WorkspaceFeature.validationChain: _state(
    _admin,
    "Bruno's new tariff has "
    'one of its two validations',
    (w) =>
        w.f.events.policies.any((p) => p.requiredCount > 1) &&
        w.pending(EventType.priceNegotiation),
  ),
  WorkspaceFeature.deletionRequests: _state(
    _admin,
    'Bruno asks to delete '
    "yesterday's booking",
    (w) => w.pending(EventType.reservationDelete),
  ),
  WorkspaceFeature.memberNotifications: _state(
    _owner,
    "Bruno's unread "
    'message',
    (w) => w.f.workspaces.memberNotes.any((n) => n.readAt == null),
  ),
  WorkspaceFeature.notificationGrouping: _state(
    _admin,
    'several events of a '
    'kind fold into one',
    (w) => w.f.events.events.length > 5,
  ),
  WorkspaceFeature.richMessageRefs: _action(
    _owner,
    'Ada links a booking in '
    'a reply',
    (w) => w.f.workspaces.conversations.isNotEmpty,
  ),
  WorkspaceFeature.messageGestures: _action(
    _owner,
    "Ada quotes Bruno's "
    'message',
    (w) => w.f.workspaces.memberNotes.isNotEmpty,
  ),
  WorkspaceFeature.messagesHub: _state(
    _owner,
    'every conversation in both '
    'spaces in one inbox',
    (w) =>
        w.f.messenger.inboxRows.map((r) => r['workspace_id']).toSet().length >=
        2,
  ),
  WorkspaceFeature.spaceInquiries: _state(
    _owner,
    "a stranger's visit "
    'request',
    (w) =>
        w.f.messenger.inboxRows.any((r) => r['context_kind'] == 'inquiry_in'),
  ),
  WorkspaceFeature.messageForwarding: _action(
    _owner,
    'Ada forwards a '
    'message to the studio group',
    (w) => w.f.workspaces.conversations.length >= 2,
  ),
  WorkspaceFeature.captureProtection: _action(_member, 'a screenshot of a thread is recorded in the thread', (_) => captureAction()),
  WorkspaceFeature.messageMentions: _state(
    _owner,
    'the studio group to '
    'mention people in',
    (w) => w.f.workspaces.participants.isNotEmpty,
  ),
  // ── membershipCommerce ───────────────────────────────────────────────
  WorkspaceFeature.services: _state(
    _member,
    'coffee and printing to buy',
    (w) => w.f.money.services.any((s) => s.active),
  ),
  WorkspaceFeature.accessorySupplements: _state(
    _member,
    'the window seat '
    'comes with a monitor',
    (w) => w.f.accessories.seatAccessories.isNotEmpty,
  ),
  WorkspaceFeature.priceNegotiations: _state(
    _owner,
    "Bruno's tariff in "
    'force and the next one pending',
    (w) => w.f.money.negotiations['member-2']?.pending != null,
  ),
  WorkspaceFeature.memberPaymentTerms: _action(
    _owner,
    'Ada gives Bruno 30 '
    'days',
    (w) => w.members.any((m) => m.id == 'member-2'),
  ),
  WorkspaceFeature.carnets: _state(
    _member,
    'Bruno has 6 half-days left on '
    'his carnet',
    (w) =>
        (w.f.credits.balances['member-2'] ?? 0) > 0 &&
        w.f.credits.products.isNotEmpty,
  ),
  // ── billingPayments / records ───────────────────────────────────────
  WorkspaceFeature.moneyTab: _state(
    _member,
    "Bruno's bills and payments",
    (w) => w.f.money.invoices.any((i) => i.memberId == 'member-2'),
  ),
  WorkspaceFeature.financeFaces: _state(
    _owner,
    'the money a member owes, '
    'by face',
    (w) => w.f.money.invoices.isNotEmpty,
  ),
  WorkspaceFeature.memberReports: _state(
    _member,
    "Bruno's statement",
    (w) => w.f.money.ledger.any((l) => l.memberId == 'member-2'),
  ),
  // ── billingPayments / invoicing ─────────────────────────────────────
  WorkspaceFeature.invoicing: _state(
    _owner,
    'monthly bills for three '
    'years',
    (w) => w.f.money.invoices.length > 50,
  ),
  WorkspaceFeature.adminInvoicing: _state(
    _admin,
    'Chiara issues bills too',
    (w) => w.members.any((m) => m.id == 'member-3' && m.isAdmin),
  ),
  WorkspaceFeature.subscriptionInvoices: _state(
    _owner,
    'the fee billed '
    'before the month',
    (w) =>
        w.f.money.ledger.any((l) => l.category == LedgerCategory.subscription),
  ),
  WorkspaceFeature.usageInvoices: _state(
    _owner,
    'rooms and parking billed '
    'by use',
    (w) => w.f.money.invoices.any((i) => i.id.contains('usage')),
  ),
  WorkspaceFeature.invoiceSettlement: _action(
    _admin,
    "Chiara regroups "
    "Bruno's open bills into one",
    (w) =>
        w.f.money.invoices
            .where(
              (i) =>
                  i.memberId == 'member-2' &&
                  (w.f.money.invoiceMatchesStore[i.id]?.paidCents ?? 0) <
                      i.totalCents,
            )
            .length >=
        2,
  ),
  WorkspaceFeature.invoiceJourney: _state(
    _member,
    'issued, paid, confirmed '
    'and closed bills',
    (w) => w.f.money.invoiceMatchesStore.isNotEmpty,
  ),
  WorkspaceFeature.invoicingWizard: _state(
    _owner,
    'this month is ready to '
    'invoice',
    _somethingToInvoice,
  ),
  WorkspaceFeature.settlementFold: _action(
    _admin,
    'the regrouped bills fold '
    'under the new one',
    (w) => w.f.money.invoices.isNotEmpty,
  ),
  WorkspaceFeature.numberSequences: _state(
    _owner,
    'bills and credit notes '
    'are numbered',
    (w) => w.f.money.invoices.any((i) => i.number.isNotEmpty),
  ),
  // ── billingPayments / collection ────────────────────────────────────
  // #3961 — the order the app starts, the Demo's stand-in for the provider's
  // page, and the books that agree afterwards.
  WorkspaceFeature.onlinePayments: _action(
    _member,
    'Bruno pays his bill online on the Demo\'s stand-in for the provider\'s '
    'page',
    (w) => _open(w, 'member-2') ? onlinePaymentJourney() : false,
  ),
  WorkspaceFeature.bankImport: _state(
    _owner,
    "the bank's last statement: two "
    'invoices paid with their QR and RF references, a transfer without one '
    'in the work list, and a reimbursement going out that reconciles the '
    'payment reported as made',
    (w) async {
      final repo = seedDemoBankStatements(w.f.money, w.now);
      final statement = (await repo.fetchStatements('ws-1'))
          .singleWhere((s) => s.statementRef == 'DEMO-NTFCTN-1');
      final lines = await repo.fetchLines(statement.id);
      final open = openInvoices(w.f.money.invoices, w.f.money.invoiceMatchesStore);
      final byReference = BankWorkList(lines, open, windowDays: 60).referenceBatch;
      return byReference.length == 2 &&
          lines.any((l) => l.isMoneyIn && l.reference.isEmpty) &&
          lines.any((l) => !l.isMoneyIn && l.outgoingCandidates.isNotEmpty);
    },
  ),
  WorkspaceFeature.dunning: _state(
    _owner,
    "Bruno's bill is overdue",
    (w) => w.f.money.invoices.any(
      (i) =>
          i.memberId == 'member-2' &&
          i.dueOn != null &&
          i.dueOn!.isBefore(w.now) &&
          _open(w, 'member-2'),
    ),
  ),
  WorkspaceFeature.paymentReminders: _state(
    _owner,
    'a reminder was sent',
    (w) => w.f.money.invoiceReminders.isNotEmpty,
  ),
  // ── billingPayments / expenses ──────────────────────────────────────
  WorkspaceFeature.supplyExpenses: _state(
    _admin,
    "Chiara's printer paper "
    'waits for a decision',
    (w) => w.pending(EventType.expense),
  ),
  WorkspaceFeature.expenseRepartitionWizard: _action(
    _owner,
    'Ada shares '
    'the cleaning among members',
    (w) => w.f.money.expenseSchedules.isNotEmpty,
  ),
  WorkspaceFeature.scheduledExpenses: _state(
    _admin,
    "this month's cleaning "
    'to confirm',
    (w) => w.f.money.expenseOccurrences.isNotEmpty,
  ),
  WorkspaceFeature.expenseRepartition: _action(
    _owner,
    'an expense split '
    'between members',
    (w) => w.settled(EventType.expense),
  ),
  WorkspaceFeature.purchases: _state(
    _owner,
    'a draft to submit, a bill to '
    'approve, one approved unpaid, one part-paid, a credit note, receipts '
    'waiting, refused and reimbursed',
    (w) async {
      final docs = await w.purchases();
      bool has(PurchaseKind k, PurchaseState s) =>
          docs.any((d) => d.kind == k && d.state == s);
      final rows = w.purchasing.purchases.payables;
      return has(PurchaseKind.bill, PurchaseState.draft) &&
          has(PurchaseKind.bill, PurchaseState.pending) &&
          has(PurchaseKind.creditNote, PurchaseState.draft) &&
          has(PurchaseKind.memberReceipt, PurchaseState.pending) &&
          has(PurchaseKind.memberReceipt, PurchaseState.rejected) &&
          rows.any((r) => r.obligation.paidCents == 0) &&
          rows.any(
            (r) =>
                r.obligation.paidCents > 0 && r.obligation.remainingCents > 0,
          ) &&
          rows.any(
            (r) =>
                r.obligation.creditorKind == CreditorKind.member &&
                r.obligation.remainingCents == 0,
          ) &&
          w.purchasing.inbox.documents.any(
            (d) => d.status == InboxStatus.received,
          );
    },
  ),
  WorkspaceFeature.premisesLease: _state(
    _owner,
    'the rent matched to the '
    "lessor's bills, a difference to accept, this month expected",
    (w) async {
      final page = await w.commitments.fetchCommitments(
        'ws-1',
        'demo-lease-premises',
      );
      final o = page.occurrences;
      return o.any((x) => x.state == CommitmentState.expected) &&
          o.any((x) => x.matches.any((m) => m.lineUnallocatedCents > 0)) &&
          o.any((x) => x.state == CommitmentState.matched);
    },
  ),
  WorkspaceFeature.assetRegister: _state(
    _owner,
    'the espresso machine in '
    'use, the printer to decide, a purchase line to register',
    (w) async {
      final assets = await w.assets.fetchAssets('ws-1');
      final lines = await w.assets.fetchCandidateLines('ws-1');
      final batches = await w.valuations.fetchBatches('ws-1');
      return assets.any((a) => a.decision == AssetDecision.capitalise) &&
          assets.any((a) => a.state == AssetState.candidate) &&
          lines.isNotEmpty &&
          batches.any((b) => b.status == ValuationStatus.confirmed);
    },
  ),
  WorkspaceFeature.foreignCurrencyPurchases: _state(
    _owner,
    'a licence billed in Swiss francs waits with its rate',
    (w) async =>
        (await w.purchasing.purchases.fetchExchangeRate(
          'ws-1',
          'demo-bill-licence-chf',
        ))?.currency ==
        'CHF',
  ),
  // #3307 — the orders the space sent its suppliers, one received.
  WorkspaceFeature.purchaseOrders: _state(
    _owner,
    'orders to the suppliers: '
    'a draft, one awaited, one received',
    (w) async {
      final orders = FakePurchaseOrderRepository(
        suppliers: () => w.purchasing.suppliers.suppliers,
        services: () => w.f.money.services,
        now: () => w.now,
      );
      seedDemoPurchaseOrders(orders, w.now);
      final states = {for (final o in await orders.fetchOrders('ws-1')) o.state};
      return states.containsAll({
        PurchaseOrderState.draft,
        PurchaseOrderState.sent,
        PurchaseOrderState.received,
      });
    },
  ),
  WorkspaceFeature.purchaseAnalytics: _state(
    _owner,
    'what is owed to '
    'suppliers and members, and what is waiting',
    (w) async {
      final kpi = await DemoPurchaseKpiRepository(
        purchases: w.purchasing.purchases,
        now: w.now,
      ).summary('ws-1', fromMonth: '2000-01', toMonth: '2999-12');
      return (kpi.apOutstandingMinor ?? 0) > 0 && kpi.pendingCount > 0;
    },
  ),
  // ── billingPayments / tax ───────────────────────────────────────────
  WorkspaceFeature.accountingBook: _state(
    _owner,
    'the bills and supplier '
    'documents posted to the books',
    (w) async =>
        (await w.purchases()).isNotEmpty && w.f.money.invoices.isNotEmpty,
  ),
  WorkspaceFeature.accountingPeriods: _state(
    _owner,
    'last year closed and '
    'exported',
    (w) async => (await w.books.fetch('ws-1')).periods.isNotEmpty,
  ),
  WorkspaceFeature.accountingConnectors: _state(
    _owner,
    'the studio connected to '
    'Pennylane: one invoice received, a credit note waiting for its readback',
    (w) async {
      final repo = seedDemoAccountingConnections(w.books, w.now);
      final connected = (await repo.fetchConnections('ws-1')).any(
        (c) => c.status == ConnectionStatus.connected && c.maps.isNotEmpty,
      );
      final moved = (await repo.fetchTransfers(
        'ws-1',
        DateTime(w.now.year),
        DateTime(w.now.year, 12, 31),
      )).deliveries;
      return connected &&
          moved.any((d) => d.status == DeliveryStatus.acknowledged) &&
          moved.any((d) => d.status == DeliveryStatus.conflict);
    },
  ),
  WorkspaceFeature.vatManagement: _state(
    _owner,
    "France's rates",
    (w) => w.f.money.vatRates.length >= 3,
  ),
  WorkspaceFeature.vatDeclarations: _state(
    _owner,
    'one quarter filed, the '
    'next to prepare',
    (w) =>
        w.f.money.vatDeclarations.any((d) => d.submittedAt == null) &&
        w.f.money.vatDeclarations.any((d) => d.submittedAt != null),
  ),
  WorkspaceFeature.vatGroups: _state(
    _owner,
    'reduced and exempt groups',
    (w) => w.f.money.vatRates.any((r) => r.groupKey.isNotEmpty),
  ),
  WorkspaceFeature.vatRateHistory: _action(
    _owner,
    'Ada changes a rate from '
    'a date',
    (w) => w.f.money.vatRates.isNotEmpty,
  ),
  WorkspaceFeature.vatCounterparty: _action(
    _owner,
    "a member's company VAT "
    'number on a bill',
    (w) => w.f.money.invoices.isNotEmpty,
  ),
  WorkspaceFeature.supplyClassification: _state(
    _owner,
    'goods and services '
    'told apart on supplier lines',
    (w) async => (await w.purchases()).isNotEmpty,
  ),
  // #3963 — the customer form's VAT number check answers by rule: valid,
  // invalid, and a member state that does not answer.
  WorkspaceFeature.viesVerification: _action(
    _owner,
    "Ada checks three customers' EU VAT numbers: valid, invalid and no answer",
    (_) => viesJourney(),
  ),
  WorkspaceFeature.recapitulativeStatement: _action(
    _owner,
    'the EU sales '
    'list of the quarter',
    (w) => w.f.money.vatDeclarations.isNotEmpty,
  ),
  WorkspaceFeature.inputVat: _state(
    _owner,
    'VAT to recover on supplier '
    'bills',
    (w) async => (await w.purchases()).isNotEmpty,
  ),
  // #4009 — performed in the New York house, in dollars.
  WorkspaceFeature.salesTax: _action(
    _owner,
    'Ada reads New York\'s sales-tax return of last month in dollars, as the '
    'invoices froze it: three taxed sales with the tax of each jurisdiction, '
    'and the memberships and bookings outside the tax',
    (w) async {
      final ny = w.house(DemoSpaceKey.newYork);
      final container = ny.container();
      try {
        return await salesTaxJourney(ny.newYork, container, ny.now);
      } finally {
        container.dispose();
      }
    },
    business: demoNewYorkSpaceId,
  ),
  // #4009 — performed in the London house; left off in the head.
  WorkspaceFeature.mtdSubmission: _action(
    _owner,
    'Ada connects London to HMRC (simulated sign-in), submits the prepared '
    'return, reads the Demo receipt, and a second submission is refused',
    (w) => mtdSubmissionJourney(w.house(DemoSpaceKey.london).london),
    business: demoLondonSpaceId,
  ),
  // ── documentsInformation ─────────────────────────────────────────────
  WorkspaceFeature.documents: _state(
    _member,
    'house rules and the Wi-Fi '
    'guide; the insurance for admins',
    (w) => w.f.workspaces.documents.any((d) => d.minRole == 'admin'),
  ),
  WorkspaceFeature.pdfExport: _state(
    _member,
    'a bill as PDF',
    (w) => w.f.money.invoices.isNotEmpty,
  ),
  WorkspaceFeature.invoicePdfTemplate: _state(_owner, 'an issued invoice prints with the owner\'s template: letterhead, lines in euros, footer', (_) => invoiceTemplateState()),
  WorkspaceFeature.invoiceAddressWindow: _state(_owner, 'the recipient sits in the window of the envelope, on A4', (_) => addressWindowState()),
  WorkspaceFeature.letterStandard: _state(_owner, 'a statement prints as a standard letter, a designed kind keeps its design', (_) => letterStandardState()),
  WorkspaceFeature.reportDesignExchange: _action(_owner, 'a design leaves as its exchange file and comes back equal', (_) => exchangeAction()),
  WorkspaceFeature.reportLayouts: _state(_owner, 'a positioned layout is saved for the usage statement and is the one that prints', (_) => layoutState()),
  WorkspaceFeature.reportTexts: _action(_owner, 'Ada changes a text of the report and reads it in the printed footer', (_) => reportTextAction()),
  WorkspaceFeature.reportDesigner: _action(_owner, 'the designer opens the design, a line is edited and saved', (_) => designerEditAction()),
  // #3963 — the analysis export is made from the Demo's own figures, in
  // euros; what the Demo does not answer is left out and said. The sample-data
  // card holds the Demo's one batch and loads no more: the Demo is sample data.
  WorkspaceFeature.biReportDesigner: _action(
    _owner,
    'a saved analysis is designed and exported as a file from the Demo\'s own '
    'figures',
    (w) async {
      final views = await w.f.biViews.list('ws-1');
      return views.length >= 3 &&
          views.any((v) => (v.definition?.report?.pages.length ?? 0) >= 2) &&
          await exportJourney();
    },
  ),
  WorkspaceFeature.usageReport: _state(
    _admin,
    'usage by member and month',
    (w) => w.f.money.usageRecords.isNotEmpty,
  ),
  WorkspaceFeature.vatReport: _state(
    _owner,
    'the VAT of a quarter',
    (w) => w.f.money.vatDeclarations.isNotEmpty,
  ),
  WorkspaceFeature.dataAccessLog: _action(
    _member,
    'Bruno sees who opened '
    'his data',
    (w) => w.members.length > 1,
  ),
  WorkspaceFeature.memberDataExport: _action(
    _member,
    'Bruno downloads his '
    'data',
    (w) => w.bookings.any((r) => r.memberId == 'member-2'),
  ),
  WorkspaceFeature.dataExport: _action(_owner, 'the whole space as a workbook, written from the Demo\'s own rows', (_) => dataExportAction()),
  WorkspaceFeature.dataReport: _state(_owner, 'the whole space as a printed report: every section holds the Demo\'s records', (_) => dataReportState()),
  // ── operations ───────────────────────────────────────────────────────
  WorkspaceFeature.workspaceStatus: _state(
    _owner,
    "the quarter's figures",
    (w) => w.f.money.invoices.isNotEmpty,
  ),
  WorkspaceFeature.environmentPairs: _state(
    _owner,
    'the production side '
    'and its development twin',
    (w) => w.f.workspaces.workspaces.any((x) => x.environment == 'dev'),
  ),
  WorkspaceFeature.deployments: _state(
    _owner,
    'three deployments, one '
    'rolled back',
    (w) => w.f.deployments.journalRows.any((d) => d.rolledBackAt != null),
  ),
  // #3964 — the business's configuration travels in a file a second
  // business reads.
  WorkspaceFeature.configurationTransfer: _action(
    _owner,
    'Ada exports her business to a file and a second business reads it',
    (_) => configurationTransferJourney(),
  ),
  WorkspaceFeature.configurableSettings: _action(
    _owner,
    'Ada changes a setting for her business alone; it is refused out of '
    'bounds and on a guardrail',
    (_) => settingsJourney(),
  ),
  WorkspaceFeature.workspaceLibrary: _state(
    _owner,
    'templates to start '
    'from',
    (w) async => (await w.f.workspaces.fetchWorkspaceTemplates()).isNotEmpty,
  ),
  WorkspaceFeature.instanceWizard: _state(
    _owner,
    'the route of the instance wizard stays open where the flag is on and '
    'leaves where it is off',
    (_) => instanceWizardState(),
  ),
  // #2869 — the guide's demo setup states come with #2872.
  // #3963 — the guide's sample-data card holds the Demo's one batch and a fill
  // answers it: the Demo is itself sample data, so it loads no more.
  WorkspaceFeature.setupGuide: _state(
    _owner,
    'the setup guide holds done steps by its own records; its sample-data '
    'card holds the Demo\'s one batch, the Demo being sample data itself, and '
    'loads no more',
    (_) => setupGuideJourney(),
  ),
  WorkspaceFeature.decisionSurface: _state(
    _admin,
    'what needs a person, '
    'ranked',
    (w) =>
        w.f.events.events
            .where((e) => e.status == EventStatus.pending)
            .length >=
        3,
  ),
  WorkspaceFeature.workspaceOverview: _state(
    _owner,
    'what waits for Ada, then the figures she may read',
    (w) =>
        w.f.events.events.any((e) => e.status == EventStatus.pending) &&
        w.f.money.invoices.isNotEmpty,
  ),
  WorkspaceFeature.formHelpHints: _action(
    _member,
    'Bruno dismisses a hint and it stays dismissed; the hints come back',
    (_) => helpHintsJourney(),
  ),
  WorkspaceFeature.memberGettingStarted: _action(
    _member,
    'the Get started card points Bruno to choosing a time, then to his '
    'membership once he has booked',
    (_) => gettingStartedJourney(),
  ),
  WorkspaceFeature.placeFeedback: _action(
    _member,
    'Bruno rates his seat',
    (w) => w.bookings.any((r) => r.memberId == 'member-2'),
  ),
  WorkspaceFeature.taskRecorder: _action(
    _owner,
    'Ada records how she '
    'issues a bill',
    (w) => w.f.money.invoices.isNotEmpty,
  ),
  // A switch, kept: motion is how every screen moves, read once by the app
  // shell, and has no state or step to perform. Performable when a Demo
  // step shows a reduced-motion comparison.
  WorkspaceFeature.uiAnimations: _toggle('motion'),
  // #4006 — the owner opens the organisation's sheet and adds the Berlin
  // practice, the business of hers outside it, through the Demo's own
  // commands: it is a house afterwards.
  WorkspaceFeature.organisation: _action(
    _owner,
    'Ada adds the Berlin practice to her organisation',
    (w) async {
      final organisations = FakeOrganisationRepository.from(
        () => demoOrganisations(w.f.workspaces),
        businesses: () => demoBusinessesAsHouses(w.f.workspaces),
      );
      final before = (await organisations.myOrganisations()).single;
      if (before.houseOf(demoPracticeSpaceId) != null) return false;
      final refused = await organisations.add(before.id, demoPracticeSpaceId);
      final after = (await organisations.myOrganisations()).single;
      return refused == null && after.houseOf(demoPracticeSpaceId) != null;
    },
  ),
  // #4161 — the owner reads the shop stock: exact quantities, a syrup
  // received in thirds of a litre is 0.999999 l, and its movements.
  WorkspaceFeature.stockManagement: _action(
    _owner,
    'Ada reads the shop stock and finds the syrup received in thirds of a '
    'litre at exactly 0.999999 l',
    (w) async {
      final stock = DemoStockQueries(
        DemoStockLedger(demoFirstSpaceId, DemoStockConfigCommands(demoFirstSpaceId)),
      );
      final onHand = await stock.onHandPage(demoFirstSpaceId);
      final moves = await stock.movementsPage(demoFirstSpaceId);
      return onHand.rows.any(
            (r) => r.itemName == 'Syrup' && r.quantity.text == '0.999999',
          ) &&
          moves.rows.isNotEmpty;
    },
  ),
  // #4169 — the owner tracks the T-shirt by expiry date with a shelf life; the
  // syrup, which has history, keeps the tracking its first movement fixed.
  WorkspaceFeature.stockLots: _action(
    _owner,
    'Ada tracks the T-shirt by expiry date with a shelf life of 30 days, and '
    'is told the syrup keeps the tracking its first movement fixed',
    (w) async {
      final config = DemoStockConfigCommands(demoFirstSpaceId);
      final shirt = (await config.item(demoFirstSpaceId, 'demo-item-shirt'))!;
      await config.saveItem(
        demoFirstSpaceId,
        StockItemConfig(
          itemId: shirt.itemId, revision: shirt.revision, stockable: shirt.stockable,
          purchasable: shirt.purchasable, sellable: shirt.sellable, inventoryUnit: shirt.inventoryUnit,
          tracking: 'expiry', shelfLifeDays: 30, units: shirt.units, codes: shirt.codes,
        ),
        'r-1',
      );
      final saved = (await config.item(demoFirstSpaceId, 'demo-item-shirt'))!;
      final syrup = (await config.item(demoFirstSpaceId, 'demo-item-syrup'))!;
      try {
        await config.saveItem(
          demoFirstSpaceId,
          StockItemConfig(
            itemId: syrup.itemId, revision: syrup.revision, stockable: true, purchasable: true,
            sellable: true, inventoryUnit: syrup.inventoryUnit, tracking: 'lot', shelfLifeDays: null,
            units: syrup.units, codes: syrup.codes,
          ),
          'r-2',
        );
        return false;
      } on StockConfigInUse {
        return saved.tracking == 'expiry' && saved.shelfLifeDays == 30;
      }
    },
  ),
  // #4171 — the delivery of the partly received order is put away into the
  // shop's stock, once: what arrived is put away, no more than arrived is.
  WorkspaceFeature.stockReceiving: _action(
    _owner,
    'Ada puts the 20 kg of coffee beans that arrived into the main store, '
    'and is told she cannot put away more than arrived',
    (w) async {
      final orders = FakePurchaseOrderRepository(
        suppliers: () => w.purchasing.suppliers.suppliers,
        services: () => w.f.money.services,
        now: () => w.now,
      );
      seedDemoPurchaseOrders(orders, w.now);
      final config = DemoStockConfigCommands(demoFirstSpaceId);
      final ledger = DemoStockLedger(demoFirstSpaceId, config);
      final receiving = DemoStockReceivingCommands(demoFirstSpaceId, orders, config, ledger);
      final place = (await config.places(demoFirstSpaceId)).firstWhere((p) => p.code == 'MAIN').id;
      await receiving.putAway(demoFirstSpaceId, 'demo-receipt-3', [
        PutAwayAllocation(lineNo: 1, quantity: '20', locationId: place),
      ], 'req-1');
      try {
        await receiving.putAway(demoFirstSpaceId, 'demo-receipt-3', [
          PutAwayAllocation(lineNo: 1, quantity: '1', locationId: place),
        ], 'req-2');
        return false;
      } on StockConfigRefused catch (e) {
        final rows = await receiving.allocationsOfOrder(demoFirstSpaceId, 'demo-order-${w.now.year}-5');
        return e.reason == 'over_allocated' && rows.map((a) => a.enteredQuantity.text).toList().join() == '20';
      }
    },
  ),
  // #4170 — goods taken out of the stock, on the Demo's one ledger: a broken
  // mug is written off, and a take-out of more than is held moves nothing.
  WorkspaceFeature.stockTakeOut: _action(
    _owner,
    'Ada writes off a broken mug from the main store, and is told she cannot '
    'take out more mugs than the store holds',
    (w) async {
      final config = DemoStockConfigCommands(demoFirstSpaceId);
      final ledger = DemoStockLedger(demoFirstSpaceId, config);
      final operations = DemoStockOperations(ledger, config);
      final main = (await config.places(demoFirstSpaceId)).firstWhere((p) => p.code == 'MAIN').id;
      await operations.takeOut(demoFirstSpaceId, StockTakeOutReason.loss, [
        StockLineDraft(itemId: 'demo-item-mugs', quantity: '1', fromLocationId: main),
      ], 'req-loss');
      try {
        await operations.takeOut(demoFirstSpaceId, StockTakeOutReason.loss, [
          StockLineDraft(itemId: 'demo-item-mugs', quantity: '500', fromLocationId: main),
        ], 'req-too-many');
        return false;
      } on StockNotEnough {
        return ledger.balance('demo-item-mugs', main).text == '35' && ledger.movements.first.reason == 'loss';
      }
    },
  ),
  // #4294 — reorder points: two shop items are below theirs, the beans are ordered from their
  // preferred supplier as a draft (once per request), the syrup has no supplier chosen.
  WorkspaceFeature.stockReorder: _action(
    _owner,
    'Ada sees the beans and the syrup below their reorder point, makes a draft order of the beans '
    'from Café Import, and the syrup stays "no supplier chosen"',
    (w) async {
      final config = DemoStockConfigCommands(demoFirstSpaceId);
      final ledger = DemoStockLedger(demoFirstSpaceId, config);
      final reorder = DemoStockReorder(demoFirstSpaceId, ledger, config);
      final low = await reorder.low(demoFirstSpaceId);
      final list = await reorder.replenishment(demoFirstSpaceId);
      final group = list.groups.single;
      final draft = await reorder.createDraft(demoFirstSpaceId, supplierId: group.supplierId, lines: group.lines, requestId: 'req-draft');
      final again = await reorder.createDraft(demoFirstSpaceId, supplierId: group.supplierId, lines: group.lines, requestId: 'req-draft');
      return low.map((r) => r.itemId).toSet().containsAll({'demo-item-beans', 'demo-item-syrup'}) &&
          low.length == 2 &&
          group.supplierName == 'Café Import' &&
          list.noSupplier.single.itemId == 'demo-item-syrup' &&
          draft.number != null &&
          again.number == draft.number;
    },
  ),
  // #4172 — goods go back: a part of a delivery returns to its supplier from
  // the place the goods are in, and more than the delivery held is refused.
  WorkspaceFeature.stockReturns: _action(
    _owner,
    'Ada returns 4 mugs of the delivery to the supplier, and is told she cannot '
    'return more than the delivery held',
    (w) async {
      final config = DemoStockConfigCommands(demoFirstSpaceId);
      final ledger = DemoStockLedger(demoFirstSpaceId, config);
      final reversals = DemoStockReversals(ledger);
      await reversals.makeReturn(demoFirstSpaceId, 'return-1', StockReturnKind.supplier, const [
        (lineId: 'line-1', sourceMovementId: 'demo-stock-movement-3', quantity: '4', locationId: 'demo-place-main', note: ''),
      ], 'req-1');
      try {
        await reversals.makeReturn(demoFirstSpaceId, 'return-2', StockReturnKind.supplier, const [
          (lineId: 'line-2', sourceMovementId: 'demo-stock-movement-3', quantity: '51', locationId: 'demo-place-main', note: ''),
        ], 'req-2');
        return false;
      } on PostgrestException catch (e) {
        final allows = (await reversals.reversible(demoFirstSpaceId, ['demo-stock-movement-3']))['demo-stock-movement-3']!;
        return e.code == 'DKG17' && ledger.balance('demo-item-mugs', 'demo-place-main').text == '32' && allows.remaining.text == '50';
      }
    },
  ),
  // #4172 — a count is approved before it moves the stock, and not if the
  // stock moved since.
  WorkspaceFeature.stockCounts: _action(
    _owner,
    'Ada counts 10 kg of beans where the ledger holds 12.5 and approves it, and '
    'a count the stock has moved since is refused',
    (w) async {
      final config = DemoStockConfigCommands(demoFirstSpaceId);
      final ledger = DemoStockLedger(demoFirstSpaceId, config);
      final reversals = DemoStockReversals(ledger);
      await reversals.recordCount(demoFirstSpaceId, (countId: 'count-1', itemId: 'demo-item-beans', locationId: 'demo-place-main', observed: '10', requestId: 'req-1', variantId: null, lotId: null, reason: ''));
      await reversals.decideCount(demoFirstSpaceId, 'count-1', StockCountDecision.apply, 'req-2');
      await reversals.recordCount(demoFirstSpaceId, (countId: 'count-2', itemId: 'demo-item-beans', locationId: 'demo-place-main', observed: '9', requestId: 'req-3', variantId: null, lotId: null, reason: ''));
      await ledger.post(
        DemoStockPost(item: ledger.itemOf('demo-item-beans')!, quantity: ExactQuantity.parse('1'), from: 'demo-place-main', to: 'demo-place-shelf', reason: 'transfer'),
      );
      try {
        await reversals.decideCount(demoFirstSpaceId, 'count-2', StockCountDecision.apply, 'req-4');
        return false;
      } on PostgrestException catch (e) {
        return e.code == 'DKG20' && ledger.balance('demo-item-beans', 'demo-place-main').text == '9';
      }
    },
  ),
  // #4295 — the high-value shelf's plan made a task: counted blind (a counter is not told what the
  // ledger holds), a skip needs a reason, and every line counted or skipped completes the task.
  WorkspaceFeature.stockCycleCounts: _action(
    _owner,
    'Ada counts the high-value shelf blind, skips one line with a reason, and the task is complete',
    (w) async {
      final config = DemoStockConfigCommands(demoFirstSpaceId);
      final ledger = DemoStockLedger(demoFirstSpaceId, config);
      final reversals = DemoStockReversals(ledger);
      final cycle = DemoStockCycleCounts(
        demoFirstSpaceId,
        ledger,
        reversals,
        DemoStockRegistry(demoFirstSpaceId, ledger, config),
        () => {WorkspacePermission.countStock},
        () => DateTime(2026, 5, 13),
      );
      final task = (await cycle.tasks(demoFirstSpaceId)).single;
      final lines = (await cycle.task(demoFirstSpaceId, task.taskId)).lines;
      if (lines.length < 2) return false;
      final blind = await cycle.countLine(demoFirstSpaceId, lines.first.lineId, '3', 'req-1');
      try {
        await cycle.skipLine(demoFirstSpaceId, lines[1].lineId, ' ', 'req-2');
        return false;
      } on PostgrestException catch (e) {
        if (e.code != 'DKG07') return false;
      }
      for (final l in lines.skip(1)) {
        await cycle.skipLine(demoFirstSpaceId, l.lineId, 'Behind the pallet', 'skip-${l.lineId}');
      }
      final done = (await cycle.task(demoFirstSpaceId, task.taskId)).state == CountTaskState.complete;
      return blind.difference == null && blind.baseline == null && done && (await reversals.counts(demoFirstSpaceId)).length == 1;
    },
  ),
  // #4361 — the owner changes the shelf life of the drinks group: the preview says the milk follows, the syrup
  // keeps its own and the beans have their sub-group's; only the second save applies it, and the history says so.
  WorkspaceFeature.stockItemGroups: _action(
    _owner,
    'Ada changes the drinks group\'s shelf life, sees "applies to 1, 1 keeps its own", applies it and reads it in the history',
    (w) async {
      final groups = DemoItemGroups(demoFirstSpaceId, DemoStockConfigCommands(demoFirstSpaceId), () => DateTime(2026, 5, 13));
      final drinks = (await groups.groups(demoFirstSpaceId)).firstWhere((g) => g.id == 'demo-group-drinks');
      final body = {'parameters': {'shelf_life_days': 120}};
      final preview = await groups.save(demoFirstSpaceId, requestId: 'preview', groupId: drinks.id, expectedRevision: drinks.revision, body: body, apply: false);
      final impact = preview.impact['shelf_life_days'];
      if (impact == null || impact.affected != 1 || impact.keptOwn != 1) return false;
      await groups.save(demoFirstSpaceId, requestId: 'apply', groupId: drinks.id, expectedRevision: drinks.revision, body: body);
      final milk = await groups.effective(demoFirstSpaceId, 'demo-item-milk');
      final history = await groups.history(demoFirstSpaceId, groupId: drinks.id);
      return milk.params['shelf_life_days']!.value == 120 && history.length == 1;
    },
  ),
  // #4164 — the owner keeps a customer with no account: a business is added
  // to the head's billing customers and is listed beside the seeded ones.
  WorkspaceFeature.billingCustomers: _action(
    _owner,
    'Ada adds Studio Nord, a business with no account, to her billing '
    'customers',
    (w) async {
      final customers = w.house(DemoSpaceKey.home).stores.billingCustomers;
      final before = (await customers.fetch(demoFirstSpaceId)).length;
      await customers.create(
        demoFirstSpaceId,
        const BillingPartyDraft(company: 'Studio Nord', city: 'Kiel'),
        capacity: 'business',
      );
      final after = await customers.fetch(demoFirstSpaceId);
      return before > 0 &&
          after.length == before + 1 &&
          after.any((c) => c.displayName == 'Studio Nord');
    },
  ),
  // #4166 — the owner sends a quote to a billing customer: the first send takes
  // the next reference from the quote series and freezes the revision.
  WorkspaceFeature.customerQuotes: _action(
    _owner,
    'Ada sends the draft quote to Hanna Weiss and it takes the next reference',
    (w) async {
      final quotes = w.house(DemoSpaceKey.home).stores.customerQuotes;
      final draft = (await quotes.quotes(demoFirstSpaceId)).firstWhere(
        (q) => q.status == QuoteStatus.draft,
      );
      final rev = draft.draft!;
      final sent = await quotes.send(
        demoFirstSpaceId,
        draft.id,
        revision: rev.revision,
        version: rev.draftVersion,
      );
      final after = await quotes.quote(demoFirstSpaceId, draft.id);
      return sent.reference.startsWith('QUO-') &&
          after.status == QuoteStatus.sent &&
          after.current?.totals != null;
    },
  ),
  // #4178 — the owner commits a service to a billing customer and starts it:
  // the engagement is ordered, then started, and nothing is invoiced by it.
  WorkspaceFeature.serviceFulfilment: _action(
    _owner,
    'Ada commits a coaching service to Hanna Weiss and starts it',
    (w) async {
      final house = w.house(DemoSpaceKey.home).stores;
      final customer = (await house.billingCustomers.fetch(demoFirstSpaceId)).first;
      final invoices = w.f.money.invoices.length;
      final opened = await demoServiceFulfilments(w.f, DemoSpaceKey.home).openDirect(
        demoFirstSpaceId,
        requestId: 'scenario-engagement',
        input: DirectEngagementInput(subjectId: customer.subjectId, description: 'Coaching', quantity: '3'),
      );
      final started = await demoServiceFulfilments(w.f, DemoSpaceKey.home).transition(
        demoFirstSpaceId,
        opened.fulfilment.id,
        expectedRevision: opened.fulfilment.revision,
        to: FulfilmentState.started,
        requestId: 'scenario-engagement-start',
      );
      return started.state == FulfilmentState.started && w.f.money.invoices.length == invoices;
    },
  ),
  // #3610 — Ctrl+K finds an invoice of the Demo by its number, and a
  // member by name.
  WorkspaceFeature.quickSearch: _action(
    _owner,
    'Ada presses Ctrl+K and finds an invoice by its number',
    (w) =>
        w.f.money.invoices.isNotEmpty && w.f.workspaces.workspaces.isNotEmpty,
  ),
  WorkspaceFeature.regionalFormats: _action(
    _member,
    'Bruno chooses Swiss formats and reads the business in them, its '
    'currency unchanged',
    (_) => regionalFormatsJourney(),
  ),
  WorkspaceFeature.navigationStyle: _action(
    _member,
    'Bruno chooses the menu over the bar, and choosing nothing brings the '
    'default back',
    (_) => navigationJourney(),
  ),
  // A switch, kept: the personal shell is the installation's answer (the
  // platform's defaults), not a business's state; performable when the Demo
  // holds its own installation defaults.
  WorkspaceFeature.personalShell: _toggle('Me as five destinations'),
  WorkspaceFeature.memberAccountMenu: _state(
    _member,
    'a member sees "Account" instead of Settings, an owner and an admin do '
    'not',
    (_) => accountMenuJourney(),
  ),
  // #4009 — the mode is this demonstration itself, and what it shows first is
  // one organisation: the head and its houses in five countries and four
  // currencies, the Berlin practice outside it. Entered and reset by
  // demo_entry_test and demo_session_test.
  WorkspaceFeature.demoMode: _state(
    _owner,
    'the demonstration is one organisation: Atelier du Marché with its five '
    'houses in four currencies, and the Berlin practice outside it',
    (w) async {
      final organisation = (await demoOrganisations(w.f.workspaces)).single;
      return organisation.headWorkspaceId == demoFirstSpaceId &&
          {for (final h in organisation.houses) h.workspaceId}.containsAll(
            _organisation,
          ) &&
          {for (final h in organisation.houses) h.currencyCode}.length == 4 &&
          organisation.houseOf(demoPracticeSpaceId) == null;
    },
  ),
  // ── integrations ─────────────────────────────────────────────────────
  WorkspaceFeature.pushNotifications: _state(
    _owner,
    'the notices the business sends travel on the push channel; the Demo '
    'registers no device',
    (_) => pushLinesState(),
  ),
  // #3963 — the group link is stored and a member reads it.
  WorkspaceFeature.whatsappIntegration: _action(
    _owner,
    "Ada stores the space's group link and a member reads it",
    (_) => whatsappJourney(),
  ),
  WorkspaceFeature.einvoiceCustomerDelivery: _action(
    _owner,
    'a bill sent as an e-invoice through the configured channel, its receipt '
    'read, and the submission nobody could confirm settled',
    (_) => eInvoiceJourney(),
  ),
  // #3962 — an assistant connected in the reference business, the request it
  // left for confirmation, and the page's assistant that books a room.
  WorkspaceFeature.mcpAccess: _action(
    _owner,
    'Ada reads what her assistant may do and confirms the request it left',
    (_) => confirmRoomRequestJourney(),
  ),
  WorkspaceFeature.webMcp: _action(
    _owner,
    'the assistant in the page books the meeting room on a Thursday morning',
    (_) => webAssistantBooksJourney(),
  ),
  // #3960 — e-mail is recorded in the Demo's outbox; nothing is sent.
  WorkspaceFeature.reminderEmail: _action(
    _owner,
    'Ada e-mails the first reminder of an overdue bill; the customer '
    'without an address is refused',
    (_) => reminderEmailJourney(),
  ),
  WorkspaceFeature.invoiceEmail: _action(
    _owner,
    'Ada e-mails an invoice and sees it recorded with its date; the '
    'customer without an address is refused',
    (_) => invoiceEmailJourney(),
  ),
  // #4165 — a customer invoice without a member-month, drafted and issued.
  WorkspaceFeature.standaloneInvoicing: _action(
    _owner,
    'Ada invoices 1.5 hours at 80.00 to a customer with no booking behind it: '
    'the preview and the issued invoice state the exact quantity, and the same '
    'request never issues twice',
    (_) => standaloneInvoiceJourney(),
  ),
};

bool _open(_World w, String member) => w.f.money.invoices.any(
  (i) =>
      i.memberId == member &&
      i.totalCents > 0 &&
      (w.f.money.invoiceMatchesStore[i.id]?.paidCents ?? 0) < i.totalCents,
);

/// A member with charges this month and no bill for it yet.
bool _somethingToInvoice(_World w) {
  final month = '${w.now.year}-${w.now.month.toString().padLeft(2, '0')}';
  final billed = {
    for (final i in w.f.money.invoices)
      if (i.period == month && i.kind != InvoiceKind.settlement) i.memberId,
  };
  return w.f.money.ledger.any(
    (l) =>
        l.kind == LedgerKind.charge &&
        l.period == month &&
        !billed.contains(l.memberId),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  final world = _World(DemoFixture.build());

  test('every feature of the registry has a scenario, or a reason it '
      'cannot run without a server', () {
    final missing = [
      for (final f in WorkspaceFeature.values)
        if (!_scenarios.containsKey(f) && !demoFeaturesLeftOff.containsKey(f))
          f.name,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'give each a scenario in demo_scenarios_test.dart and the '
          'data that makes it true in lib/core/demo/seed/',
    );
    expect(
      [
        for (final f in _scenarios.keys)
          if (demoFeaturesLeftOff.containsKey(f) &&
              _scenarios[f]!.business == demoFirstSpaceId)
            f.name,
      ],
      isEmpty,
      reason:
          'a feature the head leaves off has no scenario in the head; one '
          'tied to a house is performed there, and the house has it on',
    );
    for (final f in _scenarios.keys.where(demoFeaturesLeftOff.containsKey)) {
      final house = world.f.workspaces.workspaces.firstWhere(
        (w) => w.id == _scenarios[f]!.business,
      );
      expect(
        effectiveFeatures(
          resolveEnabledFeatures(house.featureFlags),
          country: house.countryCode,
        ),
        contains(f),
        reason: '${f.name} is performed in ${house.id}, which must have it on',
      );
    }
  });

  test('the main space has every feature on but the ones left off, and '
      'every chain holds', () {
    final ws = world.f.workspaces.workspaces.firstWhere((w) => w.id == 'ws-1');
    final effective = effectiveFeatures(
      resolveEnabledFeatures(ws.featureFlags),
      country: ws.countryCode,
    );
    final expected = {
      for (final f in WorkspaceFeature.values)
        if (!demoFeaturesLeftOff.containsKey(f)) f,
    };
    expect(effective, expected);
  });

  test('every step of every process in the catalogue is covered', () {
    for (final process in workspaceProcesses) {
      for (final step in process.subprocesses) {
        for (final f in step.capabilities) {
          expect(
            _scenarios.containsKey(f) || demoFeaturesLeftOff.containsKey(f),
            isTrue,
            reason: '${process.key}/${step.key}/${f.name}',
          );
        }
      }
    }
  });

  test('every persona has something to do', () {
    final byPersona = {for (final s in _scenarios.values) s.persona};
    expect(byPersona, containsAll(DemoPersona.values));
  });

  test('a scenario outside the reference organisation is named in '
      '_elsewhere, and the list holds nothing stale', () {
    expect(_businessProblems(_scenarios, _elsewhere), isEmpty);
  });

  test('the guard bites: planted scenarios outside the reference business', () {
    final planted = {
      WorkspaceFeature.coOwner: _state(
        _owner,
        'planted',
        (_) => true,
      ),
      WorkspaceFeature.guestPasses: _action(
        _owner,
        'planted',
        (_) => true,
        business: demoLondonSpaceId,
      ),
      WorkspaceFeature.customFields: _action(
        _owner,
        'planted',
        (_) => true,
        business: demoPracticeSpaceId,
      ),
    };
    expect(_businessProblems(planted, const {}), [
      'guestPasses happens in $demoLondonSpaceId: name the reason',
      'customFields happens in $demoPracticeSpaceId, outside the organisation',
    ]);
    expect(
      _businessProblems(planted, {
        WorkspaceFeature.guestPasses: 'x',
        WorkspaceFeature.coOwner: 'stale',
      }),
      [
        'customFields happens in $demoPracticeSpaceId, outside the '
            'organisation',
        'coOwner is listed as elsewhere but happens in the head',
      ],
    );
  });

  test('the switch-only scenarios only fall', () {
    expect(
      _switchOnlyCount(_scenarios.values),
      _switchOnlyBudget,
      reason:
          'a feature takes a state or an action, not a switch; when one is '
          'upgraded, lower _switchOnlyBudget to the new count',
    );
  });

  test('a check reads the business its scenario names, and no other', () async {
    final inLondon = world.within(demoLondonSpaceId);
    expect(inLondon.house(DemoSpaceKey.london).key, DemoSpaceKey.london);
    expect(() => inLondon.house(DemoSpaceKey.newYork), throwsStateError);
    expect(() => inLondon.f, throwsStateError);
    expect(() => inLondon.bookings, throwsStateError);
    expect(() => world.house(DemoSpaceKey.london), throwsStateError);
    expect(world.house(DemoSpaceKey.home).key, DemoSpaceKey.home);
    // A planted scenario in London that reads the head, or New York, fails
    // when it runs; one that reads London passes.
    final reachesHead = _action(
      _owner,
      'planted',
      (w) => w.bookings.isNotEmpty,
      business: demoLondonSpaceId,
    );
    final reachesNewYork = _action(
      _owner,
      'planted',
      (w) => w.house(DemoSpaceKey.newYork).parts.money.invoices.isNotEmpty,
      business: demoLondonSpaceId,
    );
    final readsLondon = _action(
      _owner,
      'planted',
      (w) => w.house(DemoSpaceKey.london).parts.money.invoices.isNotEmpty,
      business: demoLondonSpaceId,
    );
    expect(
      () async => reachesHead.check(world.within(reachesHead.business)),
      throwsStateError,
    );
    expect(
      () async => reachesNewYork.check(world.within(reachesNewYork.business)),
      throwsStateError,
    );
    expect(await readsLondon.check(world.within(readsLondon.business)), isTrue);
  });

  test('the budget bites: a planted extra switch is counted', () {
    final planted = [
      ..._scenarios.values,
      _toggle('planted'),
    ];
    expect(_switchOnlyCount(planted), isNot(_switchOnlyBudget));
  });

  group('the state each scenario starts from', () {
    for (final entry in _scenarios.entries) {
      final s = entry.value;
      if (s.kind == _Kind.toggle) continue;
      test('${entry.key.name} — ${s.persona.name}: ${s.story}', () async {
        expect(await s.check(world.within(s.business)), isTrue);
      });
    }
  });

  // #3031 — the demo's books read the licence billed in francs at its
  // recorded rate once approved: 480.00 CHF × 1.0657 = 511.54 EUR.
  test('the approved CHF licence posts in euros at its rate', () async {
    final f = DemoFixture.build();
    final purchasing = seedDemoPurchasing(f.seededAt, money: f.money);
    await purchasing.purchases.decideBill(
      'ws-1',
      'demo-bill-licence-chf',
      1,
      approve: true,
      reason: '',
      requestId: 'r-chf',
    );
    final profile = demoBookProfile(f.seededAt);
    final books = FakeBookProfileRepository(
      money: f.money,
      purchases: purchasing.purchases,
    );
    for (final (role, code, type) in [
      (BookRole.expenses, '606', AccountType.expense),
      (BookRole.suppliers, '401', AccountType.liability),
    ]) {
      books
        ..accounts.add(
          BookAccount(
            id: 'acc-$code',
            workspaceId: 'ws-1',
            issuerSiteId: profile.issuerSiteId,
            code: code,
            name: code,
            type: type,
            isPosting: true,
            origin: AccountOrigin.manual,
            revision: 1,
          ),
        )
        ..mappings.add(
          BookMapping(
            id: role.wire,
            workspaceId: 'ws-1',
            issuerSiteId: profile.issuerSiteId,
            role: role,
            accountId: 'acc-$code',
            effectiveFrom: DateTime(2020),
            revision: 1,
          ),
        );
    }
    final set = await books.fetchPostings(
      'ws-1',
      profile.issuerSiteId,
      f.seededAt.subtract(const Duration(days: 60)),
      f.seededAt,
    );
    final bill = set.postings.singleWhere(
      (p) =>
          p.documentId == 'demo-bill-licence-chf' &&
          p.kind == PostingKind.supplierBill,
    );
    expect(
      bill.lines.map((l) => (l.debit.currency, l.credit.minor)).toList(),
      [('EUR', 0), ('EUR', 51154)],
    );
  });
}
