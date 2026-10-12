// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../events/presentation/widgets/event_validation_trail.dart';
import '../../../workspace/domain/overage_policy.dart';
import '../../../workspace/domain/payment_instructions.dart';
import '../../domain/bill_sections.dart';
import '../../domain/invoice_line_text.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/money_face.dart';
import '../../domain/statement.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import '../report_strings_l10n.dart';
import 'how_to_pay_tiles.dart';

part 'bill_view_part1.dart';
part 'bill_view_part2.dart';


/// The structured monthly bill (#132, ADR 0008): subscription, consumed
/// services, open positions awaiting validation, payments & credits, and
/// the balance footer. Grouping lives in [buildBillSections] so the PDF
/// export renders the exact same sections.
class BillView extends StatelessWidget {
  const BillView({
    super.key,
    required this.statement,
    required this.ledger,
    required this.pendingMoneyEvents,
    required this.currencyCode,
    required this.memberId,
    required this.nowPeriod,
    this.paymentInstructions = const PaymentInstructions(),
    this.onlinePaymentsEnabled = false,
    this.face,
    this.onPayOnline,
    this.settlement,
    // #870 — an association collects a participation.
    this.association = false,
  });


  final Statement statement;
  final List<LedgerEntry> ledger;
  final List<WorkspaceEvent> pendingMoneyEvents;
  final String currencyCode;
  final String memberId;

  /// The running month, read from `clockProvider` by the caller. Open
  /// positions only ever show on the CURRENT period, so letting this
  /// default to the wall clock made the section appear or vanish
  /// depending on the date the test ran.
  final String nowPeriod;

  /// #155 — the workspace's how-to-pay details; rendered below the
  /// balance footer only while the statement is outstanding.
  final PaymentInstructions paymentInstructions;

  /// Whether the workspace enabled online payments (0043 scaffolding). When
  /// true and the statement is outstanding, the how-to-pay card shows a
  /// "Pay online" button that calls [onPayOnline] with the owed amount.
  final bool onlinePaymentsEnabled;

  /// Called with the outstanding amount in cents when the member taps the
  /// online-payment button. Owned by the Money screen (it has the ref to
  /// start the provider order and open the approval URL).
  final void Function(int amountCents)? onPayOnline;

  /// #510 — the invoice covering this month, when one exists. From then
  /// on the DOCUMENT decides whether the month is settled: the payment
  /// that clears it is usually recorded in a later month, so the raw
  /// ledger balance of an invoiced-and-paid month would read
  /// outstanding forever.
  final PeriodSettlement? settlement;

  final bool association;

  /// #720 — render only the cards of one face; null keeps the whole bill
  /// (the flag-off column and the PDF export, which prints everything).
  final MoneyFace? face;


  @override
  Widget build(BuildContext context) {
    final currency = moneyFormat(currencyCode);

    final sections = buildBillSections(
      period: statement.period,
      memberId: memberId,
      ledger: ledger,
      pendingEvents: pendingMoneyEvents,
      nowPeriod: nowPeriod,
    );

    // #720 — the STATEMENT face is the whole bill as it stands; the
    // PAYMENTS face carries the balance and how to settle it. The
    // whole bill (face null) is both, for the classic column and the PDF.
    final showStatement = face == null || face == MoneyFace.statement;
    final showPayments = face == null || face == MoneyFace.payments;
    final balance = _BalanceFooter(statement: statement, settlement: settlement,
        money: currency.formatMinor, prominent: face != null);
    final cards = <Widget>[
      if (face != null && (showStatement || showPayments)) balance,
      if (showStatement) ...[
        // At-a-glance usage for the current month (days included, used and
        // left) — the member's answer to "how much can I still book?".
        _EntitlementCard(statement: statement, money: currency.formatMinor),
        _SubscriptionCard(
            statement: statement,
            money: currency.formatMinor,
            association: association),
        if (sections.serviceEntries.isNotEmpty)
          _ServicesCard(sections: sections, money: currency.formatMinor),
        if (sections.packageEntries.isNotEmpty)
          _PackagesCard(entries: sections.packageEntries, money: currency.formatMinor),
        if (sections.openPositions.isNotEmpty)
          _OpenPositionsCard(positions: sections.openPositions, money: currency.formatMinor),
        if (sections.creditEntries.isNotEmpty)
          _CreditsCard(entries: sections.creditEntries, money: currency.formatMinor),
        if (settlement != null)
          _InvoiceCard(settlement: settlement!, money: currency.formatMinor),
      ],
      if (face == null) balance,
      if (showPayments &&
          // #155 — how to pay, only while something is owed (spec §7:
          // "shown on unpaid statements") and only when the owner configured
          // manual instructions or enabled online payments. An invoiced
          // month owes its invoice REMAINDER, not its ledger balance (#510).
          _owedCents > 0 &&
          (!paymentInstructions.isEmpty ||
              (onlinePaymentsEnabled && onPayOnline != null)))
        HowToPayCard(
          instructions: paymentInstructions,
          onPayOnline: onlinePaymentsEnabled && onPayOnline != null
              ? () => onPayOnline!(_owedCents)
              : null,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          cards[i],
        ],
      ],
    );
  }

  /// What the member still has to pay for this month: the invoice
  /// remainder once a document covers it, the ledger deficit before.
  int get _owedCents => settlement != null
      ? (settlement!.remainingCents > 0 ? settlement!.remainingCents : 0)
      : (statement.isSettled ? 0 : -statement.balanceCents);
}
