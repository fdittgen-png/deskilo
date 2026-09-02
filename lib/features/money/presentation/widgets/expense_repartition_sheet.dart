// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/expense_repartition.dart';
import '../../providers/expense_repartition_providers.dart';
import '../../providers/money_providers.dart';
import '../period_label.dart';

/// #828 — one shared cost split over the members: the amount, the key,
/// the period it lands on, every share previewed to the cent, then
/// booked through the validation framework. A reversal books credits.
Future<void> showExpenseRepartitionSheet(
  BuildContext context,
  WidgetRef ref,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RepartitionSheet(),
    );

class _RepartitionSheet extends ConsumerStatefulWidget {
  const _RepartitionSheet();

  @override
  ConsumerState<_RepartitionSheet> createState() => _RepartitionSheetState();
}

class _RepartitionSheetState extends ConsumerState<_RepartitionSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final Map<String, TextEditingController> _weights = {};
  RepartitionMethod _method = RepartitionMethod.equal;
  bool _reverse = false;
  late String _period = _current(ref.read(clockProvider).now());
  bool _busy = false;

  static String _current(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  static String _shift(String period, int months) {
    final parts = period.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]) + months, 1);
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
    final value = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return null;
    final cents = (value * 100).round();
    return _reverse ? -cents : cents;
  }

  TextEditingController _weightOf(String memberId) =>
      _weights.putIfAbsent(memberId, () => TextEditingController(text: '1'));

  List<RepartitionMember> _members(List<Member> members, Map<String, String> names) => [
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
              customWeight:
                  num.tryParse(_weightOf(m.id).text.trim()) ?? 0,
            ),
      ];

  Future<void> _submit(List<RepartitionShare> shares) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final cents = _cents;
    if (workspace == null || cents == null || shares.isEmpty) return;
    setState(() => _busy = true);
    final repo = ref.read(moneyRepositoryProvider);
    String? id;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'distribute expense failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        id = await repo.distributeExpense(
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
    if (!ok || id == null) return;
    ref
      ..invalidate(expenseRepartitionsProvider)
      ..invalidate(eventsProvider)
      ..invalidate(invoicingOverviewProvider);
    final filed = (await repo.fetchExpenseRepartitions(workspace.id))
        .where((r) => r.id == id)
        .firstOrNull;
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(
      context,
      (filed?.isPending ?? false)
          ? (l10n?.repartitionFiledPending ??
              'Shares filed — they book once validated.')
          : (l10n?.repartitionFiled ??
              'Shares booked — they appear on the next usage invoice.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
    final canSubmit = !_busy &&
        _title.text.trim().isNotEmpty &&
        cents != null &&
        shares.isNotEmpty;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SheetShell(
          title: l10n?.repartitionTitle ?? 'Distribute an expense',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n?.repartitionHint ??
                        'Split a shared cost over the members. The shares '
                            'land as lines on each member\'s next usage '
                            'invoice; a reversal gives the money back as '
                            'credit notes.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const ValueKey('repartition-title'),
                    controller: _title,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        labelText: l10n?.repartitionTitleField ?? 'What for'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const ValueKey('repartition-amount'),
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n?.repartitionAmount ?? 'Total amount',
                      suffixText: workspace?.currencyCode ?? '',
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('repartition-reverse'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n?.repartitionReverse ??
                        'Reversal — give back as credit notes'),
                    value: _reverse,
                    onChanged: (v) => setState(() => _reverse = v),
                  ),
                  Text(l10n?.repartitionMethod ?? 'Split by',
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<RepartitionMethod>(
                    key: const ValueKey('repartition-method'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: RepartitionMethod.equal,
                        label: Text(l10n?.repartitionMethodEqual ?? 'Equal'),
                      ),
                      ButtonSegment(
                        value: RepartitionMethod.subscription,
                        label: Text(l10n?.repartitionMethodSubscription ??
                            'Subscription'),
                      ),
                      ButtonSegment(
                        value: RepartitionMethod.usage,
                        label: Text(l10n?.repartitionMethodUsage ?? 'Usage'),
                      ),
                      ButtonSegment(
                        value: RepartitionMethod.custom,
                        label: Text(
                            l10n?.repartitionMethodCustom ?? 'Custom key'),
                      ),
                    ],
                    selected: {_method},
                    onSelectionChanged: (s) =>
                        setState(() => _method = s.first),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Text(l10n?.repartitionPeriod ?? 'Lands on',
                        style: theme.textTheme.labelLarge),
                    const Spacer(),
                    IconButton(
                      key: const ValueKey('repartition-period-prev'),
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () =>
                          setState(() => _period = _shift(_period, -1)),
                    ),
                    Text(monthLabel(context, _period),
                        key: const ValueKey('repartition-period')),
                    IconButton(
                      key: const ValueKey('repartition-period-next'),
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () =>
                          setState(() => _period = _shift(_period, 1)),
                    ),
                  ]),
                  const Divider(),
                  Text(l10n?.repartitionPreview ?? 'Shares',
                      style: theme.textTheme.labelLarge),
                  if (cents != null && shares.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        l10n?.repartitionNoShares ??
                            'Nobody carries a share — check the key.',
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
                              labelText: l10n?.repartitionWeight ?? 'Key',
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
                        l10n?.repartitionSum(
                                shares.length, currency.formatMinor(cents!)) ??
                            '${shares.length} members · ${currency.formatMinor(cents!)}',
                        key: const ValueKey('repartition-sum'),
                        style: theme.textTheme.labelMedium,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const ValueKey('repartition-submit'),
                    onPressed: canSubmit ? () => _submit(shares) : null,
                    child: Text(l10n?.repartitionSubmit ?? 'Book the shares'),
                  ),
                  const Divider(height: AppSpacing.xl),
                  Text(l10n?.repartitionHistory ?? 'Distributions',
                      style: theme.textTheme.labelLarge),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        l10n?.repartitionHistoryEmpty ?? 'No distribution yet.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  for (final r in history)
                    ListTile(
                      key: ValueKey('repartition-history-${r.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(r.isReversal
                          ? Icons.undo_outlined
                          : Icons.call_split),
                      title: Text(r.title),
                      subtitle: Text([
                        currency.formatMinor(r.amountCents),
                        monthLabel(context, r.period),
                        _statusLabel(l10n, r.status),
                      ].join(' · ')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(AppLocalizations? l10n, String status) =>
      switch (status) {
        'confirmed' => l10n?.repartitionStatusConfirmed ?? 'Booked',
        'rejected' => l10n?.repartitionStatusRejected ?? 'Rejected',
        'expired' => l10n?.repartitionStatusExpired ?? 'Expired',
        _ => l10n?.repartitionStatusPending ?? 'Awaiting validation',
      };
}
