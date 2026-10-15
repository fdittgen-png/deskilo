// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/bill_sections.dart';
import '../../providers/billing_invoice_sweep.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/money_focus_controller.dart';
import '../../providers/money_providers.dart';
import '../../providers/payment_reminder_sweep.dart';
import '../widgets/focused_invoice.dart';
import 'money_body.dart';
import 'money_member_documents.dart';
import 'money_online_payment.dart';
import 'money_payment_sheets.dart';
import 'money_screen_ops.dart';

/// Money tab (spec §7.3, #132): a structured monthly bill per period —
/// subscription, consumed services, open positions awaiting validation,
/// payments & credits, balance — plus payment/expense/consumption actions.
/// Amounts render in the workspace currency.
///
/// This State owns the browsed month and the two focus requests (#718);
/// the content is [MoneyBody], the operations are [MoneySheets],
/// [MoneyMemberDocuments] and [MoneyOnlinePayment] (#2494).
class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  late final MoneySheets _sheets = MoneySheets(this, ref);
  late final MoneyMemberDocuments _documents = MoneyMemberDocuments(this, ref);
  late final MoneyOnlinePayment _onlinePayment = MoneyOnlinePayment(this, ref);

  /// First day of the visible month; the bill shows this period.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    // #718 — a focus request made BEFORE this branch was built (the
    // calendar hub sets it, then switches) is already there when the
    // listener in build subscribes, and a listener only sees changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyFocus(ref.read(moneyFocusControllerProvider));
      unawaited(_applyInvoiceFocus(ref.read(invoiceFocusProvider)));
    });
    // #726 — an admin opening Finances is one of the two clocks that
    // apply the dunning rules (the other is the morning cron).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ws = ref.read(currentWorkspaceProvider).value;
      if (ws != null) {
        ref
          ..read(paymentReminderSweepProvider(ws.id))
          // #816 — the billing cycle (#802) gets the same client clock.
          ..read(billingInvoiceSweepProvider(ws.id));
      }
    });
    final now = ref.read(clockProvider).now();
    _month = DateTime(now.year, now.month);
  }

  void _applyFocus(String? period) {
    if (period == null) return;
    final parts = period.split('-');
    if (parts.length == 2) {
      setState(() => _month = DateTime(int.parse(parts[0]), int.parse(parts[1])));
    }
    ref.read(moneyFocusControllerProvider.notifier).clear();
  }

  /// Me › Finances asked for one invoice of this space: open it here.
  Future<void> _applyInvoiceFocus(
    ({String workspaceId, String invoiceId})? focus,
  ) {
    final workspace = ref.read(currentWorkspaceProvider).value;
    return openFocusedInvoice(
      context,
      ref,
      focus,
      workspaceId: workspace?.id,
      countryCode: workspace?.countryCode ?? '',
    );
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    // #718 — the calendar hub asks for a month; consume it once.
    ref.listen(moneyFocusControllerProvider, (_, period) => _applyFocus(period));
    ref.listen(invoiceFocusProvider, (_, focus) => _applyInvoiceFocus(focus));
    // The space may arrive after the request: try again once it does.
    ref.listen(currentWorkspaceProvider, (_, _) =>
        _applyInvoiceFocus(ref.read(invoiceFocusProvider)));
    return MoneyBody(
      ops: MoneyScreenOps(
        month: _month,
        nowPeriod: currentPeriod(ref.read(clockProvider).now()),
        shiftMonth: _shiftMonth,
        sheets: _sheets,
        documents: _documents,
        onlinePayment: _onlinePayment,
      ),
    );
  }
}
