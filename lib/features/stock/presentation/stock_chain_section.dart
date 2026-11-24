// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4432 (G18) -- "Every movement of this lot" on a movement's page: the lot's whole chain, from where it came in to
// where it went out, each step with its places, its quantity, the pieces it carried and the document that caused it.
// A document the reader may not see is said, never left out. Each step opens its own movement. A failed read can be
// asked again and is never shown as an empty chain. The same chain opens from "Where is it" for a lot or a piece
// (showStockChainSheet), and from a sale found by its track ID (#4436): a sold line read backwards names the lots and
// the pieces it took, the facts its receipt froze.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_trace_chain.dart';
import '../providers/stock_providers.dart';
import 'stock_read_failed.dart';

/// The words of a movement's reason; an unknown reason is shown as it came.
String stockMoveReasonText(AppLocalizations l10n, String reason) => switch (reason) {
  'receipt' => l10n.stockMoveReasonReceipt,
  'transfer' => l10n.stockMoveReasonTransfer,
  'sale' => l10n.stockMoveReasonSale,
  'loss' => l10n.stockMoveReasonLoss,
  'consumption' => l10n.stockMoveReasonConsumption,
  'adjustment' => l10n.stockMoveReasonAdjustment,
  'opening' => l10n.stockMoveReasonOpening,
  'return_in' => l10n.stockMoveReasonReturnIn,
  'return_out' => l10n.stockMoveReasonReturnOut,
  _ => reason,
};

String? _documentText(AppLocalizations l10n, TraceDocument? d) {
  if (d == null) return null;
  if (!d.available) return l10n.stockChainUnavailable;
  final label = d.label ?? '';
  return switch (d.kind) {
    TraceDocumentKind.delivery => l10n.stockChainDelivery(label, d.supplier ?? ''),
    TraceDocumentKind.counterReceipt => l10n.stockChainReceipt(label),
    TraceDocumentKind.invoice => l10n.stockChainInvoice(label),
    _ => null,
  };
}

/// Opens the chain of a lot, a piece or a sold line (exactly one of them) in a sheet.
Future<void> showStockChainSheet(BuildContext context, {required String workspaceId, String? lotId, String? pieceId, String? counterLineId}) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('stock-chain-sheet'),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: StockChainSection(workspaceId: workspaceId, lotId: lotId, pieceId: pieceId, counterLineId: counterLineId),
        ),
      ),
    );

class StockChainSection extends ConsumerWidget {
  /// The chain of exactly one subject: the movement on screen, a lot, a piece or a sold line.
  const StockChainSection({required this.workspaceId, this.movementId, this.lotId, this.pieceId, this.counterLineId, super.key})
    : assert(
        (movementId == null ? 0 : 1) + (lotId == null ? 0 : 1) + (pieceId == null ? 0 : 1) + (counterLineId == null ? 0 : 1) == 1,
        'one subject',
      );

  final String workspaceId;
  final String? movementId;
  final String? lotId;
  final String? pieceId;
  final String? counterLineId;

  String _title(AppLocalizations l10n) {
    if (counterLineId != null) return l10n.stockChainSaleTitle;
    return pieceId != null ? l10n.stockChainPieceTitle : l10n.stockChainTitle;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = stockMovementChainProvider((
      workspaceId: workspaceId,
      movementId: movementId,
      lotId: lotId,
      pieceId: pieceId,
      counterLineId: counterLineId,
    ));
    final fmt = appFormatOf(context);
    final body = switch (ref.watch(provider)) {
      AsyncLoading() => const LinearProgressIndicator(),
      AsyncError(:final error) => StockReadFailed(keyName: 'stock-chain', error: error, onRetry: () => ref.invalidate(provider)),
      AsyncData(:final value) => value.steps.length < 2 && value.took.isEmpty
          ? Text(l10n.stockChainEmpty, key: const ValueKey('stock-chain-empty'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, t) in value.took.indexed) _TookTile(index: i, track: t),
                for (final s in value.steps)
                  ListTile(
                    key: ValueKey('stock-chain-step-${s.movementId}'),
                    contentPadding: EdgeInsets.zero,
                    selected: s.movementId == movementId,
                    title: Text('${stockMoveReasonText(l10n, s.reason)} · ${s.fromCode} → ${s.toCode} · ${appFormatOf(context).quantity(s.quantity)}'),
                    subtitle: Text([
                      fmt.date(s.at),
                      if (s.pieces != null && s.pieces! > 0) l10n.stockChainPieces(s.pieces!),
                      ?_documentText(l10n, s.document),
                    ].join(' · ')),
                    onTap: s.movementId == movementId ? null : () => context.push(Routes.stockMovement(s.movementId)),
                  ),
                if (value.truncated) Text(l10n.stockChainTruncated, key: const ValueKey('stock-chain-truncated')),
              ],
            ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        key: const ValueKey('stock-chain'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title(l10n), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          body,
        ],
      ),
    );
  }
}

/// What a sold line took, as its receipt froze it: a lot with its quantity, a piece by its tag.
class _TookTile extends StatelessWidget {
  const _TookTile({required this.index, required this.track});

  final int index;
  final TraceTrack track;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final piece = track.kind == 'piece';
    return ListTile(
      key: ValueKey('stock-chain-took-$index'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(piece ? Icons.sell_outlined : Icons.inventory_2_outlined),
      title: Text(piece ? l10n.stockChainTookPiece(track.code) : l10n.stockChainTookLot(track.code, switch (track.quantity) { final q? => appFormatOf(context).quantity(q), null => '' })),
    );
  }
}
