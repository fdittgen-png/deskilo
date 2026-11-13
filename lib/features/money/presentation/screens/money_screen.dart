// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/address_query.dart';
import '../../../../core/time/clock.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/bill_sections.dart';
import '../../domain/money_face.dart';
import '../../providers/billing_invoice_sweep.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/money_face_controller.dart';
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
    if (_monthOf(period) case final month?) _showMonth(month);
    ref.read(moneyFocusControllerProvider.notifier).clear();
  }

  /// #3627 — `yyyy-MM` as the first day of that month, or null.
  static DateTime? _monthOf(String? period) {
    final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(period ?? '');
    if (m == null) return null;
    final month = int.parse(m.group(2)!);
    return month < 1 || month > 12 ? null : DateTime(int.parse(m.group(1)!), month);
  }

  /// #3627 — the month shown: the address's (`?month=yyyy-MM`), else the
  /// month this page keeps itself (no router: a test pumping it alone).
  DateTime get _shown => _monthOf(addressQuery(context, 'month')) ?? _month;

  void _showMonth(DateTime month) {
    final period = currentPeriod(month);
    if (!setAddressQuery(context, {'month': period})) {
      setState(() => _month = month);
    }
  }

  /// #3627 — the face shown is kept in the address (`?face=`): an address
  /// naming one shows it; choosing one writes it.
  void _syncFace() {
    final asked = MoneyFace.fromWire(addressQuery(context, 'face'));
    if (asked != null && asked != ref.read(moneyFaceControllerProvider)) {
      ref.read(moneyFaceControllerProvider.notifier).show(asked);
    }
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
    final shown = _shown;
    _showMonth(DateTime(shown.year, shown.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    // #718 — the calendar hub asks for a month; consume it once.
    ref.listen(moneyFocusControllerProvider, (_, period) => _applyFocus(period));
    ref.listen(invoiceFocusProvider, (_, focus) => _applyInvoiceFocus(focus));
    // The space may arrive after the request: try again once it does.
    ref.listen(currentWorkspaceProvider, (_, _) =>
        _applyInvoiceFocus(ref.read(invoiceFocusProvider)));
    ref.listen(moneyFaceControllerProvider,
        (_, face) => setAddressQuery(context, {'face': face.name}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFace();
    });
    return MoneyBody(
      ops: MoneyScreenOps(
        month: _shown,
        nowPeriod: currentPeriod(ref.read(clockProvider).now()),
        shiftMonth: _shiftMonth,
        sheets: _sheets,
        documents: _documents,
        onlinePayment: _onlinePayment,
      ),
    );
  }
}
