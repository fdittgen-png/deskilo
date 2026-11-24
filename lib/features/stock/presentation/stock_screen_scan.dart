// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- a scan on a list screen (the Items and the Places): the code is resolved by the same port the
// goods sheets use, and a code that names nothing, or that could not be read, is said in a snack. What the
// screen does with a place or an item is the screen's own.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../domain/stock_code_resolver.dart';
import '../providers/stock_providers.dart';

class StockScreenScan {
  const StockScreenScan(this._ref);

  final WidgetRef _ref;

  /// Whether the business uses a scanner at all (the `stockScanning` feature).
  bool get on => _ref.read(stockScanningProvider);

  /// What [code] names, or null after saying why it names nothing.
  Future<StockCodeResolution?> resolve(BuildContext context, String workspaceId, String code) async {
    final l10n = context.l10n;
    final answer = await guardRead<StockCodeResolution?>(
      domain: 'stock',
      message: 'a scanned code could not be resolved',
      read: () => _ref.read(stockCodeResolverProvider).resolve(workspaceId, code),
      fallback: (_) {
        if (context.mounted) AppSnack.error(context, l10n.stockScanFailed);
        return null;
      },
    );
    if (answer == null || !context.mounted) return null;
    if (answer.kind == ScannedKind.unknown) {
      AppSnack.info(context, l10n.stockScanUnknown(answer.code));
      return null;
    }
    return answer;
  }
}
