// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4007 — an organisation's houses side by side (decision 0052, point 6):
// one month for every house; each house's figures exactly as its own
// analysis shows them, in its own currency; a house whose figures the
// reader may not read is named with the reason; below, one total per
// currency, never one across currencies. A house is one tap away: its own
// analysis when the reader may read it, else its home.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show yearMonth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_classes.dart' show kDefaultHome;
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/country_names.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/page_spec.dart';
import '../../../../core/session/session_source.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/organisation_overview.dart';
import '../../providers/active_workspace_providers.dart';
import '../../providers/organisation_providers.dart';

/// The overview of the organisation [organisationId].
class OrganisationOverviewScreen extends ConsumerStatefulWidget {
  const OrganisationOverviewScreen({super.key, required this.organisationId});

  final String organisationId;

  /// Where the overview of [organisationId] is.
  static String _location(String organisationId) =>
      '/organisation/$organisationId/overview';

  /// Opens the overview of [organisationId].
  static Future<void> open(BuildContext context, String organisationId) =>
      openLocation<void>(
        context,
        _location(organisationId),
        orBuild: (_) =>
            OrganisationOverviewScreen(organisationId: organisationId),
      );

  @override
  ConsumerState<OrganisationOverviewScreen> createState() =>
      _OrganisationOverviewScreenState();
}

class _OrganisationOverviewScreenState
    extends ConsumerState<OrganisationOverviewScreen> {
  /// The first day of the month shown; this month until the reader moves.
  late DateTime _month = () {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month);
  }();

  bool get _isThisMonth {
    final now = ref.read(clockProvider).now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final month = yearMonth(_month.year, _month.month);
    final provider = organisationOverviewProvider(widget.organisationId, month);
    final name = ref
        .watch(myOrganisationsProvider)
        .value
        ?.where((o) => o.id == widget.organisationId)
        .firstOrNull
        ?.name;
    return Scaffold(
      appBar: AppBar(title: Text(name ?? l10n.organisationOverviewTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthBar(month: _month, isThisMonth: _isThisMonth, onShift: _shift),
          Expanded(
            child: AsyncReadBody<OrganisationOverview>(
              value: ref.watch(provider),
              onRetry: () => ref.invalidate(provider),
              data: (overview) => _OverviewBody(overview: overview),
            ),
          ),
        ],
      ),
    );
  }
}

