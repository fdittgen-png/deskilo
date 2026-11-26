// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the quotes of the business on a screen of their own
// (`/money/quotes`): what was offered to a billing customer, and where each
// offer stands. A list that could not be read says so: it is never shown as "no
// quotes". The issuer's right to issue invoices opens the New quote door.
// #4492 -- the list is a records table like the invoices beside it: number,
// customer, state, validity and amount as columns (cards on a phone), a
// filter, the states as chips and the total per currency.
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
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/kit/page_bar.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/kit/records_table.dart';
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
            pageBarAction(
              key: const ValueKey('quote-new'),
              label: l10n.quotesNew,
              onPressed: () => context.go(Routes.moneyQuoteNew),
            ),
          HelpDot(l10n.quotesTitle, anchor: HelpAnchor.moneyQuotes),
        ],
      ),
      body: workspace == null
          ? const SizedBox.shrink()
          : _Body(workspaceId: workspace.id),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          // A sentence keeps a line a person reads, also above a wide table.
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
              child: Text(l10n.quotesIntro, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ),
        Expanded(
          child: switch (quotes) {
            // A typed refusal keeps its own words (#4414), which the table's
            // plain failure does not carry.
            AsyncError(:final error) => Padding(
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
            _ => _QuotesTable(
              quotes: quotes.value ?? const <CustomerQuote>[], // empty-ok: the table shows loading while it is not read
              state: quotes.hasValue ? RecordsState.ready : RecordsState.loading,
              names: names,
            ),
          },
        ),
      ],
    );
  }
}

class _QuotesTable extends StatelessWidget {
  const _QuotesTable({
    required this.quotes,
    required this.state,
    required this.names,
  });

  final List<CustomerQuote> quotes;
  final RecordsState state;

  /// The customers' names by subject.
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String customer(CustomerQuote q) => names[q.subjectId] ?? '';
    String until(CustomerQuote q) => switch (q.shown?.validUntil) {
      final day? => quoteDate(context, day),
      null => '',
    };
    String amount(CustomerQuote q) => switch (q.shown?.totals) {
      final totals? => quoteAmount(context, totals),
      null => '',
    };
    bool stands(CustomerQuote q, QuoteStatus status) =>
        q.status == status && !(q.expired && status == QuoteStatus.sent);
    return RecordsTable<CustomerQuote>(
      tableId: 'customer-quotes',
      rows: quotes,
      state: state,
      keyOf: (q) => q.id,
      searchText: (q) => '${q.reference ?? ''} ${customer(q)}',
      onOpen: (q) => context.go(Routes.moneyQuote(q.id)),
      empty: EmptyState(
        key: const ValueKey('quotes-empty'),
        icon: Icons.request_quote_outlined,
        title: l10n.quotesEmpty,
      ),
      chips: [
        RecordChip(
          id: 'draft',
          label: l10n.invoicingStatusDraft,
          keeps: (q) => stands(q, QuoteStatus.draft),
        ),
        RecordChip(
          id: 'sent',
          label: l10n.quoteStatusSent,
          keeps: (q) => stands(q, QuoteStatus.sent),
        ),
        RecordChip(
          id: 'accepted',
          label: l10n.quoteStatusAccepted,
          keeps: (q) => stands(q, QuoteStatus.accepted),
        ),
      ],
      amountOf: (q) => switch (q.shown?.totals) {
        final totals? => (currency: totals.currency, minor: totals.totalCents),
        null => null,
      },
      amountColumn: 'total',
      formatAmount: (currency, minor) => quoteAmount(
        context,
        QuoteTotals(totalCents: minor, currency: currency),
      ),
      columns: [
        RecordColumn(
          id: 'number',
          label: l10n.invoiceRegisterNumber,
          flex: 2,
          hideable: false,
          sortKey: (q) => q.reference ?? '',
          cell: (_, q) => Text(q.reference ?? ''),
        ),
        RecordColumn(
          id: 'customer',
          label: l10n.invoicingColCustomer,
          flex: 4,
          sortKey: (q) => customer(q).toLowerCase(),
          cell: (_, q) => Text(customer(q), overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'state',
          label: l10n.invoicingColStatus,
          flex: 3,
          sortKey: (q) => q.status.index,
          cell: (_, q) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: quoteStatusChip(l10n, q),
          ),
        ),
        RecordColumn(
          id: 'valid-until',
          label: l10n.quoteFieldValidUntil,
          staysBeside: false,
          flex: 3,
          sortKey: (q) => q.shown?.validUntil ?? DateTime(0),
          cell: (_, q) => Text(until(q)),
        ),
        RecordColumn(
          id: 'total',
          label: l10n.invoiceRegisterTotal,
          numeric: true,
          flex: 3,
          sortKey: (q) => q.shown?.totals?.totalCents ?? 0,
          cell: (_, q) => Text(amount(q)),
        ),
      ],
      cardBuilder: (context, q) {
        // A draft has no number yet: its customer names the card, and the
        // state is said once.
        final head = [?q.reference, if (customer(q).isNotEmpty) customer(q)];
        final status = quoteStatusLabel(l10n, q);
        return ListTile(
          key: ValueKey('quote-row-${q.id}'),
          title: Text(head.isEmpty ? status : head.join(' · ')),
          subtitle: Text(
            [
              if (head.isNotEmpty) status,
              if (until(q).isNotEmpty) l10n.quoteValidUntil(until(q)),
            ].join(' · '),
          ),
          trailing: amount(q).isEmpty ? null : Text(amount(q)),
        );
      },
    );
  }
}
