// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/billing_rules.dart';
import '../../domain/einvoice_gateway.dart';
import '../../domain/invoice.dart';
import '../../domain/invoice_line_text.dart';
import '../invoice_journey.dart';
import '../invoice_status.dart';
import '../report_strings_l10n.dart';
import 'einvoice_receipt_line.dart';

/// The parts of the invoice sheet below the header: what the document
/// says, the settlement trail, the timeline and the actions.
class InvoiceDetailSections {
  const InvoiceDetailSections({
    required this.invoice,
    required this.canIssue,
    required this.isEu,
    required this.reminder,
    required this.replacedByNumber,
    required this.transmission,
    required this.journey,
  });

  final Invoice invoice;
  final bool canIssue;
  final bool isEu;
  final ({int count, DateTime last})? reminder;
  final String replacedByNumber;
  final InvoiceTransmission? transmission;
  final InvoiceJourney? journey;

  Widget kindRow(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('invoice-detail-kind'),
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            switch (invoice.kind) {
              InvoiceKind.subscription => Icons.event_repeat_outlined,
              InvoiceKind.usage => Icons.receipt_long_outlined,
              InvoiceKind.settlement => Icons.merge_outlined,
              InvoiceKind.full => Icons.description_outlined,
            },
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              invoiceKindLabel(l10n, invoice.kind),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The positions as the PDF prints them, the tax inside them, the balance.
  List<Widget> amounts(BuildContext context, {required bool association}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currency = moneyFormat(invoice.currency);
    return [
      // The positions, exactly as the PDF prints them.
      for (final (i, position) in invoice.lines.indexed)
        Padding(
          key: ValueKey('invoice-detail-line-$i'),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  invoiceLineText(
                    reportStringsOf(l10n),
                    position,
                    association: association,
                    period: invoice.period,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(currency.formatMinor(position.amountCents)),
            ],
          ),
        ),
      const Divider(),
      // What of the charges is tax (0072). Shown as an explanation
      // of the amount, never as an addition to it: the prices the
      // member agreed to already include it.
      for (final total in invoice.vatTotals)
        if (total.vatCents > 0)
          Padding(
            key: ValueKey('invoice-detail-vat-${total.percent}'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.vatPdfVat} '
                    '${_percentLabel(total.percent)}',
                    style: TextStyle(color: theme.hintColor),
                  ),
                ),
                Text(
                  currency.formatMinor(total.vatCents),
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),
          ),
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.invoiceBalance,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            currency.formatMinor(invoice.totalCents),
            key: const ValueKey('invoice-detail-total'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ];
  }

  /// #804 — what a settlement regroups, position by position.
  List<Widget> settlementTrail(
    BuildContext context, {
    required bool association,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final currency = moneyFormat(invoice.currency);
    Widget line(String text) => _detailLine(theme, text);
    return [
      const Divider(height: AppSpacing.xl),
      Text(l10n.settlementRegroups, style: theme.textTheme.titleSmall),
      for (final source in invoice.settles)
        Padding(
          key: ValueKey('settlement-source-${source.invoiceId}'),
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        source.number,
                        if (source.period != null) source.period!,
                        invoiceKindLabel(l10n, source.kind),
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(currency.formatMinor(source.totalCents)),
                ],
              ),
              // The positions of the ORIGINAL, so the trail
              // does not stop at a number.
              for (final position in source.lines)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          invoiceLineText(
                            reportStringsOf(l10n),
                            position,
                            association: association,
                            period: source.period,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                      Text(
                        currency.formatMinor(position.amountCents),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      line(l10n.settlementVatNote),
    ];
  }

  /// Lifecycle facts: the correction chain, the payment that closed it,
  /// the reminders sent, the annex it carries.
  List<Widget> timeline(BuildContext context, InvoiceMatch? standingMatch) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currency = moneyFormat(invoice.currency);
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    Widget line(String text) => _detailLine(theme, text);
    final sent = transmission;
    // The platform's answer, in the reader's language.
    final sentStatus = switch (sent?.status) {
      EInvoiceSubmissionStatus.accepted => l10n.invoiceSendStatusAccepted,
      EInvoiceSubmissionStatus.rejected => l10n.invoiceSendStatusRejected,
      EInvoiceSubmissionStatus.failed => l10n.invoiceSendStatusFailed,
      null => '',
    };

    return [
      // Lifecycle facts: the correction chain, the payment that
      // closed it, the reminders sent, the annex it carries.
      if (journey != null &&
          (invoice.replacesNumber.isNotEmpty ||
              replacedByNumber.isNotEmpty ||
              standingMatch != null ||
              reminder != null ||
              sent != null))
        Padding(
          key: const ValueKey('invoice-detail-timeline'),
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(
            l10n.journeyTimelineTitle,
            style: theme.textTheme.titleSmall,
          ),
        ),
      if (invoice.replacesNumber.isNotEmpty)
        line(
          '${l10n.invoicePdfReplaces} '
          '${invoice.replacesNumber}',
        ),
      if (replacedByNumber.isNotEmpty)
        line(l10n.invoiceReplacedBy(replacedByNumber)),
      if (standingMatch != null)
        line(
          l10n.invoiceMatchSummary(
            currency.formatMinor(standingMatch.paidCents),
            dateFormat.format(standingMatch.matchedAt),
          ),
        ),
      if (standingMatch != null && standingMatch.note.isNotEmpty)
        line(standingMatch.note),
      if (reminder != null)
        line(
          '${l10n.invoiceRemindedBadge(reminder!.count)} · '
          '${l10n.invoiceRemindedLast(dateFormat.format(reminder!.last))}',
        ),
      // Did it LEAVE, and what came back (0073). A rehearsal
      // names its environment so it never reads as the real
      // submission (#393).
      if (sent != null)
        line(
          '${l10n.invoiceSentOn(dateFormat.format(sent.sentAt), sentStatus)}${sent.isTestSend ? ' · '
                    '${sent.environment.toUpperCase()} '
                    '(${l10n.invoiceSentTestChip})' : ''}',
        ),
      if (sent != null && sent.externalId.isNotEmpty) line(sent.externalId),
      // #2358 — what the national channel said afterwards.
      if (sent != null)
        EInvoiceReceiptLine(
          key: const ValueKey('invoice-detail-einvoice-receipt'),
          transmission: sent,
          workspaceId: invoice.workspaceId,
          canAsk: canIssue,
        ),
      if (invoice.detailed)
        line(
          l10n.invoiceAnnexSummary(
            invoice.detailLedger.length,
            invoice.attendance.length,
          ),
        ),
      line(
        '${l10n.invoicePdfSignature} '
        '${invoice.signature.substring(0, invoice.signature.length < 12 ? invoice.signature.length : 12)}…',
      ),
    ];
  }
}

Widget _detailLine(ThemeData theme, String text) => Padding(
  padding: const EdgeInsets.only(top: AppSpacing.xs),
  child: Text(
    text,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  ),
);

/// '20 %', '5.5 %' — a rate beside its caption.
String _percentLabel(double percent) =>
    '${percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent} %';
