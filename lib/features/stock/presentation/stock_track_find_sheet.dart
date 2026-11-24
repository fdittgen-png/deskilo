// SPDX-License-Identifier: AGPL-3.0-or-later
//
// "Find a track ID" on the Stock page: a lot code as received, a lot's label code or a piece's tag, typed or scanned,
// names the lots and pieces of this business that carry it and the counter sales that took them. A lot or a piece opens
// its whole chain; a sale whose receipt the reader may see opens what that line took. A receipt the reader may not see
// is named by its kind, never left out. Nothing found says so; a refusal or a failed read says so and can be asked
// again, and is never shown as nothing found. Looking writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/refusal_text.dart';
import '../../../core/ui/adaptive/task_surface.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_trace_chain.dart';
import '../domain/stock_track_find.dart';
import '../providers/stock_providers.dart';
import 'stock_chain_section.dart';

/// Opens the search of [workspaceId] by track ID: a sheet on a phone, a panel at the desk.
Future<void> showStockTrackFindSheet(
  BuildContext context, {
  required String workspaceId,
}) => showTask<void>(
  context,
  size: TaskSize.standard,
  builder: (_) => SingleChildScrollView(
    key: const ValueKey('stock-track-find-sheet'),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: StockTrackFind(workspaceId: workspaceId),
  ),
);

class StockTrackFind extends ConsumerStatefulWidget {
  const StockTrackFind({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  ConsumerState<StockTrackFind> createState() => _State();
}

class _State extends ConsumerState<StockTrackFind> {
  final _code = TextEditingController();

  /// The code last asked for; null before the first search.
  String? _asked;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _find() {
    final code = _code.text.trim();
    setState(() {
      _error = code.isEmpty ? context.l10n.stockTrackFindRequired : null;
      if (code.isNotEmpty) _asked = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final asked = _asked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.stockTrackFindTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            HelpDot(
              l10n.stockTrackFindTitle,
              anchor: HelpAnchor.moneyStockWhereIs,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          key: const ValueKey('stock-track-find-code'),
          controller: _code,
          label: l10n.stockTrackFindField,
          helper: l10n.stockTrackFindHelper,
          error: _error,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _find(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            key: const ValueKey('stock-track-find-submit'),
            icon: const Icon(Icons.search),
            label: Text(l10n.stockTrackFindSubmit),
            onPressed: _find,
          ),
        ),
        if (asked != null)
          _Result(workspaceId: widget.workspaceId, code: asked),
      ],
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({required this.workspaceId, required this.code});

  final String workspaceId;
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = stockTrackFindProvider((
      workspaceId: workspaceId,
      code: code,
    ));
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: switch (ref.watch(provider)) {
        AsyncLoading() => const LinearProgressIndicator(),
        AsyncError(:final error) => Column(
          key: const ValueKey('stock-track-find-failed'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(knownRefusalText(l10n, error) ?? l10n.stockReadFailed),
            TextButton(
              key: const ValueKey('stock-track-find-retry'),
              onPressed: () => ref.invalidate(provider),
              child: Text(l10n.identityConnectRetry),
            ),
          ],
        ),
        AsyncData(:final value) when value.isEmpty => Text(
          l10n.stockTrackFindNone(value.code),
          key: const ValueKey('stock-track-find-none'),
        ),
        AsyncData(:final value) => _Found(
          workspaceId: workspaceId,
          answer: value,
        ),
      },
    );
  }
}

class _Found extends StatelessWidget {
  const _Found({required this.workspaceId, required this.answer});

  final String workspaceId;
  final TrackFindAnswer answer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = appFormatOf(context);
    final pieces = answer.pieces ?? const <TrackFindPiece>[];
    return Column(
      key: const ValueKey('stock-track-find-found'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (answer.lots.isNotEmpty) _Heading(l10n.stockTrackFindLots),
        for (final lot in answer.lots)
          ListTile(
            key: ValueKey('stock-track-lot-${lot.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${lot.item} · ${l10n.stockLotLabel(lot.code ?? lot.labelCode ?? '')}',
            ),
            subtitle: lot.expiresOn == null
                ? null
                : Text(l10n.stockTrackFindExpires(fmt.date(lot.expiresOn!))),
            trailing: const Icon(Icons.timeline),
            onTap: () => showStockChainSheet(
              context,
              workspaceId: workspaceId,
              lotId: lot.id,
            ),
          ),
        if (pieces.isNotEmpty) _Heading(l10n.stockTrackFindPieces),
        for (final piece in pieces)
          ListTile(
            key: ValueKey('stock-track-piece-${piece.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text('${piece.item} · ${piece.tag}'),
            trailing: const Icon(Icons.timeline),
            onTap: () => showStockChainSheet(
              context,
              workspaceId: workspaceId,
              pieceId: piece.id,
            ),
          ),
        _Heading(l10n.stockTrackFindSales),
        if (answer.sales.isEmpty)
          Text(
            l10n.stockTrackFindNoSale,
            key: const ValueKey('stock-track-find-no-sale'),
          ),
        for (final (i, sale) in answer.sales.indexed)
          ListTile(
            key: ValueKey('stock-track-sale-$i'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${_receiptText(l10n, sale.document)} · ${appFormatOf(context).quantity(sale.quantity)}',
            ),
            subtitle: Text(fmt.date(sale.at)),
            trailing: sale.lineId == null ? null : const Icon(Icons.timeline),
            onTap: sale.lineId == null
                ? null
                : () => showStockChainSheet(
                    context,
                    workspaceId: workspaceId,
                    counterLineId: sale.lineId,
                  ),
          ),
        if (answer.truncated)
          Text(
            l10n.stockTrackFindTruncated,
            key: const ValueKey('stock-track-find-truncated'),
          ),
      ],
    );
  }
}

/// The receipt of a sale; one the reader may not see is named by its kind.
String _receiptText(AppLocalizations l10n, TraceDocument? d) =>
    d == null || !d.available
    ? l10n.stockChainUnavailable
    : l10n.stockChainReceipt(d.label ?? '');

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
