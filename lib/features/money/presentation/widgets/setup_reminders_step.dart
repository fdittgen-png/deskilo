// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "reminders": the reminder rules dialog's own fields
// ([DunningRulesFields]) prefilled from the stored policy and saved through
// its one write ([SaveDunningRules]); the payment conditions the letter
// recalls are edited with the legal identity, one tap away. Beside it, as
// the owner changes the fields, the reminder a member receives: the
// message the reminder goes out with, for a sample invoice, the payment
// conditions the letter recalls, when each level falls due and who sends
// it. The first level waits for the payment term the rules freeze on every
// invoice at issue; the next ones wait from the previous reminder.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/save_dunning_rules.dart';
import '../../domain/dunning.dart';
import '../../domain/invoice_legal.dart';
import '../../domain/report_data_sample.dart';
import '../../providers/money_providers.dart';
import 'dunning_rules_dialog.dart';

class SetupRemindersStep extends ConsumerWidget {
  const SetupRemindersStep({
    super.key,
    required this.workspaceId,
    required this.currencyCode,
    required this.invoiceLegal,
    required this.onSaved,
  });

  final String workspaceId;
  final String currencyCode;

  /// The workspace's statutory mentions as stored, the payment conditions
  /// among them.
  final Map<String, Object?> invoiceLegal;

  /// Called after a save: the first delay is also a setting, read again.
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(dunningRulesProvider)) {
        AsyncValue(hasValue: true, :final value) => _RemindersPage(
          step: this,
          stored: value ?? DunningRules.defaults,
        ),
        AsyncError() => Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-reminders-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
          ),
        ),
        _ => const LoadingView(),
      };
}

class _RemindersPage extends ConsumerStatefulWidget {
  const _RemindersPage({required this.step, required this.stored});
  final SetupRemindersStep step;
  final DunningRules stored;

  @override
  ConsumerState<_RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<_RemindersPage> {
  late final _draft = ValueNotifier<DunningRules>(widget.stored);
  final _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _draft.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'setup reminder rules failed',
      errorText: l10n.setupGrowSaveFailed,
      action: () => ref
          .read(saveDunningRulesProvider)
          .save(widget.step.workspaceId, _draft.value),
    );
    if (ok) {
      ref.invalidate(dunningRulesProvider);
      widget.step.onSaved();
    }
    if (!mounted) return;
    _busy.value = false;
    if (ok) AppSnack.success(context, l10n.dunningSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<DunningRules>(
      valueListenable: _draft,
      builder: (context, rules, _) => SetupStepLayout(
        form: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.setupStepHint('reminders')),
            const FormGap.large(),
            DunningRulesFields(
              key: const ValueKey('setup-reminders-fields'),
              rules: rules,
              onChanged: (next) => _draft.value = next,
            ),
            const FormGap(),
            ValueListenableBuilder<bool>(
              valueListenable: _busy,
              builder: (context, busy, _) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  key: const ValueKey('setup-reminders-save'),
                  onPressed: busy ? null : _save,
                  child: Text(l10n.commonSave),
                ),
              ),
            ),
            const FormGap.small(),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('setup-reminders-terms'),
                onPressed: () => context.push('/legal-identity'),
                child: Text(l10n.setupGrowRemindersTerms),
              ),
            ),
          ],
        ),
        preview: _ReminderPreview(
          rules: rules,
          currencyCode: widget.step.currencyCode,
          paymentTerms: InvoiceLegal.fromJson(widget.step.invoiceLegal)
              .paymentTerms
              .trim(),
        ),
      ),
    );
  }
}

/// The reminder a member receives under [rules], for a sample invoice.
class _ReminderPreview extends StatelessWidget {
  const _ReminderPreview({
    required this.rules,
    required this.currencyCode,
    required this.paymentTerms,
  });

  final DunningRules rules;
  final String currencyCode;
  final String paymentTerms;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final amount = moneyFormat(
      currencyCode,
      locale: Localizations.localeOf(context).toString(),
    ).formatMinor(SampleInvoice.grossCents);
    return Column(
      key: const ValueKey('setup-reminders-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupGrowRemindersPreviewNote),
        const FormGap.small(),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.mdAll,
          ),
          child: Padding(
            padding: AppSpacing.mdAll,
            child: Text(
              l10n.invoiceReminderMessage(l10n.setupGrowSampleNumber, amount),
              key: const ValueKey('setup-reminders-message'),
            ),
          ),
        ),
        const FormGap.small(),
        Text(
          paymentTerms.isEmpty
              ? l10n.setupGrowRemindersNoTerms
              : l10n.setupGrowRemindersTermsPrinted(paymentTerms),
          key: const ValueKey('setup-reminders-terms-printed'),
          style: theme.textTheme.bodySmall,
        ),
        const FormGap(),
        for (var level = 1; level <= rules.levels; level++)
          Text(
            level == 1
                ? l10n.setupGrowRemindersFirst('${rules.firstAfterDays}')
                : l10n.setupGrowRemindersNext('$level', '${rules.betweenDays}'),
            key: ValueKey('setup-reminders-level-$level'),
          ),
        const FormGap.small(),
        Text(
          rules.automatic
              ? l10n.setupGrowRemindersAuto
              : l10n.setupGrowRemindersManual,
          key: const ValueKey('setup-reminders-who'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
