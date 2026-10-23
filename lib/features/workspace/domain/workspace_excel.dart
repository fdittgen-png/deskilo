// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import '../../../core/files/xlsx.dart';
import '../../../core/i18n/currencies.dart';
import '../../../core/time/workspace_time.dart';
import '../../events/domain/workspace_event.dart';
import '../../money/domain/invoice.dart';
import '../../money/domain/ledger_entry.dart';
import '../../money/domain/payment_intent.dart';
import '../../money/domain/service_item.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/level.dart';
import '../../profile/domain/profile.dart';
import '../../reservations/domain/reservation.dart';
import 'member.dart';
import 'workspace.dart';
import 'workspace_overview_sheets.dart';

/// The data export's workbook (#395): one tab per dataset, one row per
/// record, every stored detail a client may read.
///
/// Tab and column names are STABLE ENGLISH IDENTIFIERS on purpose — the
/// XML floor-plan export's decision, not the bill PDF's: this file is a
/// bookkeeping/interchange document whose headers get referenced by
/// formulas, pivots and importers, and a header that renames itself when
/// the owner's phone changes language breaks every one of them. The
/// surrounding UI (tile, snackbar) is localized like everything else.
///
/// Money lands as MAJOR units (a `cents / 100` double) so Excel can sum
/// a column without every consumer re-deriving the currency's scale.
List<XlsxSheet> buildWorkspaceExcelExport({
  required Workspace workspace,
  required Set<String> enabledFeatures,
  required List<Level> levels,
  required Map<String, FloorPlan> plansByLevel,
  required List<Member> members,
  required Map<String, Profile> profilesByUserId,
  required List<Reservation> reservations,
  required List<LedgerEntry> ledger,
  required List<WorkspaceEvent> pendingEvents,
  required List<PaymentIntent> paymentIntents,
  required List<ServiceItem> services,
  required List<Invoice> invoices,
  required Map<String, DateTime> transmissionsByInvoice,
}) {
  return _ExcelExport(
    workspace: workspace,
    enabledFeatures: enabledFeatures,
    levels: levels,
    plansByLevel: plansByLevel,
    members: members,
    profilesByUserId: profilesByUserId,
    reservations: reservations,
    ledger: ledger,
    pendingEvents: pendingEvents,
    paymentIntents: paymentIntents,
    services: services,
    invoices: invoices,
    transmissionsByInvoice: transmissionsByInvoice,
  ).sheets();
}

/// Member id → the name every sheet prints: the account's display name,
/// else the id (#395).
Map<String, String> workspaceMemberNames(
  List<Member> members,
  Map<String, Profile> profilesByUserId,
) => {
  for (final m in members)
    m.id: profilesByUserId[m.userId]?.displayName ?? m.id,
};

/// The context every sheet reads: the workspace, its name lookups and
/// the currency scale. One method per sheet keeps each tab a unit.
class _ExcelExport {
  _ExcelExport({
    required this.workspace,
    required this.enabledFeatures,
    required this.levels,
    required this.plansByLevel,
    required this.members,
    required this.profilesByUserId,
    required this.reservations,
    required this.ledger,
    required this.pendingEvents,
    required this.paymentIntents,
    required this.services,
    required this.invoices,
    required this.transmissionsByInvoice,
  })  : levelName = {for (final l in levels) l.id: l.name},
        memberName = workspaceMemberNames(members, profilesByUserId),
        attended = reservations.where((r) => r.checkedInAt != null).toList();

  final Workspace workspace;
  final Set<String> enabledFeatures;
  final List<Level> levels;
  final Map<String, FloorPlan> plansByLevel;
  final List<Member> members;
  final Map<String, Profile> profilesByUserId;
  final List<Reservation> reservations;
  final List<LedgerEntry> ledger;
  final List<WorkspaceEvent> pendingEvents;
  final List<PaymentIntent> paymentIntents;
  final List<ServiceItem> services;
  final List<Invoice> invoices;
  final Map<String, DateTime> transmissionsByInvoice;
  final Map<String, String> levelName;
  final Map<String, String> memberName;
  final List<Reservation> attended;

  String? spaceOf(Reservation r) {
    for (final plan in plansByLevel.values) {
      for (final seat in plan.seats) {
        if (seat.id == r.seatId) return seat.name;
      }
      for (final desk in plan.desks) {
        if (desk.id == r.deskId) return desk.name;
      }
      for (final office in plan.offices) {
        if (office.id == r.officeId) return office.name;
      }
    }
    return r.levelId == null ? null : levelName[r.levelId];
  }

  // #1140 — the workspace currency's minor digits, never a literal 100.
  XlsxAmount major(int cents) => XlsxAmount(
      cents / Currencies.minorPerMajor(workspace.currencyCode));

