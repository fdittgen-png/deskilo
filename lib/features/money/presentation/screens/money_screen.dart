// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/file_saver.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/payment_instructions.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/bill_pdf.dart';
import '../../domain/bill_sections.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/payment_method.dart';
import '../../domain/statement.dart';
import '../../providers/money_providers.dart';
import '../payment_method_labels.dart';
import '../widgets/bill_view.dart';
import '../widgets/consumption_sheet.dart';

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
  /// First day of the visible month; the bill shows this period.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  String get _period => DateFormat('yyyy-MM').format(_month);

  bool get _isCurrentPeriod => _period == currentPeriod();

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  /// Renders the visible period's bill as a PDF — the exact sections
  /// [BillView] shows via [buildBillSections] — and hands it to the system
  /// share sheet (#133, ADR 0008).
  Future<void> _exportPdf(Statement statement) async {
    final context = this.context;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final workspace = ref.read(currentWorkspaceProvider).value;
    final member = ref.read(myMemberProvider).value;
    if (workspace == null || member == null) return;
    final ledger = ref.read(myLedgerProvider).value ?? const <LedgerEntry>[];
    final pendingEvents = ref.read(eventsProvider).value ?? const [];
    final memberName =
        ref.read(memberNamesProvider).value?[member.id] ?? '';
    final monthLabel = DateFormat.yMMMM(locale).format(_month);
    final save = ref.read(fileSaverProvider);

    final strings = BillPdfStrings(
      title: l10n?.billPdfTitle ?? 'Monthly bill',
      subscription: l10n?.billSubscription(statement.subscriptionPct) ??
          'Subscription ${statement.subscriptionPct}%',
      entitlement: l10n?.billEntitlement(
            statement.usedHalfDays,
            statement.includedHalfDays,
            statement.openDays,
          ) ??
          '${statement.usedHalfDays} of '
              '${statement.includedHalfDays} half-days used '
              '(${statement.openDays} open days)',
      overage: l10n?.billOverage(statement.extraHalfDays) ??
          '${statement.extraHalfDays} extra half-days',
      accessorySupplements:
          l10n?.billAccessorySupplements ?? 'Accessory supplements',
      services: l10n?.billServices ?? 'Consumed services',
      servicesTotal: l10n?.billServicesTotal ?? 'Services total',
      serviceFallback: l10n?.ledgerCategoryService ?? 'Service',
      openPositions: l10n?.billOpenPositions ?? 'Open positions',
      pendingBadge: l10n?.billPendingBadge ?? 'pending validation',
      paymentsCredits: l10n?.billPaymentsCredits ?? 'Payments & credits',
      paymentFallback: l10n?.ledgerCategoryPayment ?? 'Payment',
      expenseFallback:
          l10n?.ledgerCategoryExpense ?? 'Expense reimbursement',
      adjustmentFallback: l10n?.ledgerCategoryAdjustment ?? 'Adjustment',
      eventPayment: l10n?.eventTypePayment ?? 'Payment',
      eventExpense: l10n?.eventTypeExpense ?? 'Expense',
      eventAdjustment: l10n?.eventTypeAdjustment ?? 'Adjustment',
      balance: l10n?.billBalance ?? 'Balance',
      settled: l10n?.billSettled ?? 'Settled',
      outstanding: l10n?.billOutstanding ?? 'Outstanding',
    );

    try {
      final sections = buildBillSections(
        period: statement.period,
        memberId: member.id,
        ledger: ledger,
        pendingEvents: pendingEvents,
      );
      // Embedded Roboto: base-14 PDF fonts cannot encode '€'/'−' (#133).
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final bytes = await buildBillPdf(
        statement: statement,
        sections: sections,
        currencyCode: workspace.currencyCode,
        workspaceName: workspace.name,
        memberName: memberName,
        periodLabel: monthLabel,
        strings: strings,
        baseFont: pw.Font.ttf(regular),
        boldFont: pw.Font.ttf(bold),
        locale: locale,
      );
      final path = await save(
        bytes: bytes,
        fileName: 'deskilo-bill-${statement.period}.pdf',
      );
      if (!context.mounted) return;
      if (path == null) {
        AppSnack.error(context, l10n?.commonSaveFailed ?? 'Could not save.');
      } else {
        AppSnack.success(
          context,
          l10n?.commonSavedTo(path) ?? 'Saved to $path',
        );
      }
    } catch (e, st) {
      debugPrint('bill PDF export failed: $e\n$st');
      TraceLogger.instance
          .error('money', 'bill PDF export failed', error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> _recordPaymentSheet(NumberFormat currency) async {
    final context = this.context;
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final member = ref.read(myMemberProvider).value;
    if (workspace == null || member == null) return;

    final amount = TextEditingController();
    final note = TextEditingController();
    // #154 — how the money moved. Survives sheet rebuilds via the
    // StatefulBuilder below; null = not specified (kept valid so old
    // habits keep working).
    PaymentMethod? method;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.moneyRecordPayment ?? 'Record a payment',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                decoration: InputDecoration(
                  labelText: l10n?.moneyAmountLabel ?? 'Amount',
                  suffixText: currency.currencyName,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              // #154 — payment method chips (spec §7: amount + date +
              // method + note). Tapping the selected chip deselects it.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // displayOrder, not values: the enum is append-only
                  // (#192 added methods after `other`), but the catch-all
                  // chip must stay last.
                  for (final candidate in PaymentMethod.displayOrder)
                    ChoiceChip(
                      label: Text(paymentMethodLabel(l10n, candidate)),
                      selected: method == candidate,
                      onSelected: (selected) => setSheetState(
                        () => method = selected ? candidate : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: InputDecoration(
                  labelText: l10n?.moneyNoteLabel ?? 'Note (optional)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  l10n?.moneySubmitPayment ?? 'Submit for confirmation',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (submitted != true) return;

    final parsed =
        double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    try {
      await ref.read(moneyRepositoryProvider).recordPayment(
            workspaceId: workspace.id,
            memberId: member.id,
            amountCents: (parsed * 100).round(),
            note: note.text.trim(),
            method: method,
          );
    } catch (e, st) {
      debugPrint('record payment failed: $e\n$st');
      TraceLogger.instance
          .error('money', 'record payment failed', error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    if (!context.mounted) return;
    AppSnack.success(
      context,
      l10n?.moneyPaymentPending ??
          'Payment submitted — waiting for confirmation.',
    );
    ref.invalidate(eventsProvider);
  }

  Future<void> _submitExpenseSheet(NumberFormat currency) async {
    final context = this.context;
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;

    const categories = ['coffee', 'supplies', 'equipment', 'other'];
    String categoryLabel(String key) => switch (key) {
          'coffee' => l10n?.expenseCategoryCoffee ?? 'Coffee & kitchen',
          'supplies' => l10n?.expenseCategorySupplies ?? 'Supplies',
          'equipment' => l10n?.expenseCategoryEquipment ?? 'Equipment',
          _ => l10n?.expenseCategoryOther ?? 'Other',
        };

    final amount = TextEditingController();
    final description = TextEditingController();
    var category = categories.first;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.moneySubmitExpense ?? 'Submit an expense',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                decoration: InputDecoration(
                  labelText: l10n?.moneyAmountLabel ?? 'Amount',
                  suffixText: currency.currencyName,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: l10n?.moneyExpenseCategoryLabel ?? 'Category',
                ),
                items: [
                  for (final key in categories)
                    DropdownMenuItem(
                      value: key,
                      child: Text(categoryLabel(key)),
                    ),
                ],
                onChanged: (v) =>
                    setSheetState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                decoration: InputDecoration(
                  labelText: l10n?.moneyDescriptionLabel ?? 'Description',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  l10n?.moneySubmitPayment ?? 'Submit for confirmation',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (submitted != true) return;

    final parsed =
        double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;
    try {
      await ref.read(moneyRepositoryProvider).submitExpense(
            workspaceId: workspace.id,
            amountCents: (parsed * 100).round(),
            category: category,
            description: description.text.trim(),
          );
    } catch (e, st) {
      debugPrint('submit expense failed: $e\n$st');
      TraceLogger.instance
          .error('money', 'submit expense failed', error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    if (!context.mounted) return;
    AppSnack.success(
      context,
      l10n?.moneyExpensePending ??
          'Expense submitted — waiting for approval.',
    );
    ref.invalidate(eventsProvider);
  }

  /// Request extra half-days beyond the subscription entitlement (0031):
  /// lands as a pending 'quota' event that owners/admins validate per the
  /// owner's policy; once confirmed the booking cap rises for [_period].
  Future<void> _requestQuotaSheet() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final count = TextEditingController();
    final period = _period;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.quotaRequestTitle ?? 'Request extra half-days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.quotaRequestExplainer(period) ??
                  'Your reservations are capped by your subscription. '
                      'Extra half-days for $period apply once validated.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('quota-request-count'),
              controller: count,
              decoration: InputDecoration(
                labelText:
                    l10n?.quotaRequestCountLabel ?? 'Number of half-days',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n?.moneySubmitPayment ?? 'Submit for confirmation',
              ),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;

    final halfDays = int.tryParse(count.text.trim());
    if (halfDays == null || halfDays < 1) return;
    try {
      await ref.read(eventRepositoryProvider).requestQuotaExtension(
            workspace.id,
            period: period,
            halfDays: halfDays,
          );
    } catch (e, st) {
      debugPrint('quota request failed: $e\n$st');
      TraceLogger.instance
          .error('money', 'quota request failed', error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n?.quotaRequestPending ?? 'Request sent — waiting for validation.',
    );
    ref.invalidate(eventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final member = ref.watch(myMemberProvider).value;
    final statementAsync = ref.watch(myStatementProvider(_period));
    final ledger = ref.watch(myLedgerProvider).value ?? const <LedgerEntry>[];
    final pendingEvents = ref.watch(eventsProvider).value ?? const [];
    final currencyCode = workspace?.currencyCode ?? 'EUR';
    final currency = NumberFormat.simpleCurrency(name: currencyCode);
    final monthLabel = DateFormat.yMMMM(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(_month);

    final features = ref.watch(enabledFeaturesSyncProvider);
    final visibleStatement = statementAsync.value;
    final periodHeader = Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _shiftMonth(-1),
        ),
        Expanded(
          child: Text(
            monthLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _isCurrentPeriod ? null : () => _shiftMonth(1),
        ),
        if (features.contains(WorkspaceFeature.pdfExport))
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n?.billPdfExport ?? 'Export bill as PDF',
            onPressed: visibleStatement == null
                ? null
                : () => _exportPdf(visibleStatement),
          ),
      ],
    );

    return switch (statementAsync) {
      AsyncData(value: final statement) => ListView(
          padding: AppSpacing.mdAll,
          children: [
            periodHeader,
            if (statement != null)
              BillView(
                statement: statement,
                ledger: ledger,
                pendingMoneyEvents: pendingEvents,
                currencyCode: currencyCode,
                memberId: member?.id ?? '',
                // #155 — how-to-pay card on an outstanding balance.
                paymentInstructions: PaymentInstructions.fromDb(
                  workspace?.paymentInstructions ?? const {},
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _recordPaymentSheet(currency),
              icon: const Icon(Icons.payments_outlined),
              label: Text(l10n?.moneyRecordPayment ?? 'Record a payment'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _submitExpenseSheet(currency),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l10n?.moneySubmitExpense ?? 'Submit an expense'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('quota-request-button'),
              onPressed: _requestQuotaSheet,
              icon: const Icon(Icons.hourglass_top_outlined),
              label: Text(
                l10n?.quotaRequestButton ?? 'Request extra half-days',
              ),
            ),
            // Consumption entry points follow the services feature (#146).
            if (features.contains(WorkspaceFeature.services)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final me = ref.read(myMemberProvider).value;
                  if (me == null) return;
                  showConsumptionSheet(
                    context,
                    ref,
                    subjectMemberId: me.id,
                  );
                },
                icon: const Icon(Icons.room_service_outlined),
                label: Text(l10n?.consumptionAdd ?? 'Add consumption'),
              ),
            ],
          ],
        ),
      AsyncError() => Center(
          child: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      _ => const LoadingView(),
    };
  }
}
