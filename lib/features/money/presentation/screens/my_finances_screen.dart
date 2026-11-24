// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances — everything about MY money, from every workspace I belong
// to: what I still owe, what I paid, my payments and the reminders I got.
// Issuing and chasing invoices is the workspace's process (Invoicing); this
// screen never shows another member's document.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/page_spec.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/ui/app_tab_bar.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/account_activity.dart';
import '../../domain/business_payables.dart';
import '../../domain/business_receivables.dart';
import '../../domain/finance_filter.dart';
import '../../domain/finance_overview.dart';
import '../../providers/account_activity_providers.dart';
import '../../providers/business_receivables_providers.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/invoice_group_providers.dart';
import '../my_finances_open.dart';
import '../widgets/billed_section.dart';
import '../widgets/business_detail_sheet.dart';
import '../widgets/dev_label.dart';
import '../widgets/finance_document_views.dart';
import '../widgets/finance_selection_bar.dart';
import '../widgets/finances_owed_summary.dart';
import '../widgets/host_payment_pages.dart';
import '../widgets/invoice_groups_bar.dart';
import '../widgets/invoice_process_sheet.dart';
import '../widgets/my_businesses_face.dart';
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

  /// #3556 — one of my own groups, or none.
  String? _groupId;

  /// #4167 — Personal (everything above, unchanged) or My businesses.
  FinancesFace _face = FinancesFace.personal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overview = ref.watch(financeOverviewProvider);
    final all = overview.value ?? const FinanceOverview(); // empty-ok: the body shows it only on data; loading and a failure have their own faces (below)
    // Me is production. A development space's documents are test data:
    // shown apart, in the development colour, and never counted.
    final devIds = ref.watch(financeDevelopmentWorkspaceIdsProvider);
    final group = ref.watch(invoiceGroupViewsProvider)[_groupId];
    final data = group == null ? _filter.apply(all) : _filter.apply(all).where(group.shows);
    final (prod, dev) = (data.production(devIds), data.development(devIds));
    final (owed, options) = (prod.payable.length, all.workspaces);
    // #3682 — while a source has not answered, an empty list is not "none".
    final partial = all.notAnswered.isNotEmpty;
    // #4167 — My businesses is reachable only for a person who may read at least
    // one business's finances; being a customer of a business grants nothing.
    final businesses = ref.watch(myBusinessReceivablesProvider).value ?? // empty-ok: each business says its own failure in the face; with no list the face is not offered
        const <BusinessReceivablesSource>[];
    final hasBusinesses = businesses.any((s) => s is BusinessReceivablesAnswered);
    final payables = ref.watch(myBusinessPayablesProvider).value ?? const <BusinessPayables>[]; // empty-ok: each direction of each business says its own failure; nothing is invented for what was not read
    Widget faceSwitch() => FinancesFaceSwitch(
      key: const ValueKey('finances-face-switch'),
      selected: _face,
      onChanged: (f) => setState(() => _face = f),
    );
    if (hasBusinesses && _face == FinancesFace.businesses) {
      return Scaffold(
        appBar: AppBar(title: PageTitle(l10n.tabMoney)),
        body: Column(
          children: [
            faceSwitch(),
            Expanded(
              child: MyBusinessesFace(
                sources: [
                  for (final s in businesses)
                    if (s is! BusinessReceivablesRefused) s,
                ],
                payables: payables,
                onRetry: () => ref
                  ..invalidate(myBusinessReceivablesProvider)
                  ..invalidate(myBusinessPayablesProvider),
                onDetail: (detail) => unawaited(showBusinessDetail(context, detail)),
                onOpen: (workspaceId) {
                  final s = businesses.firstWhere((s) => s.workspaceId == workspaceId);
                  unawaited(openMyInvoice(context, ref, s.target, null, s.name));
                },
              ),
            ),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        // #3556 — a selection's count, total, Pay and I have paid.
        bottomNavigationBar: const FinanceSelectionBar(),
        appBar: AppBar(
          title: PageTitle(l10n.tabMoney),
          actions: [const InvoiceProcessHelpButton(),
            if (overview.hasValue) OwnFinanceExportMenu(overview: all)], // #2557 C3
          bottom: AppTabBar.bottom(
            context,
            barKey: const ValueKey('finances-tabs'),
            tabs: [
              AppTab(l10n.financesOutstanding,
                  key: const ValueKey('finances-tab-outstanding'), badge: owed),
              AppTab(l10n.financesPaid,
                  key: const ValueKey('finances-tab-paid')),
              AppTab(l10n.invoicePdfPayments,
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
              children: [
                if (hasBusinesses) faceSwitch(),
                FinancesCoverage(overview: all), // #2557 C4
                if (options.length > 1 || _filter.workspaceId != null)
                  FinancesWorkspaceFilter(
                    key: const ValueKey('my-finances-finances-workspace-filter'),
                    options: options,
                    devIds: devIds,
                    selected: _filter.workspaceId,
                    onSelected: (id) => setState(
                        () => _filter = _filter.copyWith(workspaceId: () => id)),
                  ),
                InvoiceGroupsBar(
                    key: const ValueKey('my-finances-groups'),
                    selected: group?.group.id,
                    onSelected: (id) => setState(() => _groupId = id)),
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
                      _Outstanding(data: prod, dev: dev, partial: partial, billed: prod.billedGroups),
                      _Paid(data: prod, dev: dev, partial: partial),
                      _Payments(
                          filter: _filter,
                          devIds: devIds,
                          zones: financeZones(all),
                          hostPayments: all.payments),
                      _Reminders(data: prod, dev: dev, partial: partial),
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

/// An empty list: complete only when every source answered (#3682).
Widget _empty(BuildContext context, String key, IconData icon, String none,
        {required bool partial}) =>
    EmptyState(key: ValueKey(key), icon: icon,
        title: partial ? context.l10n.financesNothingSoFar : none);

class _Outstanding extends ConsumerWidget {
  const _Outstanding({required this.data, required this.dev, required this.partial, required this.billed});
  final FinanceOverview data;
  final bool partial;
  final List<BilledSubject> billed; // #4164 B2: invoiced to me as a customer, apart

  /// The development spaces' outstanding invoices, listed apart.
  final FinanceOverview dev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(financeNowProvider);
    final list = newestFirst(data.outstanding);
    return FinancesColumn(
      onRefresh: () => refreshMyFinances(ref),
      children: [
        if (list.isEmpty)
          _empty(context, 'finances-outstanding-empty',
              Icons.check_circle_outline, l10n.financesNothingOwed,
              partial: partial)
        else ...[
          FinancesOwedSummary(data: data, now: now),
          const SizedBox(height: AppSpacing.sm),
          FinanceDocumentList(invoices: list, documents: data, now: now,
              onOpen: (i) => unawaited(
                  openMyInvoice(context, ref, i.target, i.id, i.workspaceName))),
        ],
        if (dev.outstanding.isNotEmpty) ...[
          const FinancesDevSection(),
          FinanceDocumentList(
              invoices: newestFirst(dev.outstanding),
              documents: dev,
              now: now,
              isDev: true,
              onOpen: (i) => unawaited(
                  openMyInvoice(context, ref, i.target, i.id, i.workspaceName))),
        ],
        BilledPart(groups: billed, now: now), // #4164 B2
      ],
    );
  }
}

class _Paid extends ConsumerWidget {
  const _Paid({required this.data, required this.dev, required this.partial});
  final FinanceOverview data;
  final FinanceOverview dev;
  final bool partial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final now = ref.watch(financeNowProvider);
    final list = data.paid;
    return FinancesColumn(
      onRefresh: () => refreshMyFinances(ref),
      children: [
        if (list.isEmpty)
          _empty(context, 'finances-paid-empty', Icons.receipt_long_outlined,
              l10n.financesNothingPaid, partial: partial)
        else
          FinanceDocumentList(
              invoices: newestFirst(list),
              documents: data,
              now: now,
              onOpen: (i) => unawaited(
                  openMyInvoice(context, ref, i.target, i.id, i.workspaceName))),
        if (dev.paid.isNotEmpty) ...[
          const FinancesDevSection(),
          FinanceDocumentList(
              invoices: newestFirst(dev.paid),
              documents: dev,
              now: now,
              isDev: true,
              onOpen: (i) => unawaited(
                  openMyInvoice(context, ref, i.target, i.id, i.workspaceName))),
        ],
      ],
    );
  }
}

class _Reminders extends ConsumerWidget {
  const _Reminders({required this.data, required this.dev, required this.partial});
  final FinanceOverview data;
  final FinanceOverview dev;
  final bool partial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final format = personalFormatOf(context).dates(DateShape.date);
    final workspaceOf = {
      for (final i in [...data.invoices, ...dev.invoices]) (i.networkId, i.id): i.target,
    };
    Widget row(FinanceReminder r, {bool isDev = false}) {
      final tone = AppEnvironmentColors.developmentOf(theme.brightness);
      // A reminder opens its invoice in the reminder's own workspace: an
      // equal local invoice id on another host is another invoice.
      final target = r.target ?? workspaceOf[(r.networkId, r.invoiceId)];
      return KeyedSubtree(
        key: ValueKey((r.networkId ?? r.workspaceName, r.id)),
        child: Card(
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
                  format.format(personalFormatOf(context).wall(r.sentAt)),
                  if (r.automatic) l10n.financesAutomatic,
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          // A reminder opens the invoice it is about, in its own space.
          onTap: target == null
              ? null
              : () => openMyInvoice(context, ref, target, r.invoiceId, r.workspaceName),
        ),
      ),
      );
    }

    return FinancesColumn(
      onRefresh: () => refreshMyFinances(ref),
      children: [
        if (data.reminders.isEmpty && dev.reminders.isEmpty)
          _empty(context, 'finances-reminders-empty',
              Icons.notifications_none_outlined, l10n.financesNoReminders,
              partial: partial),
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
  const _Payments({
    required this.filter,
    this.devIds = const {},
    this.zones = const {},
    this.hostPayments = const [],
  });

  /// The business zone of each workspace, so a payment's year is read on its business's calendar.
  final Map<String, String?> zones;

  /// C6 — my payments on the connected hosts, as they answer; beside the
  /// personal home's own, each payment once by workspace and id.
  final List<AccountActivity> hostPayments;

  /// The space and the period the payments are narrowed to (#2557 C4).
  final FinanceFilter filter;

  /// My development spaces: their payments are tinted and labelled DEV.
  final Set<String> devIds;

  bool _kept(AccountActivity e) =>
      (filter.workspaceId == null || e.networkId == filter.workspaceId) &&
      filter.inPeriod(e.occurredAt, timezone: zones[e.networkId]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final home = ref.watch(accountActivityProvider(AccountActivityKind.payments));
    final format = personalFormatOf(context).dates(DateShape.date);
    Widget list(List<AccountActivity> all) => Column(
              children: [
                for (final e in all.where(_kept))
                  KeyedSubtree(
                    key: ValueKey((e.networkId, e.id)),
                    child: Card(
                    key: ValueKey('finances-payment-${e.id}'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    color: devIds.contains(e.networkId)
                        ? AppEnvironmentColors.developmentOf(
                            Theme.of(context).brightness,
                          ).withValues(alpha: .10)
                        : null,
                    child: ListTile(
                      key: ValueKey('finances-payment-open-${e.id}'),
                      leading: const Icon(Icons.payments_outlined),
                      title: devIds.contains(e.networkId)
                          ? DevLabel(name: e.workspaceName)
                          : Text(e.workspaceName),
                      onTap: () => openMyPayment(
                        context,
                        ref,
                        e.target,
                        e.occurredAt,
                        e.workspaceName,
                      ),
                      subtitle: Text([
                        if (e.description.isNotEmpty) e.description,
                        format.format(personalFormatOf(context).wall(e.occurredAt)),
                      ].join(' · ')),
                      trailing: e.amountCents == null
                          ? null
                          : Text(personalFormatOf(context).moneyNamed(e.currency).formatMinor(e.amountCents!)),
                    ),
                  ),
                  ),
              ],
            );
    return FinancesColumn(
      onRefresh: () async {
        ref.invalidate(accountActivityProvider(AccountActivityKind.payments));
        await Future.wait([
          refreshMyFinances(ref),
          ref.read(accountActivityProvider(AccountActivityKind.payments).future),
        ]);
      },
      children: [
        const PersonalPaymentProvider(),
        HostPaymentPages(
          builder: (more) {
            final away = [...hostPayments, ...more];
            final rows = home.whenData(
              (own) => FinanceOverview.newestFirst(
                FinanceOverview(payments: own)
                    .merge(FinanceOverview(payments: away))
                    .payments,
              ),
            );
            return switch (rows) {
              AsyncData(value: final all) when all
                  .where(_kept)
                  .isEmpty => EmptyState(
                  key: const ValueKey('finances-payments-empty'),
                  icon: Icons.payments_outlined,
                  title: l10n.accountActivityEmpty,
                ),
              AsyncData(value: final all) => list(all),
              // The home did not answer: its Try again, and the connected
              // hosts' payments stay.
              AsyncError() => Column(
                  children: [
                    TextButton(
                      key: const ValueKey('finances-payments-retry'),
                      onPressed: () => ref.invalidate(
                          accountActivityProvider(AccountActivityKind.payments)),
                      child: Text(l10n.accountActivityFailed),
                    ),
                    list(FinanceOverview.newestFirst(away)),
                  ],
                ),
              _ => const LoadingView(),
            };
          },
        ),
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
