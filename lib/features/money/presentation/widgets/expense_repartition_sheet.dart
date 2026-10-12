// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #828 — split a shared cost over the members; the shares land as
// adjustment lines on each member's next usage invoice, a reversal
// gives the money back as credits. #872 — runs as an assistant: the
// expense, then the shares, then Book — the month-close wizard's shape.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/page_spec.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/date_text.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/book_repartition.dart';
import '../../domain/expense_repartition.dart';
import '../../providers/expense_repartition_providers.dart';
import '../../providers/money_providers.dart';
import '../period_label.dart';
import 'wizard_scaffold.dart';

/// Opens the repartition assistant (kept under its historical name).
Future<void> showExpenseRepartitionSheet(
  BuildContext context,
  WidgetRef ref,
) =>
    expenseRepartitionPage.open<void>(context, null);

/// #2388 — the repartition wizard as a page with a path.
final expenseRepartitionPage = PageSpec<Null>(
  '/money/repartition',
  (_) => const _RepartitionWizard(),
  fallback: '/money',
  fullscreenDialog: true,
);

class _RepartitionWizard extends ConsumerStatefulWidget {
  const _RepartitionWizard();

  @override
  ConsumerState<_RepartitionWizard> createState() =>
      _RepartitionWizardState();
}

class _RepartitionWizardState extends ConsumerState<_RepartitionWizard> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final Map<String, TextEditingController> _weights = {};
  RepartitionMethod _method = RepartitionMethod.equal;
  bool _reverse = false;
  late String _period = _current(ref.read(clockProvider).now());
  int _index = 0;
  bool _busy = false;

  static String _current(DateTime now) =>
      yearMonth(now.year, now.month);

  static String _shift(String period, int months) {
    final parts = period.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]) + months);
    return _current(d);
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
    final cents = parseCentsInput(_amount.text);
    if (cents == null || cents <= 0) return null;
    return _reverse ? -cents : cents;
  }

  TextEditingController _weightOf(String memberId) =>
      _weights.putIfAbsent(memberId, () => TextEditingController(text: '1'));

  List<RepartitionMember> _members(
          List<Member> members, Map<String, String> names) =>
      [
        for (final m in members)
          if (m.status == MemberStatus.active && !m.isKiosk)
            (
              id: m.id,
              name: names[m.id] ?? '',
              subscriptionPct: m.subscriptionPct,
              usageDays: ref
                      .watch(memberStatementProvider(m.id, _period))
                      .value
                      ?.usedHalfDays ??
                  0,
              customWeight: num.tryParse(_weightOf(m.id).text.trim()) ?? 0,
            ),
      ];

  Future<void> _submit(List<RepartitionShare> shares) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    final cents = _cents;
    if (workspace == null || cents == null || shares.isEmpty) return;
    setState(() => _busy = true);
    DistributedExpense? done;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'distribute expense failed',
      errorText: l10n.workspaceGenericError,
      // Distributing and then learning WHICH of the two things happened
      // is one decision, so it lives in the command (#1449).
      action: () async {
        done = await ref.read(repartitionsProvider).distribute(
              workspaceId: workspace.id,
              title: _title.text.trim(),
              amountCents: cents,
              method: _method,
              period: _period,
              shares: shares,
            );
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final outcome = done;
    if (!ok || outcome == null) return;
    ref
      ..invalidate(expenseRepartitionsProvider)
      ..invalidate(eventsProvider)
      ..invalidate(invoicingOverviewProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      outcome.pending
          ? (l10n.repartitionFiledPending)
          : (l10n.repartitionFiled),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final currency = moneyFormat(workspace?.currencyCode);
    final members = ref.watch(workspaceMembersProvider).value ?? const [];
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final pool = _members(members, names);
    final cents = _cents;
    final shares = cents == null
        ? const <RepartitionShare>[]
        : distributeExpense(
            amountCents: cents, members: pool, method: _method);
    final history = ref.watch(expenseRepartitionsProvider).value ?? const [];
    final expenseComplete = _title.text.trim().isNotEmpty && cents != null;
    final canSubmit = !_busy && expenseComplete && shares.isNotEmpty;
    final steps = <WizardStepSpec>[
      (name: 'expense', label: l10n.repartitionStepExpense),
      (name: 'shares', label: l10n.repartitionPreview),
    ];
    final body = _index == 0
        ? ListView(children: [
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.repartitionHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('repartition-title'),
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: l10n.repartitionTitleField),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('repartition-amount'),
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.repartitionAmount,
                suffixText: workspace?.currencyCode ?? '',
              ),
            ),
            SwitchListTile(
              key: const ValueKey('repartition-reverse'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.repartitionReverse),
              value: _reverse,
              onChanged: (v) => setState(() => _reverse = v),
            ),
            Row(children: [
              Text(l10n.repartitionPeriod,
                  style: theme.textTheme.labelLarge),
              const Spacer(),
              IconButton(
                tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
                key: const ValueKey('repartition-period-prev'),
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    setState(() => _period = _shift(_period, -1)),
              ),
              Text(monthLabel(context, _period),
                  key: const ValueKey('repartition-period')),
              IconButton(
                tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
                key: const ValueKey('repartition-period-next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    setState(() => _period = _shift(_period, 1)),
              ),
            ]),
            const Divider(height: AppSpacing.xl),
            Text(l10n.repartitionHistory,
                style: theme.textTheme.labelLarge),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.repartitionHistoryEmpty,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final r in history)
              ListTile(
                key: ValueKey('repartition-history-${r.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    r.isReversal ? Icons.undo_outlined : Icons.call_split),
                title: Text(r.title),
                subtitle: Text([
                  currency.formatMinor(r.amountCents),
                  monthLabel(context, r.period),
                  _statusLabel(l10n, r.status),
                ].join(' · ')),
              ),
          ])
        : ListView(children: [
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.repartitionMethod,
                style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<RepartitionMethod>(
              key: const ValueKey('repartition-method'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: RepartitionMethod.equal,
                  label: Text(l10n.repartitionMethodEqual),
                ),
                ButtonSegment(
                  value: RepartitionMethod.subscription,
                  label: Text(
                      l10n.repartitionMethodSubscription),
                ),
                ButtonSegment(
                  value: RepartitionMethod.usage,
                  label: Text(l10n.repartitionMethodUsage),
                ),
                ButtonSegment(
                  value: RepartitionMethod.custom,
                  label:
                      Text(l10n.repartitionMethodCustom),
                ),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const Divider(),
            Text(l10n.repartitionPreview,
                style: theme.textTheme.labelLarge),
            if (cents != null && shares.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.repartitionNoShares,
                  key: const ValueKey('repartition-no-shares'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            for (final m in pool)
              Row(children: [
                Expanded(child: Text(m.name)),
                if (_method == RepartitionMethod.custom)
                  SizedBox(
                    width: 64,
                    child: TextField(
                      key: ValueKey('repartition-weight-${m.id}'),
                      controller: _weightOf(m.id),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.right,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: l10n.repartitionWeight,
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 96,
                  child: Text(
                    currency.formatMinor(shares
                            .where((s) => s.memberId == m.id)
                            .firstOrNull
                            ?.amountCents ??
                        0),
                    key: ValueKey('repartition-share-${m.id}'),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ]),
            if (shares.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.repartitionSum(
                          shares.length, currency.formatMinor(cents!)),
                  key: const ValueKey('repartition-sum'),
                  style: theme.textTheme.labelMedium,
                  textAlign: TextAlign.right,
                ),
              ),
          ]);
    return WizardScaffold(
      title: l10n.repartitionTitle,
      steps: steps,
      index: _index,
      body: body,
      onStepTap: (i) =>
          setState(() => _index = i == 0 || expenseComplete ? i : 0),
      onBack: () => setState(() => _index = 0),
      onNext: () => setState(() => _index = 1),
      nextEnabled: expenseComplete,
      onFinish: () => _submit(shares),
      finishKey: const ValueKey('repartition-submit'),
      finishLabel: l10n.repartitionSubmit,
      finishEnabled: canSubmit,
    );
  }

  static String _statusLabel(AppLocalizations l10n, String status) =>
      switch (status) {
        'confirmed' => l10n.repartitionStatusConfirmed,
        'rejected' => l10n.repartitionStatusRejected,
        'expired' => l10n.repartitionStatusExpired,
        _ => l10n.repartitionStatusPending,
      };
}
