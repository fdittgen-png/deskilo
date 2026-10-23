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
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/core/demo/data/kpi_repositories.dart';
import 'package:deskilo/core/demo/data/lease_commitment_repository.dart';
import 'package:deskilo/core/demo/data/premises_lease_repository.dart';
import 'package:deskilo/core/demo/data/room_rental_repository.dart';
import 'package:deskilo/core/demo/data/workspace_asset_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/seed/demo_asset_seed.dart';
import 'package:deskilo/core/demo/seed/demo_book_period_seed.dart';
import 'package:deskilo/core/demo/seed/demo_flags.dart';
import 'package:deskilo/core/demo/seed/demo_lease_seed.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/core/demo/seed/demo_room_seed.dart';
import 'package:deskilo/core/demo/seed/demo_valuation_seed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/asset_valuation.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/einvoice_inbox.dart';
import 'package:deskilo/features/money/domain/lease_commitment.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/workspace_asset.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything a scenario may look at: the session and the repositories
/// the Demo scope seeds beside it.
class _World {
  _World(this.f)
    : purchasing = seedDemoPurchasing(f.seededAt, money: f.money),
      lease = seedDemoLease(f.seededAt),
      commitments = seedDemoCommitments(f.seededAt),
      assets = seedDemoAssets(f.seededAt),
      valuations = seedDemoValuations(f.seededAt),
      books = seedDemoBookPeriods(f.seededAt),
      rooms = seedDemoRooms(f.seededAt);

  final DemoFixture f;
  final DemoPurchasing purchasing;
  final FakePremisesLeaseRepository lease;
  final FakeLeaseCommitmentRepository commitments;
  final FakeWorkspaceAssetRepository assets;
  final FakeAssetValuationRepository valuations;
  final FakeBookPeriodRepository books;
  final FakeRoomRentalRepository rooms;

  DateTime get now => f.seededAt;
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
  const _Scenario(this.kind, this.persona, this.story, this.check);

  final _Kind kind;
  final DemoPersona persona;
  final String story;
  final _Check check;
}

const _owner = DemoPersona.owner;
const _admin = DemoPersona.admin;
const _member = DemoPersona.member;
const _kiosk = DemoPersona.kiosk;

_Scenario _state(DemoPersona p, String story, _Check check) =>
    _Scenario(_Kind.state, p, story, check);
_Scenario _action(DemoPersona p, String story, _Check check) =>
    _Scenario(_Kind.action, p, story, check);
