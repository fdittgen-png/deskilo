// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup steps of the purchase side: the suppliers, the lease the space
// holds and the equipment it owns. Each is a whole register with its own
// dialogs, so the page lists what is stored and opens the register's own
// sheet — the one the purchases page opens, with the same rights. The
// sheet refreshes the list it changes, and this page watches that list.
// Members see none of it; the preview says so.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../domain/premises_lease.dart';
import '../../domain/purchase.dart';
import '../../providers/asset_providers.dart';
import '../../providers/premises_lease_providers.dart';
import '../../providers/supplier_providers.dart';
import '../screens/money_view_data.dart';
import 'equipment_sheet.dart';
import 'premises_lease_sheet.dart';
import 'suppliers_sheet.dart';

class SetupPurchaseSideStep extends ConsumerWidget {
  const SetupPurchaseSideStep({
    super.key,
    required this.stepId,
    required this.workspaceId,
    required this.currencyCode,
    required this.held,
  });

  /// `purchases`, `lease` or `assets`.
  final String stepId;
  final String workspaceId;
  final String currencyCode;

  /// The wire names of the permissions the signed-in person holds.
  final Set<String> held;

  /// What is stored, one line each; null while it loads, an error when the
  /// read failed.
  AsyncValue<List<String>> _stored(WidgetRef ref) => switch (stepId) {
    'lease' =>
      ref
          .watch(premisesLeasesProvider(workspaceId))
          .whenData(
            (rows) => [
              for (final l in rows) '${l.premises} · ${l.supplierName}',
            ],
          ),
    'assets' =>
      ref
          .watch(workspaceAssetsProvider(workspaceId))
          .whenData((rows) => [for (final a in rows) a.description]),
    _ =>
      ref
          .watch(suppliersProvider(workspaceId))
          .whenData(
            (rows) => [for (final s in rows) '${s.number} · ${s.name}'],
          ),
  };

  Widget _open(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (stepId) {
      'lease' => OutlinedButton.icon(
        key: const ValueKey('setup-lease-open'),
        onPressed: () => showPremisesLeaseSheet(
          context,
          workspaceId,
          currencyCode: currencyCode,
          canManage: held.contains(leaseManagePermission),
          canMatch: held.contains(purchaseManagePermission),
        ),
        icon: const Icon(Icons.apartment_outlined),
        label: Text(l10n.leaseTitle),
      ),
      'assets' => EquipmentButton(workspaceId: workspaceId, held: held),
      _ => OutlinedButton.icon(
        key: const ValueKey('setup-purchases-open'),
        onPressed: () => showSuppliersSheet(
          context,
          workspaceId,
          lookupOn: MoneyViewData.gates(ref).supplierLookupOn,
        ),
        icon: const Icon(Icons.storefront_outlined),
        label: Text(l10n.suppliersTitle),
      ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final empty = switch (stepId) {
      'lease' => l10n.leaseEmpty,
      'assets' => l10n.equipmentEmpty,
      _ => l10n.suppliersEmpty,
    };
    return switch (_stored(ref)) {
      AsyncValue(hasValue: true, :final value) => SetupStepLayout(
        form: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.setupStepHint(stepId)),
            const SizedBox(height: AppSpacing.lg),
            if (value == null || value.isEmpty)
              Text(empty, key: ValueKey('setup-$stepId-none')),
            for (final (i, line) in (value ?? const <String>[]).indexed)
              ListTile(
                key: ValueKey('setup-$stepId-stored-$i'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(line),
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _open(context, ref),
            ),
          ],
        ),
        preview: Text(
          l10n.setupPurchaseSidePreview,
          key: ValueKey('setup-$stepId-preview'),
        ),
      ),
      AsyncError() => Padding(
        padding: AppSpacing.lgAll,
        child: InlineBanner(
          key: ValueKey('setup-$stepId-failed'),
          icon: Icons.error_outline,
          text: l10n.setupStepLoadFailed,
        ),
      ),
      _ => const LoadingView(),
    };
  }
}
