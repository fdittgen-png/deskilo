// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/domain/invoice.dart';
import '../../../money/domain/ledger_entry.dart';
import '../../../money/presentation/widgets/account_card.dart';
import '../../../money/providers/money_providers.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// WHERE THIS MEMBER STANDS, on their own profile (#704).
///
/// The money was always in the app and never beside the person it was
/// about: an admin looking at Ana's profile — her booking, her check-in,
/// her plan — had to leave for the invoicing hub, find her again in a
/// list of invoices, and hold the answer in their head on the way back.
/// The question "does Ana owe us anything?" is a question about Ana.
///
/// WHAT IT SHOWS, in the order the question is usually asked: the net
/// position first (one number: who owes whom), then the open invoices
/// that make it up, then the payments that have come in, then the month
/// being consumed right now.
///
/// WHO SEES IT. Yourself always — it is your money. Otherwise the
/// `viewFinances` permission, the same one that gates the Money tab for
/// somebody else's figures. The gate here is a COURTESY: `member_account`
/// and `member_statement` both refuse a caller who is neither the member
/// nor an admin of their workspace, and RLS scopes the ledger and the
/// invoices the same way. Nothing here is the boundary; it is the part
/// of the boundary the member can see.
class MemberMoneyCard extends ConsumerWidget {
  const MemberMoneyCard({
    super.key,
    required this.memberId,
    required this.isSelf,
  });

  final String memberId;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final maySee = isSelf ||
        ref.watch(myPermissionsProvider).contains(WorkspacePermission.viewFinances);
    if (!maySee) return const SizedBox.shrink();

    final workspace = ref.watch(currentWorkspaceProvider).value;
    final currencyCode = workspace?.currencyCode ?? 'EUR';
    final currency = NumberFormat.simpleCurrency(name: currencyCode);
    String money(int cents) => currency.format(cents / 100);

    final account = ref.watch(memberAccountProvider(memberId)).value;
    final invoices =
        ref.watch(memberInvoicesProvider(memberId)).value ?? const <Invoice>[];
    final ledger =
        ref.watch(memberLedgerProvider(memberId)).value ?? const <LedgerEntry>[];
    final period = DateFormat('yyyy-MM').format(ref.watch(clockProvider).now());
    final statement =
        ref.watch(memberStatementProvider(memberId, period)).value;

    // Nothing at all to say: no account movement, no document, no
    // payment. A card that renders "0,00 €" three times is noise on a
    // profile whose point is the person.
    if (account == null && invoices.isEmpty && ledger.isEmpty) {
      return const SizedBox.shrink();
    }

    final payments = [
      for (final entry in ledger)
        if (entry.category == LedgerCategory.payment) entry,
    ].take(3).toList();

    // Remaining per open invoice, so a row can say "partly paid" rather
    // than just "open" — the account RPC already computed it.
    final remaining = {
      for (final open in account?.openInvoices ?? const [])
        open.invoiceId: open,
    };

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 2),
          child: Text(
            text.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
        );

    return Column(
      key: const ValueKey('member-money'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(l10n?.tabMoney ?? 'Money'),
        // The one number the question is really about. The shared card,
        // not a second rendering of the same arithmetic — a profile that
        // computed the position itself is a profile that can disagree
        // with the Money tab.
        if (account != null && account.isNotable)
          AccountCard(account: account, currencyCode: currencyCode),
        if (account != null && !account.isNotable)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              l10n?.memberMoneySettled ?? 'Nothing outstanding.',
              key: const ValueKey('member-money-settled'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (invoices.isNotEmpty) ...[
          label(l10n?.invoicesTitle ?? 'Invoices'),
          for (final invoice in invoices.take(5))
            _InvoiceRow(
              invoice: invoice,
              remainingCents: remaining[invoice.id]?.remainingCents,
              money: money,
            ),
          if (invoices.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n?.memberMoreInvoices(invoices.length - 5) ??
                    '+${invoices.length - 5} more',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
        if (payments.isNotEmpty) ...[
          label(l10n?.memberPayments ?? 'Payments'),
          for (final payment in payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(
                  child: Text(
                    payment.description.isEmpty
                        ? DateFormat.yMMMd().format(payment.createdAt.toLocal())
                        : payment.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  money(payment.amountCents.abs()),
                  style: theme.textTheme.bodyMedium,
                ),
              ]),
            ),
        ],
        // The month being consumed right now — what the next invoice
        // will be made of, before it exists.
        if (statement != null) ...[
          label(l10n?.memberMonthInProgress ?? 'This month'),
          Text(
            '${statement.usedHalfDays}/'
            '${statement.includedHalfDays + statement.grantedHalfDays}'
            ' · ${money(statement.balanceCents)}',
            key: const ValueKey('member-money-statement'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// One invoice line: number and date, then what it costs and what is
/// left on it. A voided document says so instead of pretending to be
/// owed.
class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.remainingCents,
    required this.money,
  });

  final Invoice invoice;
  final int? remainingCents;
  final String Function(int cents) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final voided = invoice.voidedAt != null;
    final open = !voided && (remainingCents ?? 0) > 0;
    final status = voided
        ? (l10n?.memberInvoiceVoided ?? 'Voided')
        : open
            ? (l10n?.memberInvoiceOpen(money(remainingCents!)) ??
                '${money(remainingCents!)} open')
            : (l10n?.memberInvoicePaid ?? 'Paid');
    return Padding(
      key: ValueKey('member-invoice-${invoice.id}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invoice.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${DateFormat.yMMMd().format(invoice.issuedAt.toLocal())}'
                ' · $status',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: open
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  decoration: voided ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
        Text(money(invoice.totalCents), style: theme.textTheme.bodyMedium),
      ]),
    );
  }
}
