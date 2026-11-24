// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4434 (G19) -- "Where is it" (`/stock/where/:itemId`, optionally `?lot=`): every place that holds the item with the quantity,
// variant and lot, now or on a day chosen; the goods on the road with their from and to; what left to a customer or a loss
// or came back, with the movement that moved it; the pieces with their place, state and tags. The real places add up to
// what the item holds, and the screen says so. A failed read says so and can be asked again; it is never an empty list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/date_field.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../money/providers/business_day_provider.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_where_is.dart';
import '../providers/stock_providers.dart';

class StockWhereIsScreen extends ConsumerStatefulWidget {
  const StockWhereIsScreen({required this.itemId, this.lotId, super.key});

  final String itemId;
  final String? lotId;

  @override
  ConsumerState<StockWhereIsScreen> createState() => _State();
}

class _State extends ConsumerState<StockWhereIsScreen> {
  /// The end of the day chosen, or null for now.
  DateTime? _at;

  /// What the item held when the day typed or picked was over (the start of the next day); today (or nothing readable) is now, never a time to come.
  void _day(DateRead read, DateTime today) {
    final day = read.date;
    setState(() => _at = day == null || !day.isBefore(today) ? null : DateUtils.addDaysToDate(day, 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.stockWhereIsTitle),
        actions: [HelpDot(l10n.stockWhereIsTitle, anchor: HelpAnchor.moneyStockWhereIs)],
      ),
      body: workspaceId == null ? const LoadingView() : _body(context, workspaceId),
    );
  }

  Widget _body(BuildContext context, String workspaceId) {
    final l10n = context.l10n;
    final provider = stockWhereIsAnswerProvider((workspaceId: workspaceId, itemId: widget.itemId, lotId: widget.lotId, at: _at));
    return ref
        .watch(provider)
        .when(
          loading: () => const LoadingView(),
          error: (_, _) => Center(
            key: const ValueKey('stock-where-failed'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.stockReadFailed),
                TextButton(key: const ValueKey('stock-where-retry'), onPressed: () => ref.invalidate(provider), child: Text(l10n.identityConnectRetry)),
              ],
            ),
          ),
          data: (a) => _Answer(
            answer: a,
            at: _at,
            today: ref.watch(businessDayProvider),
            onDay: (read) => _day(read, ref.read(businessDayProvider)),
            onNow: () => setState(() => _at = null),
          ),
        );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.answer, required this.at, required this.today, required this.onDay, required this.onNow});

  final WhereIsAnswer answer;
  final DateTime? at;
  final DateTime today;
  final ValueChanged<DateRead> onDay;
  final VoidCallback onNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(answer.itemName, key: const ValueKey('stock-where-item'), style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.stockWhereIsOnHand(l10n.stockQuantityWithUnit(answer.onHand.text, answer.unit)),
              key: const ValueKey('stock-where-on-hand'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DateChips(at: at, today: today, onDay: onDay, onNow: onNow),
            const SizedBox(height: AppSpacing.md),
            ..._places(context, answer),
            ..._transit(context, answer),
            ..._away(context, answer),
            ..._pieces(context, answer, at),
          ],
        ),
      ),
    );
  }
}

String _what(BuildContext context, WhereIsPlace p) {
  final l10n = context.l10n;
  return [
    if (p.variantLabel != null) p.variantLabel!,
    if (p.lotCode == null || p.lotId == null) l10n.stockNoLot else l10n.stockLotLabel(p.lotCode!),
  ].join(' \u00b7 ');
}

String _placeTitle(WhereIsPlace p) => p.locationName.isEmpty ? p.locationCode : '${p.locationCode} \u00b7 ${p.locationName}';

class _DateChips extends StatelessWidget {
  const _DateChips({required this.at, required this.today, required this.onDay, required this.onNow});

