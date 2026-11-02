// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — the suppliers on a screen of their own: a searchable list with a
// deep link (`/money/suppliers`), the same add, edit, archive and bank doors
// as the sheet, which stays the picker inside forms.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/purchase.dart';
import '../widgets/purchases_sheet.dart';
import '../widgets/suppliers_sheet.dart';
import 'money_view_data.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = MoneyViewData.gates(ref);
    final workspace = data.workspace;
    final lookupOn = data.supplierLookupOn;
    final held = {for (final p in ref.watch(myPermissionsProvider)) p.wireName};
    final canReadBalances = data.purchasesOn &&
        (held.contains('viewFinances') || held.contains(purchaseManagePermission));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.suppliersTitle),
        actions: [HelpDot(l10n.suppliersTitle, anchor: HelpAnchor.moneySupplierBalance)],
      ),
      body: workspace == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: AppTextField(
                    key: const ValueKey('suppliers-search'),
                    controller: _search,
                    label: l10n.suppliersSearch,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: SuppliersView(
                    workspaceId: workspace.id,
                    lookupOn: lookupOn,
                    embedded: true,
                    query: _search.text,
                    onOpenPayables: !canReadBalances
                        ? null
                        : (supplierId) => showPurchasesSheet(
                            context,
                            workspace.id,
                            supplierId: supplierId,
                            canCapture: held.contains(purchaseManagePermission),
                            canPay: held.contains(purchasePayPermission),
                            canDecide: held.contains(purchaseDecidePermission),
                            canOffset: held.contains(purchaseOffsetPermission),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
