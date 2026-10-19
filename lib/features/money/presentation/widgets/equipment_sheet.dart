// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_asset.dart';
import '../../providers/asset_providers.dart';
import 'asset_valuations_sheet.dart';
import 'equipment_dialogs.dart';

/// Opens the equipment register of [workspaceId]. The caller decides when to
/// offer it; the server decides who reads and who writes.
Future<void> _showEquipmentSheet(
  BuildContext context,
  String workspaceId, {
  required bool canRegister,
  required bool canDecide,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => EquipmentView(
    workspaceId: workspaceId,
    canRegister: canRegister,
    canDecide: canDecide,
  ),
);

/// The Money door to the register: the signed-in person's rights decide which
/// actions the sheet offers (the server decides again on every write).
class EquipmentButton extends StatelessWidget {
  const EquipmentButton({required this.workspaceId, required this.held, super.key});

  final String workspaceId;

  /// The wire names of the permissions the signed-in person holds.
  final Set<String> held;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('equipment-button'),
      onPressed: () => _showEquipmentSheet(
        context,
        workspaceId,
        canRegister: held.contains('managePurchases'),
        canDecide: held.contains('manageBilling') && held.contains('viewFinances'),
      ),
      icon: const Icon(Icons.precision_manufacturing_outlined),
      label: Text(context.l10n.equipmentTitle),
    );
  }
}

String _stateLabel(AppLocalizations l10n, WorkspaceAsset a) =>
    switch (a.state) {
      AssetState.candidate => l10n.equipmentStateCandidate,
      AssetState.inUse => l10n.equipmentStateInUse,
      AssetState.disposed => l10n.equipmentStateDisposed,
      AssetState.expensed => l10n.equipmentStateExpensed,
    };

/// The equipment the space bought: each piece with its cost, its source
/// purchase and the reviewer's treatment, and the doors to register a
/// purchase line and to decide, for who may.
@visibleForTesting
class EquipmentView extends ConsumerWidget {
  const EquipmentView({
    required this.workspaceId,
    required this.canRegister,
    required this.canDecide,
    super.key,
  });

  final String workspaceId;
  final bool canRegister;
  final bool canDecide;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Future<bool?> Function() dialog,
  ) async {
    final saved = await dialog();
    if (saved != true) return;
    ref
      ..invalidate(workspaceAssetsProvider(workspaceId))
      ..invalidate(assetCandidateLinesProvider(workspaceId));
    if (context.mounted) AppSnack.success(context, context.l10n.equipmentSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assets = ref.watch(workspaceAssetsProvider(workspaceId));
    return SheetShell(
      title: l10n.equipmentTitle,
      children: [
        Text(l10n.equipmentIntro, style: Theme.of(context).textTheme.bodySmall),
        if (canDecide) AssetValuationsButton(workspaceId: workspaceId),
        if (canRegister)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('equipment-register'),
              onPressed: () => _open(
                context,
                ref,
                () => showEquipmentRegisterDialog(context, workspaceId),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.equipmentRegister),
            ),
          ),
        assets.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(l10n.equipmentLoadFailed),
          data: (rows) => rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(l10n.equipmentEmpty, key: const ValueKey('equipment-empty')),
                )
              : Column(
                  children: [
                    for (final a in rows)
                      _AssetCard(
                        asset: a,
                        onDecide: !canDecide || !a.isCandidate
                            ? null
                            : () => _open(
                                context,
                                ref,
                                () => showEquipmentDecideDialog(context, workspaceId, a),
                              ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset, required this.onDecide});

  final WorkspaceAsset asset;
  final VoidCallback? onDecide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final cost = asset.acquisitionCostCents;
    return Card(
      key: ValueKey('equipment-${asset.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.equipmentHeading(asset.assetNumber, asset.description),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${_stateLabel(l10n, asset)}'
              '${asset.availableForUseOn == null ? '' : ' · ${l10n.equipmentUsedSince(material.formatMediumDate(asset.availableForUseOn!))}'}',
              key: ValueKey('equipment-state-${asset.id}'),
            ),
            Text(
              cost == null
                  ? l10n.equipmentCostUnknown
                  : l10n.equipmentCost(moneyFormat(asset.currency).formatMinor(cost)),
              key: ValueKey('equipment-cost-${asset.id}'),
            ),
            if (asset.supplierName.isNotEmpty || asset.originalReference.isNotEmpty)
              Text(l10n.equipmentSource(asset.supplierName, asset.originalReference)),
            if (asset.decisionBasis.isNotEmpty) Text(asset.decisionBasis),
            if (onDecide != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: ValueKey('equipment-decide-${asset.id}'),
                  onPressed: onDecide,
                  child: Text(l10n.equipmentDecide),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
