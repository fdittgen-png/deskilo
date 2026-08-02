// SPDX-License-Identifier: 0BSD
import '../../../core/files/xlsx.dart';
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
  final levelName = {for (final l in levels) l.id: l.name};
  final memberName = {
    for (final m in members)
      m.id: profilesByUserId[m.userId]?.displayName ?? m.id,
  };

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

  double major(int cents) => cents / 100;

  final attended =
      reservations.where((r) => r.checkedInAt != null).toList();

  return [
    XlsxSheet(name: 'Workspace', rows: [
      [
        'id', 'name', 'country', 'currency', 'timezone', 'workspace_code',
        'vat_regime', 'vat_id', 'legal_id', 'street', 'postal_code',
        'city', 'enabled_features',
      ],
      [
        workspace.id, workspace.name, workspace.countryCode,
        workspace.currencyCode, workspace.timezone, workspace.inviteCode,
        workspace.vatRegime, workspace.vatId, workspace.legalId,
        workspace.street, workspace.postalCode, workspace.city,
        (enabledFeatures.toList()..sort()).join(', '),
      ],
    ]),
    XlsxSheet(name: 'Levels', rows: [
      ['id', 'name', 'sort_order'],
      for (final l in levels) [l.id, l.name, l.sortOrder],
    ]),
    XlsxSheet(name: 'Desks', rows: [
      ['id', 'level', 'office', 'name', 'x', 'y', 'width', 'height'],
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
          ],
    ]),
    XlsxSheet(name: 'Seats', rows: [
      [
        'id', 'level', 'desk', 'name', 'x', 'y', 'orientation', 'chair',
        'amenities', 'blocked_from', 'blocked_to',
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
            s.amenities.join(', '), s.blockedFrom, s.blockedTo,
          ],
    ]),
    XlsxSheet(name: 'Users', rows: [
      [
        'member_id', 'name', 'status', 'owner', 'admin', 'kiosk',
        'subscription_pct', 'overage_policy', 'country', 'vat_id',
        'address', 'whatsapp', 'last_seen',
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
          profilesByUserId[m.userId]?.lastSeenAt,
        ],
    ]),
    XlsxSheet(name: 'Reservations', rows: [
      [
        'id', 'member', 'space', 'starts_at', 'ends_at', 'status',
        'series_id', 'series_pattern', 'checked_in_at', 'checked_out_at',
      ],
      for (final r in reservations)
        [
          r.id, memberName[r.memberId], spaceOf(r), r.startsAt, r.endsAt,
          r.status.name, r.seriesId, r.seriesPattern, r.checkedInAt,
          r.checkedOutAt,
        ],
    ]),
    XlsxSheet(name: 'Check-ins', rows: [
      [
        'reservation_id', 'member', 'space', 'checked_in_at',
        'checked_out_at', 'minutes_present',
      ],
      for (final r in attended)
        [
          r.id, memberName[r.memberId], spaceOf(r), r.checkedInAt,
          r.checkedOutAt,
          r.checkedOutAt?.difference(r.checkedInAt!).inMinutes,
        ],
    ]),
    // Confirmed / unconfirmed / online in ONE tab, told apart by `state`
    // — the reconciliation view the request asked for is a filter away.
    XlsxSheet(name: 'Payments', rows: [
      [
        'state', 'member', 'amount', 'currency', 'period', 'occurred_on',
        'recorded_at', 'description', 'provider', 'order_id',
      ],
      for (final entry in ledger)
        if (entry.kind == LedgerKind.credit &&
            entry.category == LedgerCategory.payment)
          [
            'confirmed', memberName[entry.memberId],
            major(entry.amountCents), workspace.currencyCode, entry.period,
            entry.occurredOn, entry.createdAt, entry.description, null,
            null,
          ],
      for (final event in pendingEvents)
        if (event.type == EventType.payment)
          [
            'pending', memberName[event.subjectMemberId],
            event.payload['amount_cents'] is int
                ? major(event.payload['amount_cents'] as int)
                : null,
            workspace.currencyCode,
            event.payload['period'], null, event.createdAt,
            event.payload['note'], null, null,
          ],
      for (final intent in paymentIntents)
        [
          'online (${intent.status})', memberName[intent.memberId],
          major(intent.amountCents), workspace.currencyCode, intent.period,
          null, intent.createdAt, null, intent.provider, intent.orderId,
        ],
    ]),
    XlsxSheet(name: 'Services', rows: [
      [
        'state', 'member', 'description', 'amount', 'currency', 'period',
        'recorded_at',
      ],
      for (final entry in ledger)
        if (entry.category == LedgerCategory.service)
          [
            'confirmed', memberName[entry.memberId], entry.description,
            major(entry.amountCents), workspace.currencyCode, entry.period,
            entry.createdAt,
          ],
      for (final event in pendingEvents)
        if (event.type == EventType.serviceCharge)
          [
            'pending', memberName[event.subjectMemberId],
            event.payload['name'],
            event.payload['price_cents'] is int
                ? major((event.payload['price_cents'] as int) *
                    (event.payload['quantity'] is int
                        ? event.payload['quantity'] as int
                        : 1))
                : null,
            workspace.currencyCode, event.payload['period'],
            event.createdAt,
          ],
    ]),
    XlsxSheet(name: 'Service catalog', rows: [
      ['id', 'name', 'price', 'currency', 'active'],
      for (final s in services)
        [s.id, s.name, major(s.priceCents), workspace.currencyCode, s.active],
    ]),
    XlsxSheet(name: 'Invoices', rows: [
      [
        'number', 'member', 'period', 'issued_at', 'total', 'currency',
        'voided_at', 'replaces', 'detailed', 'last_sent_at',
      ],
      for (final i in invoices)
        [
          i.number, memberName[i.memberId], i.period, i.issuedAt,
          major(i.totalCents), i.currency, i.voidedAt,
          i.replacesNumber.isEmpty ? null : i.replacesNumber, i.detailed,
          transmissionsByInvoice[i.id],
        ],
    ]),
  ];
}
