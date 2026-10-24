// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances — everything about MY money, from every workspace I belong
// to: what I still owe, what I paid, my payments and the reminders I got.
// Issuing and chasing invoices is the workspace's process (Invoicing); this
// screen never shows another member's document.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/page_spec.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/date_text.dart';
import '../../../../core/ui/app_tab_bar.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/account_activity.dart';
import '../../domain/finance_filter.dart';
import '../../domain/finance_overview.dart';
import '../../domain/money_face.dart';
import '../../providers/account_activity_providers.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/money_face_controller.dart';
import '../../providers/money_focus_controller.dart';
import '../widgets/dev_label.dart';
import '../widgets/finance_document_views.dart';
import '../widgets/my_finances_parts.dart';
import '../widgets/own_finance_export_menu.dart';
import '../widgets/personal_payment_provider.dart';
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
  late FinanceFilter _filter = FinanceFilter(workspaceId: widget.workspaceId);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overview = ref.watch(financeOverviewProvider);
    final all = overview.value ?? const FinanceOverview();
    // Me is production. A development space's documents are test data:
    // shown apart, in the development colour, and never counted.
    final devIds = ref.watch(myDevelopmentWorkspaceIdsProvider);
    final data = _filter.apply(all);
    final (prod, dev) = (data.production(devIds), data.development(devIds));
    final (owed, options) = (prod.outstanding.length, all.workspaces);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.financesTitle),
          actions: [if (overview.hasValue) OwnFinanceExportMenu(overview: all)], // #2557 C3
          bottom: AppTabBar.bottom(
            context,
            barKey: const ValueKey('finances-tabs'),
            tabs: [
              AppTab(l10n.financesOutstanding,
                  key: const ValueKey('finances-tab-outstanding'), badge: owed),
              AppTab(l10n.financesPaid,
                  key: const ValueKey('finances-tab-paid')),
              AppTab(l10n.financesPayments,
                  key: const ValueKey('finances-tab-payments')),
              AppTab(l10n.financesReminders,
                  key: const ValueKey('finances-tab-reminders'),
                  badge: prod.invoices.where((i) => i.state.owed && i.reminderCount > 0).length),
            ],
          ),
        ),
        body: switch (overview) {
          AsyncError() => Center(
              child: TextButton(
                key: const ValueKey('finances-retry'),
                onPressed: () => ref.invalidate(financeOverviewProvider),
                child: Text(l10n.accountActivityFailed),
              ),
            ),
          AsyncData() => Column(
              children: [FinancesCoverage(overview: all), // #2557 C4
                if (options.length > 1 || _filter.workspaceId != null)
                  FinancesWorkspaceFilter(
                    key: const ValueKey('my-finances-finances-workspace-filter'),
                    options: options,
                    devIds: devIds,
                    selected: _filter.workspaceId,
                    onSelected: (id) => setState(
                        () => _filter = _filter.copyWith(workspaceId: () => id)),
                  ),
                if (all.invoices.isNotEmpty)
                  FinancesPeriodTypeFilter(
                    key: const ValueKey('finances-period-type-filter'),
                    years: financeYears(all),
                    filter: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _Outstanding(data: prod, dev: dev),
                      _Paid(data: prod, dev: dev),
                      _Payments(filter: _filter, devIds: devIds),
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

/// The window width from which the documents read as rows.
const double _rowsWindowWidth = 840;

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
    // #2557 C4 — a wide window gets the documents as rows, in a wider
    // column; a phone keeps the narrow one.
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: box.maxWidth >= _rowsWindowWidth ? 1200 : 760,
          ),
          child: onRefresh == null
              ? list
              : RefreshIndicator(onRefresh: onRefresh!, child: list),
        ),
      ),
    );
  }
}

