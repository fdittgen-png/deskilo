// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../events/presentation/widgets/event_validation_trail.dart';
import '../../../../core/i18n/money_format.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/einvoice_gateway.dart';
import '../../domain/billing_rules.dart';
import '../../domain/invoice.dart';
import '../../providers/money_providers.dart';
import '../invoice_journey.dart';
import '../../domain/invoice_line_text.dart';
import '../report_strings_l10n.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import 'invoice_journey_view.dart';
import '../invoice_actions.dart';
import '../../../workspace/providers/workspace_providers.dart';
import 'invoice_sheet_actions.dart';

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
/// #1217 — the sheet RUNS what its buttons ask for.
///
/// It used to pop an `InvoiceAction` and leave the caller to act on it.
/// Six surfaces opened it and three of them awaited the future and threw
/// the result away, so Download PDF, Quick view, Share PDF and
/// E-invoice were inert on the member's own Invoices tab, on an invoice
/// opened from the agenda, and on one opened from a message reference —
/// while the same buttons worked from the three admin lists.
///
/// A returned value the compiler lets you discard was the whole bug, so
/// there is no longer one to discard: the action is dispatched here,
/// once, where it cannot be forgotten.
Future<void> showInvoiceDetailSheet(
  BuildContext context, {
  required WidgetRef ref,
  required Invoice invoice,
  required InvoiceMatch? match,
  required bool canIssue,
  required bool isEu,
  ({int count, DateTime last})? reminder,
  String replacedByNumber = '',
  bool showMemberName = false,
  InvoiceTransmission? transmission,
  InvoiceJourney? journey,
  // #831 — the settlement a regrouped source went into.
  String settledByNumber = '',
}) async {
  final action = await showModalBottomSheet<InvoiceAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _InvoiceDetailBody(
        settledByNumber: settledByNumber,
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
  if (action == null || !context.mounted) return;
  // The country comes from the workspace rather than from a parameter,
  // for the same reason the seller kind does below: six callers, six
  // chances to pass the wrong one.
  await runInvoiceAction(
    context,
    ref,
    action,
    invoice,
    countryCode: ref.read(currentWorkspaceProvider).value?.countryCode ?? '',
  );
}

/// #910 — the seller kind is READ here, not passed in. Every one of the
/// six callers forgot the flag, so an association's own app called its
/// participations "subscriptions" while the PDF beside it said
/// "participation" — the very word #870 exists to keep off the
/// document. A parameter nobody remembers is not a setting.
class _InvoiceDetailBody extends ConsumerWidget {
  const _InvoiceDetailBody({
    this.settledByNumber = '',
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

  final String settledByNumber;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final association = ref.watch(sellerIsAssociationProvider);
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
                if (showMemberName && invoice.clientName.isNotEmpty)
                  invoice.clientName,
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
              // #910 — "Billed to: , SASU KaloA, …": the name was empty
              // and its comma stayed behind. Build the parts, then join.
              line('${l10n?.invoicePdfBilledTo ?? 'Billed to'}: '
                  '${[
                    invoice.clientName,
                    ...invoice.memberAddress.split('\n'),
                  ].map((p) => p.trim()).where((p) => p.isNotEmpty).join(', ')}'),
              const Divider(height: AppSpacing.xl),

              // The positions, exactly as the PDF prints them.
              for (final (i, position) in invoice.lines.indexed)
                Padding(
                  key: ValueKey('invoice-detail-line-$i'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(
                        child: Text(invoiceLineText(reportStringsOf(l10n), position,
                            association: association,
                            period: invoice.period))),
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
                                  invoiceLineText(reportStringsOf(l10n), position,
                                      association: association,
                                      period: source.period),
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
                Container(
                  key: const ValueKey('invoice-detail-folded'),
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  padding: AppSpacing.mdAll,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Text(
                    [
                      if (settledByNumber.isNotEmpty)
                        l10n?.settlementFoldedIn(settledByNumber) ??
                            'Regrouped in $settledByNumber'
                      else
                        l10n?.settlementSettledBy ??
                            'Regrouped into another invoice — that one is what is owed and chased.',
                      l10n?.settlementDocumentationOnly ??
                          'Documentation only — every operation happens on the regrouping invoice.',
                    ].join(' '),
                    style: theme.textTheme.bodySmall,
                  ),
                ),

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
              // #841 — who released this document, in what order, and
              // when. Silent when no rule ever governed the match.
              if (match?.eventId case final eventId?)
                EventValidationTrail(eventId: eventId),
              const SizedBox(height: AppSpacing.lg),

              // Every permitted action, spelled out. #812 — the one the
              // journey expects from the issuer comes FIRST and filled;
              // otherwise the PDF keeps its historical place.
              ...[
                ...() {
                  final actions = InvoiceSheetActions(
                    invoice: invoice,
                    canIssue: canIssue,
                    isEu: isEu,
                    replacedByNumber: replacedByNumber,
                    onAction: (InvoiceAction a) =>
                        Navigator.of(context).pop(a),
                  );
                  final all = actions.build(context, l10n, status, expected);
                  return [
                    // The expected next move first, the rest after it.
                    for (final e in all)
                      if (e.$1 == expected && actions.allowed(e.$1)) e.$2,
                    for (final e in all)
                      if (e.$1 != expected && actions.allowed(e.$1)) e.$2,
                  ];
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }

}

/// '20 %', '5.5 %' — a rate beside its caption.
String _percentLabel(double percent) =>
    '${percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent} %';
