// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- how "Invoice the month" ended, honestly: what was issued, what
// waits for a validation, what was not done and WHY (the refusal's own words,
// with a Fix when a detail is missing), and a retry for those only. Nothing is
// claimed that the server did not record; no e-mail is ever mentioned.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/result_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/issue_month.dart';
import '../../application/issue_month_readiness.dart';
import '../../providers/money_providers.dart';
import 'invoice_month_parts.dart';

class MonthResultView extends ConsumerWidget {
  const MonthResultView({
    super.key,
    required this.report,
    required this.entries,
    required this.currency,
    required this.busy,
    required this.onRetry,
    required this.onFixCustomer,
    required this.onFixBusiness,
  });

  final MonthIssueReport report;
  final List<ToInvoiceEntry> entries;
  final String currency;
  final bool busy;
  final VoidCallback onRetry;
  final Future<void> Function(String memberId) onFixCustomer;
  final Future<void> Function() onFixBusiness;

  /// The refusal's own words, or the fallback.
  ({String text, List<String> missing}) _reasonOf(
    AppLocalizations l10n,
    MonthIssueReport report,
    String memberId,
  ) {
    final raw = report.refusalTextOf(memberId) ?? '';
    if (raw.contains('already invoiced')) {
      return (text: l10n.invoiceAlreadyInvoiced, missing: const []);
    }
    if (raw.contains('invoice_feature_disabled')) {
      return (text: l10n.invoiceFeatureDisabled, missing: const []);
    }
    if (raw.contains('invoice_essentials_missing')) {
      final keys = RegExp(r'[a-z]+(?:_[a-z0-9]+)+')
          .allMatches(raw)
          .map((m) => m.group(0)!)
          .where(_isEssentialKey)
          .toList();
      return (
        text: keys.isEmpty
            ? l10n.invoiceEssentialsRefused
            : '${l10n.invoiceEssentialsRefused}\n${monthMissingWords(l10n, keys)}',
        missing: keys,
      );
    }
    return (text: l10n.invoiceMonthNotIssued, missing: const []);
  }

  bool _isEssentialKey(String key) =>
      key.startsWith('seller_') ||
      key.startsWith('buyer_') ||
      key.startsWith('vat_') ||
      key == 'exemption_reason' ||
      key == 'vies_unverified';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final money = ref.watch(appFormatProvider).moneyIn(currency);
    final byId = {for (final e in entries) e.memberId: e};
    ResultLine line(String memberId, String detail, String outcome) => (
      title: byId[memberId]?.name ?? memberId,
      detail: detail,
      outcome: outcome,
    );
    String amount(String id) => money.formatMinor(byId[id]?.totalCents ?? 0);
    final done = [
      for (final id in report.issued)
        line(id, amount(id), l10n.invoiceMonthIssued),
      for (final id in report.held) line(id, amount(id), l10n.invoiceMonthHeld),
    ];
    final notDoneIds = [...report.refused, ...report.unknown];
    final notDone = <ResultLine>[];
    final fixes = <Widget?>[];
    for (final id in notDoneIds) {
      if (report.unknown.contains(id)) {
        notDone.add(line(id, l10n.invoiceMonthUnknown, ''));
        fixes.add(null);
      } else {
        final reason = _reasonOf(l10n, report, id);
        notDone.add(line(id, reason.text, ''));
        fixes.add(
          reason.missing.isEmpty
              ? null
              : TextButton(
                  key: ValueKey('invoice-month-result-fix-$id'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: busy
                      ? null
                      : () => reason.missing.every(isBusinessEssential)
                            ? onFixBusiness()
                            : onFixCustomer(id),
                  child: Text(l10n.invoiceMonthFix),
                ),
        );
      }
    }
    final issued = report.issued.length;
    final total = report.outcomes.length;
    final onlyLost = report.refused.isEmpty && report.unknown.isNotEmpty;
    final tone = issued == 0 && report.held.isEmpty
        ? ResultTone.failed
        : notDone.isEmpty
        ? ResultTone.ok
        : ResultTone.partial;
    return ResultPage(
      key: const ValueKey('invoice-month-result'),
      tone: tone,
      title: tone == ResultTone.failed
          ? l10n.invoiceMonthResultNone
          : notDone.isEmpty
          ? l10n.invoiceMonthResultTitle(issued)
          : l10n.invoiceMonthResultPartial(issued, total),
      subtitle: issued == 0
          ? l10n.invoiceMonthResultNoneSubtitle
          : l10n.invoiceMonthResultSubtitle(issued),
      done: done,
      notDone: notDone,
      notDoneActions: fixes,
      notDoneHeading: l10n.invoiceMonthNotDone,
      staysNote: l10n.invoiceMonthStays,
      doneLabel: l10n.invoiceMonthDone,
      onDone: () => Navigator.of(context).maybePop(),
      secondaryAction: notDone.isEmpty
          ? null
          : FilledButton.tonal(
              key: const ValueKey('invoice-month-retry'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: busy ? null : onRetry,
              child: Text(
                onlyLost ? l10n.invoiceMonthCheckAgain : l10n.invoiceMonthRetry,
              ),
            ),
    );
  }
}
