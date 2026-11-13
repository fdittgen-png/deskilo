// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3616 (desk M3) — Books opens on its status (#3609, a dashboard page):
// how far the books are closed, the last file handed to the accountant,
// the VAT return still to file, the bank lines waiting for a match and the
// next invoice number. Each tile says what its page says and opens it; the
// doors to every part of the books follow below. A read that failed is
// said on its tile, never shown as nothing to do. No country's rule is
// assumed: the VAT tile names the return to file and its period, not a
// deadline, which no jurisdiction package carries.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart'
    show BookExport, BookPeriodsOverview;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/kit/dashboard_grid.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/number_sequence.dart';
import '../../providers/bank_statement_providers.dart';
import '../../providers/book_period_providers.dart';
import '../../providers/money_providers.dart';
import '../../providers/vat_declaration_providers.dart';
import '../widgets/bank_statements_sheet.dart';
import '../widgets/book_periods_sheet.dart';

/// The figures of the status page, each as its page reads it.
@immutable
class _AccountingStatus {
  const _AccountingStatus({
    required this.closedUpTo,
    required this.lastExport,
    required this.vatToFile,
    required this.bankToMatch,
    required this.nextInvoiceNumber,
  });

  /// The last day of the latest closed period; null when none is closed.
  final AsyncValue<DateTime?> closedUpTo;

  /// The latest file handed to the accountant; null when there is none.
  final AsyncValue<BookExport?> lastExport;

  /// The period of the oldest VAT return not filed; null when all are.
  final AsyncValue<({DateTime from, DateTime to})?> vatToFile;

  /// Bank movements still waiting for a person, over every statement.
  final AsyncValue<int> bankToMatch;

  /// The next invoice number, as the number series page previews it.
  final AsyncValue<String> nextInvoiceNumber;
}

/// The last day of the latest closed period of [overview], or null.
@visibleForTesting
DateTime? closedUpToOf(BookPeriodsOverview overview) {
  DateTime? last;
  for (final p in overview.periods) {
    if (p.closed && (last == null || p.to.isAfter(last))) last = p.to;
  }
  return last;
}

/// The latest export of [overview], or null.
BookExport? _lastExportOf(BookPeriodsOverview overview) {
  BookExport? last;
  for (final e in overview.exports) {
    if (last == null || e.exportedAt.isAfter(last.exportedAt)) last = e;
  }
  return last;
}

/// The status of [workspaceId]'s books, read from the same providers as
/// the pages its tiles open.
_AccountingStatus _accountingStatusOf(WidgetRef ref, String workspaceId) {
  final periods = ref.watch(bookPeriodsProvider(workspaceId));
  final declarations = ref.watch(vatDeclarationsProvider);
  final statements = ref.watch(bankStatementsProvider(workspaceId));
  final sequences = ref.watch(numberSequencesProvider);
  final now = ref.watch(clockProvider).now();
  return _AccountingStatus(
    closedUpTo: periods.whenData(closedUpToOf),
    lastExport: periods.whenData(_lastExportOf),
    vatToFile: declarations.whenData((all) {
      final open = [
        for (final d in all)
          if (!d.isFiled) d,
      ]..sort((a, b) => a.periodStart.compareTo(b.periodStart));
      final first = open.firstOrNull;
      return first == null
          ? null
          : (from: first.periodStart, to: first.periodEnd);
    }),
    bankToMatch: statements.whenData(
      (all) => all.fold(0, (sum, s) => sum + s.openCount),
    ),
    nextInvoiceNumber: sequences.whenData((all) {
      final invoice =
          all.where((s) => s.journal == 'invoice').firstOrNull ??
          const NumberSequence(journal: 'invoice');
      return invoice.format(invoice.nextValue, now);
    }),
  );
}

