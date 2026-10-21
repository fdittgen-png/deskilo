// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../events/presentation/widgets/event_validation_trail.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/billing_rules.dart';
import '../../domain/einvoice_gateway.dart';
import '../../domain/invoice.dart';
import '../../providers/money_providers.dart';
import '../dunning_hold_actions.dart';
import '../invoice_actions.dart';
import '../invoice_journey.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import 'invoice_detail_sections.dart';
import 'invoice_journey_view.dart';
import 'invoice_sheet_actions.dart';
import 'reminder_evidence_list.dart';

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
  // #1913 — place or release a dunning hold.
  dunningHold,
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
  final action = await showAppSheet<InvoiceAction>(
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

  /// Every permitted action; the one the journey expects comes first.
  List<Widget> _actions(
    BuildContext context,
    InvoiceLifecycle status,
    InvoiceAction expected,
    String? heldReason,
  ) {
    final l10n = context.l10n;
          final actions = InvoiceSheetActions(
            invoice: invoice,
            heldReason: heldReason,
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final association = ref.watch(sellerIsAssociationProvider);
    // #1913 — an active dunning hold, for whoever issues invoices.
    final holds = canIssue ? ref.watch(dunningHoldsProvider).value : null;
    final heldReason = holds == null ? null : holds[invoice.id];
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    final status = invoiceLifecycleOf(invoice, match);
    final standingMatch = match != null && !match!.pending ? match : null;
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

    final sections = InvoiceDetailSections(
      invoice: invoice,
      canIssue: canIssue,
      isEu: isEu,
      reminder: reminder,
      replacedByNumber: replacedByNumber,
      transmission: transmission,
      journey: journey,
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
              if (invoice.kind != InvoiceKind.full) sections.kindRow(context),
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
              line('${l10n.invoicePdfIssuedOn} '
                  '${dateFormat.format(invoice.issuedAt)}'
                  '${invoice.issuerName.isEmpty ? '' : ' · '
                      '${l10n.invoicePdfIssuedBy} '
                      '${invoice.issuerName}'}'),
              // #910 — "Billed to: , SASU KaloA, …": the name was empty
              // and its comma stayed behind. Build the parts, then join.
              // #1913 — why reminders stop, and a due date nobody agreed
              // to, said where the issuer decides.
              if (canIssue && heldReason != null)
                line(l10n.invoiceHeldNote(
                        dunningHoldReasonLabel(l10n, heldReason))),
              if (canIssue &&
                  invoice.maturityBasis != null &&
                  invoice.maturityBasis != 'document_term')
                line(l10n.invoiceMaturityReview),
              line('${l10n.invoicePdfBilledTo}: '
                  '${[
                    invoice.clientName,
                    ...invoice.memberAddress.split('\n'),
                  ].map((p) => p.trim()).where((p) => p.isNotEmpty).join(', ')}'),
              const Divider(height: AppSpacing.xl),

              ReminderEvidenceList(invoiceId: invoice.id),
              ...sections.amounts(context, association: association),

              // #804 — the trail, both directions. A settlement names
              // every invoice inside it AND their positions; a settled
              // invoice names the document that now carries its balance,
              // because otherwise it just looks unpaid and unchased.
              if (invoice.settles.isNotEmpty)
                ...sections.settlementTrail(context, association: association),
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
                        l10n.settlementFoldedIn(settledByNumber)
                      else
                        l10n.settlementSettledBy,
                      l10n.settlementDocumentationOnly,
                    ].join(' '),
                    style: theme.textTheme.bodySmall,
                  ),
                ),

              ...sections.timeline(context, standingMatch),
              // #841 — who released this document, in what order, and
              // when. Silent when no rule ever governed the match.
              if (match?.eventId case final eventId?)
                EventValidationTrail(eventId: eventId),
              const SizedBox(height: AppSpacing.lg),

              // Every permitted action, spelled out. #812 — the one the
              // journey expects from the issuer comes FIRST and filled;
              // otherwise the PDF keeps its historical place.
              ..._actions(context, status, expected, heldReason),
            ],
          ),
        ),
      ),
    );
  }

}
