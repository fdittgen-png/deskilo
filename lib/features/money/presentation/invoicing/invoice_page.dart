// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-d -- one invoice: who, how much is open of the total, its status
// in words, what happened (dated, the last line "now"), what was invoiced,
// the PDF, and "More" with every action the invoice had before (section 4
// of the final design). The main action sits in a bottom bar under the
// thumb: Share reminder n (by hand), Confirm / Not received (a declared
// payment), Match the payment, Record the refund (a credit note) or the
// e-invoice to fix. A phone opens it as a page; a desk keeps it beside
// the list ([panel]).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/story.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/invoice_detail_facts.dart';
import '../../application/receivables.dart';
import '../../domain/dunning.dart';
import '../../providers/money_providers.dart';
import '../dunning_hold_actions.dart';
import '../invoice_status.dart';
import '../widgets/invoice_detail_sheet.dart' show InvoiceApprovals;
import '../widgets/reminder_evidence_list.dart';
import 'invoice_details_section.dart';
import 'invoice_page_bar.dart';
import 'invoice_page_parts.dart';
import 'invoicing_reads.dart';

/// What the story needs beyond the receivable: the hold's reason, and the
/// day a cancelled invoice was cancelled with the number that replaced it.
typedef _StoryFacts = ({
  String? heldReason,
  DateTime? cancelledOn,
  String? replacedBy,
});

/// Opens [invoiceId]'s page over the current one (a phone, a narrow
/// window), full screen.
Future<void> openInvoicePage(BuildContext context, String invoiceId) =>
    showDialog<void>(
      context: context,
      // Its own messenger: what an action says is said once, on the page,
      // not also on the home under it.
      builder: (_) => Dialog.fullscreen(
        child: ScaffoldMessenger(child: InvoicePage(invoiceId: invoiceId)),
      ),
    );

class InvoicePage extends ConsumerWidget {
  const InvoicePage({super.key, required this.invoiceId, this.onClose});

  final String invoiceId;

