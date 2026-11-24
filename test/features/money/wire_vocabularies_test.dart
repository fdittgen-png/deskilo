// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4418 -- each swept wire vocabulary decodes a value from the future to its
// named unknown, and the screen says the neutral wording for it.
import 'package:deskilo/features/money/application/issue_month_readiness.dart';
import 'package:deskilo/features/money/domain/account_activity.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/invoice_missing.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/presentation/invoice_status.dart';
import 'package:deskilo/features/money/presentation/report_kind_labels.dart';
import 'package:deskilo/features/money/presentation/widgets/finance_claim_state.dart';
import 'package:deskilo/features/money/presentation/widgets/host_activity.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_missing_sales_tax.dart';
import 'package:deskilo/features/money/presentation/widgets/online_payment_status_card.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_clock.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Invoice _invoice() => Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-1',
  issuedAt: kTestNow,
  title: '2026-07',
  lines: const [],
  totalCents: 25000,
  currency: 'EUR',
  memberName: 'Flo',
  memberAddress: '',
  workspaceName: 'Test Space',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 'sig',
);

void main() {
  group('bank-match resolution', () {
    test('every known name reads back; a value from the future is unknown', () {
      for (final r in MatchResolution.sendable) {
        expect(MatchResolution.fromWire(r.wire), r);
      }
      expect(MatchResolution.fromWire('over_split_future'), MatchResolution.unknown);
      expect(MatchResolution.fromWire(null), MatchResolution.unknown);
      expect(MatchResolution.sendable, isNot(contains(MatchResolution.unknown)));
    });

    test('a match of an unknown resolution reads as a standing match, never '
        'as partly paid or refunded', () {
      final match = InvoiceMatch(
        invoiceId: 'inv-1',
        paidCents: 25000,
        resolution: 'over_split_future',
        matchedAt: kTestNow,
      );
      expect(match.settles, MatchResolution.unknown);
      final lifecycle = invoiceLifecycleOf(_invoice(), match);
      expect(lifecycle, InvoiceLifecycle.paid);
      expect(invoiceLifecycleLabel(_en, lifecycle), _en.invoiceMatchedBadge);
    });
  });

  group('account activity status', () {
    test('every known name reads back; a value from the future is unknown '
        'and the row says no status word', () {
      for (final s in ActivityStatus.values) {
        if (s == ActivityStatus.unknown) continue;
        expect(ActivityStatus.fromWire(s.wire), s);
        expect(activityStatusText(_en, s), isNotEmpty);
      }
      final row = AccountActivity.fromJson({
        'id': 'a-1',
        'workspace_id': 'ws-1',
        'workspace_name': 'Test Space',
        'occurred_at': kTestNow.toIso8601String(),
        'currency': 'EUR',
        'status': 'escrowed_future',
      });
      expect(row.state, ActivityStatus.unknown);
      expect(activityStatusText(_en, row.state), isEmpty);
    });

    test('the account screen and a provider row say the same words', () {
      expect(activityStatusText(_en, ActivityStatus.issued), _en.accountInvoiceIssued);
      expect(activityStatusText(_en, ActivityStatus.awaitingMatch), _en.accountPaymentAwaitingMatch);
    });
  });

  group('online payment attempt status', () {
    PaymentIntent attempt(String id, String status) => PaymentIntent(
      id: id,
      memberId: 'member-1',
      provider: 'stripe',
      orderId: 'cs_test_$id',
      reference: 'PAY-2026-$id',
      period: kTestPeriod,
      amountCents: 1600,
      status: status,
      createdAt: kTestNow,
    );

    test('every known name reads back; a value from the future is unknown, '
        'awaits no review and is not listed as pending or failed', () {
      for (final s in PaymentIntentStatus.values) {
        if (s == PaymentIntentStatus.unknown) continue;
        expect(PaymentIntentStatus.fromWire(s.wire), s);
      }
      final future = attempt('9', 'disputed_future');
      expect(future.state, PaymentIntentStatus.unknown);
      expect(future.awaitsReview, isFalse);
      expect(
        OnlinePaymentStatusCard.shown([future, attempt('1', 'created')], kTestPeriod)
            .map((i) => i.id),
        ['1'],
      );
    });
  });

  group('payment claim state', () {
    test('every known name reads back; a value from the future is unknown '
        'and no word is said about it', () {
      for (final s in PaymentClaimState.values) {
        if (s == PaymentClaimState.unknown) continue;
        expect(PaymentClaimState.fromWire(s.wire), s);
      }
      expect(PaymentClaimState.fromWire('paused_future'), PaymentClaimState.unknown);
      expect(claimEndedText(_en, PaymentClaimState.unknown), isNull);
      expect(claimEndedText(_en, null), isNull);
      expect(claimEndedText(_en, PaymentClaimState.expired), _en.financesPaymentExpired);
    });
  });

  group('report document', () {
    test('every registered kind is a known document, each document but the '
        'reminder and unknown is registered once', () {
      final kinds = reportKinds(reminderLevels: 2);
      for (final kind in kinds) {
        expect(kind.document, isNot(ReportDocument.unknown), reason: kind.id);
      }
      expect(kinds.where((k) => k.isReminder).map((k) => k.document).toSet(),
          {ReportDocument.reminder});
      for (final d in ReportDocument.values) {
        if (d == ReportDocument.reminder || d == ReportDocument.unknown) continue;
        expect(kinds.where((k) => k.id == d.id), hasLength(1), reason: d.name);
      }
    });

    test('an id from the future is unknown and the editor names it by its id',
        () {
      const kind = ReportKind(id: 'delivery_note', slot: ReportDocSlot('delivery_note'));
      expect(kind.document, ReportDocument.unknown);
      expect(reportKindLabel(_en, kind), 'delivery_note');
    });
  });

  group('missing invoice essential', () {
    test('every known key reads back with its own words; a key from the '
        'future is unknown, shown as itself and kept on its side', () {
      for (final m in InvoiceMissing.values) {
        if (m == InvoiceMissing.unknown) continue;
        expect(InvoiceMissing.fromWire(m.wire), m);
        expect(invoiceMissingLabel(_en, m.wire), isNot(m.wire), reason: m.wire);
      }
      expect(InvoiceMissing.fromWire('seller_eori_future'), InvoiceMissing.unknown);
      expect(invoiceMissingLabel(_en, 'seller_eori_future'), 'seller_eori_future');
      expect(isBusinessEssential('seller_eori_future'), isTrue);
      expect(isBusinessEssential('buyer_eori_future'), isFalse);
      expect(isBusinessEssential(InvoiceMissing.exemptionReason.wire), isTrue);
    });
  });
}
