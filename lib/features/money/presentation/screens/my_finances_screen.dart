// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances — everything about MY money, from every workspace I belong
// to: what I still owe, what I paid, my payments and the reminders I got.
// Issuing and chasing invoices is the workspace's process (Invoicing); this
// screen never shows another member's document.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/account_activity.dart';
import '../../domain/finance_overview.dart';
import '../../providers/account_activity_providers.dart';
import '../../providers/finance_overview_provider.dart';
import '../widgets/dev_label.dart';
import '../widgets/my_finances_parts.dart';
import '../../domain/money_face.dart';
import '../../providers/money_face_controller.dart';
import '../../providers/money_focus_controller.dart';
import '../widgets/personal_payment_provider.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/status_colors.dart';
import 'account_activity_screen.dart';

class MyFinancesScreen extends ConsumerStatefulWidget {
  /// [workspaceId] narrows every list to one workspace — what a workspace's
  /// own screens link to ("my documents from this space").
  const MyFinancesScreen({super.key, this.workspaceId});
  final String? workspaceId;

  @override
  ConsumerState<MyFinancesScreen> createState() => _MyFinancesState();
}

class _MyFinancesState extends ConsumerState<MyFinancesScreen> {
  late String? _workspace = widget.workspaceId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(financeOverviewProvider);
    final all = overview.value ?? const FinanceOverview();
    // Me is production. A development space's documents are test data:
    // shown apart, in the development colour, and never counted.
    final devIds = ref.watch(myDevelopmentWorkspaceIdsProvider);
    final data = all.inWorkspace(_workspace);
    final prod = data.production(devIds);
    final dev = data.development(devIds);
    final owed = prod.outstanding.length;
    final options = all.workspaces;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n?.financesTitle ?? 'Finances'),
          bottom: TabBar(
            key: const ValueKey('finances-tabs'),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                key: const ValueKey('finances-tab-outstanding'),
                child: _FinancesLabel.label(l10n?.financesOutstanding ?? 'Outstanding', owed),
              ),
              Tab(
                key: const ValueKey('finances-tab-paid'),
                text: l10n?.financesPaid ?? 'Paid',
              ),
              Tab(
                key: const ValueKey('finances-tab-payments'),
                text: l10n?.financesPayments ?? 'Payments',
              ),
              Tab(
                key: const ValueKey('finances-tab-reminders'),
                child: _FinancesLabel.label(
                  l10n?.financesReminders ?? 'Reminders',
                  prod.invoices.where((i) => i.state.owed && i.reminderCount > 0).length,
                ),
              ),
            ],
          ),
        ),
        body: switch (overview) {
          AsyncError() => Center(
              child: TextButton(
                key: const ValueKey('finances-retry'),
                onPressed: () => ref.invalidate(financeOverviewProvider),
                child: Text(l10n?.accountActivityFailed ??
                    'Could not load your financial history. Tap to retry.'),
              ),
            ),
          AsyncData() => Column(
              children: [
                if (options.length > 1 || _workspace != null)
                  FinancesWorkspaceFilter(
                    options: options,
                    devIds: devIds,
                    selected: _workspace,
                    onSelected: (id) => setState(() => _workspace = id),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _Outstanding(data: prod, dev: dev),
                      _Paid(data: prod, dev: dev),
                      _Payments(workspaceId: _workspace, devIds: devIds),
                      _Reminders(data: prod, dev: dev),
                    ],
                  ),
                ),
              ],
            ),
          _ => const LoadingView(),
        },
      ),
    );
  }
}

class _FinancesLabel {
  static Widget label(String text, int count) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Badge.count(count: count),
          ],
        ],
      );
}

