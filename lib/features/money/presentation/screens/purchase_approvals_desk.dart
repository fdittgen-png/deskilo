// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3615 (desk M2) — what waits for approval, at the desk: a records table
// (#3606) of date, document, category and gross, one total per currency;
// a row opens the document with its decision bar; several are approved
// from a selection, each decided on its own (PurchaseBatchApproval), and
// the result is said per item with a Retry for what did not answer.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/adaptive/task_choice.dart';
import '../../../../core/ui/adaptive/task_surface.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/purchase_batch_approval.dart';
import '../../domain/purchase.dart';
import '../../providers/purchase_approval_provider.dart';
import '../../providers/purchase_providers.dart';
import '../widgets/purchase_labels.dart';

/// The waiting documents as a records table.
class PurchaseApprovalsTable extends ConsumerWidget {
  const PurchaseApprovalsTable({
    super.key,
    required this.workspaceId,
    required this.docs,
    required this.onOpen,
    required this.onDecided,
  });

  final String workspaceId;
  final List<PurchaseSummary> docs;
  final ValueChanged<String> onOpen;

  /// After a selection was decided: the queue is read again.
  final VoidCallback onDecided;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.numeric);
    return RecordsTable<PurchaseSummary>(
      tableId: 'purchase-approvals',
      rows: docs,
      keyOf: (p) => p.id,
      searchText: (p) => '${p.reference} ${p.category}',
      onOpen: (p) => onOpen(p.id),
      empty: Center(child: Text(l.purchaseApprovalsEmpty)),
      initialQuery: const RecordsQuery(sortColumn: 'date'),
      amountOf: (p) => (currency: p.currency, minor: p.grossCents),
      formatAmount: (c, m) => format.moneyIn(c).formatMinor(m),
      columns: [
        RecordColumn(
          id: 'date',
          label: l.numberSequenceDatePart,
          flex: 2,
          sortKey: (p) => p.dated ?? DateTime(0),
          cell: (_, p) => Text(p.dated == null ? '' : dates.format(p.dated!)),
        ),
        RecordColumn(
          id: 'document',
          label: l.invoiceRegisterNumber,
          flex: 3,
          hideable: false,
          sortKey: (p) => p.reference,
          cell: (_, p) => Text(
            p.reference.isEmpty ? purchaseKindLabel(l, p.kind) : p.reference,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        RecordColumn(
          id: 'category',
          label: l.servicesCategory,
          flex: 3,
          sortKey: (p) => p.category.toLowerCase(),
          cell: (_, p) => Text(p.category, overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'gross',
          label: l.purchasesTotal,
          numeric: true,
          flex: 2,
          sortKey: (p) => p.grossCents,
          cell: (_, p) =>
              Text(format.moneyIn(p.currency).formatMinor(p.grossCents)),
        ),
      ],
      bulkActions: [
        RecordBulkAction(
          id: 'approve',
          label: l.purchaseApproveSelected,
          icon: Icons.task_alt_outlined,
          onRun: (keys) => _approve(context, ref, keys),
        ),
      ],
      cardBuilder: (context, p) => ListTile(
        title: Text(
          p.reference.isEmpty ? purchaseKindLabel(l, p.kind) : p.reference,
        ),
        subtitle: Text(p.category),
        trailing: Text(format.moneyIn(p.currency).formatMinor(p.grossCents)),
      ),
    );
  }

  /// Decides the selection [keys] item by item, as they were shown, and
  /// says what became of each.
  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    Set<String> keys,
  ) async {
    final items = <ApprovalItem>[
      for (final p in docs)
        if (keys.contains(p.id))
          (
            id: p.id,
            grossCents: p.grossCents,
            currency: p.currency,
            reference: p.reference,
          ),
    ];
    final batch = PurchaseBatchApproval(
      workspaceId: workspaceId,
      reads: ref.read(purchaseApprovalReadsProvider),
      commands: ref.read(purchaseCommandProvider),
      newRequestId: newRequestId,
    );
    await showTask<void>(
      context,
      size: TaskSize.short,
      builder: (_) => _Outcomes(batch: batch, items: items, docs: docs),
    );
    onDecided();
  }
}

/// The selection's outcomes, item by item, with a Retry of what did not
/// answer.
class _Outcomes extends StatefulWidget {
  const _Outcomes({
    required this.batch,
    required this.items,
    required this.docs,
  });

  final PurchaseBatchApproval batch;
  final List<ApprovalItem> items;
  final List<PurchaseSummary> docs;

  @override
  State<_Outcomes> createState() => _OutcomesState();
}

class _OutcomesState extends State<_Outcomes> {
  bool _running = true;

  @override
  void initState() {
    super.initState();
    unawaited(_run(widget.items));
  }

  Future<void> _run(List<ApprovalItem> items) async {
    setState(() => _running = true);
    await widget.batch.run(items);
    if (mounted) setState(() => _running = false);
  }

  static String _word(AppLocalizations l, ApprovalOutcome? o) => switch (o) {
    ApprovalOutcome.applied => l.purchaseApprovalApplied,
    ApprovalOutcome.refused => l.purchaseApprovalRefusedItem,
    ApprovalOutcome.changed => l.purchaseApprovalChanged,
    ApprovalOutcome.unknown || null => l.purchaseApprovalUnknown,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final uncertain = widget.batch.uncertain(widget.items);
    String name(ApprovalItem i) {
      final doc = widget.docs.where((d) => d.id == i.id).firstOrNull;
      return i.reference.isNotEmpty
          ? i.reference
          : doc == null
          ? ''
          : purchaseKindLabel(l, doc.kind);
    }

    return TaskChoice(
      title: l.purchaseApprovalOutcomesTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in widget.items)
            ListTile(
              key: ValueKey('approval-outcome-${i.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(name(i)),
              trailing: _running && widget.batch.outcomes[i.id] == null
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_word(l, widget.batch.outcomes[i.id])),
            ),
        ],
      ),
      actions: [
        if (!_running && uncertain.isNotEmpty)
          OutlinedButton(
            key: const ValueKey('approval-outcomes-retry'),
            onPressed: () => _run(uncertain),
            child: Text(l.commonRetry),
          ),
        FilledButton(
          key: const ValueKey('approval-outcomes-done'),
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
