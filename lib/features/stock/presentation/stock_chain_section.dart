// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4432 (G18) -- "Every movement of this lot" on a movement's page: the lot's whole chain, from where it came in to
// where it went out, each step with its places, its quantity, the pieces it carried and the document that caused it.
// A document the reader may not see is said, never left out. Each step opens its own movement. A failed read can be
// asked again and is never shown as an empty chain.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_trace_chain.dart';
import '../providers/stock_providers.dart';

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

class StockChainSection extends ConsumerWidget {
  const StockChainSection({required this.workspaceId, required this.movementId, super.key});

  final String workspaceId;
  final String movementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = stockMovementChainProvider((workspaceId: workspaceId, movementId: movementId));
    final fmt = appFormatOf(context);
    final body = switch (ref.watch(provider)) {
      AsyncLoading() => const LinearProgressIndicator(),
      AsyncError() => Column(
        key: const ValueKey('stock-chain-failed'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.stockReadFailed),
          TextButton(
            key: const ValueKey('stock-chain-retry'),
            onPressed: () => ref.invalidate(provider),
            child: Text(l10n.identityConnectRetry),
          ),
        ],
      ),
      AsyncData(:final value) => value.steps.length < 2
          ? Text(l10n.stockChainEmpty, key: const ValueKey('stock-chain-empty'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in value.steps)
                  ListTile(
                    key: ValueKey('stock-chain-step-${s.movementId}'),
                    contentPadding: EdgeInsets.zero,
                    selected: s.movementId == movementId,
                    title: Text('${stockMoveReasonText(l10n, s.reason)} · ${s.fromCode} → ${s.toCode} · ${s.quantity.text}'),
                    subtitle: Text([
                      fmt.date(s.at),
                      if (s.pieces != null && s.pieces! > 0) l10n.stockChainPieces(s.pieces!),
                      ?_documentText(l10n, s.document),
                    ].join(' · ')),
                    onTap: s.movementId == movementId ? null : () => context.push('/stock/movements/${s.movementId}'),
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
          Text(l10n.stockChainTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          body,
        ],
      ),
    );
  }
}
