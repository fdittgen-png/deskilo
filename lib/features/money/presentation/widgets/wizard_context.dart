// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/billing_rules.dart';
import '../../domain/dunning.dart';
import '../../domain/invoice.dart';
import '../../domain/invoicing_wizard.dart';
import '../../providers/invoicing_wizard_providers.dart';
import '../../providers/money_providers.dart';
import '../screens/invoicing_wizard_screen.dart';

/// #827 — everything a wizard step reads, gathered once per build from
/// the providers so each step is a pure function of it.
class WizardContext {
  const WizardContext({
    required this.state,
    required this.period,
    required this.kind,
    required this.now,
    required this.workspaceId,
    required this.currency,
    required this.members,
    required this.names,
    required this.invoices,
    required this.matches,
    required this.reminders,
    required this.dunning,
    required this.events,
    required this.previews,
    required this.loading,
  });

  final WizardState state;
  final String period;
  final InvoiceKind kind;
  final DateTime now;
  final String workspaceId;
  final MoneyFormat currency;
  final List<Member> members;
  final Map<String, String> names;
  final List<Invoice> invoices;
  final Map<String, InvoiceMatch> matches;
  final Map<String, ({int count, DateTime last})> reminders;
  final DunningRules dunning;
  final List<WorkspaceEvent> events;
  final Map<String, ({List<InvoiceLine> lines, int totalCents})> previews;

  /// True while any of the lists is still on its first load.
  final bool loading;

  Iterable<({String id, String name})> get activeMembers => [
        for (final m in members)
          if (m.status == MemberStatus.active && !m.isKiosk)
            (id: m.id, name: names[m.id] ?? ''),
      ];

  List<WizardIssueItem> get issueItems => issuePlan(
        members: activeMembers,
        previews: previews,
        invoices: invoices,
        period: period,
        kind: kind,
      );

  List<Invoice> get issued => issuedForRun(invoices, period, kind);

  List<Invoice> get open => openInvoicesOf(invoices, matches);

  List<WizardRemindItem> get reminds => remindPlan(
        invoices: invoices,
        matches: matches,
        reminders: reminders,
        rules: dunning,
        now: now,
      );

  List<WorkspaceEvent> get pending => pendingPayments(events);

  ({List<WizardCloseGroup> groups, List<Invoice> refunds}) get close =>
      closePlan(invoices: invoices, matches: matches);

  /// Watches every provider a step needs; the screen builds it once.
  static WizardContext of(WidgetRef ref, WizardState state) {
    final now = ref.watch(clockProvider).now();
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final period = wizardPeriod(state.run, now);
    final invoices = ref.watch(invoicesProvider);
    final matches = ref.watch(invoiceMatchesProvider);
    final reminders = ref.watch(invoiceRemindersProvider);
    final events = ref.watch(eventsProvider);
    final previews = ref.watch(wizardPreviewsProvider(period));
    return WizardContext(
      state: state,
      period: period,
      kind: wizardKind(state.run),
      now: now,
      workspaceId: workspace?.id ?? '',
      currency: moneyFormat(workspace?.currencyCode),
      members: ref.watch(workspaceMembersProvider).value ?? const [],
      names: ref.watch(memberNamesProvider).value ?? const {},
      invoices: invoices.value ?? const [],
      matches: matches.value ?? const {},
      reminders: reminders.value ?? const {},
      dunning: ref.watch(dunningRulesProvider).value ?? DunningRules.defaults,
      events: events.value ?? const [],
      previews: previews.value ?? const {},
      loading: invoices.isLoading ||
          matches.isLoading ||
          events.isLoading ||
          previews.isLoading,
    );
  }
}

/// A step's explanatory line under its title.
class WizardHint extends StatelessWidget {
  const WizardHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}

/// "Nothing to do here" — a step that is already done says so, never a
/// blank panel.
class WizardNothing extends StatelessWidget {
  const WizardNothing(this.text, {super.key, required this.stepKey});

  final String text;
  final String stepKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('wizard-nothing-$stepKey'),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Row(children: [
          Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text)),
        ]),
      ),
    );
  }
}

String wizardStepLabel(AppLocalizations? l10n, WizardStep step) =>
    switch (step) {
      WizardStep.review => l10n?.wizardStepReview ?? 'Review',
      WizardStep.issue => l10n?.wizardStepIssue ?? 'Issue',
      WizardStep.send => l10n?.wizardStepSend ?? 'Send',
      WizardStep.remind => l10n?.wizardStepRemind ?? 'Remind',
      WizardStep.payments => l10n?.wizardStepPayments ?? 'Payments',
      WizardStep.match => l10n?.wizardStepMatch ?? 'Match',
      WizardStep.close => l10n?.wizardStepClose ?? 'Close',
      WizardStep.summary => l10n?.wizardStepSummary ?? 'Summary',
    };

String wizardRunLabel(AppLocalizations? l10n, WizardRun run) => switch (run) {
      WizardRun.startOfMonth => l10n?.wizardRunStart ?? 'Start of month',
      WizardRun.endOfMonth => l10n?.wizardRunEnd ?? 'End of month',
    };

/// #827 — the door to the wizard on the invoicing hub: names the run the
/// date calls for. Hidden with the flag off.
class WizardEntryCard extends ConsumerWidget {
  const WizardEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (!ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.invoicingWizard)) {
      return const SizedBox.shrink();
    }
    final rules = ref.watch(billingRulesProvider).value ?? const BillingRules();
    final run = suggestedRun(ref.watch(clockProvider).now(), rules);
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('invoice-wizard-card'),
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: InkWell(
        onTap: () => openInvoicingWizard(context, run: run),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(children: [
            Icon(Icons.auto_fix_high_outlined,
                color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n?.invoiceWizardAction ?? 'Month-close wizard',
                      style: theme.textTheme.titleSmall),
                  Text(wizardRunLabel(l10n, run),
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

/// #827 — opens the wizard: the route where a router hosts the caller,
/// a plain page push otherwise.
Future<void> openInvoicingWizard(BuildContext context, {WizardRun? run}) async {
  if (GoRouter.maybeOf(context) != null) {
    await context.push(
        run == null ? '/invoicing/wizard' : '/invoicing/wizard?run=${run.name}');
  } else {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => InvoicingWizardScreen(initialRun: run),
    ));
  }
}
