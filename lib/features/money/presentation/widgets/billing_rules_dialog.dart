// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/billing_rules.dart';
import '../../providers/money_providers.dart';

/// Owner dialog for the two automatic invoice runs (#802).
///
/// The subscription is paid in advance, so its invoice has to exist
/// before the month it covers; what the month actually cost can only be
/// invoiced once it is over. Both dates are the owner's decision, and
/// both are decisions they have to be able to defend to a member — so
/// this dialog states the resulting DATE rather than leaving them to
/// work it out from a number of days.
Future<void> showBillingRulesDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final rules = await ref.read(billingRulesProvider.future);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _BillingDialog(initial: rules),
  );
}

class _BillingDialog extends ConsumerStatefulWidget {
  const _BillingDialog({required this.initial});

  final BillingRules initial;

  @override
  ConsumerState<_BillingDialog> createState() => _BillingDialogState();
}

class _BillingDialogState extends ConsumerState<_BillingDialog> {
  late BillingRules _rules = widget.initial;
  bool _busy = false;

  Future<void> _save() async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(moneyRepositoryProvider)
          .setBillingRules(workspace.id, _rules);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'set billing rules failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
        context,
        l10n.workspaceGenericError,
      );
      return;
    }
    ref.invalidate(billingRulesProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.info(
      context,
      l10n.billingRulesSaved,
      replace: true,
    );
  }

  /// "Issued on 28 August for September" — the sentence the number
  /// actually means, computed on the workspace clock for the month
  /// that is coming next.
  String _whenLine(AppLocalizations l10n) {
    final now = ref.read(clockProvider).now();
    final nextMonth = DateTime(now.year, now.month + 1);
    final issue = subscriptionIssueDay(nextMonth, _rules);
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    return l10n.billingSubscriptionWhen(
          DateFormat.MMMd(locale).format(issue),
          DateFormat.MMMM(locale).format(nextMonth),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final features = ref.watch(enabledFeaturesSyncProvider);
    final subscriptionOn =
        features.contains(WorkspaceFeature.subscriptionInvoices);
    final usageOn = features.contains(WorkspaceFeature.usageInvoices);
    return AlertDialog(
      title: Text(l10n.billingRulesTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  l10n.billingSubscriptionSection,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              HelpDot(l10n.billingRulesTitle,
                anchor: HelpAnchor.billingSchedule,
              ),
            ]),
            if (!subscriptionOn)
              Text(
                l10n.billingSubscriptionOff,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            SwitchListTile(
              key: const ValueKey('billing-subscription-auto'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.billingSubscriptionAuto),
              value: _rules.subscriptionAuto,
              onChanged: (v) => setState(
                  () => _rules = _rules.copyWith(subscriptionAuto: v)),
            ),
            Row(children: [
              Expanded(
                child: Text(l10n.billingAdvanceDays),
              ),
              DropdownButton<int>(
                key: const ValueKey('billing-advance-days'),
                value: _rules.subscriptionAdvanceDays,
                underline: const SizedBox.shrink(),
                items: [
                  for (final v in const [0, 1, 2, 3, 5, 7, 10, 14, 21, 28])
                    DropdownMenuItem(value: v, child: Text(v.toString())),
                ],
                onChanged: (v) => v == null
                    ? null
                    : setState(() => _rules =
                        _rules.copyWith(subscriptionAdvanceDays: v)),
              ),
            ]),
            Text(
              _whenLine(l10n),
              key: const ValueKey('billing-when-line'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Divider(height: 24),
            Text(
              l10n.billingUsageSection,
              style: theme.textTheme.titleSmall,
            ),
            if (!usageOn)
              Text(
                l10n.billingUsageOff,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            SwitchListTile(
              key: const ValueKey('billing-usage-auto'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.billingUsageAuto),
              value: _rules.usageAuto,
              onChanged: (v) =>
                  setState(() => _rules = _rules.copyWith(usageAuto: v)),
            ),
            SwitchListTile(
              key: const ValueKey('billing-usage-zero'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.billingUsageWhenZero),
              // The point of a zero invoice is that it is a receipt, not
              // a demand: the member is told the subscription covered
              // everything, instead of wondering whether one is missing.
              subtitle: Text(l10n.billingUsageWhenZeroHint),
              value: _rules.usageWhenZero,
              onChanged: (v) =>
                  setState(() => _rules = _rules.copyWith(usageWhenZero: v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('billing-rules-dialog-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('billing-rules-save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
