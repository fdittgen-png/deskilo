// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #934 — the workspace status as the report engine reads it: the same
// numbers the screen shows, formatted, with the per-member rows.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/report_data.dart';
import '../domain/workspace_status.dart';
import 'report_strings_l10n.dart';

Map<String, Object?> workspaceStatusReportData(
  BuildContext context,
  WidgetRef ref,
  WorkspaceStatus status, {
  AppLocalizations? l10nOverride,
  String? localeName,
}) {
  final l10n = l10nOverride ?? AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  final currency = moneyFormat(status.currency);
  final issued = DateFormat.yMMMd(
    localeName ?? Localizations.maybeLocaleOf(context)?.toString(),
  ).format(ref.read(clockProvider).now());
  final lines = <Map<String, Object?>>[
    {'label': l10n?.statusInvoiced ?? 'Invoiced', 'amount': currency.formatMinor(status.invoicedCents)},
    {'label': l10n?.statusCreditNotes ?? 'Credit notes', 'amount': currency.formatMinor(-status.creditNotesCents), 'negative': true},
    {'label': l10n?.statusPaymentsMatched ?? 'Payments matched', 'amount': currency.formatMinor(status.paymentsMatchedCents)},
    {'label': l10n?.statusPaymentsReceived ?? 'Payments received', 'amount': currency.formatMinor(status.paymentsReceivedCents)},
    {'label': l10n?.statusReimbursed ?? 'Expenses reimbursed', 'amount': currency.formatMinor(-status.reimbursedCents), 'negative': true},
    {'label': l10n?.statusRepartitioned ?? 'Expenses shared out', 'amount': currency.formatMinor(status.repartitionedCents)},
    {'label': l10n?.statusCredits ?? 'Credits granted', 'amount': currency.formatMinor(-status.creditsGrantedCents), 'negative': true},
  ];
  return <String, Object?>{
    'workspace': workspace?.name ?? '',
    'workspace_address': workspace?.address ?? '',
    'member': '',
    'number': '',
    'period': '${status.from} → ${status.to}',
    'issued': issued,
    'issued_by': workspace?.name ?? '',
    'replaces': '',
    'total': currency.formatMinor(status.netCents),
    'charges': '',
    'payments': currency.formatMinor(status.paymentsMatchedCents),
    'net_total': '',
    'vat_total': '',
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'lines': lines,
    'vat': const <Map<String, Object?>>[],
    'status_from': status.from,
    'status_to': status.to,
    'status_invoiced': currency.formatMinor(status.invoicedCents),
    'status_credit_notes': currency.formatMinor(status.creditNotesCents),
    'status_payments': currency.formatMinor(status.paymentsMatchedCents),
    'status_reimbursed': currency.formatMinor(status.reimbursedCents),
    'status_repartitioned': currency.formatMinor(status.repartitionedCents),
    'status_credits': currency.formatMinor(status.creditsGrantedCents),
    'status_net': currency.formatMinor(status.netCents),
    'status_members': [
      for (final m in status.members)
        {
          'number': m.memberNumber,
          'name': m.name,
          'pct': m.subscriptionPct,
          'invoiced': currency.formatMinor(m.invoicedCents),
          'paid': currency.formatMinor(m.paidCents),
        },
    ],
    ...legalMentionData(reportStringsOf(l10n), workspace),
  };
}
