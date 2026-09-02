// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice.dart';
import '../../providers/invoicing_wizard_providers.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../invoice_journey.dart';
import 'invoice_journey_view.dart';
import 'register_payment_sheet.dart';
import 'settlement_sheet.dart';
import 'wizard_context.dart';
import 'wizard_steps_issue.dart';

/// #827 — step 5: the payments members declared that wait for a
/// decision, decided here; and the payments that reached the workspace
/// (bank, cash) registered for a member.
class WizardPaymentsStep extends ConsumerWidget {
  const WizardPaymentsStep(this.wiz, {super.key});

  final WizardContext wiz;

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    WorkspaceEvent event, {
    required bool accept,
  }) async {
    final l10n = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'wizard payment decision failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () =>
          ref.read(eventRepositoryProvider).respond(event.id, accept: accept),
    );
    if (!ok) return;
    ref
      ..invalidate(eventsProvider)
      ..invalidate(invoiceMatchesProvider);
    ref
        .read(invoicingWizardControllerProvider.notifier)
        .bump((t) => t.copyWith(paymentsDecided: t.paymentsDecided + 1));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = wiz.pending;
    final me = ref.watch(myMemberProvider).value?.id;
    return ListView(
      children: [
        WizardHint(l10n?.wizardPaymentsHint ??
            'What members declared waits for your confirmation below. A '
                'payment that reached the account without a declaration is '
                'registered here — the member then confirms it.'),
        FilledButton.tonalIcon(
          key: const ValueKey('wizard-register-payment'),
          icon: const Icon(Icons.add_card_outlined),
          label: Text(l10n?.registerPaymentTitle ?? 'Register a payment'),
          onPressed: () async {
            final done = await showRegisterPaymentSheet(context, ref);
            if (done) {
              ref.read(invoicingWizardControllerProvider.notifier).bump(
                  (t) => t.copyWith(
                      paymentsRegistered: t.paymentsRegistered + 1));
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (!wiz.loading && pending.isEmpty)
          WizardNothing(
            l10n?.wizardPaymentsNone ?? 'No declared payment waits for you.',
            stepKey: 'payments',
          ),
        for (final event in pending)
          Card(
            key: ValueKey('wizard-payment-${event.id}'),
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(wiz.names[event.subjectMemberId] ?? ''),
              subtitle: Text([
                wiz.currency.formatMinor(
                    (event.payload['amount_cents'] as num?)?.toInt() ?? 0),
                if (event.payload['method'] is String)
                  event.payload['method'] as String,
                if (event.payload['paid_on'] is String)
                  event.payload['paid_on'] as String,
              ].join(' · ')),
              // The declaring member never validates their own line.
              trailing: event.actorMemberId == me
                  ? Text(l10n?.wizardMatchPending ?? 'Awaiting validation')
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        key: ValueKey('wizard-payment-reject-${event.id}'),
                        icon: const Icon(Icons.close),
                        tooltip: l10n?.wizardPaymentReject ?? 'Reject',
                        onPressed: () =>
                            _decide(context, ref, event, accept: false),
                      ),
                      IconButton.filled(
                        key: ValueKey('wizard-payment-accept-${event.id}'),
                        icon: const Icon(Icons.check),
                        tooltip: l10n?.wizardPaymentAccept ?? 'Confirm',
                        onPressed: () =>
                            _decide(context, ref, event, accept: true),
                      ),
                    ]),
            ),
          ),
      ],
    );
  }
}

/// #827 — step 6: every open invoice against the member's credit; a
/// row with credit on the account opens the match dialog.
class WizardMatchStep extends ConsumerWidget {
  const WizardMatchStep(this.wiz, {super.key});

