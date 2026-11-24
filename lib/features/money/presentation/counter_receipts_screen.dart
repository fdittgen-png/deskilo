// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4185 (CS2) -- the counter's receipts: the sales the till made and their corrections, each as it was frozen, with
// what can still be done to it. A sale is shared as the immutable document it is and is corrected by a NEW receipt; a
// correction is what money is given back and goods are taken back against, each its own act; a sale whose card answer
// was lost waits at the top until the terminal's answer is recorded and the sale is completed, once.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/i18n/money_format.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/share/text_sharer.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/adaptive/window_class.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/async_read_body.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/counter_book.dart';
import '../providers/counter_book_providers.dart';
import 'counter_receipt_sheets.dart';
import 'till_text.dart';

class CounterReceiptsScreen extends ConsumerWidget {
  const CounterReceiptsScreen({super.key, required this.workspaceId});

  /// The open business; null while it is being read.
  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = this.workspaceId;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.counterSaleReceiptsTitle),
        actions: [HelpDot(l10n.counterSaleReceiptsTitle, anchor: HelpAnchor.moneyTillReceipts)],
      ),
      body: workspaceId == null
          ? const LoadingView()
          : AsyncReadBody<CounterBook>(
              value: ref.watch(counterBookProvider(workspaceId)),
              onRetry: () => ref.invalidate(counterBookProvider(workspaceId)),
              data: (book) => _Book(workspaceId: workspaceId, book: book),
            ),
    );
  }
}

class _Book extends ConsumerWidget {
  const _Book({required this.workspaceId, required this.book});

  final String workspaceId;
  final CounterBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (book.receipts.isEmpty) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l10n.counterSaleReceiptsEmpty, textAlign: TextAlign.center)),
      );
    }
    final waiting = book.waiting;
    final issued = book.issued;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: WindowClass.expandedMinWidth),
        child: ListView(
          key: const ValueKey('counter-receipts'),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (waiting.isNotEmpty) ...[
              Text(l10n.counterSaleWaitingTitle, style: theme.textTheme.titleMedium),
              for (final r in waiting) _Receipt(workspaceId: workspaceId, book: book, receipt: r),
              const SizedBox(height: AppSpacing.md),
            ],
            if (issued.isNotEmpty) Text(l10n.counterSaleIssuedTitle, style: theme.textTheme.titleMedium),
            for (final r in issued) _Receipt(workspaceId: workspaceId, book: book, receipt: r),
          ],
        ),
      ),
    );
  }
}

String _title(AppLocalizations l10n, CounterBook book, CounterBookReceipt r, MoneyFormat money) {
  if (!r.finalized) return l10n.counterSaleDraft(money.formatMinor(r.totalMinor));
  if (r.isCorrection) return l10n.counterSaleCorrection(r.number, book.byId(r.correctsId ?? '')?.number ?? '');
  return l10n.counterSaleSale(r.number);
}

String _tenderState(AppLocalizations l10n, CounterBookTender t) {
  if (t.needsReconciliation) return l10n.counterSaleStateReconcile;
  return switch (t.tenderState) {
    TenderState.requested => l10n.counterSaleStateRequested,
    TenderState.unknown => l10n.counterSaleStateUnknown,
    TenderState.refused => l10n.counterSaleStateRefused,
    TenderState.recorded || TenderState.accepted => l10n.counterSaleStateAccepted,
  };
}

String _tenderKind(AppLocalizations l10n, CounterBookTender t) => switch (t.tenderKind) {
  TenderKind.cash => l10n.counterSaleTenderCash,
  TenderKind.card => l10n.counterSaleTenderCard,
  TenderKind.other => l10n.counterSaleTenderOther,
  TenderKind.unknown => t.kind,
};

/// The request id of each one-tap act, per receipt revision, for as long as the app runs.
final Map<String, String> _onceIds = {};

class _Receipt extends ConsumerWidget {
  const _Receipt({required this.workspaceId, required this.book, required this.receipt});

  final String workspaceId;
  final CounterBook book;
  final CounterBookReceipt receipt;

  CounterBookPort _port(WidgetRef ref) => ref.read(counterBookPortProvider);

  /// After an act: the book is read again, and the act is said.
  void _done(BuildContext context, WidgetRef ref, String text) {
    ref.invalidate(counterBookProvider(workspaceId));
    if (context.mounted) AppSnack.success(context, text);
  }

  Future<void> _correct(BuildContext context, WidgetRef ref) async {
    final number = await showCounterCorrectSheet(
      context,
      book: book,
      sale: receipt,
      correct: (id, lines, reason) => _port(ref).correct(workspaceId, requestId: id, originalId: receipt.id, lines: lines, reason: reason),
    );
    if (number != null && context.mounted) _done(context, ref, context.l10n.counterSaleCorrected(number));
  }

  Future<void> _refund(BuildContext context, WidgetRef ref) async {
    final ok = await showCounterRefundSheet(
      context,
      correction: receipt,
      tillId: book.byId(receipt.correctsId ?? '')?.tillId,
      refund: (id, part) => _port(ref).refund(workspaceId, requestId: id, correctionId: receipt.id, parts: [part]),
    );
    if (ok && context.mounted) _done(context, ref, context.l10n.counterSaleRefundDone);
  }

  Future<void> _return(BuildContext context, WidgetRef ref) async {
    final ok = await showCounterReturnSheet(
      context,
      correction: receipt,
      takeBack: (id, lines) => _port(ref).returnGoods(workspaceId, requestId: id, correctionId: receipt.id, lines: lines),
    );
    if (ok && context.mounted) _done(context, ref, context.l10n.counterSaleReturnDone);
  }