/// The month every house is read for: previous, its name, next (not past
/// this month).
class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.isThisMonth,
    required this.onShift,
  });

  final DateTime month;
  final bool isThisMonth;
  final void Function(int) onShift;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('organisation-overview-previous'),
            tooltip: material.previousMonthTooltip,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onShift(-1),
          ),
          Expanded(
            child: Text(
              appFormatOf(context).dates(DateShape.monthYear).format(month),
              key: const ValueKey('organisation-overview-month'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: const ValueKey('organisation-overview-next'),
            tooltip: material.nextMonthTooltip,
            icon: const Icon(Icons.chevron_right),
            onPressed: isThisMonth ? null : () => onShift(1),
          ),
        ],
      ),
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({required this.overview});

  final OrganisationOverview overview;

  /// Opens [house]: its own analysis when the reader may read it, else its
  /// home. The tap stands only for the account it was made in.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    OverviewHouse house,
  ) async {
    final router = GoRouter.of(context);
    final principal = ref.read(sessionStateProvider).value;
    await ref
        .read(activeWorkspaceIdProvider.notifier)
        .select(house.workspaceId);
    if (!context.mounted) return;
    if (ref.read(sessionStateProvider).value != principal) return;
    router.go(house.withheld == null ? '/bi' : kDefaultHome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    String figureText(OverviewHouse h, HouseFigure? f) =>
        f == null ? '—' : format.moneyIn(h.currencyCode).formatMinor(f.minor);
    String overdue(OverviewHouse h) => switch (h.overdue) {
      final f? when f.asOf != null => l10n.organisationOverviewAsOf(
        figureText(h, f),
        format.time(f.asOf!),
      ),
      final f => figureText(h, f),
    };
    Widget amount(OverviewHouse h, String text) =>
        Text(h.withheld == null ? text : '', textAlign: TextAlign.end);
    return Padding(
      padding: AppSpacing.gutterAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (overview.houses.length == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                l10n.organisationOverviewOneHouse,
                key: const ValueKey('organisation-overview-one-house'),
              ),
            ),
          Expanded(
            child: RecordsTable<OverviewHouse>(
              tableId: 'organisation-overview',
              rows: overview.houses,
              keyOf: (h) => h.workspaceId,
              searchText: (h) => h.name,
              onOpen: (h) => _open(context, ref, h),
              empty: Center(child: Text(l10n.organisationOverviewNone)),
              cardBuilder: (context, h) => _HouseCard(
                house: h,
                invoiced: figureText(h, h.invoiced),
                collected: figureText(h, h.collected),
                overdue: overdue(h),
              ),
              columns: [
                RecordColumn(
                  id: 'house',
                  label: l10n.organisationOverviewHouse,
                  flex: 3,
                  sortKey: (h) => h.name,
                  cell: (_, h) => Text(
                    h.isHead
                        ? l10n.organisationOverviewHeadName(h.name)
                        : h.name,
                  ),
                ),
                RecordColumn(
                  id: 'country',
                  label: l10n.organisationOverviewCountry,
                  flex: 2,
                  cell: (_, h) =>
                      Text(localizedCountryName(l10n, h.countryCode)),
                ),
                RecordColumn(
                  id: 'currency',
                  label: l10n.organisationOverviewCurrency,
                  flex: 2,
                  cell: (_, h) => Text(h.currencyCode),
                ),
                RecordColumn(
                  id: 'invoiced',
                  label: l10n.biFinanceInvoiced,
                  flex: 2,
                  numeric: true,
                  cell: (_, h) => h.withheld == null
                      ? amount(h, figureText(h, h.invoiced))
                      : Text(
                          _withheldText(l10n, h.withheld!),
                          key: ValueKey('withheld-${h.workspaceId}'),
                        ),
                ),
                RecordColumn(
                  id: 'collected',
                  label: l10n.biFinanceCollected,
                  flex: 2,
                  numeric: true,
                  cell: (_, h) => amount(h, figureText(h, h.collected)),
                ),
                RecordColumn(
                  id: 'overdue',
                  label: l10n.overviewOverdueTitle,
                  flex: 2,
                  numeric: true,
                  cell: (_, h) => amount(h, overdue(h)),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(child: _Totals(overview: overview)),
          ),
        ],
      ),
    );
  }
}

String _withheldText(AppLocalizations l10n, OverviewWithheld withheld) =>
    switch (withheld) {
      OverviewWithheld.notPermitted => l10n.organisationOverviewNotPermitted,
      OverviewWithheld.notEnabled => l10n.organisationOverviewNotEnabled,
    };

/// One house on a phone: its name and its three figures, or the reason it
/// shows none.
class _HouseCard extends StatelessWidget {
  const _HouseCard({
    required this.house,
    required this.invoiced,
    required this.collected,
    required this.overdue,
  });

  final OverviewHouse house;
  final String invoiced;
  final String collected;
  final String overdue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final withheld = house.withheld;
    return ListTile(
      title: Text(
        house.isHead
            ? l10n.organisationOverviewHeadName(house.name)
            : house.name,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${localizedCountryName(l10n, house.countryCode)} · '
            '${house.currencyCode}',
          ),
          if (withheld != null)
            Text(_withheldText(l10n, withheld))
          else ...[
            Text(
              l10n.organisationOverviewCardLine(
                l10n.biFinanceInvoiced,
                invoiced,
              ),
            ),
            Text(
              l10n.organisationOverviewCardLine(
                l10n.biFinanceCollected,
                collected,
              ),
            ),
            Text(
              l10n.organisationOverviewCardLine(
                l10n.overviewOverdueTitle,
                overdue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line per currency, each its own; an incomplete total says which
/// houses it is missing.
class _Totals extends StatelessWidget {
  const _Totals({required this.overview});

  final OrganisationOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            l10n.organisationOverviewTotals,
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final t in overview.totals) ...[
          Text(
            l10n.organisationOverviewTotalLine(
              t.currencyCode,
              format.moneyIn(t.currencyCode).formatMinor(t.invoiced),
              format.moneyIn(t.currencyCode).formatMinor(t.collected),
              format.moneyIn(t.currencyCode).formatMinor(t.overdue),
            ),
            key: ValueKey('organisation-total-${t.currencyCode}'),
          ),
          if (t.incomplete)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                l10n.organisationOverviewIncomplete(
                  overview.missingIn(t.currencyCode).join(', '),
                ),
                key: ValueKey('organisation-incomplete-${t.currencyCode}'),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}
