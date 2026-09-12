// SPDX-License-Identifier: 0BSD
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../report_facts_of.dart';
import '../report_strings_l10n.dart';

/// #1061 — the live data for the designer's SELECTED document, or null
/// when the app has none yet (→ simulated sample data). Moved out of
/// the template sheet: the sheet designs, this decides what a design is
/// previewed against.
Map<String, Object?>? liveReportData(
    BuildContext context, WidgetRef ref, String doc) {
  final invoices = ref.read(invoicesProvider).value ?? const [];
  final liveWorkspace = ref.read(currentWorkspaceProvider).value;
  switch (doc) {
    case 'invoice':
      if (invoices.isEmpty) return null;
      return invoiceReportData(reportStringsFor(context), invoices.first,
          proforma: false, copy: false, workspace: liveWorkspace);
    case 'proforma':
      if (invoices.isEmpty) return null;
      return invoiceReportData(reportStringsFor(context), invoices.first,
          proforma: true, copy: false, workspace: liveWorkspace);
    case 'statement':
      final now = ref.read(clockProvider).now();
      final period =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final statement =
          ref.read(myStatementProvider(period)).value;
      final workspace = ref.read(currentWorkspaceProvider).value;
      final me = ref.read(myMemberProvider).value;
      final names = ref.read(memberNamesProvider).value ?? const {};
      if (statement == null || workspace == null) return null;
      return statementReportData(
        reportStringsFor(context),
        statement: statement,
        workspaceName: workspace.name,
        memberName: names[me?.id] ?? '',
        periodLabel: statement.period,
        currencyCode: workspace.currencyCode,
        workspace: workspace,
      );
    case 'agreement':
      final me = ref.read(myMemberProvider).value;
      final names = ref.read(memberNamesProvider).value ?? const {};
      if (me == null) return null;
      return agreementReportData(
          reportStringsFor(context), agreementFactsOf(ref),
          memberName: names[me.id] ?? '',
          subscriptionPct: me.subscriptionPct);
    case 'payments':
      final me = ref.read(myMemberProvider).value;
      final names = ref.read(memberNamesProvider).value ?? const {};
      final now = ref.read(clockProvider).now();
      final period =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      if (me == null) return null;
      return paymentsReportData(
          reportStringsFor(context), paymentsFactsOf(ref, period),
          period: period, memberName: names[me.id] ?? '');
    case 'workspace':
      return workspaceReportData(reportStringsFor(context),
          workspaceFactsOf(ref, AppLocalizations.of(context)));
    case 'status':
      return null; // #934 — sample data; the live view prints from its screen.
    case 'coa':
    case 'badges':
    case 'space_codes':
      return null;
    default:
      if (invoices.isEmpty) return null;
      return reminderReportData(
          reportStringsFor(context), reminderFactsOf(ref, invoices.first),
          invoices.first, level: int.tryParse(doc.substring(1)) ?? 1);
  }
}
