// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — the suppliers on a screen of their own: a searchable list with a
// deep link (`/money/suppliers`), the same add, edit, archive and bank doors
// as the sheet, which stays the picker inside forms.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../domain/purchase.dart';
import '../../providers/supplier_providers.dart';
import '../widgets/purchases_sheet.dart';
import '../widgets/suppliers_sheet.dart';
import 'money_view_data.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key, this.supplier});

  /// #3610 — the supplier the address names (search,
  /// `/money/suppliers?supplier=<id>`), opened once as its row opens it.
  /// #3615 gives suppliers an address of their own, and this goes.
  final String? supplier;

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _search = TextEditingController();

  /// How a row opens its supplier at the last build; null when it opens
  /// nothing for this reader.
  ValueChanged<String>? _openRow;

  /// The workspace at the last build.
  String? _workspaceId;

  @override
  void initState() {
    super.initState();
    final id = widget.supplier;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openLinked(id)),
      );
    }
  }

  @override
  void didUpdateWidget(SuppliersScreen old) {
    super.didUpdateWidget(old);
    final id = widget.supplier;
    if (id != null && id != old.supplier) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openLinked(id)),
      );
    }
  }

  Future<void> _openLinked(String id) async {
    final workspaceId = _workspaceId;
    var known = false;
    try {
      known = workspaceId != null &&
          (await ref.read(suppliersProvider(workspaceId).future))
              .any((s) => s.id == id && s.isActive);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'the linked supplier could not be read',
        error: e,
        stackTrace: st,
      );
    }
    if (!mounted) return;
    final open = _openRow;
    if (known && open != null) return open(id);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: const ValueKey('search-record-unreadable'),
        content: Text(context.l10n.searchRecordUnreadable),
      ),
    );
  }

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
    _workspaceId = workspace?.id;
    _openRow = !canReadBalances || workspace == null
        ? null
        : (supplierId) => unawaited(
            showSupplierPayablesSheet(
              context,
              workspace.id,
              supplierId,
              canCapture: held.contains(purchaseManagePermission),
              canPay: held.contains(purchasePayPermission),
              canDecide: held.contains(purchaseDecidePermission),
            ),
          );
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
                    onOpenPayables: _openRow,
                  ),
                ),
              ],
            ),
    );
  }
}
