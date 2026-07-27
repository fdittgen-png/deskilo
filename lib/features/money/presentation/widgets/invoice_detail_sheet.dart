// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice.dart';
import '../invoice_line_text.dart';
import '../invoice_status.dart';
import '../period_label.dart';

/// What the reader asked for after looking at an invoice. The sheet only
/// DECIDES — the screen runs the action with its own live context, so no
/// action ever depends on a sheet that is being dismissed.
enum InvoiceAction {
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
  });

  final Invoice invoice;
  final InvoiceMatch? match;
  final bool canIssue;
  final bool isEu;
  final ({int count, DateTime last})? reminder;
  final String replacedByNumber;
  final bool showMemberName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final currency = NumberFormat.simpleCurrency(name: invoice.currency);
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    final status = invoiceLifecycleOf(invoice, match);
    final standingMatch = match != null && !match!.pending ? match : null;

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
              line([
                invoicePeriodLabel(context, invoice),
                if (showMemberName && invoice.memberName.isNotEmpty)
                  invoice.memberName,
              ].join(' · ')),
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
                    Text(currency.format(position.amountCents / 100)),
                  ]),
                ),
              const Divider(),
              Row(children: [
                Expanded(
                  child: Text(
                    l10n?.invoiceBalance ?? 'Balance due',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  currency.format(invoice.totalCents / 100),
                  key: const ValueKey('invoice-detail-total'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ]),

              // Lifecycle facts: the correction chain, the payment that
              // closed it, the reminders sent, the annex it carries.
              if (invoice.replacesNumber.isNotEmpty)
                line('${l10n?.invoicePdfReplaces ?? 'Replaces'} '
                    '${invoice.replacesNumber}'),
              if (replacedByNumber.isNotEmpty)
                line(l10n?.invoiceReplacedBy(replacedByNumber) ??
                    'Replaced by $replacedByNumber'),
              if (standingMatch != null)
                line(l10n?.invoiceMatchSummary(
                      currency.format(standingMatch.paidCents / 100),
                      dateFormat.format(standingMatch.matchedAt),
                    ) ??
                    'Paid ${currency.format(standingMatch.paidCents / 100)} '
                        'on ${dateFormat.format(standingMatch.matchedAt)}'),
              if (standingMatch != null && standingMatch.note.isNotEmpty)
                line(standingMatch.note),
              if (reminder != null)
                line('${l10n?.invoiceRemindedBadge(reminder!.count) ??
                    'Reminded ×${reminder!.count}'} · '
                    '${l10n?.invoiceRemindedLast(
                          dateFormat.format(reminder!.last),
                        ) ?? 'last ${dateFormat.format(reminder!.last)}'}'),
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

              // Every permitted action, spelled out.
              _action(
                context,
                key: 'invoice-download-${invoice.id}',
                icon: Icons.download_outlined,
                label: l10n?.invoiceDownload ?? 'Download PDF',
                action: InvoiceAction.downloadPdf,
                primary: true,
              ),
              _action(
                context,
                key: 'invoice-share-${invoice.id}',
                icon: Icons.share_outlined,
                label: l10n?.invoiceShare ?? 'Share PDF',
                action: InvoiceAction.sharePdf,
              ),
              // 2014/55/EU: the e-invoice affordance is for EU workspaces.
              if (isEu)
                _action(
                  context,
                  key: 'invoice-einvoice-action',
                  icon: Icons.code_outlined,
                  label: l10n?.invoiceEInvoiceAction ?? 'E-invoice (XML)',
                  action: InvoiceAction.eInvoice,
                ),
              if (canIssue && status == InvoiceLifecycle.open) ...[
                if (invoice.totalCents > 0)
                  _action(
                    context,
                    key: 'invoice-remind-action',
                    icon: Icons.notifications_outlined,
                    label: l10n?.invoiceRemindAction ?? 'Send a reminder',
                    action: InvoiceAction.remind,
                  ),
                _action(
                  context,
                  key: 'invoice-match-action',
                  icon: Icons.price_check_outlined,
                  label: l10n?.invoiceMatchAction ?? 'Mark as paid',
                  action: InvoiceAction.markPaid,
                ),
                _action(
                  context,
                  key: 'invoice-void-action',
                  icon: Icons.block_outlined,
                  label: l10n?.invoiceVoidAction ?? 'Mark erroneous',
                  action: InvoiceAction.markErroneous,
                  danger: true,
                ),
              ],
              // A correction chain, never a fork (0061): only an erroneous
              // invoice that nothing replaces yet can be re-issued.
              if (canIssue &&
                  status == InvoiceLifecycle.erroneous &&
                  replacedByNumber.isEmpty)
                _action(
                  context,
                  key: 'invoice-replace-action',
                  icon: Icons.published_with_changes_outlined,
                  label: l10n?.invoiceReplaceAction ?? 'Issue replacement',
                  action: InvoiceAction.replace,
                ),
            ],
          ),
        ),
      ),
    );
  }

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