  final WizardContext wiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final open = wiz.open;
    if (!wiz.loading && open.isEmpty) {
      return WizardNothing(
        l10n?.wizardMatchNone ?? 'Every invoice is paid or closed.',
        stepKey: 'match',
      );
    }
    return ListView(
      children: [
        WizardHint(l10n?.wizardMatchHint ??
            'An invoice is paid once a real payment is matched to it. '
                'Rows with credit on the member\'s account are ready.'),
        for (final invoice in open)
          Consumer(builder: (context, ref, _) {
            final match = wiz.matches[invoice.id];
            final pending = match != null && match.status == 'pending';
            final credit =
                ref.watch(memberAccountProvider(invoice.memberId)).value?.creditCents ??
                    0;
            final ready = !pending && credit > 0;
            return Card(
              key: ValueKey('wizard-match-row-${invoice.id}'),
              child: ListTile(
                leading: Icon(
                  ready ? Icons.link : Icons.hourglass_empty,
                  color: ready ? theme.colorScheme.primary : null,
                ),
                title: Text(invoice.memberName),
                subtitle: Text([
                  invoiceLine(wiz, invoice),
                  if (pending)
                    l10n?.wizardMatchPending ?? 'Awaiting validation'
                  else if (credit > 0)
                    l10n?.wizardMatchCredit(wiz.currency.formatMinor(credit)) ??
                        'Credit available: ${wiz.currency.formatMinor(credit)}'
                  else
                    l10n?.wizardMatchNoCredit ?? 'No payment on the account yet',
                ].join(' · ')),
                trailing: ready
                    ? FilledButton.tonal(
                        key: ValueKey('wizard-match-${invoice.id}'),
                        onPressed: () async {
                          await matchInvoiceToPayment(context, ref, invoice);
                          ref
                              .read(invoicingWizardControllerProvider.notifier)
                              .bump((t) => t.copyWith(matched: t.matched + 1));
                        },
                        child: Text(l10n?.wizardMatchAction ?? 'Match'),
                      )
                    : null,
              ),
            );
          }),
      ],
    );
  }
}

/// #827 — step 7: what stays open, closed by governance — regroup a
/// member's several invoices into one, write off a remainder, refund a
/// credit note.
class WizardCloseStep extends ConsumerWidget {
  const WizardCloseStep(this.wiz, {super.key});

  final WizardContext wiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plan = wiz.close;
    final controller = ref.read(invoicingWizardControllerProvider.notifier);
    if (!wiz.loading && plan.groups.isEmpty && plan.refunds.isEmpty) {
      return WizardNothing(
        l10n?.wizardCloseNone ?? 'Nothing to regroup, write off or refund.',
        stepKey: 'close',
      );
    }
    return ListView(
      children: [
        WizardHint(l10n?.wizardCloseHint ??
            'A member with several open invoices can pay ONE; a partly '
                'paid invoice can have its remainder written off; a credit '
                'note is refunded. Each goes through validation.'),
        for (final group in plan.groups) ...[
          if (group.canSettle)
            Card(
              key: ValueKey('wizard-settle-row-${group.memberId}'),
              child: ListTile(
                leading: const Icon(Icons.merge_outlined),
                title: Text(group.memberName),
                subtitle: Text(group.open.map((i) => i.number).join(', ')),
                trailing: FilledButton.tonal(
                  key: ValueKey('wizard-settle-${group.memberId}'),
                  onPressed: () async {
                    await showSettlementSheet(context, ref);
                    controller.bump((t) => t.copyWith(settled: t.settled + 1));
                  },
                  child: Text(l10n?.wizardSettle(group.open.length) ??
                      'Regroup ${group.open.length}'),
                ),
              ),
            ),
          for (final invoice in group.partial)
            Card(
              key: ValueKey('wizard-writeoff-row-${invoice.id}'),
              child: ListTile(
                leading: const Icon(Icons.rule_outlined),
                title: Text(invoice.memberName),
                subtitle: Text(invoiceLine(wiz, invoice)),
                trailing: FilledButton.tonal(
                  key: ValueKey('wizard-writeoff-${invoice.id}'),
                  onPressed: () async {
                    await requestInvoiceWriteoffDialog(context, ref, invoice);
                    controller
                        .bump((t) => t.copyWith(writeoffs: t.writeoffs + 1));
                  },
                  child: Text(l10n?.wizardWriteoff ?? 'Write off'),
                ),
              ),
            ),
        ],
        for (final invoice in plan.refunds)
          Card(
            key: ValueKey('wizard-refund-row-${invoice.id}'),
            child: ListTile(
              leading: const Icon(Icons.undo_outlined),
              title: Text(invoice.memberName),
              subtitle: Text(invoiceLine(wiz, invoice)),
              trailing: FilledButton.tonal(
                key: ValueKey('wizard-refund-${invoice.id}'),
                onPressed: () async {
                  await settleCreditInvoiceDialog(context, ref, invoice);
                  controller.bump((t) => t.copyWith(refunds: t.refunds + 1));
                },
                child: Text(l10n?.wizardRefund ?? 'Refund'),
              ),
            ),
          ),
      ],
    );
  }
}

