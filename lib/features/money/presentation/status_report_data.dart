// SPDX-License-Identifier: 0BSD
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
import '../domain/workspace_status.dart';
import 'invoice_actions.dart';

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
  String money(int cents) => currency.formatMinor(cents);
  final issued = DateFormat.yMMMd(
    localeName ?? Localizations.maybeLocaleOf(context)?.toString(),
  ).format(ref.read(clockProvider).now());
  final lines = <Map<String, Object?>>[
    {'label': l10n?.statusInvoiced ?? 'Invoiced', 'amount': money(status.invoicedCents)},
    {'label': l10n?.statusCreditNotes ?? 'Credit notes', 'amount': money(-status.creditNotesCents), 'negative': true},
    {'label': l10n?.statusPaymentsMatched ?? 'Payments matched', 'amount': money(status.paymentsMatchedCents)},
    {'label': l10n?.statusPaymentsReceived ?? 'Payments received', 'amount': money(status.paymentsReceivedCents)},
    {'label': l10n?.statusReimbursed ?? 'Expenses reimbursed', 'amount': money(-status.reimbursedCents), 'negative': true},
    {'label': l10n?.statusRepartitioned ?? 'Expenses shared out', 'amount': money(status.repartitionedCents)},
    {'label': l10n?.statusCredits ?? 'Credits granted', 'amount': money(-status.creditsGrantedCents), 'negative': true},
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
    'total': money(status.netCents),
    'charges': '',
    'payments': money(status.paymentsMatchedCents),
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
    'status_invoiced': money(status.invoicedCents),
    'status_credit_notes': money(status.creditNotesCents),
    'status_payments': money(status.paymentsMatchedCents),
    'status_reimbursed': money(status.reimbursedCents),
    'status_repartitioned': money(status.repartitionedCents),
    'status_credits': money(status.creditsGrantedCents),
    'status_net': money(status.netCents),
    'status_members': [
      for (final m in status.members)
        {
          'number': m.memberNumber,
          'name': m.name,
          'pct': m.subscriptionPct,
          'invoiced': money(m.invoicedCents),
          'paid': money(m.paidCents),
        },
    ],
    ...legalMentionData(l10n, workspace),
  };
}