  Future<void> _answer(BuildContext context, WidgetRef ref, CounterBookTender t) async {
    final ok = await showCounterTenderAnswerSheet(
      context,
      tender: t,
      currency: receipt.currency,
      resolve: (id, outcome, providerRef) =>
          _port(ref).resolveTender(workspaceId, requestId: id, tenderId: t.id, outcome: outcome, providerRef: providerRef),
    );
    if (ok && context.mounted) _done(context, ref, context.l10n.counterSaleRecordAnswer);
  }

  /// A one-tap act (reconcile, complete): the same act on the same receipt revision goes under the same request id, so
  /// a tap again after a lost answer is answered by the act already made; a refusal is said in words.
  Future<void> _act(BuildContext context, WidgetRef ref, String what, Future<String> Function(String requestId) act) async {
    final l10n = context.l10n;
    try {
      final said = await act(_onceIds['$what|${receipt.id}|${receipt.revision}'] ??= newRequestId());
      if (context.mounted) _done(context, ref, said);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'counter $what refused', error: e, stackTrace: st);
      if (context.mounted) AppSnack.error(context, tillProblemText(l10n, e));
      ref.invalidate(counterBookProvider(workspaceId));
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref, MoneyFormat money) async {
    final l10n = context.l10n;
    final text = counterReceiptText(
      receipt,
      title: l10n.counterSaleShareTitle,
      money: money.formatMinor,
      total: l10n.counterSaleTotalLabel,
      tax: l10n.counterSaleTaxLabel,
    );
    try {
      await ref.read(textSharerProvider)(text);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'counter receipt not shared', error: e, stackTrace: st);
      if (context.mounted) AppSnack.error(context, l10n.tillFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = appFormatOf(context).moneyIn(receipt.currency);
    final r = receipt;
    final canCorrect = r.isSale && r.finalized && r.lines.any((l) => counterQuantityUnits(book.leftOf(l)) > 0);
    final canReturn = r.isCorrection && r.lines.any((l) => l.goods && counterQuantityUnits(r.returnLeft(l)) > 0);
    return Card(
      key: ValueKey('counter-receipt-${r.id}'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title(l10n, book, r, money), style: theme.textTheme.titleMedium),
            Text('${l10n.counterSaleTotal(money.formatMinor(r.totalMinor))} · ${l10n.counterSaleTax(money.formatMinor(r.taxMinor))}'),
            if (r.reason.isNotEmpty) Text(l10n.counterSaleReasonShown(r.reason)),
            const SizedBox(height: AppSpacing.sm),
            for (final line in r.lines) ...[
              Text('${line.quantity} ${line.unit} ${line.label} · ${money.formatMinor(line.grossMinor)}'),
              if (r.isSale && r.finalized && book.leftOf(line) != line.quantity)
                Text(l10n.counterSaleLeft('${book.leftOf(line)} ${line.unit}'.trim()), style: theme.textTheme.bodySmall),
            ],
            for (final t in r.tenders) ...[
              Text(l10n.counterSaleTenderLine(_tenderKind(l10n, t), money.formatMinor(t.amountMinor), _tenderState(l10n, t))),
              if (t.tenderKind == TenderKind.card && t.providerKey.isNotEmpty) Text(l10n.counterSaleReference(t.providerKey), style: theme.textTheme.bodySmall),
            ],
            if (r.isCorrection)
              Text(l10n.counterSaleRefunded(money.formatMinor(r.refundedMinor), money.formatMinor(r.totalMinor))),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (r.finalized)
                  OutlinedButton.icon(
                    key: ValueKey('counter-share-${r.id}'),
                    onPressed: () => unawaited(_share(context, ref, money)),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.counterSaleShare),
                  ),
                if (canCorrect)
                  OutlinedButton(key: ValueKey('counter-correct-${r.id}'), onPressed: () => unawaited(_correct(context, ref)), child: Text(l10n.counterSaleCorrect)),
                if (r.isCorrection && r.refundLeftMinor > 0)
                  OutlinedButton(key: ValueKey('counter-refund-${r.id}'), onPressed: () => unawaited(_refund(context, ref)), child: Text(l10n.counterSaleRefund)),
                if (canReturn)
                  OutlinedButton(key: ValueKey('counter-return-${r.id}'), onPressed: () => unawaited(_return(context, ref)), child: Text(l10n.counterSaleReturn)),
                for (final t in r.openAuthorizations)
                  FilledButton(key: ValueKey('counter-answer-${t.id}'), onPressed: () => unawaited(_answer(context, ref, t)), child: Text(l10n.counterSaleRecordAnswer)),
                for (final t in r.toReconcile)
                  OutlinedButton(
                    key: ValueKey('counter-reconcile-${t.id}'),
                    onPressed: () => unawaited(_act(context, ref, 'reconcile', (id) async {
                      await _port(ref).reconcileTender(workspaceId, requestId: id, tenderId: t.id);
                      return l10n.counterSaleReconcile;
                    })),
                    child: Text(l10n.counterSaleReconcile),
                  ),
                if (r.completable)
                  FilledButton(
                    key: ValueKey('counter-complete-${r.id}'),
                    onPressed: () => unawaited(_act(context, ref, 'completion', (id) async {
                      final number = await _port(ref).complete(workspaceId, requestId: id, receiptId: r.id, expectedRevision: r.revision, tenderIds: r.settlingCardTenders);
                      return l10n.counterSaleCompleted(number);
                    })),
                    child: Text(l10n.counterSaleComplete),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