/// #827 — step 8: the run's numbers, and what is still open with whose
/// move it is.
class WizardSummaryStep extends ConsumerWidget {
  const WizardSummaryStep(this.wiz, {super.key});

  final WizardContext wiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = wiz.state.tally;
    final tally = <(String, int)>[
      (l10n?.wizardTallyIssued ?? 'Invoices issued', t.issued),
      (l10n?.wizardTallyShared ?? 'PDFs shared or downloaded', t.shared),
      (l10n?.wizardTallyReminded ?? 'Reminders sent', t.reminded),
      (l10n?.wizardTallyDecided ?? 'Payments confirmed or rejected',
          t.paymentsDecided),
      (l10n?.wizardTallyRegistered ?? 'Payments registered',
          t.paymentsRegistered),
      (l10n?.wizardTallyMatched ?? 'Invoices matched', t.matched),
      (l10n?.wizardTallySettled ?? 'Regroupings', t.settled),
      (l10n?.wizardTallyWriteoffs ?? 'Write-offs requested', t.writeoffs),
      (l10n?.wizardTallyRefunds ?? 'Refunds', t.refunds),
    ];
    final todos = <(Invoice, String, String)>[];
    for (final invoice in wiz.open) {
      final match = wiz.matches[invoice.id];
      final journey = readInvoiceJourney(ref, invoice,
          match: match, reminder: wiz.reminders[invoice.id]);
      if (journey == null || journey.move == InvoiceMove.none) continue;
      final who = switch (journey.move.who) {
        InvoiceMover.member => invoice.memberName,
        InvoiceMover.issuer => l10n?.wizardWhoYou ?? 'You',
        InvoiceMover.validators => l10n?.wizardWhoValidators ?? 'Validators',
        InvoiceMover.nobody => '',
      };
      todos.add((
        invoice,
        who,
        invoiceMoveText(context, journey,
            invoice: invoice, match: match, issuer: true),
      ));
    }
    return ListView(
      children: [
        Card(
          key: const ValueKey('wizard-tally'),
          child: Padding(
            padding: AppSpacing.lgAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.wizardSummaryHint ?? 'What this run did',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final (label, count) in tally)
                  if (count > 0)
                    Row(children: [
                      SizedBox(
                        width: 40,
                        child: Text(count.toString(),
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.right),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(label)),
                    ]),
                if (t.total == 0)
                  Text(
                    l10n?.wizardTallyNothing ?? 'Nothing was changed.',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n?.wizardTodoHeading ?? 'Still open — whose move',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (todos.isEmpty)
          Text(
            l10n?.wizardTodoNone ?? 'Nothing left open.',
            key: const ValueKey('wizard-todo-none'),
          ),
        for (final (invoice, who, text) in todos)
          ListTile(
            key: ValueKey('wizard-todo-${invoice.id}'),
            dense: true,
            leading: const Icon(Icons.flag_outlined),
            title: Text([invoice.number, invoice.memberName].join(' · ')),
            subtitle: Text(who.isEmpty ? text : '$who — $text'),
          ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const ValueKey('wizard-finish'),
          icon: const Icon(Icons.done_all),
          label: Text(l10n?.wizardFinish ?? 'Finish'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
