// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 — one meaning has one colour on every money page: the state of a
// purchase order and of a quote is a status chip whose tone is the one the
// invoices give the same meaning (`statusToneOf`). Nothing to act on is
// neutral, waiting for the other side is information, done is done, a
// refusal is due, and a validity that ran out asks for a look.
import 'package:deskilo/core/ui/kit/status_chip.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoicing_words.dart';
import 'package:deskilo/features/money/presentation/quotes/quote_text.dart';
import 'package:deskilo/features/money/presentation/widgets/purchase_order_record.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

PurchaseOrder _order(String state) => PurchaseOrder.fromJson({
  'id': 'o-1',
  'reference': '2026-0001',
  'supplier_id': 's-1',
  'supplier_name': 'Alpha',
  'state': state,
  'currency': 'EUR',
  'revision': 1,
  'lines': const <Object?>[],
});

CustomerQuote _quote(QuoteStatus status, {bool expired = false}) =>
    CustomerQuote(
      id: 'q-1',
      subjectId: 'c-1',
      reference: 'QUO-0001',
      status: status,
      expired: expired,
      revisions: const [],
      decision: null,
      invoiceId: null,
    );

void main() {
  test('a purchase order says its state on the tone of the invoice that '
      'means the same', () {
    final expected = {
      'draft': (_en.purchasesStateDraft, InvoiceStatusKind.draft),
      'sent': (_en.purchaseOrderStateSent, InvoiceStatusKind.awaitingCustomer),
      'partly_received': (
        _en.purchaseOrderStatePartlyReceived,
        InvoiceStatusKind.awaitingCustomer,
      ),
      'received': (_en.purchaseOrderStateReceived, InvoiceStatusKind.paid),
      'cancelled': (
        _en.purchaseOrderStateCancelled,
        InvoiceStatusKind.cancelled,
      ),
    };
    for (final MapEntry(key: state, value: (label, same)) in expected.entries) {
      final chip = purchaseOrderStateChip(_en, _order(state));
      expect(chip.label, label, reason: state);
      expect(chip.tone, statusToneOf(same), reason: state);
    }
    expect(
      {
        for (final state in expected.keys)
          state: purchaseOrderStateChip(_en, _order(state)).tone,
      },
      {
        'draft': StatusTone.neutral,
        'sent': StatusTone.info,
        'partly_received': StatusTone.info,
        'received': StatusTone.ok,
        'cancelled': StatusTone.neutral,
      },
    );
  });

  test('a state this app does not know keeps its text and claims no '
      'meaning', () {
    final chip = purchaseOrderStateChip(_en, _order('future_locked'));
    expect(chip.label, contains('future_locked'));
    expect(chip.tone, StatusTone.neutral);
  });

  test('a quote says its state on the tone of the invoice that means the '
      'same; a sent quote past its validity asks for a look', () {
    StatusTone tone(QuoteStatus status, {bool expired = false}) =>
        quoteStatusChip(_en, _quote(status, expired: expired)).tone;
    expect(tone(QuoteStatus.draft), statusToneOf(InvoiceStatusKind.draft));
    expect(
      tone(QuoteStatus.sent),
      statusToneOf(InvoiceStatusKind.awaitingCustomer),
    );
    expect(
      tone(QuoteStatus.cancelled),
      statusToneOf(InvoiceStatusKind.cancelled),
    );
    expect(
      tone(QuoteStatus.declined),
      statusToneOf(InvoiceStatusKind.eInvoiceRejected),
    );
    expect(
      {
        for (final status in QuoteStatus.values) status: tone(status),
        'expired': tone(QuoteStatus.sent, expired: true),
      },
      {
        QuoteStatus.draft: StatusTone.neutral,
        QuoteStatus.sent: StatusTone.info,
        QuoteStatus.accepted: StatusTone.ok,
        QuoteStatus.converted: StatusTone.ok,
        QuoteStatus.declined: StatusTone.due,
        QuoteStatus.cancelled: StatusTone.neutral,
        'expired': StatusTone.warn,
      },
    );
    final expired = quoteStatusChip(
      _en,
      _quote(QuoteStatus.sent, expired: true),
    );
    expect(expired.label, _en.quoteStatusExpired);
    // An answered quote is not "expired" because its date passed.
    expect(tone(QuoteStatus.accepted, expired: true), StatusTone.ok);
  });
}