  List<XlsxSheet> sheets() => [
        ...workspaceOverviewSheets(workspace, enabledFeatures),
        _levels(),
        _desks(),
        _seats(),
        _users(),
        _reservations(),
        _checkins(),
        _payments(),
        _services(),
        _servicecatalog(),
        _invoices(),
      ];

  XlsxSheet _levels() =>
      XlsxSheet(name: 'Levels', rows: [
    ['id', 'name', 'sort_order', 'bookable_as_whole', 'price'],
    for (final l in levels)
      [l.id, l.name, l.sortOrder, l.bookableAsWhole, major(l.priceCents)],
  ]);

  XlsxSheet _desks() =>
      XlsxSheet(name: 'Desks', rows: [
    [
      'id', 'level', 'office', 'name', 'x', 'y', 'width', 'height',
      'bookable_as_whole', 'price',
    ],
    for (final entry in plansByLevel.entries)
      for (final d in entry.value.desks)
        [
          d.id,
          levelName[entry.key],
          entry.value.offices
              .where((o) => o.id == d.officeId)
              .map((o) => o.name)
              .firstOrNull,
          d.name,
          d.rect.x, d.rect.y, d.rect.w, d.rect.h,
          d.bookableAsWhole, major(d.priceCents),
        ],
  ]);

  XlsxSheet _seats() =>
      XlsxSheet(name: 'Seats', rows: [
    [
      'id', 'level', 'desk', 'name', 'x', 'y', 'orientation', 'chair',
      'amenities', 'blocked_from', 'blocked_to', 'resource_kind',
      'capacity', 'parking_kind', 'slot_minutes',
    ],
    for (final entry in plansByLevel.entries)
      for (final s in entry.value.seats)
        [
          s.id,
          levelName[entry.key],
          entry.value.desks
              .where((d) => d.id == s.deskId)
              .map((d) => d.name)
              .firstOrNull,
          s.name, s.x, s.y, s.orientation.name, s.chair,
          s.amenities.join(', '), _at(s.blockedFrom), _at(s.blockedTo),
          s.resourceKind.name, s.capacity, s.parkingKind?.name,
          s.slotMinutes,
        ],
  ]);

  XlsxSheet _users() =>
      XlsxSheet(name: 'Users', rows: [
    [
      'member_id', 'name', 'status', 'owner', 'admin', 'kiosk',
      'subscription_pct', 'overage_policy', 'country', 'vat_id',
      'address', 'whatsapp', 'last_seen', 'member_number', 'joined_at',
      'co_owner', 'vat_treatment', 'payment_terms', 'first_name',
      'last_name', 'company', 'street', 'postal_code', 'city', 'email',
      'phone', 'legal_id',
    ],
    for (final m in members)
      [
        m.id,
        memberName[m.id],
        m.status.name,
        m.isOwner, m.isAdmin, m.isKiosk,
        m.subscriptionPct,
        m.overagePolicy.name,
        profilesByUserId[m.userId]?.countryCode,
        profilesByUserId[m.userId]?.vatId,
        profilesByUserId[m.userId]?.address,
        profilesByUserId[m.userId]?.whatsapp,
        _at(profilesByUserId[m.userId]?.lastSeenAt),
        if (m.memberNumber.isEmpty) null else m.memberNumber,
        _at(m.joinedAt),
        m.coOwner.name,
        m.vatTreatment,
        m.paymentTerms?.paymentTerms,
        ..._identityCells(m),
      ],
  ]);

  XlsxSheet _reservations() =>
      XlsxSheet(name: 'Reservations', rows: [
    [
      'id', 'member', 'space', 'starts_at', 'ends_at', 'status',
      'series_id', 'series_pattern', 'checked_in_at', 'checked_out_at',
    ],
    for (final r in reservations)
      [
        r.id, memberName[r.memberId], spaceOf(r), _at(r.startsAt),
        _at(r.endsAt), r.status.name, r.seriesId, r.seriesPattern,
        _at(r.checkedInAt), _at(r.checkedOutAt),
      ],
  ]);

  XlsxSheet _checkins() =>
      XlsxSheet(name: 'Check-ins', rows: [
    [
      'reservation_id', 'member', 'space', 'checked_in_at',
      'checked_out_at', 'minutes_present',
    ],
    for (final r in attended)
      [
        r.id, memberName[r.memberId], spaceOf(r), _at(r.checkedInAt),
        _at(r.checkedOutAt),
        r.checkedOutAt?.difference(r.checkedInAt!).inMinutes,
      ],
  ]);

