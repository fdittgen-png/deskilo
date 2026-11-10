// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- how "Invoice the month" ended, honestly: what was issued, what
// waits for a validation, what was not done and WHY (the refusal in the words
// the issue form uses, with a Fix when a detail is missing), and a retry for
// those that can be retried. Nothing is claimed that the server did not
// record; no e-mail and no notification is ever mentioned.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/result_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/issue_month.dart';
import '../../application/issue_month_readiness.dart';
import '../../providers/money_providers.dart';
import '../widgets/invoice_issue_runner.dart';
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

  static final RegExp _keyShape = RegExp(r'[a-z]+(?:_[a-z0-9]+)+');

  static bool _isEssentialKey(String key) =>
      key.startsWith('seller_') ||
      key.startsWith('buyer_') ||
      key.startsWith('vat_') ||
      key == 'exemption_reason' ||
      key == 'vies_unverified';

  /// The missing essentials a refusal names (none when it names none).
  List<String> _missingIn(Object error) => [
    for (final m in _keyShape.allMatches(error.toString()))
      if (_isEssentialKey(m.group(0)!)) m.group(0)!,
  ];

  /// What to say of a refused customer, in the issue form's own words, and
  /// the essentials to fix when that is what refused it.
  ({String text, List<String> missing}) _reasonOf(
    AppLocalizations l10n,
    String memberId,
  ) {
    final error = report.refusalOf(memberId);
    if (error == null) {
      return (text: l10n.invoiceMonthNotIssued, missing: const []);
    }
    final text = invoiceRefusalText(
      l10n,
      error,
      fallback: l10n.invoiceMonthNotIssued,
    );
    final missing = error.toString().contains('invoice_essentials_missing')
        ? _missingIn(error)
        : const <String>[];
    return (
      text: missing.isEmpty
          ? text
          : '$text\n${monthMissingWords(l10n, missing)}',
      missing: missing,
    );
  }

  Widget _fixFor(AppLocalizations l10n, String id, List<String> missing) =>
      TextButton(
        key: ValueKey('invoice-month-result-fix-$id'),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: busy
            ? null
            : () => missing.every(isBusinessEssential)
                  ? onFixBusiness()
                  : onFixCustomer(id),
        child: Text(l10n.invoiceMonthFix),
      );

  /// What was not done, each with the words of why and, when a detail is
  /// missing, a Fix beside it.
  ({List<ResultLine> lines, List<Widget?> fixes}) _notDone(
    AppLocalizations l10n,
    String Function(String) nameOf,
  ) {
    final lines = <ResultLine>[];
    final fixes = <Widget?>[];
    for (final id in report.notDone) {
      final lost = report.unknown.contains(id);
      final reason = lost
          ? (text: l10n.invoiceMonthUnknown, missing: const <String>[])
          : _reasonOf(l10n, id);
      lines.add((title: nameOf(id), detail: reason.text, outcome: ''));
      fixes.add(
        reason.missing.isEmpty ? null : _fixFor(l10n, id, reason.missing),
      );
    }
    return (lines: lines, fixes: fixes);
  }

  /// How it ended: nothing issued is the alert; some not done is the warning.
  ResultTone get _tone => report.issued.isEmpty && report.held.isEmpty
      ? ResultTone.failed
      : report.notDone.isEmpty
      ? ResultTone.ok
      : ResultTone.partial;

  String _title(AppLocalizations l10n) => switch (_tone) {
    ResultTone.failed => l10n.invoiceMonthResultNone,
    ResultTone.ok => l10n.invoiceMonthResultTitle(report.issued.length),
    ResultTone.partial => l10n.invoiceMonthResultPartial(
      report.issued.length,
      report.outcomes.length,
    ),
  };

  /// Retry is for those the server refused or whose answer was lost; a
  /// request a validator declined is not asked again.
  Widget? _retry(AppLocalizations l10n) {
    if (report.refused.isEmpty && report.unknown.isEmpty) return null;
    final onlyLost = report.refused.isEmpty;
    return FilledButton.tonal(
      key: const ValueKey('invoice-month-retry'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: busy ? null : onRetry,
      child: Text(
        onlyLost ? l10n.invoiceMonthCheckAgain : l10n.invoiceMonthRetry,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final money = ref.watch(appFormatProvider).moneyIn(currency);
    final byId = {for (final e in entries) e.memberId: e};
    String nameOf(String id) => byId[id]?.name ?? id;
    String amount(String id) => money.formatMinor(byId[id]?.totalCents ?? 0);
    final notDone = _notDone(l10n, nameOf);
    return ResultPage(
      key: const ValueKey('invoice-month-result'),
      tone: _tone,
      title: _title(l10n),
      subtitle: report.issued.isEmpty
          ? l10n.invoiceMonthResultNoneSubtitle
          : l10n.invoiceMonthResultSubtitle(report.issued.length),
      done: [
        for (final id in report.issued)
          (
            title: nameOf(id),
            detail: amount(id),
            outcome: l10n.invoiceMonthIssued,
          ),
        for (final id in report.held)
          (
            title: nameOf(id),
            detail: amount(id),
            outcome: l10n.invoiceMonthHeld,
          ),
      ],
      notDone: notDone.lines,
      notDoneActions: notDone.fixes,
      notDoneHeading: l10n.invoiceMonthNotDone,
      staysNote: l10n.invoiceMonthStays,
      doneLabel: l10n.invoiceMonthDone,
      onDone: () => Navigator.of(context).maybePop(),
      secondaryAction: _retry(l10n),
    );
  }
}
