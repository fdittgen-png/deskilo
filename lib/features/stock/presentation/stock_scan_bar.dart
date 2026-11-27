// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- what a goods sheet shows of its scanner: the scope that listens, the current place at the top
// ("Placing into MAG1-SALES-A03"), the last line scanned, and, for a code that names nothing, the question
// "Unknown code ... -- add it to an item?" (the way to add it needs `manageStock`). A sheet with the stock
// scanning feature off mounts nothing here and so ignores a scanner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/scan/scan_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_scan_session.dart';
import 'stock_camera_scan.dart';
import 'stock_nfc_button.dart';
import 'stock_scan_feed.dart';

class StockScanBar extends ConsumerWidget {
  const StockScanBar({required this.feed, required this.onOpenItems, super.key});

  final StockScanFeed feed;

  /// Opens the items (the way to give an unknown code to an item).
  final VoidCallback onOpenItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) {
        final place = feed.session.current;
        final last = feed.last;
        final style = Theme.of(context).textTheme;
        return ScanScope(
          onScan: feed.scan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (place != null)
                Row(
                  key: const ValueKey('stock-scan-place'),
                  children: [
                    Expanded(child: Text(l10n.stockScanPlacing(place.code.isEmpty ? place.name : '${place.code} ${place.name}'), style: style.titleSmall)),
                    HelpDot(l10n.stockScanHelp, anchor: HelpAnchor.moneyStockScanning),
                  ],
                ),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('stock-scan-camera'),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(l10n.stockCameraOpen),
                    onPressed: () => showStockCameraScan(context, feed),
                  ),
                  StockNfcButton(onUid: feed.readTag),
                ],
              ),
              if (feed.problem != null)
                Text(l10n.stockScanFailed, key: const ValueKey('stock-scan-failed'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (last != null && last.outcome == ScanOutcome.line && last.line != null)
                Text(
                  l10n.stockScanLast(last.line!.itemName, last.line!.shownQuantity, last.line!.unit),
                  key: const ValueKey('stock-scan-last'),
                  style: style.bodySmall,
                ),
              if (last != null && last.outcome == ScanOutcome.unknown)
                Row(
                  key: const ValueKey('stock-scan-unknown'),
                  children: [
                    Expanded(child: Text(last.fromTag ? l10n.stockScanUnknownTag(last.code ?? '') : l10n.stockScanUnknown(last.code ?? ''))),
                    if (mayManage && !last.fromTag) TextButton(key: const ValueKey('stock-scan-open-items'), onPressed: onOpenItems, child: Text(l10n.stockScanUnknownAdd)),
                  ],
                ),
              if (last != null) _OutcomeNote(last: last, feed: feed),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

/// What the last scan says when it was not a line or an unknown code: asked which of several places, read twice, or refused.
class _OutcomeNote extends StatelessWidget {
  const _OutcomeNote({required this.last, required this.feed});

  final ScanResult last;
  final StockScanFeed feed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (last.outcome) {
      // #4495 -- a code several places carry: the person says which, never the first
      ScanOutcome.askPlace => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.stockScanWhichPlace(last.code ?? ''), key: const ValueKey('stock-scan-which-place')),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final p in last.choices)
                ActionChip(key: ValueKey('stock-scan-place-${p.id}'), label: Text(p.path.isEmpty ? p.name : p.path), onPressed: () => feed.choosePlace(p)),
            ],
          ),
        ],
      ),
      ScanOutcome.alreadyRead => Text(l10n.stockScanAlreadyRead(last.code ?? ''), key: const ValueKey('stock-scan-already-read')),
      ScanOutcome.refused => Text(
        last.place == null ? l10n.stockScanRefusedCode(last.code ?? '') : l10n.stockScanRefusedPlace(last.place!.name),
        key: const ValueKey('stock-scan-refused'),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