/// The status tiles: what each page says, each opening it.
class AccountingStatusGrid extends ConsumerWidget {
  const AccountingStatusGrid({
    super.key,
    required this.workspaceId,
    required this.isOwner,
    required this.bankDoor,
    required this.shown,
  });

  final String workspaceId;
  final bool isOwner;

  /// The tiles whose page this space has: the periods and their export
  /// log, the VAT returns, the number series.
  final ({bool periods, bool vat, bool numbers}) shown;

  /// Opens the bank statements, or null when the person reads none.
  final VoidCallback? bankDoor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.numeric);
    final status = _accountingStatusOf(ref, workspaceId);
    String figure<T>(AsyncValue<T> v, String Function(T) say) => switch (v) {
      AsyncData(:final value) => say(value),
      AsyncError() => l.accountingStatusNotRead,
      _ => l.myReservationsLoadingMore,
    };
    final export = status.lastExport.value;
    return DashboardGrid(
      key: const ValueKey('accounting-status'),
      minTileWidth: kpiTileMinWidth,
      children: [
        if (shown.periods)
          KpiTile(
            tapKey: const ValueKey('accounting-status-periods'),
            figureKey: const ValueKey('accounting-status-periods-figure'),
            label: l.accountingStatusClosedUpTo,
            figure: figure(
              status.closedUpTo,
              (d) => d == null ? l.memberPageNone : dates.format(d),
            ),
            onTap: () =>
                showBookPeriodsSheet(context, workspaceId, isOwner: isOwner),
          ),
        if (shown.periods)
          KpiTile(
            tapKey: const ValueKey('accounting-status-export'),
            figureKey: const ValueKey('accounting-status-export-figure'),
            label: l.accountingStatusLastExport,
            figure: figure(
              status.lastExport,
              (e) => e == null ? l.memberPageNone : dates.format(e.exportedAt),
            ),
            note: export == null ? null : _exportLine(l, dates, export),
            onTap: () => context.push(_accountingExportsPath),
          ),
        if (shown.vat)
          KpiTile(
            tapKey: const ValueKey('accounting-status-vat'),
            figureKey: const ValueKey('accounting-status-vat-figure'),
            label: l.accountingStatusVatToFile,
            figure: figure(
              status.vatToFile,
              (p) => p == null
                  ? l.memberPageNone
                  : '${dates.format(p.from)} – ${dates.format(p.to)}',
            ),
            onTap: () => context.push('/vat-declarations'),
          ),
        if (bankDoor case final open?)
          KpiTile(
            tapKey: const ValueKey('accounting-status-bank'),
            figureKey: const ValueKey('accounting-status-bank-figure'),
            label: l.accountingStatusBankToMatch,
            figure: figure(status.bankToMatch, format.number),
            onTap: open,
          ),
        if (shown.numbers)
          KpiTile(
            tapKey: const ValueKey('accounting-status-numbers'),
            figureKey: const ValueKey('accounting-status-numbers-figure'),
            label: l.numberSequenceNext,
            figure: figure(status.nextInvoiceNumber, (n) => n),
            onTap: () => context.push('/settings/number-sequences'),
          ),
      ],
    );
  }

  /// "FEC, 1/1/2026 – 3/31/2026": as the export log names it.
  static String _exportLine(
    AppLocalizations l,
    DateFormat dates,
    BookExport e,
  ) => l.bookPeriodsExportLine(
    e.formatId.toUpperCase(),
    dates.format(e.from),
    dates.format(e.to),
  );
}

/// The export history's address.
const String _accountingExportsPath = '/money/accounting/exports';

/// Opens the bank statements of [workspaceId] in their sheet.
VoidCallback bankStatementsDoor(
  BuildContext context, {
  required String workspaceId,
  required String currency,
  required bool canMatch,
  required bool canReconcile,
}) =>
    () => showBankStatementsSheet(
      context,
      workspaceId: workspaceId,
      currency: currency,
      canMatch: canMatch,
      canReconcile: canReconcile,
    );
