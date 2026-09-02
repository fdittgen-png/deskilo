// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice.dart';
import '../../domain/invoicing_wizard.dart';
import '../../providers/invoicing_wizard_providers.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../period_label.dart';
import 'wizard_context.dart';

/// #827 — step 1: which run, which period, and what the workspace holds
/// before anything is done.
class WizardReviewStep extends ConsumerWidget {
  const WizardReviewStep(this.wiz, {super.key});

  final WizardContext wiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final toIssue = wiz.issueItems.where((i) => !i.done).length;
    final issued = wiz.issueItems.where((i) => i.done).length;
    final counts = <(Key, String, int)>[
      (const ValueKey('wizard-review-to-issue'),
          l10n?.wizardReviewToIssue ?? 'To issue', toIssue),
      (const ValueKey('wizard-review-issued'),
          l10n?.wizardReviewIssued ?? 'Already issued', issued),
      (const ValueKey('wizard-review-open'),
          l10n?.wizardReviewOpen ?? 'Open invoices', wiz.open.length),
      (const ValueKey('wizard-review-overdue'),
          l10n?.wizardReviewOverdue ?? 'Reminders due', wiz.reminds.length),
      (const ValueKey('wizard-review-pending'),
          l10n?.wizardReviewPending ?? 'Payments to validate',
          wiz.pending.length),
    ];
    return ListView(
      children: [
        SegmentedButton<WizardRun>(
          key: const ValueKey('wizard-run'),
          segments: [
            ButtonSegment(
              value: WizardRun.startOfMonth,
              icon: const Icon(Icons.first_page),
              label: Text(wizardRunLabel(l10n, WizardRun.startOfMonth)),
            ),
            ButtonSegment(
              value: WizardRun.endOfMonth,
              icon: const Icon(Icons.last_page),
              label: Text(wizardRunLabel(l10n, WizardRun.endOfMonth)),
            ),
          ],
          selected: {wiz.state.run},
          onSelectionChanged: (s) => ref
              .read(invoicingWizardControllerProvider.notifier)
              .setRun(s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        WizardHint(switch (wiz.state.run) {
          WizardRun.startOfMonth => l10n?.wizardRunStartHint ??
              'The subscriptions members pay ahead: issue them for the '
                  'coming month, send them, plan the reminders — then the '
                  'payment side.',
          WizardRun.endOfMonth => l10n?.wizardRunEndHint ??
              'What the month that just ended cost: usage, consumption and '
                  'extra charges. Issue, send, remind — then register, '
                  'validate and match the payments, and close.',
        }),
        Text(
          l10n?.wizardPeriodLabel(monthLabel(context, wiz.period)) ??
              'Period: ${monthLabel(context, wiz.period)}',
          key: const ValueKey('wizard-period'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        if (wiz.loading) const LinearProgressIndicator(),
        for (final (key, label, count) in counts)
          ListTile(
            key: key,
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: count > 0
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              child: Text(count.toString(), style: theme.textTheme.labelLarge),
            ),
            title: Text(label),
          ),
      ],
    );
  }
}

/// #827 — step 2: the invoices of the run, member by member, issued in
/// one batch through the ordinary RPC; a member already covered is shown
/// done, never issued twice.
class WizardIssueStep extends ConsumerStatefulWidget {
  const WizardIssueStep(this.wiz, {super.key});

  final WizardContext wiz;

  @override
  ConsumerState<WizardIssueStep> createState() => _WizardIssueStepState();
}

class _WizardIssueStepState extends ConsumerState<WizardIssueStep> {
  final Set<String> _skipped = {};
  bool _busy = false;

  Future<void> _issueAll(List<WizardIssueItem> todo) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    var done = 0;
    for (final item in todo) {
      if (_skipped.contains(item.memberId)) continue;
      final ok = await runGuarded(
        context,
        domain: 'money',
        message: 'wizard issue failed',
        errorText: l10n?.wizardIssueFailed(item.memberName) ??
            'Could not issue for ${item.memberName}.',
        action: () => ref.read(moneyRepositoryProvider).createInvoice(
              workspaceId: widget.wiz.workspaceId,
              memberId: item.memberId,
              period: widget.wiz.period,
              kind: widget.wiz.kind,
            ),
      );
      if (ok) done++;
      if (!mounted) return;
    }
    ref
      ..invalidate(invoicesProvider)
      ..invalidate(invoicingOverviewProvider)
      ..invalidate(wizardPreviewsProvider(widget.wiz.period));
    ref
        .read(invoicingWizardControllerProvider.notifier)
        .bump((t) => t.copyWith(issued: t.issued + done));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final wiz = widget.wiz;
    final items = wiz.issueItems;
    final todo = items.where((i) => !i.done).toList();
    final selected = todo.where((i) => !_skipped.contains(i.memberId)).length;
    if (!wiz.loading && items.isEmpty) {
      return WizardNothing(
        l10n?.wizardIssueNothing ?? 'Nothing to issue for this period.',
        stepKey: 'issue',
      );
    }
    return ListView(
      children: [
        WizardHint(l10n?.wizardIssueHint ??
            'Untick a member to leave them out of this batch. Members '
                'already covered are shown as done.'),
        if (wiz.loading) const LinearProgressIndicator(),
        for (final item in items)
          Card(
            key: ValueKey('wizard-issue-row-${item.memberId}'),
            child: item.done
                ? ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(item.memberName),
                    subtitle: Text(
                      l10n?.wizardIssuedChip(item.issued!.number) ??
                          'Issued ${item.issued!.number}',
                      key: ValueKey('wizard-issued-${item.memberId}'),
                    ),
                    trailing: Text(
                        wiz.currency.formatMinor(item.issued!.totalCents)),
                  )
                : CheckboxListTile(
                    key: ValueKey('wizard-issue-${item.memberId}'),
                    value: !_skipped.contains(item.memberId),
                    onChanged: _busy
                        ? null
                        : (on) => setState(() => on ?? false
                            ? _skipped.remove(item.memberId)
                            : _skipped.add(item.memberId)),
                    title: Text(item.memberName),
                    subtitle: Text([
                      for (final l in item.lines)
                        l.label.isEmpty ? l.kind : l.label,
                    ].join(' · ')),
                    secondary: Text(wiz.currency.formatMinor(item.totalCents),
                        style: theme.textTheme.titleSmall),
                  ),
          ),
        const SizedBox(height: AppSpacing.md),
        if (todo.isNotEmpty)
          FilledButton.icon(
            key: const ValueKey('wizard-issue-all'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(l10n?.wizardIssueAll(selected) ??
                'Issue $selected invoices'),
            onPressed: _busy || selected == 0 ? null : () => _issueAll(todo),
          ),
      ],
    );
  }
}

/// #827 — step 3: the run's invoices, each shared or downloaded as PDF.
class WizardSendStep extends ConsumerWidget {
  const WizardSendStep(this.wiz, {super.key});

