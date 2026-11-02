// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/purchase.dart';
import '../../domain/supplier_payables_page.dart';
import '../../providers/supplier_balance_provider.dart';
import 'purchase_payables.dart';

/// The existing payable list, scoped at the server and extended one page at
/// a time. No fixed page cap can silently turn it into a complete list.
class SupplierPayablesView extends ConsumerStatefulWidget {
  const SupplierPayablesView({
    required this.workspaceId,
    required this.supplierId,
    required this.onOpen,
    this.canPay = false,
    this.canOffset = false,
    super.key,
  });

  final String workspaceId;
  final String supplierId;
  final Future<void> Function(String purchaseId) onOpen;
  final bool canPay;
  final bool canOffset;

  @override
  ConsumerState<SupplierPayablesView> createState() =>
      _SupplierPayablesViewState();
}

class _SupplierPayablesViewState extends ConsumerState<SupplierPayablesView> {
  final _cursors = <SupplierPayablesCursor?>[null];

  void _restart() {
    ref
      ..invalidate(supplierBalancesProvider(widget.workspaceId))
      ..invalidate(supplierPayablesPageProvider);
    setState(() {
      _cursors
        ..clear()
        ..add(null);
    });
  }

  @override
  void didUpdateWidget(SupplierPayablesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.supplierId != widget.supplierId) {
      _cursors
        ..clear()
        ..add(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      for (final after in _cursors)
        ref.watch(
          supplierPayablesPageProvider((
            workspaceId: widget.workspaceId,
            supplierId: widget.supplierId,
            after: after,
          )),
        ),
    ];
    if (pages.any((page) => page.isLoading)) {
      return const SizedBox(height: 40, child: LoadingView());
    }
    if (pages.any((page) => page.hasError)) {
      return Column(
        children: [
          Text(context.l10n.suppliersBalanceUnavailable),
          TextButton(
            onPressed: _restart,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      );
    }
    final resolved = [for (final page in pages) page.requireValue];
    final rows = <PayableRow>[for (final page in resolved) ...page.rows];
    final next = resolved.last.next;
    if (next != null && _cursors.contains(next)) {
      return Column(
        children: [
          Text(context.l10n.suppliersBalanceUnavailable),
          TextButton(
            onPressed: _restart,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      );
    }
    return Column(
      children: [
        PurchasePayablesView(
          workspaceId: widget.workspaceId,
          supplierRows: rows,
          canPay: widget.canPay,
          canOffset: widget.canOffset,
          onOpen: (id) async {
            await widget.onOpen(id);
            if (!mounted) return;
            _restart();
          },
          onPayablesChanged: () {
            if (!mounted) return;
            _restart();
          },
        ),
        if (next != null)
          TextButton(
            key: const ValueKey('supplier-payables-more'),
            onPressed: () => setState(() => _cursors.add(next)),
            child: Text(context.l10n.suppliersLoadMore),
          ),
      ],
    );
  }
}
