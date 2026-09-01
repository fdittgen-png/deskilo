// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import '../../../../core/i18n/money_format.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/einvoice_gateway.dart';
import '../../domain/billing_rules.dart';
import '../../domain/invoice.dart';
import '../invoice_journey.dart';
import '../invoice_line_text.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import 'invoice_journey_view.dart';

/// What the reader asked for after looking at an invoice. The sheet only
/// DECIDES — the screen runs the action with its own live context, so no
/// action ever depends on a sheet that is being dismissed.
enum InvoiceAction {
  quickView,
  downloadPdf,
  sharePdf,
  eInvoice,
  remind,
  markPaid,
  markErroneous,
  replace,
}

/// READ an invoice, in the app (UX gap 0068: the archive could only hand
/// out files — seeing what was invoiced meant downloading a PDF first).
///
/// One sheet for every invoice, whichever list it was opened from: the
/// snapshot header, the positions, the balance, where the document stands
/// in its lifecycle, and every permitted action with a LABEL instead of an
/// icon crammed into a row.
Future<InvoiceAction?> showInvoiceDetailSheet(
  BuildContext context, {
  required Invoice invoice,
  required InvoiceMatch? match,
  required bool canIssue,
  required bool isEu,
  ({int count, DateTime last})? reminder,
  String replacedByNumber = '',
  bool showMemberName = false,
  InvoiceTransmission? transmission,
  InvoiceJourney? journey,
}) =>
    showModalBottomSheet<InvoiceAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _InvoiceDetailBody(
        invoice: invoice,
        match: match,
        canIssue: canIssue,
        isEu: isEu,
        reminder: reminder,
        replacedByNumber: replacedByNumber,
        showMemberName: showMemberName,
        transmission: transmission,
        journey: journey,
      ),
    );

class _InvoiceDetailBody extends StatelessWidget {
  const _InvoiceDetailBody({
    required this.invoice,
    required this.match,
    required this.canIssue,
    required this.isEu,
    required this.reminder,
    required this.replacedByNumber,
    required this.showMemberName,
    required this.transmission,
    required this.journey,
  });

  final Invoice invoice;
  final InvoiceMatch? match;
  final bool canIssue;
  final bool isEu;
  final ({int count, DateTime last})? reminder;
  final String replacedByNumber;
  final bool showMemberName;

  /// The last attempt at posting this invoice to the platform (0073).
  final InvoiceTransmission? transmission;

  /// #812 — where the invoice stands and whose move it is; null while
  /// the process view is off.
  final InvoiceJourney? journey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final currency = moneyFormat(invoice.currency);
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    final status = invoiceLifecycleOf(invoice, match);
    final standingMatch = match != null && !match!.pending ? match : null;
    final sent = transmission;
    // The platform's answer, in the reader's language.
    final sentStatus = switch (sent?.status) {
      EInvoiceSubmissionStatus.accepted =>
        l10n?.invoiceSendStatusAccepted ?? 'accepted',
      EInvoiceSubmissionStatus.rejected =>
        l10n?.invoiceSendStatusRejected ?? 'rejected',
      EInvoiceSubmissionStatus.failed =>
        l10n?.invoiceSendStatusFailed ?? 'not delivered',
      null => '',
    };

