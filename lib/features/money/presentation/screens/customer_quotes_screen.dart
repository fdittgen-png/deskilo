// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the quotes of the business on a screen of their own
// (`/money/quotes`): what was offered to a billing customer, and where each
// offer stands. A list that could not be read says so: it is never shown as "no
// quotes". The issuer's right to issue invoices opens the New quote door.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/customer_quote.dart';
import '../../providers/billing_customer_providers.dart';
import '../../providers/customer_quote_providers.dart';
import '../quotes/quote_text.dart';
import 'money_view_data.dart';

class CustomerQuotesScreen extends ConsumerWidget {
  const CustomerQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final canIssue = MoneyViewData.purchasePermissionNames(ref).contains('issueInvoices');
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.quotesTitle),
        actions: [
          if (canIssue && workspace != null)
            OutlinedButton.icon(
              key: const ValueKey('quote-new'),
              onPressed: () => context.go(Routes.moneyQuoteNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.quotesNew),
            ),
          HelpDot(l10n.quotesTitle, anchor: HelpAnchor.moneyQuotes),
        ],
      ),
      body: workspace == null
          ? const SizedBox.shrink()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
                child: _Body(workspaceId: workspace.id),
              ),
            ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final quotes = ref.watch(customerQuotesProvider(workspaceId));
    // empty-ok: the names only label the rows; without them a row names no customer
    final names = quoteCustomerNames(
      ref.watch(billingCustomersProvider(workspaceId)).value ?? const [], // empty-ok: the names only label the rows
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(l10n.quotesIntro, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: quotes.when(
            loading: () => const LoadingView(),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ReadFailureBanner(
                error: error,
                refusal: error is QuoteRefusal
                    ? quoteRefusalText(l10n, error)
                    : null,
                retryKey: const ValueKey('quotes-retry'),
                onRetry: () => ref.invalidate(customerQuotesProvider(workspaceId)),
              ),
            ),
            data: (all) => all.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        l10n.quotesEmpty,
                        key: const ValueKey('quotes-empty'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: all.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _QuoteRow(quote: all[i], customer: names[all[i].subjectId]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.quote, required this.customer});

  final CustomerQuote quote;
  final String? customer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = quote.shown;
    final totals = shown?.totals;
    return ListTile(
      key: ValueKey('quote-row-${quote.id}'),
      title: Text([quote.reference ?? l10n.invoicingStatusDraft, ?customer].join(' · ')),
      subtitle: Text(
        [
          quoteStatusLabel(l10n, quote),
          if (shown != null) l10n.quoteValidUntil(quoteDate(context, shown.validUntil)),
        ].join(' · '),
      ),
      trailing: totals == null ? null : Text(quoteAmount(context, totals)),
      onTap: () => context.go(Routes.moneyQuote(quote.id)),
    );
  }
}