  /// Set when the page is a panel beside the list: its close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final read = ref.watch(invoicesProvider);
    final invoices = read.value;
    final invoice = invoices?.where((i) => i.id == invoiceId).firstOrNull;
    // #3680 — the status is stated once the match is read (a failed read is
    // a named source that withholds actions).
    final matchRead = ref.watch(invoiceMatchesProvider);
    if (invoice == null || !matchRead.hasValue && !matchRead.hasError) {
      // Still loading, or no longer readable: either way the page keeps a
      // way out.
      final unreadable = invoice == null && (read.hasError || invoices != null);
      return Scaffold(
        key: ValueKey('invoice-page-$invoiceId'),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [_closeButton(context)],
        ),
        body: unreadable
            ? Center(
                child: Padding(
                  padding: AppSpacing.mdAll,
                  child: Text(
                    l.invoicePageUnreadable,
                    key: const ValueKey('invoice-page-unreadable'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : const LoadingView(),
      );
    }
    final receivables = ref.watch(invoicingReaderProvider).read([invoice]);
    final match = (matchRead.value ?? const {})[invoice.id]; // empty-ok: a failed read is a named source; the page offers no action then
    final lifecycle = invoiceLifecycleOf(invoice, match);
    final replacement = invoices
        ?.where((i) => i.replacesInvoiceId == invoice.id)
        .firstOrNull;
    final heldReason = ref.watch(dunningHoldsProvider).value?[invoice.id];
    final facts = InvoiceDetailFacts.of(
      invoice,
      match,
      canIssue: true,
      showMemberName: false,
    );
    final r = receivables.isEmpty ? null : receivables.first;
    // The business's calendar day, from the workspace's own context.
    final today = ref
        .watch(invoicingBusinessProvider)
        .dayOf(ref.watch(clockProvider).now());
    final rules =
        ref.watch(dunningRulesProvider).value ?? DunningRules.defaults;
    final mode = rules.automatic ? ReminderMode.automatic : ReminderMode.byHand;
    return Scaffold(
      key: ValueKey('invoice-page-$invoiceId'),
      appBar: AppBar(
        automaticallyImplyLeading: onClose == null,
        title: Text(l.invoicePageTitle(invoice.number)),
        actions: [
          InvoiceMoreMenu(
            invoice: invoice,
            receivable: r,
            awaitsReplacement:
                lifecycle == InvoiceLifecycle.erroneous && replacement == null,
          ),
          if (onClose != null) _closeButton(context),
        ],
      ),
      // While a source the bar reads has failed, the bar would offer an
      // action on a guess: it stays away until the source reads again.
      bottomNavigationBar: r == null || _barSourceFailed(ref)
          ? null
          : InvoicePageBar(
              invoice: invoice,
              receivable: r,
              today: today,
              mode: mode,
            ),
      body: ListView(
        padding: AppSpacing.mdAll,
        children: [
          if (r != null) ...[
            InvoiceSummaryCard(
              invoice: invoice,
              receivable: r,
              today: today,
              termNote: facts.showMaturityReview
                  ? l.invoiceMaturityReview
                  : null,
              closure: _closureOf(context, invoice, match, replacement),
            ),
            const SizedBox(height: AppSpacing.md),
            KitCard(
              key: const ValueKey('invoice-page-story'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.sm,
                children: [
                  KitLabel(l.invoicePageWhatHappened),
                  _story(context, ref, r, today, (
                    heldReason: heldReason,
                    cancelledOn: lifecycle == InvoiceLifecycle.erroneous
                        ? invoice.voidedAt
                        : null,
                    replacedBy: replacement?.number,
                  )),
                  // The reminders sent and their evidence, and who released
                  // the payment: collapsed, so the page stays calm.
                  if (r.remindersSent > 0)
                    Material(
                      // Its tile paints on the card, not under it.
                      type: MaterialType.transparency,
                      child: ExpansionTile(
                        key: const ValueKey('invoice-page-reminders'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(l.invoicePageReminders(r.remindersSent)),
                        children: [ReminderEvidenceList(invoiceId: invoice.id)],
                      ),
                    ),
                  if (match?.eventId case final eventId?)
                    Material(
                      // Its tile paints on the card, not under it.
                      type: MaterialType.transparency,
                      child: ExpansionTile(
                        key: const ValueKey('invoice-page-approvals'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(l.invoicePageApprovals),
                        children: [InvoiceApprovals(eventId: eventId)],
                      ),
                    ),
                  // What the old sheet showed: who issued it, billed to,
                  // the amounts, the settlement trail, the transmission.
                  InvoiceDetailsSection(
                    invoice: invoice,
                    replacedByNumber: replacement?.number ?? '',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          InvoiceLinesCard(invoice: invoice),
          const SizedBox(height: AppSpacing.md),
          InvoicePdfCard(invoice: invoice),
        ],
      ),
    );
  }

  /// Closes the page: the panel's own close beside the list, else the
  /// dialog or route the page was opened in.
  Widget _closeButton(BuildContext context) => IconButton(
    key: const ValueKey('invoice-page-close'),
    tooltip: context.l10n.invoicePageClose,
    onPressed: onClose ?? () => Navigator.of(context).maybePop(),
    icon: const Icon(Icons.close),
  );

  /// Whether a source the bottom bar decides from has failed: the
  /// invoices, matches, reminders, holds or e-invoice transmissions.
  static bool _barSourceFailed(WidgetRef ref) =>
      ref.watch(invoicingFailedSourcesProvider).isNotEmpty;

  /// How a cancelled invoice ended, never a bare "Cancelled": replaced by
  /// another (which opens it), not replaced yet, or its remainder written
  /// off. Null while the invoice has not ended that way.
  Widget? _closureOf(
    BuildContext context,
    Invoice invoice,
    InvoiceMatch? match,
    Invoice? replacement,
  ) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final quiet = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    switch (invoiceLifecycleOf(invoice, match)) {
      case InvoiceLifecycle.erroneous:
        if (replacement == null) {
          return Text(l.invoicePageCancelledNotReplaced, style: quiet);
        }
        return InkWell(
          key: const ValueKey('invoice-page-replaced-by'),
          onTap: () => openInvoicePage(context, replacement.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l.invoicePageCancelledReplaced(replacement.number),
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        );
      case InvoiceLifecycle.remainderCancelled:
        final rest = invoice.totalCents - (match?.paidCents ?? 0);
        return Text(
          l.invoicePageRemainderWrittenOff(
            appFormatOf(context).moneyIn(invoice.currency).formatMinor(rest),
          ),
          style: quiet,
        );
      case _:
        return null;
    }
  }

  Widget _story(
    BuildContext context,
    WidgetRef ref,
    Receivable r,
    DateTime today,
    _StoryFacts facts,
  ) {
    final (:heldReason, :cancelledOn, :replacedBy) = facts;
    final l = context.l10n;
    final format = appFormatOf(context);
    String day(DateTime? d) =>
        d == null ? '' : format.dates(DateShape.monthDay).format(d);
    final reminder = ref.watch(invoiceRemindersProvider).value?[r.invoiceId];
    final late = r.isLateOn(today);
    final lines = <StoryLine>[
      (text: l.invoicePageStoryIssued, when: day(r.issuedOn)),
      if (late && r.dueOn != null)
        (text: l.invoicePageStoryDue, when: day(r.dueOn)),
      for (var k = 1; k <= r.remindersSent; k++)
        (
          text: l.invoicePageStoryReminder(k),
          // The last reminder's day is recorded; the earlier ones are counted.
          when: k == r.remindersSent ? day(reminder?.last) : '',
        ),
      if (r.paymentDeclared)
        (
          text: l.invoicePageStoryDeclared(r.customerName),
          when: day(r.declaredOn),
        ),
      if (r.paidOn != null) (text: l.invoicePageStoryPaid, when: day(r.paidOn)),
      // A cancellation ends the story, dated, saying how it ended.
      if (cancelledOn != null)
        (
          text: replacedBy == null
              ? l.invoicePageCancelledNotReplaced
              : l.invoicePageCancelledReplaced(replacedBy),
          when: day(cancelledOn),
        ),
    ];
    final now = _nowOf(l, format, r, today, heldReason);
    return Story(
      lines: lines,
      now: now == null ? null : (text: now, when: l.invoicePageToday),
    );
  }

  /// What is awaited today, or null when the story has ended.
  static String? _nowOf(
    AppLocalizations l,
    AppFormat format,
    Receivable r,
    DateTime today,
    String? heldReason,
  ) {
    if (r.stage == ReceivableStage.refundOwed) return l.invoicePageNowRefund;
    if (!r.isOutstanding) return null;
    if (r.eInvoiceRejected) return l.invoicePageNowRejected;
    if (r.paymentDeclared) return l.invoicePageNowDeclared;
    if (r.awaitingSecondApproval) return l.invoicePageNowApproval;
    if (r.paymentToMatch) return l.invoicePageNowToMatch;
    if (r.awaitingCustomerConfirmation) return l.invoicePageNowCustomer;
    if (r.onHold) {
      // On hold, and why: the reason the issuer gave.
      return heldReason == null
          ? l.invoicePageNowHold
          : l.invoiceHeldNote(dunningHoldReasonLabel(l, heldReason));
    }
    if (r.isLateOn(today)) {
      if (r.remindersExhausted) {
        // Write-off is named only where More offers it.
        return invoiceWriteOffOffered(r)
            ? l.invoicePageNowEveryReminder
            : l.invoicePageNowEveryReminderNoWriteOff;
      }
      if (r.reminderDueLevel case final level?) {
        return l.invoicePageNowReminder(level);
      }
      return l.invoicePageNowWaiting;
    }
    final due = r.dueOn;
    return due == null
        ? l.invoicePageNowWaiting
        : l.invoicePageNowDue(format.dates(DateShape.monthDay).format(due));
  }
}
