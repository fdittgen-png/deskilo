// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- one quote (`/money/quotes/:id`): the revision on offer, its
// history and what the issuer may do now. A sent revision is shown as it was
// frozen (its amounts are the real issuer's); a draft shows none, they are
// worked out when it is sent. Every action is the server's decision: a refusal
// or a lost answer is said, and the quote is read again.
// #4492 -- the page has the invoice page's anatomy: its name in the bar, the
// state said once in the summary card, the sections as cards, the action of
// the moment in the bottom bar (Send, Record the answer, Invoice this quote)
// and the corrections (amend, cancel, discard) behind the worded More.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../../../core/ui/kit/page_more_menu.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../application/customer_quote_commands.dart';
import '../../domain/customer_quote.dart';
import '../../providers/billing_customer_providers.dart';
import '../../providers/customer_quote_providers.dart';
import '../quote_print.dart';
import '../quotes/quote_conversion_sheet.dart';
import '../quotes/quote_decision_sheet.dart';
import '../quotes/quote_page_parts.dart';
import '../quotes/quote_text.dart';
import 'money_view_data.dart';

class CustomerQuoteScreen extends ConsumerStatefulWidget {
  const CustomerQuoteScreen({super.key, required this.quoteId});

  final String quoteId;

  @override
  ConsumerState<CustomerQuoteScreen> createState() => _CustomerQuoteScreenState();
}

class _CustomerQuoteScreenState extends ConsumerState<CustomerQuoteScreen> {
  bool _busy = false;
  String? _said;

  Future<void> _run(
    String workspaceId,
    Future<CommandOutcome<Object?>> Function(CustomerQuoteCommands) act, {
    bool leave = false,
  }) async {
    setState(() {
      _busy = true;
      _said = null;
    });
    final outcome = await act(ref.read(customerQuoteCommandProvider));
    if (!mounted) return;
    ref
      ..invalidate(customerQuotesProvider(workspaceId))
      ..invalidate(customerQuoteProvider((workspaceId: workspaceId, quoteId: widget.quoteId)));
    final l10n = context.l10n;
    setState(() {
      _busy = false;
      _said = switch (outcome) {
        CommandDone() => null,
        CommandRefused(refusal: Refusal(cause: final QuoteRefusal refusal)) => quoteRefusalText(l10n, refusal),
        _ => l10n.quoteUnreached,
      };
    });
    if (leave && outcome is CommandDone) context.go(Routes.moneyQuotes);
  }

  /// The answer sheet, or the conversion sheet; the quote is read again after
  /// either closes with something done.
  Future<void> _answer(
    BuildContext context,
    String workspaceId,
    CustomerQuote quote, {
    required bool convert,
  }) async {
    final done = convert
        ? await QuoteConversion.show(context, workspaceId: workspaceId, quote: quote)
        : await QuoteDecisionSheet.show(context, ref, workspaceId: workspaceId, quote: quote);
    if (!done || !mounted) return;
    ref
      ..invalidate(customerQuotesProvider(workspaceId))
      ..invalidate(customerQuoteProvider((workspaceId: workspaceId, quoteId: widget.quoteId)));
  }

  /// The corrections of the quote, behind More: a first draft is discarded,
  /// a sent quote is amended (another revision) or cancelled.
  List<PageMoreEntry> _corrections(String workspaceId, CustomerQuote quote) {
    final l10n = context.l10n;
    final draft = quote.draft;
    return [
      PageMoreEntry.heading(
        key: const ValueKey('quote-more-corrections'),
        label: l10n.invoicePageMoreCorrections,
      ),
      if (draft != null && quote.status == QuoteStatus.draft)
        PageMoreEntry(
          key: const ValueKey('quote-discard'),
          label: l10n.quoteDiscardDraft,
          onSelected: () => unawaited(
            _run(workspaceId, (c) => c.discardDraft(workspaceId, quote.id), leave: true),
          ),
        ),
      if (draft == null && quote.status == QuoteStatus.sent) ...[
        PageMoreEntry(
          key: const ValueKey('quote-amend'),
          label: l10n.quoteAmend,
          onSelected: () => unawaited(_run(workspaceId, (c) => c.amend(workspaceId, quote.id))),
        ),
        PageMoreEntry(
          key: const ValueKey('quote-cancel'),
          label: l10n.quoteCancelAction,
          onSelected: () => unawaited(_run(workspaceId, (c) => c.cancel(workspaceId, quote.id))),
        ),
      ],
    ];
  }

