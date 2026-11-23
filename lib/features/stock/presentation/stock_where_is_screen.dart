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
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
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

  Future<void> _pick() async {
    final today = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _at ?? today,
      firstDate: DateTime(today.year - 10),
      lastDate: today,
    );
    if (day == null || !mounted) return;
    // the end of that day: what the item held when the day was over (today: now, never a time to come)
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
    setState(() => _at = end.isAfter(today) ? null : end);
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
          data: (a) => _Answer(answer: a, at: _at, onPick: _pick, onNow: () => setState(() => _at = null)),
        );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.answer, required this.at, required this.onPick, required this.onNow});

  final WhereIsAnswer answer;
  final DateTime? at;
  final VoidCallback onPick;
  final VoidCallback onNow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);
    final real = answer.real.toList();
    final away = answer.places.where((p) => p.isVirtual).toList();
    String qty(WhereIsPlace p) => l10n.stockQuantityWithUnit(p.quantity.text, answer.unit);
    String what(WhereIsPlace p) => [
      if (p.variantLabel != null) p.variantLabel!,
      if (p.lotCode == null || p.lotId == null) l10n.stockNoLot else l10n.stockLotLabel(p.lotCode!),
    ].join(' · ');
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
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(key: const ValueKey('stock-where-now'), label: Text(l10n.stockWhereIsNow), selected: at == null, onSelected: (_) => onNow()),
                ActionChip(
                  key: const ValueKey('stock-where-pick'),
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(at == null ? l10n.stockWhereIsPickDate : l10n.stockWhereIsAsOf(loc.formatMediumDate(at!))),
                  onPressed: onPick,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (real.isEmpty) Text(l10n.stockWhereIsNowhere, key: const ValueKey('stock-where-nowhere')),
            for (final p in real)
              ListTile(
                key: ValueKey('stock-where-place-${p.locationId}-${p.variantId ?? ''}-${p.lotId ?? ''}'),
                contentPadding: EdgeInsets.zero,
                title: Text(p.locationName.isEmpty ? p.locationCode : '${p.locationCode} · ${p.locationName}'),
                subtitle: Text(what(p)),
                trailing: Text(qty(p), style: theme.textTheme.titleMedium),
              ),
            if (answer.transit != null && answer.transit!.isNotEmpty) ...[
              _Heading(l10n.stockWhereIsTransit),
              for (final t in answer.transit!)
                ListTile(
                  key: ValueKey('stock-where-transit-${t.transferId}-${t.lotId ?? ''}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.stockWhereIsTransitLine(t.fromCode, t.toCode)),
                  trailing: Text(l10n.stockQuantityWithUnit(t.quantity.text, answer.unit), style: theme.textTheme.titleMedium),
                ),
            ],
            if (away.isNotEmpty || answer.documents.isNotEmpty) ...[
              _Heading(l10n.stockWhereIsAway),
              for (final p in away)
                ListTile(
                  key: ValueKey('stock-where-away-${p.locationId}-${p.lotId ?? ''}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.locationName.isEmpty ? p.locationCode : '${p.locationCode} · ${p.locationName}'),
                  subtitle: Text(what(p)),
                  trailing: Text(qty(p)),
                ),
              for (final d in answer.documents)
                ListTile(
                  key: ValueKey('stock-where-document-${d.movementId}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${d.reason} · ${d.fromCode} → ${d.toCode}'),
                  subtitle: Text(loc.formatMediumDate(d.occurredAt.toLocal())),
                  trailing: Text(l10n.stockQuantityWithUnit(d.quantity.text, answer.unit)),
                ),
            ],
            if (answer.pieces == null && at != null) ...[
              _Heading(l10n.stockWhereIsPieces),
              Text(l10n.stockWhereIsPiecesPast, key: const ValueKey('stock-where-pieces-past'), style: theme.textTheme.bodySmall),
            ],
            if (answer.pieces != null && answer.pieces!.isNotEmpty) ...[
              _Heading(l10n.stockWhereIsPieces),
              for (final p in answer.pieces!)
                ListTile(
                  key: ValueKey('stock-where-piece-${p.pieceId}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.tags.isEmpty ? p.pieceId : p.tags.join(', ')),
                  subtitle: Text('${p.locationCode} · ${p.state}'),
                ),
              if (answer.piecesMore) Text(l10n.stockWhereIsPiecesMore, key: const ValueKey('stock-where-pieces-more'), style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
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
