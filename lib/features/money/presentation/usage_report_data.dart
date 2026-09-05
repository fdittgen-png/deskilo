// SPDX-License-Identifier: 0BSD
//
// #873 — the CONSUMPTION REPORT's data: since #802 the participation is
// billed ahead of its month and consumed during it (#833); at month end
// the member gets what was paid for, what was actually consumed, what
// is left or exceeded — and the records behind the numbers. Every
// figure comes from member_statement and usage_records; nothing is
// re-aggregated here.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/time/clock.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/usage_record.dart';
import '../providers/money_providers.dart';
import '../providers/usage_providers.dart';
import 'invoice_actions.dart';

Map<String, Object?> usageReportData(
  BuildContext context,
  WidgetRef ref, {
  required String period,
  required String memberId,
  required String memberName,
  AppLocalizations? l10nOverride,
  String? localeName,
}) {
  final l10n = l10nOverride ?? AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  final currency = moneyFormat(workspace?.currencyCode ?? 'EUR');
  String money(int cents) => currency.formatMinor(cents);
  final locale = localeName ?? Localizations.maybeLocaleOf(context)?.toString();
  final dateFormat = DateFormat.yMMMd(locale);
  final dayFormat = DateFormat.MMMEd(locale);
  final statement = ref.read(memberStatementProvider(memberId, period)).value;
  final records = (ref.read(usageRecordsProvider(period)).value ??
          const <UsageRecord>[])
      .where((r) => r.memberId == memberId)
      .toList()
    ..sort((a, b) => a.reservedFrom.compareTo(b.reservedFrom));
  final supplements = statement == null
      ? 0
      : statement.accessorySupplementCents +
          statement.levelSupplementCents +
          statement.officeSupplementCents +
          statement.deskSupplementCents;
  String halfDays(int n) => '$n';
  final lines = <Map<String, Object?>>[
    {
      'label': l10n?.usageReportPaid ?? 'Paid ahead (participation)',
      'amount': money(statement?.feeCents ?? 0),
    },
    {
      'label': l10n?.usageReportIncluded ?? 'Included half-days',
      'amount': halfDays(statement?.includedHalfDays ?? 0),
    },
    {
      'label': l10n?.usageReportUsed ?? 'Half-days consumed',
      'amount': halfDays(statement?.usedHalfDays ?? 0),
    },
    {
      'label': l10n?.usageReportRemaining ?? 'Half-days remaining',
      'amount': halfDays(statement?.remainingHalfDays ?? 0),
    },
    if ((statement?.extraHalfDays ?? 0) > 0)
      {
        'label': l10n?.usageReportExtra ?? 'Extra half-days',
        'amount': halfDays(statement!.extraHalfDays),
      },
    if (supplements > 0)
      {
        'label': l10n?.usageReportSupplements ??
            'Supplements (accessories, desks, offices)',
        'amount': money(supplements),
      },
  ];
  return <String, Object?>{
    'workspace': workspace?.name ?? '',
    'workspace_address': workspace?.address ?? '',
    'member': memberName,
    'number': '',
    'period': period,
    'issued': dateFormat.format(ref.read(clockProvider).now()),
    'issued_by': workspace?.name ?? '',
    'replaces': '',
    'total': money(statement?.feeCents ?? 0),
    'charges': '',
    'payments': '',
    'net_total': '',
    'vat_total': '',
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'lines': lines,
    'vat': const <Map<String, Object?>>[],
    'usage_paid': money(statement?.feeCents ?? 0),
    'usage_included_half_days': halfDays(statement?.includedHalfDays ?? 0),
    'usage_used_half_days': halfDays(statement?.usedHalfDays ?? 0),
    'usage_remaining_half_days': halfDays(statement?.remainingHalfDays ?? 0),
    'usage_extra_half_days': halfDays(statement?.extraHalfDays ?? 0),
    'usage_overage':
        (statement?.overageCents ?? 0) > 0 ? money(statement!.overageCents) : '',
    'usage_supplements': supplements > 0 ? money(supplements) : '',
    'usage_records': [
      for (final r in records)
        {
          'date': dayFormat.format(r.reservedFrom),
          'space': r.spaceLabel,
          'reserved': usageDuration(r.reservedMinutes),
          'counted': usageDuration(r.countedMinutes),
          'corrected': r.isCorrected,
        },
    ],
    ...legalMentionData(l10n, workspace),
  };
}