  // Confirmed / unconfirmed / online in ONE tab, told apart by `state`
  // — the reconciliation view the request asked for is a filter away.
  XlsxSheet _payments() =>
      XlsxSheet(name: 'Payments', totals: 'total', rows: [
    [
      'state', 'member', 'amount', 'currency', 'period', 'occurred_on',
      'recorded_at', 'description', 'provider', 'order_id',
    ],
    for (final entry in ledger)
      if (isExportedPayment(entry))
        [
          'confirmed', memberName[entry.memberId],
          major(entry.amountCents), workspace.currencyCode, entry.period,
          _day(entry.occurredOn), _at(entry.createdAt), entry.description, null,
          null,
        ],
    for (final event in pendingEvents)
      if (event.type == EventType.payment)
        [
          'pending', memberName[event.subjectMemberId],
          if (event.payload['amount_cents'] is int) major(event.payload['amount_cents'] as int) else null,
          workspace.currencyCode,
          event.payload['period'], null, _at(event.createdAt),
          event.payload['note'], null, null,
        ],
    for (final intent in paymentIntents)
      [
        'online (${intent.status})', memberName[intent.memberId],
        major(intent.amountCents), workspace.currencyCode, intent.period,
        null, _at(intent.createdAt), null, intent.provider, intent.orderId,
      ],
  ]);

  XlsxSheet _services() =>
      XlsxSheet(name: 'Services', totals: 'total', rows: [
    [
      'state', 'member', 'description', 'amount', 'currency', 'period',
      'recorded_at',
    ],
    for (final entry in ledger)
      if (entry.category == LedgerCategory.service)
        [
          'confirmed', memberName[entry.memberId], entry.description,
          major(entry.amountCents), workspace.currencyCode, entry.period,
          _at(entry.createdAt),
        ],
    for (final event in pendingEvents)
      if (event.type == EventType.serviceCharge)
        [
          'pending', memberName[event.subjectMemberId],
          event.payload['name'],
          if (event.payload['price_cents'] is int) major((event.payload['price_cents'] as int) *
                  (event.payload['quantity'] is int
                      ? event.payload['quantity'] as int
                      : 1)) else null,
          workspace.currencyCode, event.payload['period'],
          _at(event.createdAt),
        ],
  ]);

  XlsxSheet _servicecatalog() =>
      XlsxSheet(name: 'Service catalog', rows: [
    ['id', 'name', 'price', 'currency', 'active'],
    for (final s in services)
      [s.id, s.name, major(s.priceCents), workspace.currencyCode, s.active],
  ]);

  XlsxSheet _invoices() =>
      XlsxSheet(name: 'Invoices', totals: 'total', rows: [
    [
      'number', 'member', 'period', 'issued_at', 'total', 'currency',
      'voided_at', 'replaces', 'detailed', 'last_sent_at', 'kind', 'title',
      'net', 'vat', 'vat_by_rate', 'due_on', 'issued_by',
    ],
    for (final i in invoices)
      [
        i.number, memberName[i.memberId], i.period, _at(i.issuedAt),
        major(i.totalCents), i.currency, _at(i.voidedAt),
        if (i.replacesNumber.isEmpty) null else i.replacesNumber, i.detailed,
        _at(transmissionsByInvoice[i.id]),
        i.kind.name, i.title, major(i.netCents), major(i.vatCents),
        [
          for (final t in i.vatTotals)
            '${t.percent}%: ${major(t.vatCents).value.toStringAsFixed(2)}',
        ].join('; '),
        _day(i.dueOn), i.issuerName,
      ],
  ]);

  /// The member's structured identity cells: a managed profile's own, else
  /// the account's (#1310).
  List<Object?> _identityCells(Member m) {
    final p = m.managedName.isNotEmpty
        ? m.managedIdentity
        : profilesByUserId[m.userId]?.identity;
    return [
      for (final v in [
        p?.firstName, p?.lastName, p?.company, p?.street, p?.postalCode,
        p?.city, p?.email, p?.phone, p?.legalId,
      ])
        if (v == null || v.isEmpty) null else v,
    ];
  }
}

/// One decision on an event, as the Decisions tab writes it.
typedef ExportedDecision =
    ({String? memberId, bool accept, bool bySystem, DateTime at});

// #2860 — the sheets the first workbook (#395) left out: every office,
// every ledger row, every event with its decisions, every invoice line.

/// What the detail sheets are built from.
class WorkspaceExportDetails {
  const WorkspaceExportDetails({
    required this.workspace,
    required this.levels,
    required this.plansByLevel,
    required this.memberName,
    required this.ledger,
    required this.events,
    required this.decisions,
    required this.invoices,
    this.members = const [],
    this.reservations = const [],
    this.invoiceMatches = const {},
  });

  final Workspace workspace;
  final List<Level> levels;
  final Map<String, FloorPlan> plansByLevel;

  /// Member id → the name the workbook prints for them.
  final Map<String, String> memberName;
  final List<LedgerEntry> ledger;