    // #812 — the action the journey expects from an issuer, if any.
    final expected = !canIssue
        ? InvoiceAction.downloadPdf
        : switch (journey?.move) {
            InvoiceMove.issuerMatchesPayment => InvoiceAction.markPaid,
            InvoiceMove.issuerReplaces => InvoiceAction.replace,
            InvoiceMove.memberPays ||
            InvoiceMove.memberPaysRemainder
                when journey?.reminderDue != null =>
              InvoiceAction.remind,
            _ => InvoiceAction.downloadPdf,
          };

    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(text, style: theme.textTheme.bodySmall?.copyWith(
            color: muted,
          )),
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header — number, month, status.
              Row(children: [
                Expanded(
                  child: Text(
                    invoice.number,
                    key: const ValueKey('invoice-detail-number'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: invoice.isVoided
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                InvoiceStatusChip(status: status),
              ]),
              // #802/#804 — WHAT this document is. A subscription invoice
              // dated before the month it charges looks like a mistake
              // unless it says so; a settlement is meaningless without
              // the list of what it replaced.
              if (invoice.kind != InvoiceKind.full)
                Padding(
                  key: const ValueKey('invoice-detail-kind'),
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(children: [
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
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ]),
                ),
              line([
                invoicePeriodLabel(context, invoice),
                if (showMemberName && invoice.memberName.isNotEmpty)
                  invoice.memberName,
              ].join(' · ')),
              // #812 — the journey first: the four steps, then the move.
              if (journey case final journey?) ...[
                const SizedBox(height: AppSpacing.md),
                InvoiceJourneyBar(journey: journey),
                const SizedBox(height: AppSpacing.sm),
                InvoiceMoveLine(
                  journey: journey,
                  invoice: invoice,
                  match: match,
                  issuer: canIssue,
                ),
              ],
              const Divider(height: AppSpacing.xl),

              // The SNAPSHOT — what the document itself says, never the
              // live profile (0060).
              line('${l10n?.invoicePdfIssuedOn ?? 'Issued on'} '
                  '${dateFormat.format(invoice.issuedAt)}'
                  '${invoice.issuerName.isEmpty ? '' : ' · '
                      '${l10n?.invoicePdfIssuedBy ?? 'Issued by'} '
                      '${invoice.issuerName}'}'),
              line('${l10n?.invoicePdfBilledTo ?? 'Billed to'}: '
                  '${invoice.memberName}'
                  '${invoice.memberAddress.isEmpty ? '' : ', '
                      '${invoice.memberAddress.replaceAll('\n', ', ')}'}'),
              const Divider(height: AppSpacing.xl),

              // The positions, exactly as the PDF prints them.
              for (final (i, position) in invoice.lines.indexed)
                Padding(
                  key: ValueKey('invoice-detail-line-$i'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(invoiceLineText(l10n, position))),
                    const SizedBox(width: AppSpacing.sm),
                    Text(currency.formatMinor(position.amountCents)),
                  ]),
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
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          '${l10n?.vatPdfVat ?? 'VAT'} '
                          '${_percentLabel(total.percent)}',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ),
                      Text(
                        currency.formatMinor(total.vatCents),
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ]),
                  ),
              Row(children: [
                Expanded(
                  child: Text(
                    l10n?.invoiceBalance ?? 'Balance due',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  currency.formatMinor(invoice.totalCents),
                  key: const ValueKey('invoice-detail-total'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ]),

              // #804 — the trail, both directions. A settlement names
              // every invoice inside it AND their positions; a settled
              // invoice names the document that now carries its balance,
              // because otherwise it just looks unpaid and unchased.
              if (invoice.settles.isNotEmpty) ...[
                const Divider(height: AppSpacing.xl),
                Text(
                  l10n?.settlementRegroups ?? 'This invoice regroups',
                  style: theme.textTheme.titleSmall,
                ),
                for (final source in invoice.settles)
                  Padding(
                    key: ValueKey('settlement-source-${source.invoiceId}'),
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
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
                        ]),
                        // The positions of the ORIGINAL, so the trail
                        // does not stop at a number.
                        for (final position in source.lines)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.md),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  invoiceLineText(l10n, position),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: muted),
                                ),
                              ),
                              Text(
                                currency.formatMinor(position.amountCents),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: muted),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                line(l10n?.settlementVatNote ??
                    'VAT stays declared on the invoices above; this '
                        'document only regroups what is owed.'),
              ],
              if (invoice.settledByInvoiceId != null)
                line(l10n?.settlementSettledBy ??
                    'Regrouped into another invoice — that one is what is '
                        'owed and chased.'),

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
                    l10n?.journeyTimelineTitle ?? 'Timeline',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              if (invoice.replacesNumber.isNotEmpty)
                line('${l10n?.invoicePdfReplaces ?? 'Replaces'} '
                    '${invoice.replacesNumber}'),
              if (replacedByNumber.isNotEmpty)
                line(l10n?.invoiceReplacedBy(replacedByNumber) ??
                    'Replaced by $replacedByNumber'),
              if (standingMatch != null)
                line(l10n?.invoiceMatchSummary(
                      currency.formatMinor(standingMatch.paidCents),
                      dateFormat.format(standingMatch.matchedAt),
                    ) ??
                    'Paid ${currency.formatMinor(standingMatch.paidCents)} '
                        'on ${dateFormat.format(standingMatch.matchedAt)}'),
              if (standingMatch != null && standingMatch.note.isNotEmpty)
                line(standingMatch.note),
              if (reminder != null)
                line('${l10n?.invoiceRemindedBadge(reminder!.count) ??
                    'Reminded ×${reminder!.count}'} · '
                    '${l10n?.invoiceRemindedLast(
                          dateFormat.format(reminder!.last),
                        ) ?? 'last ${dateFormat.format(reminder!.last)}'}'),
              // Did it LEAVE, and what came back (0073). A rehearsal
              // names its environment so it never reads as the real
              // submission (#393).
              if (sent != null)
                line('${l10n?.invoiceSentOn(
                      dateFormat.format(sent.sentAt),
                      sentStatus,
                    ) ?? 'Sent ${dateFormat.format(sent.sentAt)} · '
                        '$sentStatus'}${sent.isTestSend ? ' · '
                        '${sent.environment.toUpperCase()} '
                        '(${l10n?.invoiceSentTestChip ?? 'test'})' : ''}'),
              if (sent != null && sent.externalId.isNotEmpty)
                line(sent.externalId),
              if (invoice.detailed)
                line(l10n?.invoiceAnnexSummary(
                      invoice.detailLedger.length,
                      invoice.attendance.length,
                    ) ??
                    '${l10n?.invoicePdfAnnex ?? 'Annex'}: '
                        '${invoice.detailLedger.length} · '
                        '${invoice.attendance.length}'),
              line('${l10n?.invoicePdfSignature ?? 'Digital signature'} '
                  '${invoice.signature.substring(
                    0,
                    invoice.signature.length < 12
                        ? invoice.signature.length
                        : 12,
                  )}…'),
              const SizedBox(height: AppSpacing.lg),

              // Every permitted action, spelled out. #812 — the one the
              // journey expects from the issuer comes FIRST and filled;
              // otherwise the PDF keeps its historical place.
              ...[
                for (final entry in _actions(context, l10n, status, expected))
                  if (entry.$1 == expected) entry.$2,
                for (final entry in _actions(context, l10n, status, expected))
                  if (entry.$1 != expected) entry.$2,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The permitted actions in their historical order, each tagged so
  /// the build can pull the expected one to the front.
  List<(InvoiceAction, Widget)> _actions(
    BuildContext context,
    AppLocalizations? l10n,
    InvoiceLifecycle status,
    InvoiceAction expected,
  ) =>
      [
        // #514 — see it on screen before any PDF exists.
        (
          InvoiceAction.quickView,
          _action(
            context,
            key: 'invoice-quick-${invoice.id}',
            icon: Icons.bolt_outlined,
            label: l10n?.reportQuickView ?? 'Quick view',
            action: InvoiceAction.quickView,
          ),
        ),
        (
          InvoiceAction.downloadPdf,
          _action(
            context,
            key: 'invoice-download-${invoice.id}',
            icon: Icons.download_outlined,
            label: l10n?.invoiceDownload ?? 'Download PDF',
            action: InvoiceAction.downloadPdf,
            primary: expected == InvoiceAction.downloadPdf,
          ),
        ),
        (
          InvoiceAction.sharePdf,
          _action(
            context,
            key: 'invoice-share-${invoice.id}',
            icon: Icons.share_outlined,
            label: l10n?.invoiceShare ?? 'Share PDF',
            action: InvoiceAction.sharePdf,
          ),
        ),
        // 2014/55/EU: the e-invoice affordance is for EU workspaces.
        if (isEu)
          (
            InvoiceAction.eInvoice,
            _action(
              context,
              key: 'invoice-einvoice-action',
              icon: Icons.code_outlined,
              label: l10n?.invoiceEInvoiceAction ?? 'E-invoice (XML)',
              action: InvoiceAction.eInvoice,
            ),
          ),
        if (canIssue && status == InvoiceLifecycle.open) ...[
          if (invoice.totalCents > 0)
            (
              InvoiceAction.remind,
              _action(
                context,
                key: 'invoice-remind-action',
                icon: Icons.notifications_outlined,
                label: l10n?.invoiceRemindAction ?? 'Send a reminder',
                action: InvoiceAction.remind,
                primary: expected == InvoiceAction.remind,
              ),
            ),
          (
            InvoiceAction.markPaid,
            _action(
              context,
              key: 'invoice-match-action',
              icon: Icons.price_check_outlined,
              label: l10n?.invoiceMatchAction ?? 'Mark as paid',
              action: InvoiceAction.markPaid,
              primary: expected == InvoiceAction.markPaid,
            ),
          ),
          (
            InvoiceAction.markErroneous,
            _action(
              context,
              key: 'invoice-void-action',
              icon: Icons.block_outlined,
              label: l10n?.invoiceVoidAction ?? 'Mark erroneous',
              action: InvoiceAction.markErroneous,
              danger: true,
            ),
          ),
        ],
        // A correction chain, never a fork (0061): only an erroneous
        // invoice that nothing replaces yet can be re-issued.
        if (canIssue &&
            status == InvoiceLifecycle.erroneous &&
            replacedByNumber.isEmpty)
          (
            InvoiceAction.replace,
            _action(
              context,
              key: 'invoice-replace-action',
              icon: Icons.published_with_changes_outlined,
              label: l10n?.invoiceReplaceAction ?? 'Issue replacement',
              action: InvoiceAction.replace,
              primary: expected == InvoiceAction.replace,
            ),
          ),
      ];

  Widget _action(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String label,
    required InvoiceAction action,
    bool primary = false,
    bool danger = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final child = Row(children: [
      Icon(icon, size: 20, color: danger ? colors.error : null),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(
          label,
          style: danger ? TextStyle(color: colors.error) : null,
        ),
      ),
    ]);
    void onPressed() => Navigator.of(context).pop(action);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: primary
          ? FilledButton(
              key: ValueKey(key),
              onPressed: onPressed,
              child: child,
            )
          : OutlinedButton(
              key: ValueKey(key),
              onPressed: onPressed,
              child: child,
            ),
    );
  }
}

/// '20 %', '5.5 %' — a rate beside its caption.
String _percentLabel(double percent) =>
    '${percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent} %';