/// A bounded, centred column: a list of money rows is read, not scanned
/// edge to edge.
class _Column extends StatelessWidget {
  const _Column({required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: AppSpacing.mdAll,
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}

/// Opens [invoiceId] itself, in the Money screen of the space it belongs to
/// — a development space's invoice opens in that development space.
Future<void> openMyInvoice(
  BuildContext context,
  WidgetRef ref,
  String workspaceId,
  String invoiceId,
) async {
  final router = GoRouter.of(context);
  await ref.read(activeWorkspaceIdProvider.notifier).select(workspaceId);
  ref.read(invoiceFocusProvider.notifier).request(workspaceId, invoiceId);
  router.go('/money');
}

/// Opens the Payments face of [workspaceId] on the month of [at].
Future<void> openMyPayment(
  BuildContext context,
  WidgetRef ref,
  String workspaceId,
  DateTime at,
) async {
  final router = GoRouter.of(context);
  await ref.read(activeWorkspaceIdProvider.notifier).select(workspaceId);
  ref.read(moneyFaceControllerProvider.notifier).show(MoneyFace.payments);
  final local = at.toLocal();
  ref
      .read(moneyFocusControllerProvider.notifier)
      .setPeriod('${local.year}-${local.month.toString().padLeft(2, '0')}');
  router.go('/money');
}

class _Outstanding extends ConsumerWidget {
  const _Outstanding({required this.data, required this.dev});
  final FinanceOverview data;

  /// The development spaces' outstanding invoices, listed apart.
  final FinanceOverview dev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider).now();
    final list = data.outstanding;
    final overdue = list.where((i) => i.overdueAt(now)).length;
    return _Column(
      onRefresh: () async {
        ref.invalidate(financeOverviewProvider);
        await ref.read(financeOverviewProvider.future);
      },
      children: [
        if (list.isEmpty)
          EmptyState(
            key: const ValueKey('finances-outstanding-empty'),
            icon: Icons.check_circle_outline,
            title: l10n?.financesNothingOwed ?? 'Nothing to pay — you are up to date.',
          )
        else ...[
          Card(
            key: const ValueKey('finances-summary'),
            child: Padding(
              padding: AppSpacing.mdAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n?.financesToPay ?? 'To pay',
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  for (final e in data.owedByCurrency.entries)
                    Text(
                      moneyFormat(e.key).formatMinor(e.value),
                      style: theme.textTheme.headlineSmall?.strong.copyWith(
                        color: overdue > 0 ? theme.colorScheme.error : null,
                      ),
                    ),
                  if (overdue > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n?.financesOverdueCount(overdue) ?? '$overdue overdue',
                        key: const ValueKey('finances-overdue'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final invoice in list) _InvoiceCard(invoice: invoice, now: now),
        ],
        if (dev.outstanding.isNotEmpty) ...[
          const FinancesDevSection(),
          for (final invoice in dev.outstanding)
            _InvoiceCard(invoice: invoice, now: now, isDev: true),
        ],
      ],
    );
  }
}

class _Paid extends ConsumerWidget {
  const _Paid({required this.data, required this.dev});
  final FinanceOverview data;
  final FinanceOverview dev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider).now();
    final list = data.paid;
    return _Column(
      onRefresh: () async {
        ref.invalidate(financeOverviewProvider);
        await ref.read(financeOverviewProvider.future);
      },
      children: [
        if (list.isEmpty)
          EmptyState(
            key: const ValueKey('finances-paid-empty'),
            icon: Icons.receipt_long_outlined,
            title: l10n?.financesNothingPaid ?? 'No settled invoice yet.',
          )
        else
          for (final invoice in list) _InvoiceCard(invoice: invoice, now: now),
        if (dev.paid.isNotEmpty) ...[
          const FinancesDevSection(),
          for (final invoice in dev.paid)
            _InvoiceCard(invoice: invoice, now: now, isDev: true),
        ],
      ],
    );
  }
}

class _InvoiceCard extends ConsumerWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.now,
    this.isDev = false,
  });
  final FinanceInvoice invoice;
  final DateTime now;

  /// A development space's invoice: tinted and labelled DEV.
  final bool isDev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final format = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    final overdue = invoice.overdueAt(now);
    final due = invoice.dueOn;
    final status = switch (invoice.state) {
      FinanceState.open => null,
      FinanceState.awaitingValidation =>
        l10n?.financesAwaitingValidation ?? 'Payment being validated',
      FinanceState.partiallyPaid => l10n?.financesPartlyPaid ?? 'Partly paid',
      FinanceState.paid => l10n?.financesStatePaid ?? 'Paid',
      FinanceState.refunded => l10n?.financesStateRefunded ?? 'Refunded',
      FinanceState.closed => l10n?.financesStateClosed ?? 'Closed',
    };
    final amount = invoice.state.owed ? invoice.remainingCents : invoice.totalCents;
    final devTone = AppEnvironmentColors.developmentOf(theme.brightness);
    return Card(
      key: ValueKey('finances-invoice-${invoice.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      color: isDev ? devTone.withValues(alpha: .10) : null,
      shape: isDev
          ? RoundedRectangleBorder(
              borderRadius: AppRadius.lgAll,
              side: BorderSide(color: devTone.withValues(alpha: .55)),
            )
          : null,
      child: InkWell(
        key: ValueKey('finances-open-${invoice.id}'),
        onTap: () =>
            openMyInvoice(context, ref, invoice.workspaceId, invoice.id),
        child: Padding(
          padding: AppSpacing.mdAll,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: scheme.onSurfaceVariant,
                child: Text(invoice.workspaceName.isEmpty
                    ? '?'
                    : invoice.workspaceName.characters.first.toUpperCase()),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                    if (isDev)
                      DevLabel(name: invoice.workspaceName, small: true)
                    else
                      Text(invoice.workspaceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    if (invoice.state.owed && due != null)
                      Text(
                        overdue
                            ? (l10n?.financesOverdueSince(format.format(due)) ??
                                'Overdue since ${format.format(due)}')
                            : (l10n?.financesDueOn(format.format(due)) ??
                                'Due ${format.format(due)}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: overdue ? scheme.error : scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(format.format(invoice.issuedAt),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    if (status != null || invoice.reminderCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            if (status != null)
                              Chip(
                                label: Text(status),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (invoice.reminderCount > 0 && invoice.state.owed)
                              Chip(
                                label: Text(l10n?.financesRemindedTimes(
                                        invoice.reminderCount) ??
                                    'Reminded ×${invoice.reminderCount}'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                moneyFormat(invoice.currency).formatMinor(amount),
                style: theme.textTheme.titleSmall?.strong.copyWith(
                  color: overdue ? scheme.error : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reminders extends ConsumerWidget {
  const _Reminders({required this.data, required this.dev});
  final FinanceOverview data;
  final FinanceOverview dev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    final workspaceOf = {
      for (final i in [...data.invoices, ...dev.invoices]) i.id: i.workspaceId,
    };
    Widget row(FinanceReminder r, {bool isDev = false}) {
      final tone = AppEnvironmentColors.developmentOf(theme.brightness);
      final workspaceId = workspaceOf[r.invoiceId];
      return Card(
        key: ValueKey('finances-reminder-${r.id}'),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        color: isDev ? tone.withValues(alpha: .10) : null,
        child: ListTile(
          key: ValueKey('finances-reminder-open-${r.id}'),
          leading: Icon(
            Icons.notifications_active_outlined,
            color: isDev ? tone : null,
          ),
          title: Text(
            '${l10n?.financesReminderLevel(r.level) ?? 'Reminder ${r.level}'} · ${r.invoiceNumber}',
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDev) DevLabel(name: r.workspaceName, small: true),
              Text(
                [
                  if (!isDev) r.workspaceName,
                  format.format(r.sentAt.toLocal()),
                  if (r.automatic) l10n?.financesAutomatic ?? 'automatic',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          // A reminder opens the invoice it is about, in its own space.
          onTap: workspaceId == null
              ? null
              : () => openMyInvoice(context, ref, workspaceId, r.invoiceId),
        ),
      );
    }

    return _Column(
      onRefresh: () async {
        ref.invalidate(financeOverviewProvider);
        await ref.read(financeOverviewProvider.future);
      },
      children: [
        if (data.reminders.isEmpty && dev.reminders.isEmpty)
          EmptyState(
            key: const ValueKey('finances-reminders-empty'),
            icon: Icons.notifications_none_outlined,
            title: l10n?.financesNoReminders ?? 'No reminder received.',
          ),
        for (final r in data.reminders) row(r),
        if (dev.reminders.isNotEmpty) ...[
          const FinancesDevSection(),
          for (final r in dev.reminders) row(r, isDev: true),
        ],
      ],
    );
  }
}

class _Payments extends ConsumerWidget {
  const _Payments({this.workspaceId, this.devIds = const {}});

  /// Only this workspace's payments; all of them when null.
  final String? workspaceId;

  /// My development spaces: their payments are tinted and labelled DEV.
  final Set<String> devIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(accountActivityProvider(AccountActivityKind.payments));
    final format = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    return _Column(
      onRefresh: () async {
        ref.invalidate(accountActivityProvider(AccountActivityKind.payments));
      },
      children: [
        const PersonalPaymentProvider(),
        switch (rows) {
          AsyncData(value: final all) when all
              .where((e) => workspaceId == null || e.workspaceId == workspaceId)
              .isEmpty => EmptyState(
              key: const ValueKey('finances-payments-empty'),
              icon: Icons.payments_outlined,
              title: l10n?.accountActivityEmpty ?? 'No records to display.',
            ),
          AsyncData(value: final all) => Column(
              children: [
                for (final e in all.where(
                  (e) => workspaceId == null || e.workspaceId == workspaceId,
                ))
                  Card(
                    key: ValueKey('finances-payment-${e.id}'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    color: devIds.contains(e.workspaceId)
                        ? AppEnvironmentColors.developmentOf(
                            Theme.of(context).brightness,
                          ).withValues(alpha: .10)
                        : null,
                    child: ListTile(
                      key: ValueKey('finances-payment-open-${e.id}'),
                      leading: const Icon(Icons.payments_outlined),
                      title: devIds.contains(e.workspaceId)
                          ? DevLabel(name: e.workspaceName)
                          : Text(e.workspaceName),
                      onTap: () => openMyPayment(
                        context,
                        ref,
                        e.workspaceId,
                        e.occurredAt,
                      ),
                      subtitle: Text([
                        if (e.description.isNotEmpty) e.description,
                        format.format(e.occurredAt.toLocal()),
                      ].join(' · ')),
                      trailing: e.amountCents == null
                          ? null
                          : Text(moneyFormat(e.currency).formatMinor(e.amountCents!)),
                    ),
                  ),
              ],
            ),
          AsyncError() => TextButton(
              key: const ValueKey('finances-payments-retry'),
              onPressed: () =>
                  ref.invalidate(accountActivityProvider(AccountActivityKind.payments)),
              child: Text(l10n?.accountActivityFailed ??
                  'Could not load your financial history. Tap to retry.'),
            ),
          _ => const LoadingView(),
        },
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('finances-full-history'),
            icon: const Icon(Icons.history),
            label: Text(l10n?.financesFullHistory ?? 'Full history, usage and other servers'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AccountActivityScreen()),
            ),
          ),
        ),
      ],
    );
  }
}