  /// Every event of the space, decided or not.
  final List<WorkspaceEvent> events;

  /// Event id → the decisions taken on it (who, accepted, by the timeout
  /// sweep, when).
  final Map<String, List<ExportedDecision>> decisions;
  final List<Invoice> invoices;

  /// The rows the data report reads beside the detail sheets' (#2862).
  final List<Member> members;
  final List<Reservation> reservations;
  final Map<String, InvoiceMatch> invoiceMatches;
}

/// A confirmed member payment: a row of the Payments sheet.
bool isExportedPayment(LedgerEntry e) =>
    e.kind == LedgerKind.credit && e.category == LedgerCategory.payment;

/// What a ledger row does to the member's balance (the Ledger sheet's
/// `signed_amount`): a charge adds, a credit settles.
int exportedSignedCents(LedgerEntry e) =>
    e.kind == LedgerKind.charge ? e.amountCents : -e.amountCents;

/// The detail sheets, in workbook order.
List<XlsxSheet> buildWorkspaceExcelDetailSheets(WorkspaceExportDetails d) {
  XlsxAmount major(int cents) => XlsxAmount(
      cents / Currencies.minorPerMajor(d.workspace.currencyCode));
  String? name(String? memberId) =>
      memberId == null ? null : d.memberName[memberId] ?? memberId;
  final levelName = {for (final l in d.levels) l.id: l.name};

  return [
    XlsxSheet(name: 'Offices', rows: [
      [
        'id', 'level', 'name', 'area_kind', 'x', 'y', 'width', 'height',
        'color', 'bookable_as_whole', 'price', 'currency',
      ],
      for (final entry in d.plansByLevel.entries)
        for (final o in entry.value.offices)
          [
            o.id, levelName[entry.key], o.name, o.areaKind.name,
            o.rect.x, o.rect.y, o.rect.w, o.rect.h,
            '#${(o.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
            o.bookableAsWhole, major(o.priceCents), d.workspace.currencyCode,
          ],
    ]),
    // Every row of the member accounts: a charge is what a member owes, a
    // credit what settles it — the signed amount sums to the balance.
    XlsxSheet(name: 'Ledger', totals: 'total', rows: [
      [
        'id', 'member', 'kind', 'category', 'amount', 'signed_amount',
        'currency', 'period', 'occurred_on', 'recorded_at', 'description',
      ],
      for (final e in d.ledger)
        [
          e.id, name(e.memberId), e.kind.name, e.category.name,
          major(e.amountCents),
          major(exportedSignedCents(e)),
          d.workspace.currencyCode, e.period, _day(e.occurredOn), _at(e.createdAt),
          e.description,
        ],
    ]),
    XlsxSheet(name: 'Events', rows: [
      [
        'id', 'type', 'action', 'status', 'subject', 'actor', 'created_at',
        'decided_at', 'decisions', 'details',
      ],
      for (final e in d.events)
        [
          e.id, e.type.dbName, e.action.name, e.status.name,
          name(e.subjectMemberId), name(e.actorMemberId), _at(e.createdAt),
          _at(e.decidedAt), d.decisions[e.id]?.length ?? 0,
          if (e.payload.isEmpty) null else jsonEncode(e.payload),
        ],
    ]),
    XlsxSheet(name: 'Decisions', rows: [
      ['event_id', 'event_type', 'decided_by', 'decision', 'by_system',
          'decided_at'],
      for (final e in d.events)
        for (final x in d.decisions[e.id] ?? const <ExportedDecision>[])
          [
            e.id, e.type.dbName, name(x.memberId),
            if (x.accept) 'accepted' else 'declined', x.bySystem, _at(x.at),
          ],
    ]),
    XlsxSheet(name: 'Invoice lines', totals: 'total', rows: [
      [
        'invoice', 'line', 'label', 'kind', 'quantity', 'amount',
        'currency', 'vat_percent', 'vat_category', 'source_invoice',
      ],
      for (final i in d.invoices)
        for (final (n, l) in i.lines.indexed)
          [
            i.number, n + 1, l.label, l.kind, l.quantity,
            l.amountCents / Currencies.minorPerMajor(i.currency), i.currency, l.vatPercent, l.vatCategory,
            if (l.sourceNumber.isEmpty) null else l.sourceNumber,
          ],
    ]),
  ];
}

/// #2861 — an instant at the workspace's wall-clock time, so a 09:00
/// booking in Paris reads 09:00 in the sheet.
DateTime? _at(DateTime? instant) =>
    instant == null ? null : WorkspaceTime.wall(instant);

/// #2861 — a calendar day, written without a time.
XlsxDate? _day(DateTime? day) => day == null ? null : XlsxDate(day);
