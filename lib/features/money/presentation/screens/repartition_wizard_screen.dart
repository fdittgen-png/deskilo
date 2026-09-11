// SPDX-License-Identifier: 0BSD
//
// #934 — the guided repartition: a shared cost proposed over the
// members by subscription share, each member excludable and — under the
// custom method — weighted, then booked through the same
// distribute_expense as the one-expense sheet (#828), and the adjusted
// rule remembered so next month proposes it again.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/expense_repartition.dart';
import '../../domain/workspace_status.dart';
import '../../providers/money_providers.dart';
import '../widgets/wizard_scaffold.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../../core/format/cents.dart';

class RepartitionWizardScreen extends ConsumerStatefulWidget {
  const RepartitionWizardScreen({super.key});
  @override
  ConsumerState<RepartitionWizardScreen> createState() => _State();
}

class _State extends ConsumerState<RepartitionWizardScreen> {
  int _step = 0;
  final _title = TextEditingController();
  final _amount = TextEditingController();
  late String _period;
  RepartitionRule? _rule;
  bool _remember = true;
  bool _busy = false;
  final _weights = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    for (final c in _weights.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _cents {
    // #1140 — the currency's own minor digits, never a literal 100.
    final c = parseCentsInput(_amount.text);
    return (c == null || c == 0) ? null : c;
  }

  RepartitionRule _effectiveRule() =>
      _rule ?? ref.read(repartitionRuleProvider).value ?? const RepartitionRule();

  List<RepartitionMember> _pool() {
    final rule = _effectiveRule();
    final members = ref.read(workspaceMembersProvider).value ?? const [];
    final names = ref.read(memberNamesProvider).value ?? const {};
    return [
      for (final m in members)
        if (m.status == MemberStatus.active && !m.isKiosk && !rule.excluded.contains(m.id))
          (
            id: m.id,
            name: names[m.id] ?? '',
            subscriptionPct: m.subscriptionPct,
            usageDays: 0,
            customWeight: rule.weights[m.id] ?? m.subscriptionPct,
          ),
    ];
  }

  List<RepartitionShare> _shares() {
    final cents = _cents;
    if (cents == null) return const [];
    return distributeExpense(
      amountCents: cents,
      members: _pool(),
      method: _effectiveRule().method,
    );
  }

  Future<void> _book() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final cents = _cents;
    final shares = _shares();
    if (workspace == null || cents == null || shares.isEmpty) return;
    setState(() => _busy = true);
    final rule = _effectiveRule();
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'repartition wizard failed',
      errorText: l10n?.workspaceGenericError ?? 'Something went wrong. Please try again.',
      action: () async {
        final repo = ref.read(moneyRepositoryProvider);
        await repo.distributeExpense(
          workspaceId: workspace.id,
          title: _title.text.trim(),
          amountCents: cents,
          method: rule.method,
          period: _period,
          shares: shares,
        );
        if (_remember) await repo.setRepartitionRule(workspace.id, rule);
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(repartitionRuleProvider);
      AppSnack.success(context, l10n?.repartitionBooked ?? 'Repartition booked.');
      unawaited(Navigator.of(context).maybePop());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = <WizardStepSpec>[
      (name: 'cost', label: l10n?.repartitionStepCost ?? 'The cost'),
      (name: 'rule', label: l10n?.repartitionStepRule ?? 'The rule'),
      (name: 'book', label: l10n?.repartitionStepBook ?? 'Book'),
    ];
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final currency = moneyFormat(workspace?.currencyCode ?? 'EUR');
    String money(int c) => currency.formatMinor(c);
    final rule = _effectiveRule();
    final shares = _shares();
    final total = shares.fold<int>(0, (s, x) => s + x.amountCents);
    final costComplete = _title.text.trim().isNotEmpty && _cents != null;

    final summary = '${money(_cents ?? 0)} · $_period · ${rule.method.name}';
    Widget body = switch (_step) {
      0 => ListView(
          padding: AppSpacing.lgAll,
          children: [
            TextField(
              key: const ValueKey('wizard-title'),
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n?.repartitionTitleLabel ?? 'Title'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('wizard-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n?.repartitionAmountLabel ?? 'Amount'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
                  key: const ValueKey('wizard-period-prev'),
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _period = _shift(_period, -1)),
                ),
                Expanded(child: Center(child: Text(_period, style: theme.textTheme.titleMedium))),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
                  key: const ValueKey('wizard-period-next'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _period = _shift(_period, 1)),
                ),
              ],
            ),
          ],
        ),
      1 => ListView(
          padding: AppSpacing.lgAll,
          children: [
            Text(l10n?.repartitionRuleHint ??
                'Each share is proposed by subscription percentage. Untick a member to leave them out; with the custom method, type their weight.'),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<RepartitionMethod>(
              key: const ValueKey('wizard-method'),
              initialValue: rule.method,
              items: [
                for (final m in const [RepartitionMethod.subscription, RepartitionMethod.equal, RepartitionMethod.custom])
                  DropdownMenuItem(value: m, child: Text(m.name)),
              ],
              onChanged: (m) => setState(() => _rule = rule.copyWith(method: m)),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final m in (ref.watch(workspaceMembersProvider).value ?? const []).where((m) => m.status == MemberStatus.active && !m.isKiosk))
              Builder(builder: (context) {
                final names = ref.watch(memberNamesProvider).value ?? const {};
                final share = shares.where((s) => s.memberId == m.id).firstOrNull;
                final excluded = rule.excluded.contains(m.id);
                final pctLabel = '${m.subscriptionPct} %';
                final weight = _weights.putIfAbsent(
                  m.id,
                  () => TextEditingController(text: (rule.weights[m.id] ?? m.subscriptionPct).toString()),
                );
                return CheckboxListTile(
                  key: ValueKey('wizard-member-${m.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: !excluded,
                  onChanged: (on) => setState(() {
                    final ex = {...rule.excluded};
                    if (on ?? false) {
                      ex.remove(m.id);
                    } else {
                      ex.add(m.id);
                    }
                    _rule = rule.copyWith(excluded: ex);
                  }),
                  title: Text(names[m.id] ?? ''),
                  subtitle: Row(
                    children: [
                      Text(pctLabel),
                      if (rule.method == RepartitionMethod.custom) ...[
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            key: ValueKey('wizard-weight-${m.id}'),
                            controller: weight,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: l10n?.repartitionWizardWeight ?? 'Weight', isDense: true),
                            onChanged: (v) => setState(() => _rule = rule.copyWith(
                                weights: {...rule.weights, m.id: num.tryParse(v.trim()) ?? 0})),
                          ),
                        ),
                      ],
                    ],
                  ),
                  secondary: Text(
                    share == null ? '—' : money(share.amountCents),
                    key: ValueKey('wizard-share-${m.id}'),
                    style: theme.textTheme.bodyLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                );
              }),
            const Divider(),
            ListTile(
              key: const ValueKey('wizard-shares-total'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n?.repartitionSharesTotal ?? 'Total of the shares'),
              trailing: Text(money(total)),
            ),
          ],
        ),
      _ => ListView(
          padding: AppSpacing.lgAll,
          children: [
            Text(_title.text.trim(), style: theme.textTheme.titleMedium),
            Text(summary),
            const SizedBox(height: AppSpacing.md),
            for (final s in shares)
              ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(s.memberName), trailing: Text(money(s.amountCents))),
            const Divider(),
            SwitchListTile(
              key: const ValueKey('wizard-remember'),
              contentPadding: EdgeInsets.zero,
              value: _remember,
              onChanged: (v) => setState(() => _remember = v),
              title: Text(l10n?.repartitionRememberRule ?? 'Remember this rule'),
            ),
          ],
        ),
    };
    return WizardScaffold(
      title: l10n?.repartitionWizardTitle ?? 'Share a cost',
      steps: steps,
      index: _step,
      body: body,
      onBack: _step == 0 ? null : () => setState(() => _step--),
      onNext: _step >= 2 ? null : () => setState(() => _step++),
      nextEnabled: _step == 0 ? costComplete : shares.isNotEmpty,
      onFinish: _step == 2 && !_busy && shares.isNotEmpty ? _book : null,
      finishKey: const ValueKey('wizard-book'),
      finishEnabled: !_busy && shares.isNotEmpty,
    );
  }

  static String _shift(String ym, int months) {
    final y = int.parse(ym.substring(0, 4));
    final m = int.parse(ym.substring(5, 7));
    final d = DateTime(y, m + months, 1);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }
}
