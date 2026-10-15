// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the sales-tax worksheet of a period as a CSV file: the figures the
// owner of a US seller keys into each state's portal. The app files nothing.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/time/date_text.dart';
import '../../../core/ui/app_snack.dart';
import '../providers/sales_tax_providers.dart';
import 'invoice_actions.dart';

/// The button beside the VAT report ones; nothing outside sales-tax mode.
class SalesTaxWorksheetButton extends ConsumerWidget {
  const SalesTaxWorksheetButton({
    super.key,
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  /// Saves the worksheet of `[start, end]`, or says there is nothing to state.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    ({String id, String currency}) workspace,
  ) async {
    final csv = await ref
        .read(salesTaxCommandsProvider)
        .worksheetCsv(
          workspaceId: workspace.id,
          currency: workspace.currency,
          start: start,
          end: end,
        );
    if (!context.mounted) return;
    if (csv == null) {
      AppSnack.info(context, context.l10n.salesTaxWorksheetEmpty);
      return;
    }
    await savePdfToDownloads(
      context,
      ref,
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileName: 'sales-tax-worksheet-${isoDay(start)}.csv',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = salesTaxWorkspace(ref);
    if (workspace == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          key: const ValueKey('sales-tax-worksheet-csv'),
          onPressed: () => _save(context, ref, workspace),
          icon: const Icon(Icons.table_view_outlined),
          label: Text(context.l10n.salesTaxWorksheetCsv),
        ),
      ),
    );
  }
}
