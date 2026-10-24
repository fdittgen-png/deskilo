// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — Me › Finances: one export entry per workspace my documents
// come from. Each entry writes that workspace's documents, as the overview
// read them on its host, to one CSV file and hands it to the platform's
// truthful delivery. A file is never a payment or a delivery confirmation,
// and no document is changed by exporting it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_delivery.dart';
import '../../../../core/files/file_delivery_notice.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../domain/finance_overview.dart';
import '../../domain/own_finance_csv.dart';

class OwnFinanceExportMenu extends ConsumerWidget {
  const OwnFinanceExportMenu({super.key, required this.overview});

  /// Every document read, all workspaces; each entry exports one of them.
  final FinanceOverview overview;

  /// Writes [documents] to one CSV file named after [label] and hands it
  /// to the platform's truthful delivery; a host that did not answer is
  /// noted inside the file. The workspace entries and a row's Export
  /// (#2557 C4) both go through here.
  static Future<void> export(
    BuildContext context,
    WidgetRef ref, {
    required FinanceOverview documents,
    required String label,
  }) async {
    final bytes = ownFinanceCsv(documents);
    final name = ownFinanceCsvName(label, ref.read(clockProvider).now());
    Future<void> deliver() async {
      final delivery = await deliverFile(
        context,
        ref,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      announceFileDelivery(context, delivery, retry: deliver);
    }

    await deliver();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaces = overview.workspaces;
    if (workspaces.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<(String, String)>(
      key: const ValueKey('my-finances-export'),
      icon: const Icon(Icons.download_outlined),
      tooltip: l10n.myFinancesExport,
      onSelected: (w) => export(
        context,
        ref,
        documents: overview.inWorkspace(w.$1),
        label: w.$2.isEmpty ? w.$1 : w.$2,
      ),
      itemBuilder: (_) => [
        for (final w in workspaces)
          PopupMenuItem(
            key: ValueKey('my-finances-export-${w.$1}'),
            value: w,
            child: Text(
              l10n.myFinancesExportWorkspace(w.$2.isEmpty ? w.$1 : w.$2),
            ),
          ),
      ],
    );
  }
}
