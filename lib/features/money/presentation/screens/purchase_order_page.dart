// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 — the purchase order as a long task: a page of its own with an
// address (`/money/purchase-orders/new`, `/money/purchase-orders/<id>/edit`).
// The form is in its column and the order's totals are beside it, following
// what is typed; below the expanded window class the totals come after the
// fields and the Save button stays in view. The server decides what is saved;
// a refusal keeps the page open with every entry, and a retry of the same
// entries sends the same request id, so it never saves twice.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart'
    show Supplier;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/adaptive/long_task_page.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../application/purchase_order_commands.dart';
import '../../domain/purchase_order.dart';
import '../../providers/money_providers.dart';
import '../../providers/purchase_order_providers.dart';
import '../../providers/supplier_providers.dart';
import '../widgets/purchase_order_form.dart';
import 'money_view_data.dart';

/// Where the page goes when it is closed with nothing behind it.
const String _ordersAddress = '/money/purchase-orders';

/// The page of a new order, or of the draft [orderId].
class PurchaseOrderPage extends ConsumerStatefulWidget {
  const PurchaseOrderPage({this.orderId, super.key});

  /// The draft to edit; null starts a new order.
  final String? orderId;

  @override
  ConsumerState<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends ConsumerState<PurchaseOrderPage> {
  /// The form, made once its data has arrived and kept for the page's life:
  /// a refresh of the orders behind it (a save invalidates them) never
  /// replaces what was typed.
  PurchaseOrderForm? _form;
  var _suppliers = const <Supplier>[];

  /// The draft is gone, or no longer a draft: back to the list.
  void _leave() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) context.go(_ordersAddress);
  });

  @override
  void dispose() {
    _form?.dispose();
    super.dispose();
  }

  /// The page while its data is on the way: its bar and a spinner. A key of
  /// its own, so the loaded page starts afresh and focus goes to its field.
  Widget _waiting(String title) => LongTaskPage(
    key: const ValueKey('purchase-order-loading'),
    title: title,
    fallbackAddress: _ordersAddress,
    form: const LoadingView(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.orderId == null
        ? l10n.purchaseOrderNew
        : l10n.purchaseOrderEdit;
    final workspaceId = MoneyViewData.gates(ref).workspace?.id;
    if (workspaceId == null) return _waiting(title);
    if (_form == null) {
      final suppliers = ref.watch(suppliersProvider(workspaceId));
      final items = ref.watch(servicesProvider);
      final orders = widget.orderId == null
          ? null
          : ref.watch(purchaseOrdersProvider(workspaceId));
      if (suppliers.value == null ||
          items.value == null ||
          (widget.orderId != null && orders?.value == null)) {
        return _waiting(title);
      }
      PurchaseOrder? order;
      if (widget.orderId != null) {
        order = orders!.value!.where((o) => o.id == widget.orderId).firstOrNull;
        if (order == null || order.state != PurchaseOrderState.draft) {
          _leave();
          return _waiting(title);
        }
      }
      _suppliers = [
        for (final s in suppliers.value!)
          if (s.isActive) s,
      ];
      final format = appFormatOf(context);
      _form = PurchaseOrderForm(
        order,
        items.value!,
        order?.currency ?? format.currencyCode,
        format.locale,
      );
    }
    final form = _form!;
    final locale = appFormatOf(context).locale;
    final summary = form.summary(l10n);
    return LongTaskPage(
      key: const ValueKey('purchase-order-form'),
      title: title,
      fallbackAddress: _ordersAddress,
      summary: summary,
      form: AppFormSheet(
        title: title,
        submitLabel: l10n.purchaseOrderSave,
        submitKey: const ValueKey('purchase-order-save'),
        summary: summary,
        validate: () => form.errors(l10n, locale),
        onSubmit: () async {
          final draft = form.draft(locale);
          final requestId = form.requestFor(draft);
          final ok = await runGuarded(
            context,
            domain: 'money',
            message: 'purchase order save failed',
            errorText: l10n.purchaseOrderRefused,
            action: () async {
              await ref
                  .read(purchaseOrderCommandsProvider)
                  .save(workspaceId, requestId, draft);
            },
          );
          return ok ? null : l10n.purchaseOrderRefused;
        },
        builder: (context, refresh) =>
            form.build(context, ref, l10n, _suppliers, refresh),
      ),
    );
  }
}