  /// What the issuer does now, the main action last: a draft is edited and
  /// sent, a sent quote gets its answer, an accepted one is invoiced, an
  /// invoiced one opens its invoice.
  List<Widget> _actions(String workspaceId, CustomerQuote quote) {
    final l10n = context.l10n;
    final draft = quote.draft;
    Widget filled(String key, String label, VoidCallback onPressed) => FilledButton(
      key: ValueKey(key),
      onPressed: _busy ? null : onPressed,
      child: Text(label, textAlign: TextAlign.center),
    );
    return [
      if (draft != null) ...[
        OutlinedButton(
          key: const ValueKey('quote-edit'),
          onPressed: _busy ? null : () => context.go(Routes.moneyQuoteEdit(quote.id)),
          child: Text(l10n.quoteEditDraft, textAlign: TextAlign.center),
        ),
        filled(
          'quote-send',
          l10n.quoteSend,
          () => unawaited(
            _run(
              workspaceId,
              (c) => c.send(
                workspaceId,
                quote.id,
                revision: draft.revision,
                version: draft.draftVersion,
              ),
            ),
          ),
        ),
      ],
      if (draft == null && quote.status == QuoteStatus.sent)
        filled(
          'quote-record-answer',
          l10n.quoteRecordAnswer,
          () => unawaited(_answer(context, workspaceId, quote, convert: false)),
        ),
      if (quote.status == QuoteStatus.accepted && quote.invoiceId == null)
        filled(
          'quote-convert',
          l10n.quoteConvert,
          () => unawaited(_answer(context, workspaceId, quote, convert: true)),
        ),
      if (quote.invoiceId case final invoiceId?)
        FilledButton(
          key: const ValueKey('quote-open-invoice'),
          onPressed: () => context.go(Routes.invoice(invoiceId)),
          child: Text(l10n.quoteConvertOpenInvoice, textAlign: TextAlign.center),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final canIssue = MoneyViewData.purchasePermissionNames(ref).contains('issueInvoices');
    final id = workspace?.id;
    final read = id == null
        ? null
        : ref.watch(customerQuoteProvider((workspaceId: id, quoteId: widget.quoteId)));
    // The bar and the actions say what was read: while the read has failed
    // they stay away, so nothing is offered on an answer of before.
    // #4414 kept: a guard on the actions, the failure is drawn by AsyncReadBody
    final quote = read == null || read.hasError ? null : read.value;
    final acts =
        id != null && quote != null && canIssue && (quote.openForActions || quote.invoiceId != null);
    final actions = acts ? _actions(id, quote) : const <Widget>[];
    return Scaffold(
      appBar: AppBar(
        title: switch (quote?.reference) {
          final reference? => PageTitle(
            l10n.quotePageTitle(reference),
            key: const ValueKey('quote-title'),
            whenCut: reference,
          ),
          // A quote nothing was sent of has no number yet.
          null => PageTitle(l10n.reportDocQuote, key: const ValueKey('quote-title')),
        },
        leading: BackButton(
          key: const ValueKey('quote-back'),
          onPressed: () => context.go(Routes.moneyQuotes),
        ),
        actions: [
          if (acts)
            PageMoreMenu(
              key: const ValueKey('quote-more'),
              enabled: !_busy,
              entries: _corrections(id, quote),
            ),
        ],
      ),
      bottomNavigationBar: actions.isEmpty
          ? null
          : BottomActionBar(maxWidth: kReadingColumnWidth, actions: actions),
      body: id == null || read == null
          ? const SizedBox.shrink()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
                child: AsyncReadBody(
                  value: read,
                  refusal: (error) => error is QuoteRefusal
                      ? quoteRefusalText(l10n, error)
                      : null,
                  retryKey: const ValueKey('quote-retry'),
                  onRetry: () => ref.invalidate(
                    customerQuoteProvider((workspaceId: id, quoteId: widget.quoteId)),
                  ),
                  data: (quote) => _Content(
                    quote: quote,
                    workspaceId: id,
                    canIssue: canIssue,
                    said: _said,
                  ),
                ),
              ),
            ),
    );
  }
}

/// The quote's sections, each a card: the summary, the lines, the revisions
/// and the document.
class _Content extends ConsumerWidget {
  const _Content({
    required this.quote,
    required this.workspaceId,
    required this.canIssue,
    required this.said,
  });

  final CustomerQuote quote;
  final String workspaceId;
  final bool canIssue;

  /// What the last action answered when it was not done.
  final String? said;

  /// Whether an accepted line offers its engagement: the feature is on, the
  /// person may issue, and the accepted revision is the one shown.
  bool _canFollow(WidgetRef ref) =>
      canIssue &&
      (quote.status == QuoteStatus.accepted || quote.status == QuoteStatus.converted) &&
      quote.decision?.revision == quote.shown?.revision &&
      MoneyViewData.gates(ref).serviceFulfilmentOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = quoteCustomerNames(
      ref.watch(billingCustomersProvider(workspaceId)).value ?? const [], // empty-ok: the name only labels the quote
    );
    final shown = quote.shown;
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        if (said case final words?)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              words,
              key: const ValueKey('quote-said'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        QuoteSummaryCard(quote: quote, customer: names[quote.subjectId]),
        if (shown != null) ...[
          const SizedBox(height: AppSpacing.md),
          QuoteLinesCard(
            quote: quote,
            shown: shown,
            workspaceId: workspaceId,
            canFollow: _canFollow(ref),
          ),
        ],
        if (quote.revisions.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          QuoteRevisionsCard(quote: quote),
        ],
        if (quoteDocumentRevision(quote) != null) ...[
          const SizedBox(height: AppSpacing.md),
          QuoteDocumentCard(quote: quote, workspaceId: workspaceId),
        ],
      ],
    );
  }
}
