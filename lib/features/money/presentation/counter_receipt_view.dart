// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4184 (CS1) -- the counter receipt as its frozen document says it: lines, the tax per rate, the total, the original
// a correction cites, and the country operation it was issued under. Amounts are spelled in the receipt's currency
// with its own decimals (0, 2 or 3); nothing is priced here. The same words are the text a receipt is shared as, so
// what is shown and what leaves the counter are one document. A document whose amounts disagree is shown as frozen
// and said to disagree; a version this app does not read is said, never guessed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/share/text_sharer.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/refusal_text.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/async_read_body.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/counter_receipt_document.dart';
import '../providers/till_providers.dart';

/// The frozen rate as a person reads it in the language (`20 %`, `5,5 %`); a rate that is not a number is shown as written.
String _rate(AppFormat format, CounterReceiptTax tax) {
  final rate = tax.rate;
  return rate == null ? tax.percent : format.ratePercent(rate);
}

/// The lines of [doc] as words, one per line of the document, in the order a receipt prints them.
List<String> _counterReceiptLines(AppLocalizations l10n, AppFormat format, CounterReceiptDocument doc, {int? copy}) {
  final money = format.moneyIn(doc.currency);
  final corrects = doc.corrects;
  final op = doc.operation;
  return [
    if (copy != null) l10n.tillReceiptCopy('$copy'),
    l10n.tillReceiptNumber(doc.number),
    if (doc.issuedAt != null) format.dateTime(doc.issuedAt!),
    if (corrects != null) l10n.tillReceiptCorrects(corrects.number),
    for (final l in doc.lines)
      l10n.tillReceiptLine(l.returned ? l10n.tillReturnedLabel(l.label) : l.label, l.quantity, l.unit, money.formatMinor(l.grossMinor)),
    for (final t in doc.taxBreakdown) l10n.tillReceiptTaxLine(_rate(format, t), money.formatMinor(t.taxMinor), money.formatMinor(t.netMinor)),
    l10n.tillReceiptTotal(money.formatMinor(doc.totals.grossMinor)),
    if (op.specification.isNotEmpty) l10n.tillReceiptIssuedUnder(op.specification, op.specificationVersion),
  ];
}

/// The receipt as one text: what is shared.
@visibleForTesting
String counterReceiptText(AppLocalizations l10n, AppFormat format, CounterReceiptDocument doc, {int? copy}) =>
    _counterReceiptLines(l10n, format, doc, copy: copy).join('\n');

/// Shows the finalized receipt [receiptId] of the business [workspaceId]; [copy] marks it as that copy (#4476).
Future<void> showCounterReceiptSheet(BuildContext context, {required String workspaceId, required String receiptId, int? copy}) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _CounterReceiptSheet(workspaceId: workspaceId, receiptId: receiptId, copy: copy),
    );

/// The receipt read through the versioned reader, with its way out of the counter.
class _CounterReceiptSheet extends ConsumerWidget {
  const _CounterReceiptSheet({required this.workspaceId, required this.receiptId, this.copy});

  final String workspaceId;
  final String receiptId;
  final int? copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: ref
          .watch(counterReceiptProvider((workspaceId: workspaceId, receiptId: receiptId)))
          .when(
            loading: () => const LoadingView(),
            error: (e, _) => ReadFailureBanner(
              error: e,
              onRetry: () => ref.invalidate(counterReceiptProvider((workspaceId: workspaceId, receiptId: receiptId))),
              retryKey: const ValueKey('counter-receipt-retry'),
              refusal: e is CounterReceiptUnreadable ? l10n.tillReceiptUnreadable : knownRefusalText(l10n, e),
            ),
            data: (doc) => _CounterReceiptView(document: doc, channel: _channel(ref), copy: copy),
          ),
    );
  }

  /// `counter.document_channel`: `share`, `print` or `both`.
  String _channel(WidgetRef ref) => ref.watch(counterDocumentChannelProvider(workspaceId));
}

/// The document itself.
class _CounterReceiptView extends ConsumerWidget {
  const _CounterReceiptView({required this.document, this.channel = 'share', this.copy});

  final CounterReceiptDocument document;

  /// #4476 -- the copy this is (1, 2, ...), or null for the receipt as issued.
  final int? copy;

  /// How the receipt leaves the counter (`share`, `print`, `both`).
  final String channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final lines = _counterReceiptLines(l10n, format, document, copy: copy);
    return SingleChildScrollView(
      key: const ValueKey('counter-receipt'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lines.first, style: Theme.of(context).textTheme.titleLarge),
          for (final line in lines.skip(1)) Text(line),
          if (document.disagreements.isNotEmpty) ...[
            const FormGap(),
            Text(
              l10n.tillReceiptDisagrees,
              key: const ValueKey('counter-receipt-disagrees'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const FormGap(),
          FilledButton.icon(
            key: const ValueKey('counter-receipt-share'),
            icon: const Icon(Icons.share),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => ref.read(textSharerProvider)(counterReceiptText(l10n, format, document)),
            label: Text(l10n.tillReceiptShare),
          ),
          if (channel != 'share')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(l10n.tillReceiptPrintNote, key: const ValueKey('counter-receipt-print-note')),
            ),
        ],
      ),
    );
  }
}
