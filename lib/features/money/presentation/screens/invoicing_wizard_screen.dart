// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/billing_rules.dart';
import '../../domain/invoicing_wizard.dart';
import '../../providers/invoicing_wizard_providers.dart';
import '../../providers/money_providers.dart';
import '../widgets/wizard_context.dart';
import '../widgets/wizard_steps_issue.dart';
import '../widgets/wizard_steps_payments.dart';

/// #827 — the invoicing wizard (`/invoicing/wizard`): ONE guided process
/// for the person who does the money — issue, send, remind, register
/// and validate payments, match, close, summarise — with a step rail
/// that shows where they are and what each step holds.
class InvoicingWizardScreen extends ConsumerStatefulWidget {
  const InvoicingWizardScreen({super.key, this.initialRun});

  /// The run to open on; null lets the date decide.
  final WizardRun? initialRun;

  @override
  ConsumerState<InvoicingWizardScreen> createState() =>
      _InvoicingWizardScreenState();
}

class _InvoicingWizardScreenState extends ConsumerState<InvoicingWizardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rules = ref.read(billingRulesProvider).value ?? const BillingRules();
      final now = ref.read(clockProvider).now();
      ref
          .read(invoicingWizardControllerProvider.notifier)
          .start(widget.initialRun ?? suggestedRun(now, rules));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(invoicingWizardControllerProvider);
    final controller = ref.read(invoicingWizardControllerProvider.notifier);
    final wiz = WizardContext.of(ref, state);
    const steps = WizardStep.values;
    final index = steps.indexOf(state.step);
    final body = switch (state.step) {
      WizardStep.review => WizardReviewStep(wiz),
      WizardStep.issue => WizardIssueStep(wiz),
      WizardStep.send => WizardSendStep(wiz),
      WizardStep.remind => WizardRemindStep(wiz),
      WizardStep.payments => WizardPaymentsStep(wiz),
      WizardStep.match => WizardMatchStep(wiz),
      WizardStep.close => WizardCloseStep(wiz),
      WizardStep.summary => WizardSummaryStep(wiz),
    };
    return Scaffold(
      key: const ValueKey('invoicing-wizard'),
      appBar: AppBar(
        title: Text(l10n?.wizardTitle ?? 'Invoicing wizard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Chip(
                key: const ValueKey('wizard-run-chip'),
                label: Text(wizardRunLabel(l10n, state.run)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // The rail: every step, done / current / ahead, tappable.
          SizedBox(
            height: 56,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(children: [

                for (final (i, step) in steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      key: ValueKey('wizard-step-${step.name}'),
                      avatar: i < index
                          ? const Icon(Icons.check, size: 16)
                          : CircleAvatar(
                              radius: 9,
                              backgroundColor: i == index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Text((i + 1).toString(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: i == index
                                        ? theme.colorScheme.onPrimary
                                        : null,
                                  )),
                            ),
                      label: Text(wizardStepLabel(l10n, step)),
                      selected: i == index,
                      onSelected: (_) => controller.goTo(step),
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: body,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Row(children: [
                TextButton.icon(
                  key: const ValueKey('wizard-back'),
                  icon: const Icon(Icons.chevron_left),
                  label: Text(l10n?.wizardBack ?? 'Back'),
                  onPressed: index == 0 ? null : controller.back,
                ),
                const Spacer(),
                Text([index + 1, steps.length].join(' / '),
                    style: theme.textTheme.labelMedium),
                const Spacer(),
                if (index < steps.length - 1)
                  FilledButton.icon(
                    key: const ValueKey('wizard-next'),
                    icon: const Icon(Icons.chevron_right),
                    label: Text(l10n?.wizardNext ?? 'Next'),
                    onPressed: controller.next,
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