  final DateTime? at;
  final DateTime today;
  final ValueChanged<DateRead> onDay;
  final VoidCallback onNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(key: const ValueKey('stock-where-now'), label: Text(l10n.stockWhereIsNow), selected: at == null, onSelected: (_) => onNow()),
        SizedBox(
          width: 240,
          child: AppDateField(
            key: const ValueKey('stock-where-date'),
            label: l10n.stockWhereIsPickDate,
            value: at,
            first: DateUtils.addMonthsToMonthDate(today, -120),
            last: today,
            onChanged: onDay,
          ),
        ),
      ],
    );
  }
}

List<Widget> _places(BuildContext context, WhereIsAnswer answer) {
  final l10n = context.l10n;
  final real = answer.real.toList();
  return [
    if (real.isEmpty) Text(l10n.stockWhereIsNowhere, key: const ValueKey('stock-where-nowhere')),
    for (final p in real)
      ListTile(
        key: ValueKey('stock-where-place-${p.locationId}-${p.variantId ?? ''}-${p.lotId ?? ''}'),
        contentPadding: EdgeInsets.zero,
        title: Text(_placeTitle(p)),
        subtitle: Text(_what(context, p)),
        trailing: Text(l10n.stockQuantityWithUnit(p.quantity.text, answer.unit), style: Theme.of(context).textTheme.titleMedium),
      ),
  ];
}

List<Widget> _transit(BuildContext context, WhereIsAnswer answer) {
  final l10n = context.l10n;
  final transit = answer.transit;
  if (transit == null || transit.isEmpty) return const [];
  return [
    _Heading(l10n.stockWhereIsTransit),
    for (final t in transit)
      ListTile(
        key: ValueKey('stock-where-transit-${t.transferId}-${t.lotId ?? ''}'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockWhereIsTransitLine(t.fromCode, t.toCode)),
        trailing: Text(l10n.stockQuantityWithUnit(t.quantity.text, answer.unit), style: Theme.of(context).textTheme.titleMedium),
      ),
  ];
}

List<Widget> _away(BuildContext context, WhereIsAnswer answer) {
  final l10n = context.l10n;
  final away = answer.places.where((p) => p.isVirtual).toList();
  if (away.isEmpty && answer.documents.isEmpty) return const [];
  return [
    _Heading(l10n.stockWhereIsAway),
    for (final p in away)
      ListTile(
        key: ValueKey('stock-where-away-${p.locationId}-${p.lotId ?? ''}'),
        contentPadding: EdgeInsets.zero,
        title: Text(_placeTitle(p)),
        subtitle: Text(_what(context, p)),
        trailing: Text(l10n.stockQuantityWithUnit(p.quantity.text, answer.unit)),
      ),
    for (final d in answer.documents)
      ListTile(
        key: ValueKey('stock-where-document-${d.movementId}'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text('${d.reason} \u00b7 ${d.fromCode} \u2192 ${d.toCode}'),
        subtitle: Text(appFormatOf(context).date(d.occurredAt)),
        trailing: Text(l10n.stockQuantityWithUnit(d.quantity.text, answer.unit)),
      ),
  ];
}

List<Widget> _pieces(BuildContext context, WhereIsAnswer answer, DateTime? at) {
  final l10n = context.l10n;
  final pieces = answer.pieces;
  if (pieces == null || pieces.isEmpty) return const [];
  final known = answer.piecesKnownFrom;
  return [
    _Heading(l10n.stockWhereIsPieces),
    for (final p in pieces)
      ListTile(
        key: ValueKey('stock-where-piece-${p.pieceId}'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(p.tags.isEmpty ? p.pieceId : p.tags.join(', ')),
        subtitle: Text('${p.locationCode} \u00b7 ${p.state}'),
      ),
    if (answer.piecesMore) Text(l10n.stockWhereIsPiecesMore, key: const ValueKey('stock-where-pieces-more'), style: Theme.of(context).textTheme.bodySmall),
    if (at != null && known != null && at.isBefore(known))
      Text(l10n.stockWhereIsPiecesFrom(appFormatOf(context).date(known)), key: const ValueKey('stock-where-pieces-from'), style: Theme.of(context).textTheme.bodySmall),
  ];
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
