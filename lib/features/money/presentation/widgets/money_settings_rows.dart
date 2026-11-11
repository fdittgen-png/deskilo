// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The money settings the business's own settings open (#3673): the reminder
// rules, the invoice runs and the business's e-mail sender. One seam, so the
// workspace settings depend on one money file rather than one per dialog.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/purchase_order_providers.dart';
import 'billing_rules_dialog.dart';
import 'dunning_rules_dialog.dart';
import 'purchase_order_mail_sheet.dart';

abstract final class MoneySettingsRows {
  /// The reminder levels and their rules.
  static Future<void> openReminderRules(BuildContext context, WidgetRef ref) =>
      showDunningRulesDialog(context, ref);

  /// When the automatic invoice runs happen.
  static Future<void> openBillingRules(BuildContext context, WidgetRef ref) =>
      showBillingRulesDialog(context, ref);

  /// #3673 — the business's one e-mail sender (its purchase orders and its
  /// reminders by e-mail), filled from the server.
  static Future<void> openMailSender(
    BuildContext context,
    WidgetRef ref,
    String workspaceId,
  ) async {
    final current = await ref.read(
      purchaseOrderMailSettingsProvider(workspaceId).future,
    );
    if (!context.mounted) return;
    await PurchaseOrderMailSheet(
      context,
      ref,
    ).open(workspaceId: workspaceId, current: current);
  }
}
