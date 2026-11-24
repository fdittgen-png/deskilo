// SPDX-License-Identifier: AGPL-3.0-or-later
//
// How a stock page opens a sheet that chooses among the stock's items and
// places: the two reads are asked together, the sheet opens only while the
// page is still there, the reads the sheet changed are asked again when it
// says it changed something, and a read that failed is said once and opens
// nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../providers/stock_providers.dart';

/// Reads the items and places of [workspaceId] together, then shows [open]
/// with them; when it answers true, [reads] are asked again. [what] names the
/// sheet in the trace when the reads failed.
Future<void> openStockSheet(
  BuildContext context,
  WidgetRef ref,
  String workspaceId, {
  required String what,
  required Future<bool> Function(StockSheetChoices choices) open,
  List<ProviderOrFamily> reads = const [],
}) async {
  final choices = await guardRead<StockSheetChoices?>(
    domain: 'stock',
    message: 'the $what sheet could not read the stock',
    read: () => ref.read(stockSheetChoicesProvider(workspaceId).future),
    fallback: (_) {
      if (context.mounted) AppSnack.error(context, context.l10n.stockReadFailed);
      return null;
    },
  );
  if (choices == null || !context.mounted) return;
  if (await open(choices) && context.mounted) {
    for (final p in reads) {
      ref.invalidate(p);
    }
  }
}
