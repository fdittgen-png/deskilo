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
import '../widgets/wizard_scaffold.dart';
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
    return WizardScaffold(
      key: const ValueKey('invoicing-wizard'),
      title: l10n?.wizardTitle ?? 'Invoicing wizard',
      steps: [
        for (final step in steps)
          (name: step.name, label: wizardStepLabel(l10n, step)),
      ],
      index: index,
      body: body,
      onStepTap: (i) => controller.goTo(steps[i]),
      onBack: controller.back,
      onNext: controller.next,
      // The summary step carries its own Finish.
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
    );
  }
}
