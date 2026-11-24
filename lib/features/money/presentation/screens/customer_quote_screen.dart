// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- one quote (`/money/quotes/:id`): the revision on offer, its
// history and what the issuer may do now. A sent revision is shown as it was
// frozen (its amounts are the real issuer's); a draft shows none, they are
// worked out when it is sent. Every action is the server's decision: a refusal
// or a lost answer is said, and the quote is read again.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../application/customer_quote_commands.dart';
import '../../domain/customer_quote.dart';
import '../../providers/billing_customer_providers.dart';
import '../../providers/customer_quote_providers.dart';
import '../engagements/follow_line_button.dart';
import '../quote_print.dart';
import '../quotes/quote_conversion_sheet.dart';
import '../quotes/quote_decision_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final canIssue = MoneyViewData.purchasePermissionNames(ref).contains('issueInvoices');
    final id = workspace?.id;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.quotesTitle),
        leading: BackButton(
          key: const ValueKey('quote-back'),
          onPressed: () => context.go(Routes.moneyQuotes),
        ),
      ),
      body: id == null
          ? const SizedBox.shrink()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ref
                    .watch(customerQuoteProvider((workspaceId: id, quoteId: widget.quoteId)))
                    .when(
                      loading: () => const LoadingView(),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: ReadFailureBanner(
                          error: error,
                          refusal: error is QuoteRefusal
                              ? quoteRefusalText(l10n, error)
                              : null,
                          retryKey: const ValueKey('quote-retry'),
                          onRetry: () => ref.invalidate(
                            customerQuoteProvider((workspaceId: id, quoteId: widget.quoteId)),
                          ),
                        ),
                      ),
                      data: (quote) => _Content(
                        quote: quote,
                        workspaceId: id,
                        canIssue: canIssue,
                        busy: _busy,
                        said: _said,
                        onRun: (act, {leave = false}) => unawaited(_run(id, act, leave: leave)),
                        onAnswer: (context, {required convert}) =>
                            unawaited(_answer(context, id, quote, convert: convert)),
                      ),
                    ),
              ),
            ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.quote,
    required this.workspaceId,
    required this.canIssue,
    required this.busy,
    required this.said,
    required this.onRun,
    required this.onAnswer,
  });

  final CustomerQuote quote;
  final String workspaceId;
  final bool canIssue;
  final bool busy;
  final String? said;
  final void Function(
    Future<CommandOutcome<Object?>> Function(CustomerQuoteCommands) act, {
    bool leave,
  }) onRun;

  /// Opens the answer sheet, or the conversion sheet when [convert].
  final void Function(BuildContext context, {required bool convert}) onAnswer;

  /// Whether an accepted line offers its engagement: the feature is on, the
  /// person may issue, and the accepted revision is the one shown.
  bool canFollow(WidgetRef ref) =>
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
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ..._header(context, names),
        if (shown != null) ..._offer(context, shown, canFollow: canFollow(ref)),
        ..._share(context, ref),
        ..._decision(context),
        if (quote.revisions.length > 1) ..._history(context),
        if (canIssue && (quote.openForActions || quote.invoiceId != null))
          ..._actions(context),
      ],
    );
  }

  List<Widget> _header(BuildContext context, Map<String, String> names) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return [
      Text(
        quote.reference ?? l10n.invoicingStatusDraft,
        key: const ValueKey('quote-title'),
        style: theme.textTheme.titleLarge,
      ),
      Text(
        [quoteStatusLabel(l10n, quote), ?names[quote.subjectId]].join(' · '),
        key: const ValueKey('quote-status'),
      ),
      if (said != null) ...[
        const FormGap(),
        Text(
          said!,
          key: const ValueKey('quote-said'),
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ],
      const FormGap(),
    ];
  }

  /// The revision on offer: dates, terms, lines, and the amounts a sent one froze.
  List<Widget> _offer(BuildContext context, QuoteRevision shown, {required bool canFollow}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final totals = shown.totals;
    return [
      Text(l10n.quoteValidUntil(quoteDate(context, shown.validUntil))),
      if (shown.buyerReference.isNotEmpty)
        Text(l10n.quoteReferenceLine(shown.buyerReference)),
      if (shown.purchaseOrder.isNotEmpty)
        Text(l10n.quoteOrderLine(shown.purchaseOrder)),
      const FormGap(),
      Text(l10n.standaloneInvoiceLines, style: theme.textTheme.titleMedium),
      for (final (i, line) in shown.lines.indexed)
        ListTile(
          key: ValueKey('quote-line-$i'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(line.description),
          subtitle: Text('${line.quantity} ${line.unitLabel} × ${line.unitPrice}'),
          // #4178 — an accepted line is followed as an engagement of its own
          trailing: canFollow && line.lineId != null
              ? FollowLineButton(workspaceId: workspaceId, quoteId: quote.id, lineId: line.lineId!)
              : null,
        ),
      if (totals != null)
        ListTile(
          key: const ValueKey('quote-total'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.quoteTotal, style: theme.textTheme.titleMedium),
          trailing: Text(quoteAmount(context, totals), style: theme.textTheme.titleMedium),
        )
      else
        Text(l10n.quoteAmountsOnSend, key: const ValueKey('quote-amounts-on-send')),
      if (shown.notes.isNotEmpty) ...[const FormGap(), Text(shown.notes)],
      if (quote.current != null && quote.reference != null) ...[
        const FormGap(),
        Text(l10n.quoteSentAs(quote.reference!), key: const ValueKey('quote-sent-as')),
      ],
    ];
  }

  /// What the issuer recorded, never a customer's signature.
  /// The offer as a document: what the customer holds, to look at, save or
  /// share. A quote nothing was sent of has none.
  List<Widget> _share(BuildContext context, WidgetRef ref) {
    if (quoteDocumentRevision(quote) == null) return const [];
    return [
      const FormGap(),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          key: const ValueKey('quote-print'),
          icon: const Icon(Icons.ios_share),
          label: Text(context.l10n.invoicePageMoreShare),
          onPressed: () =>
              QuotePrint(context, ref).show(workspaceId: workspaceId, quote: quote),
        ),
      ),
    ];
  }

  List<Widget> _decision(BuildContext context) {
    final decision = quote.decision;
    if (decision == null) return const [];
    return [
      const FormGap(),
      Text(
        context.l10n.quoteDecisionByIssuer(
          quoteSourceLabel(context.l10n, decision.source),
          quoteDate(context, decision.decidedOn),
        ),
        key: const ValueKey('quote-decision'),
      ),
    ];
  }

  List<Widget> _history(BuildContext context) {
    final l10n = context.l10n;
    return [
      const FormGap(),
      Text(l10n.quoteRevisionsTitle, style: Theme.of(context).textTheme.titleMedium),
      for (final r in quote.revisions)
        Text(
          l10n.quoteRevisionLine(
            '${r.revision}',
            r.sent ? l10n.quoteStatusSent : l10n.invoicingStatusDraft,
          ),
          key: ValueKey('quote-revision-${r.revision}'),
        ),
    ];
  }

  /// What the issuer may do now: a draft is edited, sent or discarded; a sent
  /// quote is amended (another revision) or cancelled.
  List<Widget> _actions(BuildContext context) {
    final l10n = context.l10n;
    final draft = quote.draft;
    return [
      const FormGap(),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (draft != null) ..._draftActions(context, draft),
          if (quote.status == QuoteStatus.accepted && quote.invoiceId == null)
            FilledButton(
              key: const ValueKey('quote-convert'),
              onPressed: busy ? null : () => onAnswer(context, convert: true),
              child: Text(l10n.quoteConvert),
            ),
          if (quote.invoiceId != null)
            FilledButton(
              key: const ValueKey('quote-open-invoice'),
              onPressed: () => context.go(Routes.invoice(quote.invoiceId!)),
              child: Text(l10n.quoteConvertOpenInvoice),
            ),
          if (draft == null && quote.status == QuoteStatus.sent) ...[
            FilledButton(
              key: const ValueKey('quote-record-answer'),
              onPressed: busy ? null : () => onAnswer(context, convert: false),
              child: Text(l10n.quoteRecordAnswer),
            ),
            FilledButton(
              key: const ValueKey('quote-amend'),
              onPressed: busy ? null : () => onRun((c) => c.amend(workspaceId, quote.id)),
              child: Text(l10n.quoteAmend),
            ),
            OutlinedButton(
              key: const ValueKey('quote-cancel'),
              onPressed: busy ? null : () => onRun((c) => c.cancel(workspaceId, quote.id)),
              child: Text(l10n.quoteCancelAction),
            ),
          ],
        ],
      ),
    ];
  }

  List<Widget> _draftActions(BuildContext context, QuoteRevision draft) {
    final l10n = context.l10n;
    return [
      OutlinedButton(
        key: const ValueKey('quote-edit'),
        onPressed: busy ? null : () => context.go(Routes.moneyQuoteEdit(quote.id)),
        child: Text(l10n.quoteEditDraft),
      ),
      FilledButton(
        key: const ValueKey('quote-send'),
        onPressed: busy
            ? null
            : () => onRun(
                (c) => c.send(
                  workspaceId,
                  quote.id,
                  revision: draft.revision,
                  version: draft.draftVersion,
                ),
              ),
        child: Text(l10n.quoteSend),
      ),
      if (quote.status == QuoteStatus.draft)
        OutlinedButton(
          key: const ValueKey('quote-discard'),
          onPressed: busy
              ? null
              : () => onRun((c) => c.discardDraft(workspaceId, quote.id), leave: true),
          child: Text(l10n.quoteDiscardDraft),
        ),
    ];
  }
}
