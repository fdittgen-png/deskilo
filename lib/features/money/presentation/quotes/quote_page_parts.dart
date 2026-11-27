// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 -- the parts of a quote's page, on the invoice page's anatomy: who
// and how much with the state said once (the summary), what is offered (the
// lines), the revisions, and the document the customer holds. A sent
// revision is shown as it was frozen; a draft shows no amount, they are
// worked out when it is sent.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../domain/customer_quote.dart';
import '../engagements/follow_line_button.dart';
import '../quote_print.dart';
import 'quote_decision_sheet.dart';
import 'quote_text.dart';

/// Who the offer is for, how much it comes to once sent, and where it
/// stands: the state is said here and nowhere else on the page.
class QuoteSummaryCard extends StatelessWidget {
  const QuoteSummaryCard({super.key, required this.quote, this.customer});

  final CustomerQuote quote;

  /// The customer's name, once the customers are read.
  final String? customer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final quiet = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final shown = quote.shown;
    return KitCard(
      key: const ValueKey('quote-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          if (customer case final name?)
            Text(
              name,
              key: const ValueKey('quote-customer'),
              style: theme.textTheme.titleSmall,
            ),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (shown?.totals case final totals?)
                Text(
                  quoteAmount(context, totals),
                  key: const ValueKey('quote-total'),
                  style: theme.textTheme.headlineMedium?.emphasised.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              quoteStatusChip(l10n, quote, key: const ValueKey('quote-status')),
            ],
          ),
          if (shown != null) ...[
            Text(
              l10n.quoteValidUntil(quoteDate(context, shown.validUntil)),
              style: quiet,
            ),
            if (shown.buyerReference.isNotEmpty)
              Text(l10n.quoteReferenceLine(shown.buyerReference), style: quiet),
            if (shown.purchaseOrder.isNotEmpty)
              Text(l10n.quoteOrderLine(shown.purchaseOrder), style: quiet),
          ],
          // What the issuer recorded, never a customer's signature.
          if (quote.decision case final decision?)
            Text(
              l10n.quoteDecisionByIssuer(
                quoteSourceLabel(l10n, decision.source),
                quoteDate(context, decision.decidedOn),
              ),
              key: const ValueKey('quote-decision'),
              style: quiet,
            ),
          if (quote.current != null && quote.reference != null)
            Text(
              l10n.quoteSentAs(quote.reference!),
              key: const ValueKey('quote-sent-as'),
              style: quiet,
            ),
        ],
      ),
    );
  }
}

/// What is offered, line by line, and the notes for the customer.
class QuoteLinesCard extends StatelessWidget {
  const QuoteLinesCard({
    super.key,
    required this.quote,
    required this.shown,
    required this.workspaceId,
    required this.canFollow,
  });

  final CustomerQuote quote;
  final QuoteRevision shown;
  final String workspaceId;

  /// Whether an accepted line offers its engagement.
  final bool canFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final quiet = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return KitCard(
      key: const ValueKey('quote-lines'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          KitLabel(l10n.standaloneInvoiceLines),
          for (final (i, line) in shown.lines.indexed)
            Row(
              key: ValueKey('quote-line-$i'),
              spacing: AppSpacing.md,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.description),
                      Text(
                        '${line.quantity} ${line.unitLabel} × ${line.unitPrice}',
                        style: quiet,
                      ),
                    ],
                  ),
                ),
                // An accepted line is followed as an engagement of its own.
                if (canFollow && line.lineId != null)
                  FollowLineButton(
                    workspaceId: workspaceId,
                    quoteId: quote.id,
                    lineId: line.lineId!,
                  ),
              ],
            ),
          if (shown.totals == null)
            Text(
              l10n.quoteAmountsOnSend,
              key: const ValueKey('quote-amounts-on-send'),
              style: quiet,
            ),
          if (shown.notes.isNotEmpty) ...[
            KitLabel(l10n.quoteFieldNotes),
            Text(shown.notes),
          ],
        ],
      ),
    );
  }
}

/// The revisions of a quote that has more than one: a sent one never
/// changes, an amendment is another revision.
class QuoteRevisionsCard extends StatelessWidget {
  const QuoteRevisionsCard({super.key, required this.quote});

  final CustomerQuote quote;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return KitCard(
      key: const ValueKey('quote-revisions'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          KitLabel(l10n.quoteRevisionsTitle),
          for (final r in quote.revisions)
            Text(
              l10n.quoteRevisionLine(
                '${r.revision}',
                r.sent ? l10n.quoteStatusSent : l10n.invoicingStatusDraft,
              ),
              key: ValueKey('quote-revision-${r.revision}'),
            ),
        ],
      ),
    );
  }
}

/// The offer as a document: what the customer holds, to look at, save or
/// share. Drawn only for a quote something was sent of.
class QuoteDocumentCard extends ConsumerWidget {
  const QuoteDocumentCard({
    super.key,
    required this.quote,
    required this.workspaceId,
  });

  final CustomerQuote quote;
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return KitCard(
      key: const ValueKey('quote-document'),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Icon(Icons.description_outlined, color: theme.colorScheme.primary),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.reportDocQuote, style: theme.textTheme.titleSmall),
                Text(
                  l10n.invoicePagePdfHint,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('quote-print'),
            onPressed: () => QuotePrint(
              context,
              ref,
            ).show(workspaceId: workspaceId, quote: quote),
            child: Text(l10n.invoicePageView),
          ),
        ],
      ),
    );
  }
}
