// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4431 (G17) -- the expiry report: at a date the person chooses (today on the business's calendar by default), every lot or
// piece on hand that is expired at it or expires after it, by date then place, for one place and one item group if asked. The
// same rows print through the report engine with the layout the business edits. The server reads it (the stock's own read);
// a failure says so and reads again, and nothing is shown as an empty list that was not read.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_expiry.dart';
import '../providers/stock_providers.dart';
import 'stock_page_shell.dart';

class StockExpiryScreen extends ConsumerStatefulWidget {
  const StockExpiryScreen({super.key});

  @override
  ConsumerState<StockExpiryScreen> createState() => _StockExpiryState();
}

class _StockExpiryState extends ConsumerState<StockExpiryScreen> {
  late final ValueNotifier<ExpiryQuery> _query = ValueNotifier(
    ExpiryQuery(on: ref.read(businessDateOfProvider)(ref.read(clockProvider).now())),
  );
  final _horizon = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    _horizon.dispose();
    super.dispose();
  }

  void _set({DateTime? on, ExpiryScope? scope, int? Function()? horizon, String? Function()? place, String? Function()? group}) {
    final q = _query.value;
    _query.value = ExpiryQuery(
      on: on ?? q.on,
      scope: scope ?? q.scope,
      horizonDays: horizon == null ? q.horizonDays : horizon(),
      locationId: place == null ? q.locationId : place(),
      groupId: group == null ? q.groupId : group(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StockPageShell(
      title: l10n.stockExpiryTitle,
      anchor: HelpAnchor.moneyStockExpiry,
      body: (context, ref, workspaceId) => ValueListenableBuilder<ExpiryQuery>(
        valueListenable: _query,
        builder: (context, query, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _Filters(workspaceId: workspaceId, query: query, horizon: _horizon, set: _set),
            const FormGap(),
            _Answer(workspaceId: workspaceId, query: query),
          ],
        ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.workspaceId, required this.query, required this.horizon, required this.set});

  final String workspaceId;
  final ExpiryQuery query;
  final TextEditingController horizon;
  final void Function({DateTime? on, ExpiryScope? scope, int? Function()? horizon, String? Function()? place, String? Function()? group}) set;

  String _scopeText(AppLocalizations l10n, ExpiryScope s) => switch (s) {
    ExpiryScope.expired => l10n.stockExpiryScopeExpired,
    ExpiryScope.expiring => l10n.stockExpiryScopeExpiring,
    ExpiryScope.both => l10n.stockExpiryScopeBoth,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final places = ref.watch(stockPlaceConfigsProvider(workspaceId)).value ?? const []; // empty-ok: a place is a choice, not a need
    final groups = ref.watch(itemGroupListProvider(workspaceId)).value ?? const []; // empty-ok: a group is a choice, not a need
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDateField(
          key: const ValueKey('stock-expiry-date'),
          label: l10n.stockExpiryDate,
          value: query.on,
          onChanged: (d) => set(on: d.date),
        ),
        const FormGap(),
        AppDropdownField<ExpiryScope>(
          key: const ValueKey('stock-expiry-scope'),
          label: l10n.stockExpiryScope,
          value: query.scope,
          items: [for (final s in ExpiryScope.values) (s, _scopeText(l10n, s))],
          onChanged: (v) => set(scope: v),
        ),
        const FormGap(),
        AppTextField(
          key: const ValueKey('stock-expiry-horizon'),
          controller: horizon,
          label: l10n.stockExpiryHorizon,
          helper: l10n.stockExpiryHorizonHint,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => set(horizon: () => int.tryParse(v.trim())),
        ),
        const FormGap(),
        AppDropdownField<String?>(
          key: const ValueKey('stock-expiry-place'),
          label: l10n.stockExpiryPlace,
          value: query.locationId,
          items: [(null, l10n.stockExpiryAny), for (final p in places) (p.id, p.code)],
          onChanged: (v) => set(place: () => v),
        ),
        if (groups.isNotEmpty) ...[
          const FormGap(),
          AppDropdownField<String?>(
            key: const ValueKey('stock-expiry-group'),
            label: l10n.stockExpiryGroup,
            value: query.groupId,
            items: [(null, l10n.stockExpiryAny), for (final g in groups) (g.id, g.name)],
            onChanged: (v) => set(group: () => v),
          ),
        ],
      ],
    );
  }
}

class _Answer extends ConsumerWidget {
  const _Answer({required this.workspaceId, required this.query});

  final String workspaceId;
  final ExpiryQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = stockExpiryReportProvider((workspaceId: workspaceId, query: query));
    return StockRead(
      keyName: 'stock-expiry',
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      isEmpty: (report) => report.rows.isEmpty,
      empty: context.l10n.stockExpiryNone,
      emptyIcon: Icons.event_available_outlined,
      data: (report) => _Rows(report: report, query: query),
    );
  }
}

/// The rows of a read report that has rows, with its print button and the notice of a list that was cut.
class _Rows extends ConsumerWidget {
  const _Rows({required this.report, required this.query});

  final ExpiryReport report;
  final ExpiryQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final printer = ref.watch(stockExpiryPrinterProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (printer != null)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('stock-expiry-print'),
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.stockExpiryPrint),
              onPressed: () => unawaited(printer.print(context, ref, report: report, query: query)),
            ),
          ),
        if (report.cut)
          Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(l10n.stockExpiryCut('${report.rows.length}'), key: const ValueKey('stock-expiry-cut'))),
        for (final (i, r) in report.rows.indexed) _RowTile(index: i, row: r),
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.index, required this.row});

  final int index;
  final ExpiryRow row;

  String _days(AppLocalizations l10n) => switch (row.days) {
    < 0 => l10n.stockExpiryDaysPast('${-row.days}'),
    0 => l10n.taskRecorderValueToday,
    _ => l10n.stockExpiryDaysAhead('${row.days}'),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = row;
    return ListTile(
      key: ValueKey('stock-expiry-row-$index'),
      contentPadding: EdgeInsets.zero,
      title: Text([r.itemName, if (r.variantLabel.isNotEmpty) r.variantLabel].join(' · ')),
      subtitle: Text([
        if (r.lotCode.isNotEmpty) r.lotCode,
        if (r.tag.isNotEmpty) r.tag,
        r.locationCode,
        if (r.locationName.isNotEmpty) r.locationName,
        '${appFormatOf(context).quantity(r.quantity)} ${r.unit}'.trim(),
      ].join(' · ')),
      trailing: Text(_days(l10n), style: r.days < 0 ? TextStyle(color: Theme.of(context).colorScheme.error) : null),
    );
  }
}
