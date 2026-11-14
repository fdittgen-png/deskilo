// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 — the guest pass and the e-invoice of the reference business: what a
// visitor does through the Demo's own parts, and the figures that must agree
// afterwards. Shared by the scenario checklist and their tests.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_space_pick.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/domain/guest_pass_invoice.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';

import 'demo_free_seat.dart';

/// What is still to be paid on the invoices of [f]'s reference business.
int receivableOf(DemoFixture f) => f.money.invoices.fold(
  0,
  (t, i) => i.totalCents > 0
      ? t + (i.totalCents - (f.money.invoiceMatchesStore[i.id]?.paidCents ?? 0))
      : t,
);

/// A day pass sold to a guest in the reference business and used: the seat
/// is booked and checked in, the pass invoiced in euros, and the sales, the
/// receivables and the pass's own record agree.
Future<bool> dayPassJourney() async {
  final f = DemoFixture.build();
  final held = f.stores.at(DemoSpaceKey.home).guestPasses
    ..heldBy(
      () => {
        WorkspacePermission.issueInvoices,
        WorkspacePermission.manageServices,
      },
    );
  final passes = held.repository;
  final offers = await passes.offers('ws-1');
  final offer = offers.firstWhere((o) => o.unit == GuestPassUnit.day);
  final today = DateTime(f.seededAt.year, f.seededAt.month, f.seededAt.day);
  final slot = freeSeatForPass(
    f.floorPlan.seats,
    f.reservations.reservations,
    today,
    startMinutes: 10 * 60,
    endMinutes: 17 * 60,
  );
  final owedBefore = receivableOf(f);
  final sale = await passes.sell(
    'ws-1',
    draft: GuestPassDraft(
      offer: offer,
      seatId: slot.seatId,
      day: slot.day,
      startMinutes: 10 * 60,
      endMinutes: 17 * 60,
    ),
    guest: const {'first_name': 'Gwen', 'last_name': 'Guest'},
    requestId: 'scenario-pass-home',
  );
  final booking = f.reservations.reservations.firstWhere(
    (r) => sale.reservationIds.contains(r.id),
  );
  // The guest comes: the seat is checked in.
  await f.reservations.checkIn(booking.id);
  final used = f.reservations.reservations.firstWhere(
    (r) => r.id == booking.id,
  );
  final invoice = f.money.invoices.firstWhere((i) => i.id == sale.invoiceId);
  final record = (await passes.passesSold('ws-1'))
      .firstWhere((p) => p.id == sale.passId);
  return offer.priceCents == sale.amountCents &&
      invoice.currency == 'EUR' &&
      invoice.totalCents == offer.priceCents &&
      used.status == ReservationStatus.checkedIn &&
      used.seatId == slot.seatId &&
      record.invoiceId == invoice.id &&
      passInvoiceOf(record, f.money.invoices).state ==
          PassInvoiceState.notCorrected &&
      receivableOf(f) == owedBefore + offer.priceCents;
}

/// The e-invoice channel of the reference business: configured and generic;
/// one invoice already delivered, one send with its receipt, and the
/// uncertain submission an issuer settles.
Future<bool> eInvoiceJourney() async {
  final f = DemoFixture.build();
  final platform = f.money.eInvoices;
  final gateway = await platform.fetchEInvoiceGateway('ws-1');
  final before = await platform.fetchInvoiceTransmissions('ws-1');
  const target = 'demo-usage-ada-b';
  final unsent = !before.containsKey(target);
  final delivered = before['demo-invoice-ada'];
  final sent = await platform.sendEInvoice(
    workspaceId: 'ws-1',
    invoiceId: target,
    fileName: 'U-2026-04-02.xml',
    mimeType: 'application/xml',
    bytes: const [60, 105, 110, 118, 62],
    format: 'ubl',
  );
  final after = await platform.fetchInvoiceTransmissions('ws-1');
  final transmission = after[target]!;
  await platform.requestEInvoiceReceipt(
    workspaceId: 'ws-1',
    transmissionId: transmission.id,
  );
  final received = (await platform.fetchInvoiceTransmissions('ws-1'))[target]!;
  final uncertain = after['demo-invoice-chiara']!;
  final settled = await platform.resolveEInvoiceTransmission(
    workspaceId: 'ws-1',
    transmissionId: uncertain.id,
    resolution: EInvoiceResolution.accepted,
    reason: 'the platform lists it',
    evidence: 'portal reference',
  );
  return gateway.configured &&
      gateway.provider == 'generic' &&
      unsent &&
      delivered != null &&
      delivered.status == EInvoiceSubmissionStatus.accepted &&
      delivered.receipt['state'] == 'delivered' &&
      sent.status == EInvoiceSubmissionStatus.accepted &&
      transmission.status == EInvoiceSubmissionStatus.accepted &&
      received.receipt['state'] == 'delivered' &&
      uncertain.status == EInvoiceSubmissionStatus.uncertain &&
      settled.resolved &&
      (await platform.fetchInvoiceTransmissions(
            'ws-1',
          ))['demo-invoice-chiara']!.status ==
          EInvoiceSubmissionStatus.accepted;
}
