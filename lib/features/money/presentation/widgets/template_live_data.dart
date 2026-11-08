// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/report_data.dart';
import '../../domain/report_data_letters.dart';
import '../../domain/report_kind.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart' show workspaceTaxReference;
import '../report_facts_of.dart';
import '../report_strings_l10n.dart';

/// #1061 — the live data for the designer's SELECTED document, or null
/// when the app has none yet (→ simulated sample data). Moved out of
/// the template sheet: the sheet designs, this decides what a design is
/// previewed against.
Map<String, Object?>? liveReportData(
    BuildContext context, WidgetRef ref, String doc) {
  // No reference yet: no live data, the preview falls back to the sample.
  final reference = workspaceTaxReference(ref);
  if (reference == null) return null;
  final invoices = ref.read(invoicesProvider).value ?? const [];
  final liveWorkspace = ref.read(currentWorkspaceProvider).value;
  switch (doc) {
    case 'invoice':
      if (invoices.isEmpty) return null;
      return invoiceReportData(reportStringsFor(context), invoices.first,
          proforma: false, copy: false, workspace: liveWorkspace, reference: reference);
    case 'proforma':
      if (invoices.isEmpty) return null;
      return invoiceReportData(reportStringsFor(context), invoices.first,
          proforma: true, copy: false, workspace: liveWorkspace, reference: reference);
    case 'statement':
      final now = ref.read(clockProvider).now();
      final period =
          yearMonth(now.year, now.month);
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
        workspace: workspace, reference: reference,
      );
    case 'agreement':
      final me = ref.read(myMemberProvider).value;
      final names = ref.read(memberNamesProvider).value ?? const {};
      if (me == null) return null;
      return agreementReportData(
          reportStringsFor(context), agreementFactsOf(ref),
          memberName: names[me.id] ?? '',
          subscriptionPct: me.subscriptionPct, reference: reference);
    case 'payments':
      final me = ref.read(myMemberProvider).value;
      final names = ref.read(memberNamesProvider).value ?? const {};
      final now = ref.read(clockProvider).now();
      final period =
          yearMonth(now.year, now.month);
      if (me == null) return null;
      return paymentsReportData(
          reportStringsFor(context), paymentsFactsOf(ref, period),
          period: period, memberName: names[me.id] ?? '', reference: reference);
    case 'workspace':
      return workspaceReportData(reportStringsFor(context),
          workspaceFactsOf(ref, context.l10n), reference: reference);
    case 'status':
      return null; // #934 — sample data; the live view prints from its screen.
    default:
      if (!_previewsReminder(doc, invoices)) return null;
      return reminderReportData(
          reportStringsFor(context), reminderFactsOf(ref, invoices.first),
          invoices.first, level: int.tryParse(doc.substring(1)) ?? 1, reference: reference);
  }
}

/// Only a reminder level previews against an invoice; every other kind
/// (the CoA, the badge and code sheets, #2376 the book reports printed
/// from the accounting export) previews the sample data.
bool _previewsReminder(String doc, List<Object?> invoices) =>
    invoices.isNotEmpty &&
    reportKindById(doc, reminderLevels: kMaxReminderLevels)?.slot
        is ReportReminderSlot;
