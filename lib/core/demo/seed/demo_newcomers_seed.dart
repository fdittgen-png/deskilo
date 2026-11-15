// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3674 — the two customers of the reference business who joined last
// month, so "Invoice the month" has a month to invoice:
//  * Studio Nord, a business customer the owner manages, with no postal
//    address on file: its invoice needs a fix, and adding the address on
//    its member page clears it;
//  * Farid Haddad, who prepaid a pack of meeting-room half days and paid
//    it, then released it: the pack is credited back, so his month derives
//    negative and its invoice is a credit note the business pays out.
// Neither has an earlier month, a payment of the month, a reminder or a
// receivable until the month is invoiced.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import '../../../features/money/domain/ledger_entry.dart';
import '../../../features/money/domain/statement.dart';
import '../../../features/profile/domain/personal_info.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../../../features/workspace/domain/member.dart';
import '../data/money_repository.dart';
import '../data/reservation_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_clock.dart';
import 'demo_space_seed.dart';

/// The business customer whose invoice needs a fix.
@visibleForTesting
const demoStudioNord = 'member-6';

/// The newcomer whose month is a credit note.
@visibleForTesting
const demoFaridHaddad = 'member-7';

/// What Farid's pack cost, paid and then credited back when he released it.
@visibleForTesting
const demoReleasedPackCents = 12000;

/// What each of Studio Nord's two meeting-room half days cost.
const _roomHalfDayCents = 4500;

String _period(DateTime d) => yearMonth(d.year, d.month);

/// The two newcomers: their memberships, their month's bookings and what
/// they were charged and paid. Seeded after the history, which has no month
/// of theirs.
void seedDemoNewcomers(
  FakeWorkspaceRepository workspaces,
  FakeMoneyRepository money,
  FakeReservationRepository reservations,
  DateTime now,
) {
  _people(workspaces, now);
  _bookings(reservations, now);
  _money(money, workspaces, now);
}

void _people(FakeWorkspaceRepository workspaces, DateTime now) {
  final joined = DateTime(now.year, now.month - 1, 2);
  const nord = PersonalInfo(company: 'Studio Nord');
  workspaces.otherMembers.addAll([
    Member(
      id: demoStudioNord,
      workspaceId: 'ws-1',
      userId: '',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
      subscriptionPct: 0,
      customerCapacity: 'business',
      joinedAt: joined,
      managedIdentity: nord,
      managedName: 'Studio Nord',
    ),
    Member(
      id: demoFaridHaddad,
      workspaceId: 'ws-1',
      userId: 'user-7',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
      subscriptionPct: 0,
      joinedAt: joined,
    ),
  ]);
  workspaces.managedIdentities[demoStudioNord] = nord;
  workspaces.memberNames
    ..[demoStudioNord] = 'Studio Nord'
    ..[demoFaridHaddad] = 'Farid Haddad';
  workspaces.memberEmails[demoFaridHaddad] = 'farid.haddad@example.test';
}

/// Studio Nord's two meeting-room half days, and the one Farid booked with
/// his pack and released.
void _bookings(FakeReservationRepository reservations, DateTime now) {
  Reservation room(String id, String member, int day, int from, int to) {
    final start = demoAt(now.year, now.month - 1, day, from);
    return Reservation(
      id: id,
      workspaceId: 'ws-1',
      officeId: DemoSpace.meetingRoom,
      memberId: member,
      startsAt: start,
      endsAt: demoAt(now.year, now.month - 1, day, to),
      status: id == 'demo-farid-released'
          ? ReservationStatus.cancelled
          : ReservationStatus.completed,
      checkedInAt: id == 'demo-farid-released' ? null : start,
    );
  }

  reservations.reservations.addAll([
    room('demo-nord-room-1', demoStudioNord, 9, 9, 13),
    room('demo-nord-room-2', demoStudioNord, 23, 14, 18),
    room('demo-farid-released', demoFaridHaddad, 17, 9, 13),
  ]);
}

/// The newcomers' month: their own statement (no subscription), what they
/// were charged and paid, and what stops an invoice: the customer's own
/// details.
void _money(
  FakeMoneyRepository money,
  FakeWorkspaceRepository workspaces,
  DateTime now,
) {
  final month = DateTime(now.year, now.month - 1);
  final period = _period(month);
  for (final id in [demoStudioNord, demoFaridHaddad]) {
    money.invoiceQueries.buyers.months['$id|$period'] = Statement(
      period: period,
      subscriptionPct: 0,
      feeCents: 0,
      includedHalfDays: 0,
      openDays: 0,
      usedHalfDays: 0,
      extraHalfDays: 0,
      overageCents: 0,
      creditsCents: 0,
      balanceCents: 0,
    );
  }
  LedgerEntry entry(
    String id,
    String member,
    LedgerKind kind,
    LedgerCategory category,
    int cents,
    String what,
    int day,
  ) {
    final on = DateTime(month.year, month.month, day);
    return LedgerEntry(
      id: id,
      memberId: member,
      kind: kind,
      category: category,
      amountCents: cents,
      description: what,
      period: period,
      createdAt: on,
      occurredOn: on,
    );
  }

  money.ledger.addAll([
    for (final (i, day) in [(1, 9), (2, 23)])
      entry(
        'demo-nord-room-$i',
        demoStudioNord,
        LedgerKind.charge,
        LedgerCategory.service,
        _roomHalfDayCents,
        'Meeting room, half day',
        day,
      ),
    entry(
      'demo-farid-pack',
      demoFaridHaddad,
      LedgerKind.charge,
      LedgerCategory.package,
      demoReleasedPackCents,
      'Meeting room pack',
      3,
    ),
    entry(
      'demo-farid-pack-paid',
      demoFaridHaddad,
      LedgerKind.credit,
      LedgerCategory.payment,
      demoReleasedPackCents,
      'Card payment',
      3,
    ),
    entry(
      'demo-farid-pack-released',
      demoFaridHaddad,
      LedgerKind.credit,
      LedgerCategory.adjustment,
      demoReleasedPackCents,
      'Pack released, credited back',
      17,
    ),
  ]);
  // The buyer each issued invoice names: the member's name and, for a
  // customer the business manages, the address on its identity.
  money.invoiceQueries.buyers
    ..of = (memberId) {
      final m = _memberIn(workspaces, memberId);
      final who = m != null && m.isManaged ? m.managedIdentity : null;
      final address = who == null
          ? ''
          : [
              who.street.trim(),
              '${who.postalCode.trim()} ${who.city.trim()}'.trim(),
            ].where((p) => p.isNotEmpty).join(', ');
      return (name: workspaces.memberNames[memberId] ?? '', address: address);
    }
    // As the server reads the buyer (invoice essentials): a business customer
    // needs a postal address.
    ..missing = (memberId) {
      final m = _memberIn(workspaces, memberId);
      if (m == null || m.customerCapacity != 'business') return const [];
      final who = m.isManaged ? m.managedIdentity : PersonalInfo.empty;
      final noAddress = who.street.trim().isEmpty && who.city.trim().isEmpty;
      return noAddress ? const ['buyer_address'] : const [];
    };
}

Member? _memberIn(FakeWorkspaceRepository workspaces, String memberId) => [
  workspaces.myMember,
  ...workspaces.otherMembers,
].where((m) => m.id == memberId).firstOrNull;
