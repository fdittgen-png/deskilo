// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- the one line that makes the Scanning feature easy to find: when the stock is managed, scanning
// is off and the person may change the features, "Using a barcode scanner? Turn on Scanning" opens the Features
// screen. It shows in Stock settings and in the goods sheets, and nowhere once scanning is on.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../providers/stock_providers.dart';

class StockScanHint extends ConsumerWidget {
  const StockScanHint({this.insideSheet = false, super.key});

  /// In a sheet: it closes first, then the Features screen opens.
  final bool insideSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final may = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageConfiguration);
    if (ref.watch(stockScanningProvider) || !may) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const ValueKey('stock-scan-hint'),
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(context.l10n.stockScanHint),
        onPressed: () {
          final router = GoRouter.of(context);
          if (insideSheet) Navigator.of(context).pop();
          router.go('/features');
        },
      ),
    );
  }
}
