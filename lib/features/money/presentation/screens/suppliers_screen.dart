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
import '../../../../core/navigation/list_detail_route.dart';
import '../../../../core/shortcuts/app_shortcuts.dart';
import '../../../../core/shortcuts/shortcut_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../domain/purchase.dart';
import '../../providers/supplier_providers.dart';
import '../widgets/suppliers_sheet.dart';
import 'money_view_data.dart';
import 'suppliers_desk.dart';

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
    final held = MoneyViewData.purchasePermissionNames(ref);
    final canReadBalances = data.purchasesOn &&
        (held.contains('viewFinances') || held.contains(purchaseManagePermission));
    // #3615 — a supplier opens at its address: beside the table at the
    // desk, its payables as a page on a phone.
    final ValueChanged<String>? openRow = !canReadBalances || workspace == null
        ? null
        : (supplierId) => openRecord(context, suppliersPath, supplierId);
    if (workspace != null &&
        canReadBalances &&
        WindowClass.of(context).index >= WindowClass.expanded.index) {
      final view = SuppliersView(workspaceId: workspace.id, lookupOn: lookupOn);
      return ShortcutScope(
        handlers: {
          AppShortcutId.newRecord: () => view.edit(context, ref, null),
        },
        child: Scaffold(
          appBar: AppBar(
            title: PageTitle(l10n.bookRoleSuppliers),
            actions: [
              OutlinedButton.icon(
                key: const ValueKey('supplier-add'),
                onPressed: () => view.edit(context, ref, null),
                icon: const Icon(Icons.add),
                label: Text(l10n.suppliersAdd),
              ),
              // What waits for review stays on the list it was built for.
              if (ref
                      .watch(supplierReviewsProvider(workspace.id))
                      .value
                      ?.isNotEmpty ??
                  false) // empty-ok: an unread review list offers no door
                TextButton(
                  key: const ValueKey('suppliers-reviews'),
                  onPressed: () => showSuppliersSheet(
                    context,
                    workspace.id,
                    lookupOn: lookupOn,
                  ),
                  child: Text(l10n.suppliersReviewTitle),
                ),
              HelpDot(
                l10n.bookRoleSuppliers,
                anchor: HelpAnchor.moneySupplierBalance,
              ),
            ],
          ),
          body: SuppliersDesk(view: view, held: held),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.bookRoleSuppliers),
        actions: [HelpDot(l10n.bookRoleSuppliers, anchor: HelpAnchor.moneySupplierBalance)],
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
                    onOpenPayables: openRow,
                  ),
                ),
              ],
            ),
    );
  }
}
