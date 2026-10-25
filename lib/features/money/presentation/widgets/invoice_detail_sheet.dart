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
import '../../application/invoice_detail_facts.dart';
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

  /// #812 — the action the journey expects from an issuer, if any.
  InvoiceAction get _expected => !canIssue
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

  Widget _line(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final association = ref.watch(sellerIsAssociationProvider);
    // #1913 — an active dunning hold, for whoever issues invoices.
    final holds = canIssue ? ref.watch(dunningHoldsProvider).value : null;
    final heldReason = holds == null ? null : holds[invoice.id];
    final facts = InvoiceDetailFacts.of(invoice, match,
        canIssue: canIssue,
        showMemberName: showMemberName,
        heldReason: heldReason);
    final status = invoiceLifecycleOf(invoice, match);

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
              ..._header(context, status, facts, sections),
              const Divider(height: AppSpacing.xl),
              ..._snapshot(context, facts),
              const Divider(height: AppSpacing.xl),

              ReminderEvidenceList(invoiceId: invoice.id),
              ...sections.amounts(context, association: association),

              // #804 — the trail, both directions. A settlement names
              // every invoice inside it AND their positions; a settled
              // invoice names the document that now carries its balance,
              // because otherwise it just looks unpaid and unchased.
              if (facts.showSettlementTrail)
                ...sections.settlementTrail(context, association: association),
              if (facts.showFolded) _folded(context),

              ...sections.timeline(context, facts.standingMatch),
              // #841 — who released this document, in what order, and
              // when. Silent when no rule ever governed the match.
              if (match?.eventId case final eventId?)
                EventValidationTrail(eventId: eventId),
              const SizedBox(height: AppSpacing.lg),

              // Every permitted action, spelled out. #812 — the one the
              // journey expects from the issuer comes FIRST and filled;
              // otherwise the PDF keeps its historical place.
              ..._actions(context, status, _expected, heldReason),
            ],
          ),
        ),
      ),
    );
  }

  /// Number, status, what the document is, its month, and the journey.
  List<Widget> _header(BuildContext context, InvoiceLifecycle status,
      InvoiceDetailFacts facts, InvoiceDetailSections sections) {
    final theme = Theme.of(context);
    return [
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
      if (facts.showKindRow) sections.kindRow(context),
      _line(context, [
        invoicePeriodLabel(context, invoice),
        ?facts.client,
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
    ];
  }

  /// The SNAPSHOT — what the document itself says, never the live
  /// profile (0060) — and the issuer's notes on it.
  List<Widget> _snapshot(BuildContext context, InvoiceDetailFacts facts) {
    final l10n = context.l10n;
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    return [
      _line(context, '${l10n.invoicePdfIssuedOn} '
          '${dateFormat.format(invoice.issuedAt)}'
          '${invoice.issuerName.isEmpty ? '' : ' · '
              '${l10n.invoicePdfIssuedBy} '
              '${invoice.issuerName}'}'),
      // #1913 — why reminders stop, and a due date nobody agreed
      // to, said where the issuer decides.
      if (facts.heldReason case final reason?)
        _line(context,
            l10n.invoiceHeldNote(dunningHoldReasonLabel(l10n, reason))),
      if (facts.showMaturityReview) _line(context, l10n.invoiceMaturityReview),
      _line(context, '${l10n.invoicePdfBilledTo}: ${facts.billedTo}'),
    ];
  }

  /// A settled invoice names the settlement that carries its balance.
  Widget _folded(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Container(
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
    );
  }

}
