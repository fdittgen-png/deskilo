// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice.dart';
import '../../domain/invoice_ubl.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../accounting_export.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import '../widgets/invoice_detail_sheet.dart';

/// The REGISTER: every invoice on one line — date, name, amount, status —
/// sorted by date, newest or oldest first.
///
/// The archive is a browsing surface (cards, filters, per-row actions);
/// this is the ledger view an accountant or a member scanning "what have I
/// been invoiced, what is settled" actually wants. The **name** column
/// follows the reader: an issuer scans MEMBERS, a member scans their own
/// invoice numbers — showing someone their own name in every row tells
/// them nothing.
///
/// A member sees only what concerns them: issued and not tagged erroneous
/// (RLS already scopes the rows to their own).
class InvoiceRegisterScreen extends ConsumerStatefulWidget {
  const InvoiceRegisterScreen({super.key});

  @override
  ConsumerState<InvoiceRegisterScreen> createState() =>
      _InvoiceRegisterScreenState();
}

class _InvoiceRegisterScreenState
    extends ConsumerState<InvoiceRegisterScreen> {
  bool _newestFirst = true;

  /// null = every year. An accountant works a fiscal year at a time, and
  /// the SAF-T export takes exactly what the register shows.
  int? _year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invoicesAsync = ref.watch(invoicesProvider);
    final matches = ref.watch(invoiceMatchesProvider).value ?? const {};
    final reminders = ref.watch(invoiceRemindersProvider).value ?? const {};
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final me = ref.watch(myMemberProvider).value;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final canIssue = me != null &&
        (me.actsAsOwner ||
            (me.canAdminister &&
                features.contains(WorkspaceFeature.adminInvoicing)));
    final showMemberNames = me?.canAdminister ?? false;
    final currency = NumberFormat.simpleCurrency(
      name: workspace?.currencyCode ?? 'EUR',
    );
    final dateFormat = DateFormat.yMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.invoiceRegisterTitle ?? 'Invoice register'),
        actions: [
          if (canIssue)
            IconButton(
              key: const ValueKey('invoice-accounting-export'),
              // Named for the ACTION, not for one of the seven formats
              // behind it (#669). It said "(SAF-T)" until an owner
              // hunting for the accounting export walked past it.
              tooltip: l10n?.invoiceAccountingExport ?? 'Accounting export',
              icon: const Icon(Icons.plagiarism_outlined),
              onPressed: () => exportAccountingFile(
                context,
                ref,
                _visible(invoicesAsync.value ?? const [], canIssue),
                label: _year?.toString() ??
                    (l10n?.invoiceRegisterAllYears ?? 'all'),
              ),
            ),
        ],
      ),
      body: switch (invoicesAsync) {
        AsyncData(value: final invoices) => _table(
            context,
            l10n,
            invoices: _visible(invoices, canIssue),
            years: {for (final i in invoices) i.issuedAt.year}.toList()
              ..sort((a, b) => b.compareTo(a)),
            matches: matches,
            reminders: reminders,
            currency: currency,
            dateFormat: dateFormat,
            showMemberNames: showMemberNames,
            canIssue: canIssue,
          ),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }

  /// What this reader may see, narrowed to the picked year. Erroneous
  /// documents stay with the people who correct them; a member's register
  /// only carries what they owe or have paid.
  List<Invoice> _visible(List<Invoice> invoices, bool canIssue) => [
        for (final invoice in invoices)
          if ((canIssue || !invoice.isVoided) &&
              (_year == null || invoice.issuedAt.year == _year))
            invoice,
      ];

  Widget _table(
    BuildContext context,
    AppLocalizations? l10n, {
    required List<Invoice> invoices,
    required List<int> years,
    required Map<String, InvoiceMatch> matches,
    required Map<String, ({int count, DateTime last})> reminders,
    required NumberFormat currency,
    required DateFormat dateFormat,
    required bool showMemberNames,
    required bool canIssue,
  }) {
    if (invoices.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n?.invoicesEmpty ?? 'No invoices yet.',
      );
    }
    final rows = [...invoices]..sort(
        (a, b) => _newestFirst
            ? b.issuedAt.compareTo(a.issuedAt)
            : a.issuedAt.compareTo(b.issuedAt),
      );
    final total = rows.fold(0, (sum, invoice) => sum + invoice.totalCents);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(children: [
      if (years.length > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: DropdownButtonFormField<int?>(
            key: const ValueKey('invoice-register-year'),
            initialValue: _year,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(l10n?.invoiceRegisterAllYears ?? 'All years'),
              ),
              for (final year in years)
                // A year is a number, not copy — but the lint reads the
                // literal, so the digits go through a variable.
                DropdownMenuItem(value: year, child: Text(year.toString())),
            ],
            onChanged: (value) => setState(() => _year = value),
            decoration: InputDecoration(
              labelText: l10n?.invoiceRegisterYear ?? 'Year',
            ),
          ),
        ),
      // Header — the date column is the sort control, both directions.
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(children: [
          SizedBox(
            width: 96,
            child: InkWell(
              key: const ValueKey('invoice-register-sort-date'),
              onTap: () => setState(() => _newestFirst = !_newestFirst),
              child: Row(children: [
                Text(
                  l10n?.invoiceRegisterDate ?? 'Date',
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
                Icon(
                  _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 14,
                  color: muted,
                ),
              ]),
            ),
          ),
          Expanded(
            child: Text(
              l10n?.invoiceRegisterName ?? 'Name',
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
          ),
          SizedBox(
            width: 86,
            child: Text(
              l10n?.invoiceRegisterAmount ?? 'Amount',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (context, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final invoice = rows[index];
            final status = invoiceLifecycleOf(invoice, matches[invoice.id]);
            return InkWell(
              key: ValueKey('invoice-register-${invoice.id}'),
              onTap: () => _open(
                invoice,
                match: matches[invoice.id],
                reminder: reminders[invoice.id],
                canIssue: canIssue,
                showMemberName: showMemberNames,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      dateFormat.format(invoice.issuedAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  // The name that means something to THIS reader.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showMemberNames
                              ? invoice.memberName
                              : invoice.number,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          invoicePeriodLabel(context, invoice),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currency.format(invoice.totalCents / 100),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      InvoiceStatusChip(status: status),
                    ],
                  ),
                ]),
              ),
            );
          },
        ),
      ),
      const Divider(height: 1),
      // What the register adds up to — the reason to look at a register.
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              l10n?.invoiceRegisterTotal ?? 'Total',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Text(
            currency.format(total / 100),
            key: const ValueKey('invoice-register-total'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _open(
    Invoice invoice, {
    required InvoiceMatch? match,
    required ({int count, DateTime last})? reminder,
    required bool canIssue,
    required bool showMemberName,
  }) async {
    final countryCode =
        ref.read(currentWorkspaceProvider).value?.countryCode ?? '';
    final action = await showInvoiceDetailSheet(
      context,
      invoice: invoice,
      match: match,
      canIssue: canIssue,
      isEu: isEuCountry(countryCode),
      reminder: reminder,
      showMemberName: showMemberName,
      transmission: ref.read(invoiceTransmissionsProvider).value?[invoice.id],
    );
    if (action == null || !mounted) return;
    await runInvoiceAction(
      context,
      ref,
      action,
      invoice,
      countryCode: countryCode,
    );
  }
}