/// Opens [invoiceId] itself, in the Money screen of the space it belongs to
/// — a development space's invoice opens in that development space.
Future<void> _openMyInvoice(
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
Future<void> _openMyPayment(
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
      .setPeriod(yearMonth(local.year, local.month));
  router.go('/money');
}

class _Outstanding extends ConsumerWidget {
  const _Outstanding({required this.data, required this.dev});
  final FinanceOverview data;

  /// The development spaces' outstanding invoices, listed apart.
  final FinanceOverview dev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
            title: l10n.financesNothingOwed,
          )
        else ...[
          Card(
            key: const ValueKey('finances-summary'),
            child: Padding(
              padding: AppSpacing.mdAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.financesToPay,
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
                        l10n.financesOverdueCount(overdue),
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
          FinanceDocumentList(invoices: list, documents: data, now: now,
              onOpen: (i) => unawaited(
                  _openMyInvoice(context, ref, i.workspaceId, i.id))),
        ],
        if (dev.outstanding.isNotEmpty) ...[
          const FinancesDevSection(),
          FinanceDocumentList(
              invoices: dev.outstanding,
              documents: dev,
              now: now,
              isDev: true,
              onOpen: (i) => unawaited(
                  _openMyInvoice(context, ref, i.workspaceId, i.id))),
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
    final l10n = context.l10n;
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
            title: l10n.financesNothingPaid,
          )
        else
          FinanceDocumentList(
              invoices: newestFirst(list),
              documents: data,
              now: now,
              onOpen: (i) => unawaited(
                  _openMyInvoice(context, ref, i.workspaceId, i.id))),
        if (dev.paid.isNotEmpty) ...[
          const FinancesDevSection(),
          FinanceDocumentList(
              invoices: newestFirst(dev.paid),
              documents: dev,
              now: now,
              isDev: true,
              onOpen: (i) => unawaited(
                  _openMyInvoice(context, ref, i.workspaceId, i.id))),
        ],
      ],
    );
  }
}

class _Reminders extends ConsumerWidget {
  const _Reminders({required this.data, required this.dev});
  final FinanceOverview data;
  final FinanceOverview dev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
            '${l10n.financesReminderLevel(r.level)} · ${r.invoiceNumber}',
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDev) DevLabel(name: r.workspaceName, small: true),
              Text(
                [
                  if (!isDev) r.workspaceName,
                  format.format(r.sentAt.toLocal()),
                  if (r.automatic) l10n.financesAutomatic,
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          // A reminder opens the invoice it is about, in its own space.
          onTap: workspaceId == null
              ? null
              : () => _openMyInvoice(context, ref, workspaceId, r.invoiceId),
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
            title: l10n.financesNoReminders,
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
  const _Payments({required this.filter, this.devIds = const {}});

  /// The space and the period the payments are narrowed to (#2557 C4).
  final FinanceFilter filter;

  /// My development spaces: their payments are tinted and labelled DEV.
  final Set<String> devIds;

  bool _kept(AccountActivity e) =>
      (filter.workspaceId == null || e.workspaceId == filter.workspaceId) &&
      filter.inPeriod(e.occurredAt);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
              .where(_kept)
              .isEmpty => EmptyState(
              key: const ValueKey('finances-payments-empty'),
              icon: Icons.payments_outlined,
              title: l10n.accountActivityEmpty,
            ),
          AsyncData(value: final all) => Column(
              children: [
                for (final e in all.where(_kept))
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
                      onTap: () => _openMyPayment(
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
              child: Text(l10n.accountActivityFailed),
            ),
          _ => const LoadingView(),
        },
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('finances-full-history'),
            icon: const Icon(Icons.history),
            label: Text(l10n.financesFullHistory),
            onPressed: () => accountActivityPage.open<void>(context, null),
          ),
        ),
      ],
    );
  }
}

/// #2388 — the full account history as a page with a path.
final accountActivityPage = PageSpec<Null>(
  '/account-activity/history',
  (_) => const AccountActivityScreen(),
  fallback: '/account-activity',
);
