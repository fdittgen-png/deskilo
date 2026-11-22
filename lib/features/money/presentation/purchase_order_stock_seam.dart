// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (B) -- the seam between the order pane and the stock. Receiving into
// stock belongs to the stock feature; the pane (money) only asks this seam for
// what it adds -- the put-away rows and buttons of each delivery, and the
// "also put away" part of the delivery form -- and shows nothing when nothing
// is wired. The composition root (lib/app) wires the stock's own
// implementation, so money never imports the stock.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/purchase_order.dart';

/// What the stock adds to the order pane.
abstract interface class PurchaseOrderStockSeam {
  /// The put-away rows and buttons of each delivery of [order]; null when
  /// receiving into stock is not offered here (off, or no right).
  Widget? deliveryActions(
    BuildContext context,
    WidgetRef ref, {
    required String workspaceId,
    required PurchaseOrder order,
  });

  /// #4173 -- the goods put away against a [kind] (`order` or `bill`) document [id], for a reader of
  /// the stock; null when the goods ledger is off or the reader may not read the stock.
  Widget? goodsOfDocument(
    BuildContext context,
    WidgetRef ref, {
    required String workspaceId,
    required String kind,
    required String id,
  });

  /// The "also put away" part of the delivery form, read before the form
  /// opens; null when it is not offered or the stock side could not be read.
  Future<ReceiptPutAway?> receiptPutAway(
    BuildContext context,
    WidgetRef ref, {
    required String workspaceId,
    required PurchaseOrder order,
  });
}

/// A delivery being recorded: its day, what each line brought, its note and
/// the request id that makes a retry answer once.
class ReceiptDelivery {
  const ReceiptDelivery({
    required this.receivedOn,
    required this.delivered,
    required this.note,
    required this.requestId,
  });

  final DateTime receivedOn;
  final Map<int, double> delivered;
  final String note;
  final String requestId;
}

/// The put-away that travels with a delivery being recorded.
abstract interface class ReceiptPutAway {
  /// The switch and, when it is on, the parts to put away.
  List<Widget> buildAlso(BuildContext context, VoidCallback refresh);

  /// Whether the delivery is recorded together with its put-away.
  bool get also;

  /// What is wrong with the put-away against what the delivery brings.
  FieldErrors validate(AppLocalizations l10n, Map<int, double> delivered);

  /// Records the delivery and puts it away in one command: null when it was
  /// done, else the problem to say in the form.
  Future<String?> record(
    AppLocalizations l10n,
    String workspaceId,
    PurchaseOrder order,
    ReceiptDelivery delivery,
  );

  void dispose();
}

/// What the composition root wires; null without it.
final purchaseOrderStockSeamProvider = Provider<PurchaseOrderStockSeam?>((ref) => null);