_Scenario _toggle(String story) =>
    _Scenario(_Kind.toggle, _owner, story, (_) => true);

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
  WorkspaceFeature.kioskMemberPhotos: _toggle('the kiosk shows faces'),
  WorkspaceFeature.badgeSignIn: _state(
    _kiosk,
    "Ada's badge signs her in",
    (w) => w.f.workspaces.badges.any((b) => b.authEnabled),
  ),
  WorkspaceFeature.spaceQrCodes: _toggle('every place prints its QR code'),
  // ── spaceManagement ──────────────────────────────────────────────────
  WorkspaceFeature.multiSite: _state(
    _owner,
    'the studio and the garage are '
    'two sites',
    (w) => w.f.workspaces.sites.length >= 2,
  ),
  WorkspaceFeature.siteDocuments: _toggle('reserved flag (internal)'),
  WorkspaceFeature.planObjectDelete: _toggle('the plan editor deletes'),
  WorkspaceFeature.adminSeatBlocking: _action(
    _admin,
    'Chiara blocks a seat '
    'for maintenance',
    (w) => w.f.floorPlan.seats.length > 1,
  ),
  WorkspaceFeature.workingHours: _toggle('the day runs 9 to 18'),
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
  WorkspaceFeature.planMemberPhotos: _toggle('the plan shows who sits where'),
  WorkspaceFeature.uniqueMonograms: _state(
    _member,
    'every avatar has its '
    'own letters',
    (w) => w.f.workspaces.memberNames.length > 1,
  ),
  WorkspaceFeature.singleRoomLevelNames: _toggle(
    'a one-room level reads as '
    'the room',
  ),
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
  WorkspaceFeature.bookingPolicies: _toggle('booking rules apply'),
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
  WorkspaceFeature.calendarViews: _toggle('agenda, week and month'),
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
  WorkspaceFeature.captureProtection: _toggle('a message may forbid copies'),
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
  WorkspaceFeature.onlinePayments: _action(
    _member,
    'Bruno pays his bill '
    'online (the provider is simulated)',
    (w) => _open(w, 'member-2'),
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
  WorkspaceFeature.viesVerification: _action(
    _owner,
    "Ada checks a "
    "supplier's EU VAT number",
    (w) =>
        w.purchasing.suppliers.suppliers.any((s) => s.taxIdentifier.isNotEmpty),
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
  WorkspaceFeature.salesTax: _toggle('sales tax where a country has one'),
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
  WorkspaceFeature.invoicePdfTemplate: _toggle('the bill layout'),
  WorkspaceFeature.invoiceAddressWindow: _toggle('the envelope window'),
  WorkspaceFeature.letterStandard: _toggle('the letter standard'),
  WorkspaceFeature.reportDesignExchange: _toggle('layouts in and out'),
  WorkspaceFeature.reportLayouts: _toggle('positioned layouts'),
  WorkspaceFeature.reportTexts: _toggle('the texts of a report'),
  WorkspaceFeature.reportDesigner: _toggle('the report designer'),
  WorkspaceFeature.biReportDesigner: _state(
    _owner,
    'two saved analyses',
    (w) async => (await w.f.biViews.list('ws-1')).length >= 2,
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
  WorkspaceFeature.dataExport: _toggle('the whole space as a workbook'),
  WorkspaceFeature.dataReport: _toggle('the whole space as a printed report'),
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
  WorkspaceFeature.configurationTransfer: _toggle('settings in and out'),
  WorkspaceFeature.configurableSettings: _toggle('the settings catalogue'),
  WorkspaceFeature.workspaceLibrary: _state(
    _owner,
    'templates to start '
    'from',
    (w) async => (await w.f.workspaces.fetchWorkspaceTemplates()).isNotEmpty,
  ),
  WorkspaceFeature.instanceWizard: _toggle('the instance wizard'),
  // #2869 — the guide's demo setup states come with #2872.
  WorkspaceFeature.setupGuide: _toggle('the setup guide'),
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
  WorkspaceFeature.formHelpHints: _toggle('help beside every form'),
  WorkspaceFeature.memberGettingStarted: _toggle('the getting-started card'),
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
  WorkspaceFeature.uiAnimations: _toggle('motion'),
  WorkspaceFeature.regionalFormats: _toggle(
    "dates and amounts in France's "
    'formats',
  ),
  WorkspaceFeature.navigationStyle: _toggle('tabs or a menu'),
  WorkspaceFeature.memberAccountMenu: _toggle(
    'a member sees "Account" '
    'instead of Settings',
  ),
  WorkspaceFeature.demoMode: _toggle('this demonstration'),
  // ── integrations ─────────────────────────────────────────────────────
  WorkspaceFeature.pushNotifications: _toggle('push, inert in the demo'),
  WorkspaceFeature.whatsappIntegration: _action(
    _owner,
    "Ada links the "
    "space's group",
    (w) => w.f.workspaces.memberNames.isNotEmpty,
  ),
  WorkspaceFeature.einvoiceCustomerDelivery: _action(
    _owner,
    'a bill sent '
    'as an e-invoice (the gateway is simulated)',
    (w) => w.f.money.invoices.isNotEmpty,
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
      _scenarios.keys.where(demoFeaturesLeftOff.containsKey),
      isEmpty,
      reason: 'a feature left off has no scenario to show',
    );
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

  group('the state each scenario starts from', () {
    for (final entry in _scenarios.entries) {
      final s = entry.value;
      if (s.kind == _Kind.toggle) continue;
      test('${entry.key.name} — ${s.persona.name}: ${s.story}', () async {
        expect(await s.check(world), isTrue);
      });
    }
  });
}
