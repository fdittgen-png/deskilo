// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/format/cents.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/locale/report_language.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/date_text.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_frame.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../profile/domain/personal_preferences.dart';
import '../../../profile/providers/personal_preferences_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/overage_policy.dart';
import '../../../workspace/domain/payment_instructions.dart';
import '../../../workspace/domain/workspace.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/bill_pdf.dart';
import '../../domain/bill_sections.dart';
import '../../domain/expense_schedule.dart';
import '../../domain/invoice_line_text.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/invoice_report.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/money_face.dart';
import '../../domain/package.dart';
import '../../domain/payment_method.dart';
import '../../domain/payment_provider.dart';
import '../../domain/payment_request_ids.dart';
import '../../domain/report_data_letters.dart';
import '../../domain/statement.dart';
import '../../providers/billing_invoice_sweep.dart';
import '../../providers/expense_schedule_providers.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/money_focus_controller.dart';
import '../../providers/money_providers.dart';
import '../../providers/payment_reminder_sweep.dart';
import '../../providers/usage_providers.dart';
import '../invoice_documents.dart';
import '../invoice_status.dart';
import '../payment_method_labels.dart';
import '../payment_provider_labels.dart';
import '../period_label.dart';
import '../report_actions.dart';
import '../report_facts_of.dart';
import '../report_layout_actions.dart';
import '../report_strings_l10n.dart';
import '../usage_report_data.dart';
import '../widgets/account_card.dart';
import '../widgets/bill_view.dart';
import '../widgets/consumption_sheet.dart';
import '../widgets/documents_face.dart';
import '../widgets/expense_schedule_sheet.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/focused_invoice.dart';
import '../widgets/invoice_overview.dart';
import '../widgets/money_attention_body.dart';
import '../widgets/money_faces_view.dart';
import '../widgets/my_finances_link_card.dart';
import '../widgets/my_invoices_list.dart';
import '../widgets/negotiation_card.dart';
import '../widgets/online_payment_status_card.dart';
import '../widgets/usage_face.dart';

part 'money_screen_part1.dart';
part 'money_screen_part2.dart';
part 'money_screen_part3.dart';




/// Money tab (spec §7.3, #132): a structured monthly bill per period —
/// subscription, consumed services, open positions awaiting validation,
/// payments & credits, balance — plus payment/expense/consumption actions.
/// Amounts render in the workspace currency.
class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  final _paymentRequests = PaymentRequestIds(); // #2014 B
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

  String get _period => DateFormat('yyyy-MM').format(_month);

  /// The running month's period key — the ONE clock read both uses share.
  String get _nowPeriod => currentPeriod(ref.read(clockProvider).now());

  bool get _isCurrentPeriod => _period == _nowPeriod;

  // #2386 — the operations; each body is in a part file.
  @override Widget build(BuildContext context) => _buildImpl(context);

  /// Lets the section extensions rebuild (setState is protected).
  void _update(VoidCallback fn) => setState(fn);

}