  final WizardContext wiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final issued = wiz.issued;
    if (!wiz.loading && issued.isEmpty) {
      return WizardNothing(
        l10n?.wizardSendNone ?? 'No invoice of this run to send yet.',
        stepKey: 'send',
      );
    }
    final controller = ref.read(invoicingWizardControllerProvider.notifier);
    return ListView(
      children: [
        WizardHint(l10n?.wizardSendHint ??
            'Hand each invoice to its member — share the PDF, or download '
                'it to send it your own way.'),
        for (final invoice in issued)
          Card(
            key: ValueKey('wizard-send-${invoice.id}'),
            child: ListTile(
              title: Text(invoice.memberName),
              subtitle: Text(
                  '${invoice.number} · ${wiz.currency.formatMinor(invoice.totalCents)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  key: ValueKey('wizard-share-${invoice.id}'),
                  icon: const Icon(Icons.share_outlined),
                  tooltip: l10n?.wizardSendShare ?? 'Share the PDF',
                  onPressed: () async {
                    await shareInvoicePdf(context, ref, invoice);
                    controller.bump((t) => t.copyWith(shared: t.shared + 1));
                  },
                ),
                IconButton(
                  key: ValueKey('wizard-download-${invoice.id}'),
                  icon: const Icon(Icons.download_outlined),
                  tooltip: l10n?.wizardSendDownload ?? 'Download the PDF',
                  onPressed: () async {
                    await downloadInvoicePdf(context, ref, invoice);
                    controller.bump((t) => t.copyWith(shared: t.shared + 1));
                  },
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

/// #827 — step 4: everything the dunning rules say is due, reminded in
/// one batch (the reminder is recorded and pushed; the letter PDF stays
/// one tap away per row).
class WizardRemindStep extends ConsumerStatefulWidget {
  const WizardRemindStep(this.wiz, {super.key});

  final WizardContext wiz;

  @override
  ConsumerState<WizardRemindStep> createState() => _WizardRemindStepState();
}

class _WizardRemindStepState extends ConsumerState<WizardRemindStep> {
  bool _busy = false;

  Future<void> _remindAll(List<WizardRemindItem> due) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    var done = 0;
    for (final item in due) {
      final ok = await runGuarded(
        context,
        domain: 'money',
        message: 'wizard remind failed',
        errorText: l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        action: () =>
            ref.read(moneyRepositoryProvider).remindInvoice(item.invoice.id),
      );
      if (ok) done++;
      if (!mounted) return;
    }
    ref.invalidate(invoiceRemindersProvider);
    ref
        .read(invoicingWizardControllerProvider.notifier)
        .bump((t) => t.copyWith(reminded: t.reminded + done));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wiz = widget.wiz;
    final due = wiz.reminds;
    if (!wiz.loading && due.isEmpty) {
      return WizardNothing(
        l10n?.wizardRemindNone ?? 'No reminder is due by your rules.',
        stepKey: 'remind',
      );
    }
    return ListView(
      children: [
        WizardHint(l10n?.wizardRemindHint ??
            'Overdue by your reminder rules. One tap records every reminder '
                'and notifies the members; the letter opens per row.'),
        for (final item in due)
          Card(
            key: ValueKey('wizard-remind-row-${item.invoice.id}'),
            child: ListTile(
              title: Text(item.invoice.memberName),
              subtitle: Text(
                  '${item.invoice.number} · ${wiz.currency.formatMinor(item.invoice.totalCents)} · '
                  '${l10n?.wizardRemindLevel(item.level) ?? 'reminder ${item.level}'}'),
              trailing: IconButton(
                key: ValueKey('wizard-remind-${item.invoice.id}'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: l10n?.wizardRemindOne ?? 'Reminder letter',
                onPressed: _busy
                    ? null
                    : () async {
                        await remindInvoice(context, ref, item.invoice);
                        ref
                            .read(invoicingWizardControllerProvider.notifier)
                            .bump((t) => t.copyWith(reminded: t.reminded + 1));
                      },
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const ValueKey('wizard-remind-all'),
          icon: const Icon(Icons.notifications_active_outlined),
          label: Text(l10n?.wizardRemindAll(due.length) ??
              'Send ${due.length} reminders'),
          onPressed: _busy || due.isEmpty ? null : () => _remindAll(due),
        ),
      ],
    );
  }
}

/// The invoice's own line for lists: number, member, amount.
String invoiceLine(WizardContext wiz, Invoice invoice) =>
    '${invoice.number} · ${wiz.currency.formatMinor(invoice.totalCents)}';
