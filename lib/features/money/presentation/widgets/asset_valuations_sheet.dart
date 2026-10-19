// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/share/text_sharer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/asset_valuation.dart';
import '../../providers/asset_valuation_providers.dart';
import 'asset_valuation_dialogs.dart';

/// Opens the accountant's valuations of [workspaceId].
Future<void> _showSheet(
  BuildContext context,
  String workspaceId,
) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => AssetValuationsView(workspaceId: workspaceId),
);

/// The door from the equipment register to the valuations.
class AssetValuationsButton extends StatelessWidget {
  const AssetValuationsButton({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('valuations-button'),
      onPressed: () => _showSheet(context, workspaceId),
      icon: const Icon(Icons.fact_check_outlined),
      label: Text(context.l10n.valuationTitle),
    );
  }
}

String _statusLabel(AppLocalizations l10n, ValuationStatus s) =>
    switch (s) {
      ValuationStatus.staged => l10n.valuationStatusStaged,
      ValuationStatus.confirmed => l10n.valuationStatusConfirmed,
      ValuationStatus.superseded => l10n.valuationStatusSuperseded,
    };

/// The batches the accountant sent, what each says and where it stands, with
/// the doors to import a file and to confirm a staged batch.
@visibleForTesting
class AssetValuationsView extends ConsumerWidget {
  const AssetValuationsView({required this.workspaceId, super.key});

  final String workspaceId;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Future<bool?> Function() dialog,
  ) async {
    if (await dialog() != true) return;
    ref.invalidate(assetValuationBatchesProvider(workspaceId));
    if (context.mounted) AppSnack.success(context, context.l10n.valuationSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final batches = ref.watch(assetValuationBatchesProvider(workspaceId));
    return SheetShell(
      title: l10n.valuationTitle,
      children: [
        Text(l10n.valuationIntro, style: Theme.of(context).textTheme.bodySmall),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              key: const ValueKey('valuation-import'),
              onPressed: () => _open(
                context,
                ref,
                () => showValuationImportDialog(context, workspaceId),
              ),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l10n.valuationImport),
            ),
            TextButton(
              key: const ValueKey('valuation-sample'),
              onPressed: () =>
                  ref.read(textSharerProvider)(valuationSampleCsv()),
              child: Text(l10n.valuationSample),
            ),
          ],
        ),
        batches.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(l10n.valuationLoadFailed),
          data: (rows) => rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    l10n.valuationEmpty,
                    key: const ValueKey('valuation-empty'),
                  ),
                )
              : Column(
                  children: [
                    for (final b in rows)
                      _BatchCard(
                        workspaceId: workspaceId,
                        batch: b,
                        onConfirm: b.status != ValuationStatus.staged
                            ? null
                            : () => _open(
                                context,
                                ref,
                                () => showValuationConfirmDialog(
                                  context,
                                  workspaceId,
                                  b,
                                  [
                                    for (final x in rows)
                                      if (x.status ==
                                              ValuationStatus.confirmed &&
                                          x.basis == b.basis &&
                                          x.currency == b.currency)
                                        x,
                                  ],
                                ),
                              ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BatchCard extends ConsumerWidget {
  const _BatchCard({
    required this.workspaceId,
    required this.batch,
    required this.onConfirm,
  });

  final String workspaceId;
  final ValuationBatch batch;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return Card(
      key: ValueKey('valuation-${batch.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.valuationHeading(
                batch.basis == ValuationBasis.book
                    ? l10n.valuationBasisBook
                    : l10n.valuationBasisTax,
                batch.sourceSystem,
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${material.formatMediumDate(batch.periodFrom)} – '
              '${material.formatMediumDate(batch.periodTo)} · ${batch.currency}',
            ),
            Text(
              _statusLabel(l10n, batch.status),
              key: ValueKey('valuation-status-${batch.id}'),
            ),
            Text(
              l10n.valuationRows(batch.rowCount) +
                  (batch.mismatches == 0
                      ? ''
                      : ' · ${l10n.valuationMismatches(batch.mismatches)}'),
            ),
            if (!batch.completeScope) Text(l10n.valuationPartial),
            if (batch.reason.isNotEmpty) Text(batch.reason),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  key: ValueKey('valuation-rows-${batch.id}'),
                  onPressed: () =>
                      _showRows(context, workspaceId, batch),
                  child: Text(l10n.valuationShowRows),
                ),
                if (onConfirm != null)
                  TextButton(
                    key: ValueKey('valuation-confirm-${batch.id}'),
                    onPressed: onConfirm,
                    child: Text(l10n.valuationConfirm),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The figures of one batch, an unknown one shown as such and never as zero.
Future<void> _showRows(
  BuildContext context,
  String workspaceId,
  ValuationBatch batch,
) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RowsView(workspaceId: workspaceId, batch: batch),
  );
}

class _RowsView extends ConsumerWidget {
  const _RowsView({required this.workspaceId, required this.batch});

  final String workspaceId;
  final ValuationBatch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final money = moneyFormat(batch.currency);
    final rows = ref.watch(
      assetValuationRowsProvider((workspaceId: workspaceId, batchId: batch.id)),
    );
    String fig(int? v) =>
        v == null ? l10n.valuationUnknown : money.formatMinor(v);
    return SheetShell(
      title: l10n.valuationShowRows,
      children: [
        rows.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(l10n.valuationLoadFailed),
          data: (list) => Column(
            children: [
              for (final r in list)
                Card(
                  key: ValueKey('valuation-row-${r.assetNumber}'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.equipmentHeading(r.assetNumber, r.description),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          l10n.valuationFigure(
                            l10n.valuationOpening,
                            fig(r.openingMinor),
                          ),
                        ),
                        Text(
                          l10n.valuationFigure(
                            l10n.valuationAdditions,
                            fig(r.additionsMinor),
                          ),
                        ),
                        Text(
                          l10n.valuationFigure(
                            l10n.valuationDisposals,
                            fig(r.disposalsMinor),
                          ),
                        ),
                        Text(
                          l10n.valuationFigure(
                            l10n.valuationDepreciation,
                            fig(r.depreciationMinor),
                          ),
                        ),
                        Text(
                          l10n.valuationFigure(
                            l10n.valuationImpairment,
                            fig(r.impairmentMinor),
                          ),
                        ),
                        Text(
                          l10n.valuationFigure(
                            l10n.valuationClosing,
                            fig(r.closingMinor),
                          ),
                          key: ValueKey('valuation-closing-${r.assetNumber}'),
                        ),
                        if (r.bridge == ValuationBridge.mismatch)
                          Text(
                            l10n.valuationBridgeMismatch,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
