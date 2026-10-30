// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — the suppliers on a screen of their own: a searchable list with a
// deep link (`/money/suppliers`), the same add, edit, archive and bank doors
// as the sheet, which stays the picker inside forms.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.suppliersTitle)),
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
                  ),
                ),
              ],
            ),
    );
  }
}
