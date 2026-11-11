// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/navigation/page_spec.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/domain/workspace_event.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/billing_rules.dart';
import '../../domain/dunning.dart';
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
    required this.reads,
    required this.retry,
    required this.issuingEnabled,
    required this.settlementEnabled,
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

  /// #3680 — whether the lists answered: a step lists or says "nothing to
  /// do" only then; [standIn] shows the progress or the failure instead.
  final ReadsAnswer reads;

  /// Repeats the reads.
  final VoidCallback retry;

  /// True while a list is not answered (still running, or failed).
  bool get loading => !reads.answered;

  /// The progress or the failure with Try again; null when answered.
  Widget? get standIn => reads.standIn(onRetry: retry);
  final bool issuingEnabled;

  /// Whether a member's open invoices may be regrouped into one.
  final bool settlementEnabled;

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
    final features = ref.watch(enabledFeaturesSyncProvider);
    final kind = wizardKind(state.run);
    final invoices = ref.watch(invoicesProvider);
    final matches = ref.watch(invoiceMatchesProvider);
    final reminders = ref.watch(invoiceRemindersProvider);
    final events = ref.watch(eventsProvider);
    final previews = ref.watch(wizardPreviewsProvider(period));
    final rules = ref.watch(dunningRulesProvider);
    final members = ref.watch(workspaceMembersProvider);
    final names = ref.watch(memberNamesProvider);
    return WizardContext(
      state: state,
      period: period,
      kind: kind,
      issuingEnabled: features.contains(WorkspaceFeature.invoicing) &&
          features.contains(kind == InvoiceKind.subscription
              ? WorkspaceFeature.subscriptionInvoices : WorkspaceFeature.usageInvoices),
      settlementEnabled: features.contains(WorkspaceFeature.invoiceSettlement),
      now: now,
      workspaceId: workspace?.id ?? '',
      currency: ref.watch(appFormatProvider).moneyIn(workspace?.currencyCode),
      // The lists below are used only while `reads` answered.
      members: members.value ?? const [], // empty-ok: steps wait for `reads`
      names: names.value ?? const {}, // empty-ok: steps wait for `reads`
      invoices: invoices.value ?? const [], // empty-ok: steps wait for `reads`
      matches: matches.value ?? const {}, // empty-ok: steps wait for `reads`
      reminders: reminders.value ?? const {}, // empty-ok: steps wait for `reads`
      dunning: rules.value ?? DunningRules.defaults, // empty-ok: steps wait for `reads`, the rules among them
      events: events.value ?? const [], // empty-ok: steps wait for `reads`
      previews: previews.value ?? const {}, // empty-ok: steps wait for `reads`
      reads: ReadsAnswer.of(
        [members, names, invoices, matches, reminders, events, previews, rules],
      ),
      retry: () => ref
        ..invalidate(workspaceMembersProvider)
        ..invalidate(memberNamesProvider)
        ..invalidate(invoicesProvider)
        ..invalidate(invoiceMatchesProvider)
        ..invalidate(invoiceRemindersProvider)
        ..invalidate(eventsProvider)
        ..invalidate(wizardPreviewsProvider(period)),
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

String wizardStepLabel(AppLocalizations l10n, WizardStep step) =>
    switch (step) {
      WizardStep.review => l10n.wizardStepReview,
      WizardStep.issue => l10n.wizardStepIssue,
      WizardStep.send => l10n.wizardStepSend,
      WizardStep.remind => l10n.wizardStepRemind,
      WizardStep.payments => l10n.invoicePdfPayments,
      WizardStep.match => l10n.leaseMatchSave,
      WizardStep.close => l10n.wizardStepClose,
      WizardStep.summary => l10n.wizardStepSummary,
    };

String wizardRunLabel(AppLocalizations l10n, WizardRun run) => switch (run) {
      WizardRun.startOfMonth => l10n.wizardRunStart,
      WizardRun.endOfMonth => l10n.wizardRunEnd,
    };

/// #827 — opens the wizard: the route where a router hosts the caller,
/// a plain page push otherwise.
/// Opens the month-close wizard (#827), on [run] when it is known.
Future<void> openInvoicingWizard(BuildContext context, {WizardRun? run}) async {
  await openLocation<void>(
    context,
    run == null ? '/invoicing/wizard' : '/invoicing/wizard?run=${run.name}',
    orBuild: (_) => InvoicingWizardScreen(initialRun: run),
  );
}
