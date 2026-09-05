// SPDX-License-Identifier: 0BSD
import '../invoice_line_text.dart';
import 'package:flutter/material.dart';
import '../../../../core/i18n/money_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/help/help_hint.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/format/cents.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/overage_policy.dart';
import '../../../workspace/domain/payment_instructions.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/bill_pdf.dart';
import '../../domain/invoice_pdf.dart';
import '../../domain/invoice_report.dart';
import '../invoice_actions.dart';
import '../report_layout_actions.dart';
import '../report_actions.dart';
import '../invoice_status.dart';
import '../report_defaults.dart';
import '../../domain/bill_sections.dart';
import '../../domain/money_face.dart';
import '../../domain/expense_schedule.dart';
import '../../domain/ledger_entry.dart';
import '../../domain/package.dart';
import '../../domain/payment_method.dart';
import '../../domain/payment_provider.dart';
import '../../domain/statement.dart';
import '../../providers/money_focus_controller.dart';
import '../../providers/billing_invoice_sweep.dart';
import '../../providers/payment_reminder_sweep.dart';
import '../../providers/money_providers.dart';
import '../../providers/expense_schedule_providers.dart';
import '../payment_method_labels.dart';
import '../widgets/payment_terms_card.dart';
import '../widgets/account_card.dart';
import '../widgets/bill_view.dart';
import '../widgets/usage_face.dart';
import '../widgets/documents_face.dart';
import '../widgets/expense_schedule_sheet.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/invoice_overview.dart';
import '../widgets/money_faces_view.dart';
import '../widgets/my_invoices_list.dart';
import '../widgets/negotiation_card.dart';
import '../widgets/consumption_sheet.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../../core/locale/report_language.dart';

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
    // #718 — a focus request made BEFORE this branch was built (the
    // calendar hub sets it, then switches) is already there when the
    // listener in build subscribes, and a listener only sees changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyFocus(ref.read(moneyFocusControllerProvider));
    });
    // #726 — an admin opening Finances is one of the two clocks that
    // apply the dunning rules (the other is the morning cron).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ws = ref.read(currentWorkspaceProvider).value;
      if (ws != null) {
        ref.read(paymentReminderSweepProvider(ws.id));
        // #816 — the billing cycle (#802) gets the same client clock.
        ref.read(billingInvoiceSweepProvider(ws.id));
      }
    });
    final now = ref.read(clockProvider).now();
    _month = DateTime(now.year, now.month);
  }

  String get _period => DateFormat('yyyy-MM').format(_month);

  /// The running month's period key — the ONE clock read both uses share.
  String get _nowPeriod => currentPeriod(ref.read(clockProvider).now());

  bool get _isCurrentPeriod => _period == _nowPeriod;

  void _applyFocus(String? period) {
    if (period == null) return;
    final parts = period.split('-');
    if (parts.length == 2) {
      setState(() => _month = DateTime(int.parse(parts[0]), int.parse(parts[1])));
    }
    ref.read(moneyFocusControllerProvider.notifier).clear();
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  /// Renders the visible period's bill as a PDF — the exact sections
  /// [BillView] shows via [buildBillSections] — and hands it to the system
  /// share sheet (#133, ADR 0008).
  /// #494 — one of the member's self-service letter documents: quick
  /// in-app view, download, or share.
  Future<void> _memberDoc(String docId) async {
    final l10n = AppLocalizations.of(context);
    await warmLetterDocProviders(ref, docId);
    if (!mounted) return;
    final me = ref.read(myMemberProvider).value;
    final names = ref.read(memberNamesProvider).value ?? const {};
    if (me == null) return;
    // #496 — MY documents print in MY language chain.
    final String language;
    try {
      language = resolveMemberReportLanguage(ref,
          memberLocale:
              ref.read(myProfileProvider).value?.preferredLocale ?? '');
    } on AmbiguousReportLanguage {
      AppSnack.error(
        context,
        l10n?.reportLanguageAmbiguous ??
            'This country has several languages — set the workspace '
                'language in Workspace settings first.',
      );
      return;
    }
    final docL10n = l10nForLanguage(language);
    final data = docId == 'agreement'
        ? agreementReportData(context, ref,
            memberName: names[me.id] ?? '',
            subscriptionPct: me.subscriptionPct,
            l10nOverride: docL10n,
            localeName: language)
        : paymentsReportData(context, ref,
            period: _period,
            memberName: names[me.id] ?? '',
            l10nOverride: docL10n,
            localeName: language);
    final report = renderLetterDoc(context, ref,
        docId: docId, data: data, language: language);
    final title = docId == 'agreement'
        ? docL10n.reportDocAgreement
        : docL10n.reportDocPayments;
    // #514 — the shared triad: quick view / save / share.
    await runReportActions(
      context,
      ref,
      keyPrefix: 'member-doc',
      logMessage: 'member report pdf failed',
      render: () => report,
      buildPdf: () async {
        final pdf = await letterDocPdf(context, ref,
            report: report,
            title: title,
            layoutXml:
                letterLayoutXml(ref, docId: docId, language: language),
            data: data);
        return (bytes: pdf.bytes, fileName: pdf.fileName);
      },
    );
  }

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

    final strings = BillPdfStrings(
      title: l10n?.billPdfTitle ?? 'Monthly bill',
      subscription: subscriptionLabel(l10n, statement.subscriptionPct,
          association: ref.watch(sellerIsAssociationProvider)),
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
      packages: l10n?.billPackages ?? 'Day packages',
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

    // #514 — the shared triad, for the bill too: the statement report
    // (owner template or default bands) is the quick view; download and
    // share build the same PDF the save-only path used to.
    InvoiceReport? renderStatement() {
      final data = statementReportData(
        context,
        statement: statement,
        workspaceName: workspace.name,
        memberName: memberName,
        periodLabel: monthLabel,
        currencyCode: workspace.currencyCode,
        workspace: workspace,
      );
      final statementTemplate = ref
              .read(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.invoicePdfTemplate)
          ? ref.read(invoicePdfTemplateProvider).value
          : null;
      final statementBands = statementTemplate?.statementBands;
      // #880 — the owner's texts beside the data.
      final statementTexts = statementTemplate?.texts ?? const <String, String>{};
      return (statementBands != null
              ? renderReportBands(bands: statementBands, data: withOwnerTexts(data, statementTexts))
              : null) ??
          renderReportBands(bands: defaultStatementBands(l10n), data: withOwnerTexts(data, statementTexts));
    }

    await runReportActions(
      context,
      ref,
      keyPrefix: 'bill-export',
      logMessage: 'bill PDF export failed',
      render: renderStatement,
      buildPdf: () async {
        final sections = buildBillSections(
          period: statement.period,
          memberId: member.id,
          ledger: ledger,
          pendingEvents: pendingEvents,
          // Same nowPeriod as the on-screen BillView — this path used to
          // fall back to the wall clock and section the PDF differently.
          nowPeriod: _nowPeriod,
        );
        // Embedded Roboto: base-14 PDF fonts cannot encode '€'/'−' (#133).
        final regular =
            await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        // #476: an owner-customized statement TEMPLATE replaces the
        // built-in bill layout; empty bands keep it exactly as before.
        final statementTemplate = ref
                .read(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.invoicePdfTemplate)
            ? ref.read(invoicePdfTemplateProvider).value
            : null;
        final statementBands = statementTemplate?.statementBands;
        // #880 — the owner's texts beside the data.
        final statementTexts = statementTemplate?.texts ?? const <String, String>{};
        final Uint8List bytes;
        if (statementBands != null && context.mounted) {
          final data = statementReportData(
            context,
            statement: statement,
            workspaceName: workspace.name,
            memberName: memberName,
            periodLabel: monthLabel,
            currencyCode: workspace.currencyCode,
            workspace: workspace,
          );
          final report =
              renderReportBands(bands: statementBands, data: withOwnerTexts(data, statementTexts)) ??
                  renderReportBands(bands: defaultStatementBands(l10n), data: withOwnerTexts(data, statementTexts))!;
          bytes = await buildBandedLetterPdf(
            report: report,
            reportImages: await resolveReportImages(ref, report),
            pageLabel: l10n?.invoicePdfPage ?? 'Page',
            documentTitle: strings.title,
            baseFont: pw.Font.ttf(regular),
            boldFont: pw.Font.ttf(bold),
          );
        } else {
          bytes = await buildBillPdf(
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
        }
        return (
          bytes: bytes,
          fileName: 'deskilo-bill-${statement.period}.pdf',
        );
      },
    );
  }

  Future<void> _recordPaymentSheet(MoneyFormat currency) async {
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
    // 0070 — WHEN the money moved (defaults to today) and WHICH month it
    // settles (defaults to the running one). Both were assumed until now:
    // the ledger dated every payment the day it was typed in and booked it
    // to the current month, so a transfer entered late landed on the wrong
    // bill — and on the wrong invoice.
    final today = ref.read(clockProvider).now();
    var paidOn = DateTime(today.year, today.month, today.day);
    var period = currentPeriod(today);
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final dayFormat = DateFormat.yMMMd(locale);
    final monthFormat = DateFormat.yMMMM(locale);
    DateTime monthOf(String p) => DateTime(
          int.parse(p.split('-')[0]),
          int.parse(p.split('-')[1]),
        );
    // A month back is history (settling arrears); a month forward is a
    // prepayment. Further forward is a typo, not an intent.
    final periodCeiling = DateTime(today.year, today.month + 1);
    void shiftPeriod(void Function(void Function()) setSheetState, int delta) {
      final next = DateTime(monthOf(period).year, monthOf(period).month + delta);
      if (next.isAfter(periodCeiling)) return;
      setSheetState(() => period =
          '${next.year}-${next.month.toString().padLeft(2, '0')}');
    }
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SheetShell(
          title: l10n?.moneyRecordPayment ?? 'Record a payment',
          children: [
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
              const SizedBox(height: 4),
              // WHEN the money moved.
              ListTile(
                key: const ValueKey('payment-date-tile'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(l10n?.moneyPaymentDateLabel ?? 'Payment date'),
                subtitle: Text(dayFormat.format(paidOn)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: paidOn,
                    firstDate: DateTime(today.year - 2),
                    lastDate: DateTime(today.year, today.month, today.day),
                    helpText: l10n?.moneyPaymentDateLabel ?? 'Payment date',
                  );
                  if (picked != null) setSheetState(() => paidOn = picked);
                },
              ),
              // WHICH month it settles — the bill and the invoice this
              // credit lands on.
              ListTile(
                key: const ValueKey('payment-period-tile'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(l10n?.moneyPaymentPeriodLabel ?? 'Applies to'),
                subtitle: Text(
                  monthFormat.format(monthOf(period)),
                  key: const ValueKey('payment-period-label'),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    key: const ValueKey('payment-period-prev'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => shiftPeriod(setSheetState, -1),
                  ),
                  IconButton(
                    key: const ValueKey('payment-period-next'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: monthOf(period).isAfter(
                            DateTime(today.year, today.month))
                        ? null
                        : () => shiftPeriod(setSheetState, 1),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
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
    );
    if (submitted != true || !context.mounted) return;

    final cents = parseCentsInput(amount.text);
    if (cents == null || cents <= 0) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'record payment failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(moneyRepositoryProvider).recordPayment(
            workspaceId: workspace.id,
            memberId: member.id,
            amountCents: cents,
            note: note.text.trim(),
            method: method,
            paidOn: paidOn,
            period: period,
          ),
    )) {
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

  Future<void> _submitExpenseSheet(MoneyFormat currency) =>
      showExpenseSheet(context, ref, currency);

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
      builder: (context) => SheetShell(
        title: l10n?.quotaRequestTitle ?? 'Request extra half-days',
        children: [
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
    );
    if (submitted != true || !mounted) return;

    final halfDays = int.tryParse(count.text.trim());
    if (halfDays == null || halfDays < 1) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'quota request failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(eventRepositoryProvider).requestQuotaExtension(
            workspace.id,
            period: period,
            halfDays: halfDays,
          ),
    )) {
      return;
    }
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n?.quotaRequestPending ?? 'Request sent — waiting for validation.',
    );
    ref.invalidate(eventsProvider);
  }

  /// Self-serve package purchase (0042): pick an owner-defined package; the
  /// cap rises immediately and the price posts to this month's bill.
  Future<void> _buyPackageSheet(MoneyFormat currency) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final packages = await ref.read(packagesProvider.future);
    // #744 — my negotiated package prices, when I have a deal.
    final myId = ref.read(myMemberProvider).value?.id;
    final myDeal = myId != null &&
            ref
                .read(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.priceNegotiations)
        ? ref.read(priceNegotiationProvider(myId)).value?.active
        : null;
    if (!mounted) return;
    if (packages.isEmpty) {
      AppSnack.info(
        context,
        l10n?.buyPackageNone ?? 'No packages are available yet.',
      );
      return;
    }
    final chosen = await showModalBottomSheet<Package>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SheetShell(
        title: l10n?.buyPackageTitle ?? 'Buy a package',
        children: [
            const SizedBox(height: 8),
            for (final package in packages)
              Card(
                child: ListTile(
                  title: Text(package.name),
                  subtitle: Text(
                    l10n?.buyPackageDays(package.days) ??
                        '${package.days} days',
                  ),
                  trailing: Text(currency.formatMinor(
                      myDeal?.itemPrice('packages', package.id) ??
                          package.priceCents)),
                  onTap: () => Navigator.of(context).pop(package),
                ),
              ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'buy package failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(moneyRepositoryProvider).buyPackage(
            workspace.id,
            chosen.id,
          ),
    )) {
      return;
    }
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n?.buyPackageDone ?? 'Days added — enjoy the extra time.',
    );
    // The bill (new charge + higher cap) and every booking surface (the
    // guard now allows more) must refresh.
    ref.invalidate(myStatementProvider);
    ref.invalidate(myLedgerProvider);
    invalidateBookingData(ref);
  }

  /// Starts an online payment for [amountCents] (0043 scaffolding). Opens
  /// the payment provider's approval URL when the deployment is configured;
  /// otherwise tells the member online payments are not set up. Inert until
  /// the server carries the PSP secrets (docs/design/payments-integration.md).
  /// Localized label of an online-payment [provider] button.
  String _providerLabel(AppLocalizations? l10n, PaymentProvider provider) =>
      switch (provider) {
        PaymentProvider.paypal => l10n?.paymentMethodPaypal ?? 'PayPal',
        PaymentProvider.stripe =>
          l10n?.paymentProviderStripe ?? 'Credit card (Stripe)',
        PaymentProvider.mollie =>
          l10n?.paymentProviderMollie ?? 'Mollie — iDEAL, Bancontact…',
        PaymentProvider.wero =>
          l10n?.paymentProviderWero ?? 'Wero (via Mollie)',
      };

  /// Owner/admin diagnostics when online payments cannot run: names the
  /// undeployed function or the exact missing server secrets, so "not set
  /// up" is actionable instead of a mystery. Members get the friendly
  /// snack instead.
  Future<void> _paymentDiagnostics(
    AppLocalizations? l10n,
    PaymentGatewayConfig config,
  ) async {
    final canAdminister =
        ref.read(myMemberProvider).value?.canAdminister ?? false;
    if (!canAdminister) {
      AppSnack.info(
        context,
        l10n?.payOnlineNotConfigured ??
            "Online payments aren't set up yet. Ask the workspace owner.",
      );
      return;
    }
    final lines = [
      for (final entry in config.missing.entries)
        if (entry.value.isNotEmpty)
          '${entry.key}: ${entry.value.join(', ')}',
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n?.payOnlineDiagTitle ?? 'Online payments — not configured',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.payOnlineDiagHint ??
                  'The server is missing this configuration '
                      '(docs/design/payments-integration.md):',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.commonClose ?? 'Close'),
          ),
          FilledButton(
            key: const ValueKey('pay-config-open'),
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/payment-config');
            },
            child: Text(l10n?.payConfigOpen ?? 'Configure'),
          ),
        ],
      ),
    );
  }

  Future<void> _payOnline(int amountCents) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final member = ref.read(myMemberProvider).value;
    if (workspace == null || member == null || amountCents <= 0) return;
    final trace = TraceLogger.instance;

    // 1. What can this deployment charge with?
    PaymentGatewayConfig? config;
    if (!await runGuarded(
      context,
      domain: 'payments',
      message: 'payment config probe failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        config = await ref
            .read(moneyRepositoryProvider)
            .fetchPaymentConfig(workspace.id);
      },
    )) {
      return;
    }
    final gateway = config;
    if (gateway == null || !mounted) return;
    trace.log(
      TraceLevel.info,
      'payments',
      'config: providers=${gateway.providers.map((p) => p.wireName).toList()} '
          'missing=${gateway.missing}',
    );
    if (gateway.providers.isEmpty) {
      await _paymentDiagnostics(l10n, gateway);
      return;
    }

    // 2. Pick the provider (directly when only one is configured).
    PaymentProvider? provider = gateway.providers.singleOrNull;
    provider ??= await showModalBottomSheet<PaymentProvider>(
      context: context,
      builder: (context) => SheetShell(
        title: l10n?.payOnlineChooseTitle ?? 'Pay online',
        children: [
          const SizedBox(height: 12),
          for (final candidate in gateway.providers) ...[
            FilledButton.tonalIcon(
              key: ValueKey('pay-provider-${candidate.wireName}'),
              onPressed: () => Navigator.of(context).pop(candidate),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: Text(_providerLabel(l10n, candidate)),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
    if (provider == null || !mounted) return;
    final chosen = provider;

    // 3. Start the order; every step lands in the payments trace.
    trace.log(
      TraceLevel.info,
      'payments',
      'order start: provider=${chosen.wireName} amountCents=$amountCents '
          'period=$_period',
    );
    PaymentOrderStart? start;
    if (!await runGuarded(
      context,
      domain: 'payments',
      message: 'create payment order failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        start = await ref.read(moneyRepositoryProvider).createPaymentOrder(
              provider: chosen,
              workspaceId: workspace.id,
              memberId: member.id,
              amountCents: amountCents,
              currencyCode:
                  ref.read(currentWorkspaceProvider).value?.currencyCode ??
                      'EUR',
              period: _period,
            );
      },
    )) {
      return;
    }
    final order = start;
    if (order == null || !mounted) return;
    if (!order.started) {
      trace.warn(
        'payments',
        'provider ${chosen.wireName} not configured: ${order.missing}',
      );
      await _paymentDiagnostics(
        l10n,
        PaymentGatewayConfig(
          providers: const [],
          missing: {chosen.wireName: order.missing},
        ),
      );
      return;
    }
    trace.log(
      TraceLevel.info,
      'payments',
      'order created: provider=${chosen.wireName} orderId=${order.orderId}',
    );
    // Launch failures are traced inside the shared link seam.
    await ref.read(linkLauncherProvider)(order.approveUrl!);
  }

  @override
  Widget build(BuildContext context) {
    // #718 — the calendar hub asks for a month; consume it once.
    ref.listen(moneyFocusControllerProvider, (_, period) => _applyFocus(period));
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final member = ref.watch(myMemberProvider).value;
    final statementAsync = ref.watch(myStatementProvider(_period));
    // #510 — once an invoice covers the browsed month, the DOCUMENT
    // decides settled/outstanding (its payment usually lands in a later
    // month). RLS scopes both providers to the member's own rows.
    final settlement = settlementOfPeriod(
      _period,
      member?.id ?? '',
      ref.watch(invoicesProvider).value ?? const [],
      ref.watch(invoiceMatchesProvider).value ?? const {},
    );
    final ledger = ref.watch(myLedgerProvider).value ?? const <LedgerEntry>[];
    final pendingEvents = ref.watch(eventsProvider).value ?? const [];
    final currencyCode = workspace?.currencyCode ?? 'EUR';
    final currency = moneyFormat(currencyCode);
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

    // Landscape split (#282 idiom, field request): the period header and
    // the money actions move into a side panel so the bill fills the
    // rest of the screen — same layout family as Plan/Reserve/Calendar.
    // #512 — the REAL cross-month position, above the per-month bill.
    final account = ref.watch(myAccountProvider).value;
    // #720 — one bill builder: the whole bill (face null) for the
    // classic column and the PDF, one face at a time for the faces.
    Widget bill(MoneyFace? face) => BillView(
          statement: visibleStatement!,
          ledger: ledger,
          pendingMoneyEvents: pendingEvents,
          currencyCode: currencyCode,
          memberId: member?.id ?? '',
          nowPeriod: _nowPeriod,
          // #155 — how-to-pay card on an outstanding balance.
          paymentInstructions: PaymentInstructions.fromDb(
            workspace?.paymentInstructions ?? const {},
          ),
          // 0043 — online-payment button, gated by the feature flag.
          onlinePaymentsEnabled:
              features.contains(WorkspaceFeature.onlinePayments),
          onPayOnline: _payOnline,
          settlement: settlement,
          face: face,
        );
    final billChildren = <Widget>[
      if (account != null && account.isNotable) ...[
        AccountCard(account: account, currencyCode: currencyCode),
        const SizedBox(height: 8),
      ],
      if (visibleStatement != null) bill(null),
    ];
    // #486 UX — actions grouped by MEANING: what pays, what asks, what
    // documents. The arrangement itself explains payment vs invoicing.
    // #720 — the same partition IS the three faces; each button is built
    // once and placed by whichever layout is on.
    Widget sectionLabel(String text) => moneySectionLabel(context, text);
    Widget fitted(String text) => fittedLabel(text);
    final recordPayment = FilledButton.icon(
      onPressed: () => _recordPaymentSheet(currency),
      icon: const Icon(Icons.payments_outlined),
      label: Text(l10n?.moneyRecordPayment ?? 'Record a payment'),
    );
    // Buy-a-package entry point (0042): only for members the owner
    // put on the package plan — it PAYS, so it lives here.
    final buyPackage = member?.overagePolicy == OveragePolicy.package
        ? FilledButton.tonalIcon(
            key: const ValueKey('buy-package-button'),
            onPressed: () => _buyPackageSheet(currency),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(l10n?.buyPackageButton ?? 'Buy a package'),
          )
        : null;
    final submitExpense = OutlinedButton.icon(
      onPressed: () => _submitExpenseSheet(currency),
      icon: const Icon(Icons.receipt_long_outlined),
      label: fitted(l10n?.moneySubmitExpense ?? 'Submit an expense'),
    );
    final requestQuota = OutlinedButton.icon(
      key: const ValueKey('quota-request-button'),
      onPressed: _requestQuotaSheet,
      icon: const Icon(Icons.hourglass_top_outlined),
      label: fitted(l10n?.quotaRequestButton ?? 'Request extra half-days'),
    );
    // #767 — recurring expenses: the schedule list/create door, and the
    // occurrences presented for confirmation (cards below).
    final schedOn = features.contains(WorkspaceFeature.scheduledExpenses);
    final scheduledExpensesButton = schedOn
        ? OutlinedButton.icon(
            key: const ValueKey('scheduled-expenses-button'),
            onPressed: () => showExpenseSchedulesSheet(context, ref, currency),
            icon: const Icon(Icons.event_repeat_outlined),
            label: fitted(
                l10n?.scheduledExpensesTitle ?? 'Scheduled expenses'),
          )
        : null;
    // Consumption follows the services feature (#146).
    final addConsumption = features.contains(WorkspaceFeature.services)
        ? OutlinedButton.icon(
            onPressed: () {
              final me = ref.read(myMemberProvider).value;
              if (me == null) return;
              showConsumptionSheet(context, ref, subjectMemberId: me.id);
            },
            icon: const Icon(Icons.room_service_outlined),
            label: fitted(l10n?.consumptionAdd ?? 'Add consumption'),
          )
        : null;
    // #871 — the hand-off to invoice MANAGEMENT reads like every other
    // management access in the app (the Settings tiles): a row with the
    // management icon, a verb, and a chevron — never a button that
    // repeats the name of the tab the person is already on.
    final invoicesButton = features.contains(WorkspaceFeature.invoicing)
        ? ListTile(
            key: const ValueKey('invoices-button'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(l10n?.invoicesManage ?? 'Manage invoices'),
            subtitle:
                Text(l10n?.settingsBillingReports ?? 'Billing & reports'),
            // Not chevron_right: the period bar owns that icon on this screen.
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/invoices'),
          )
        : null;
    // #494 — member self-service reports: the standing financial
    // agreement and the month's payments, viewable/downloadable/
    // shareable without asking anyone. Gated by memberReports (#502).
    final reportsOn = features.contains(WorkspaceFeature.memberReports);
    Widget grid(List<Widget> buttons) => MoneyActionGrid(buttons);
    final requestButtons = [
      submitExpense,
      ?scheduledExpensesButton,
      requestQuota,
      ?addConsumption,
    ];
    // #767 — a due occurrence is PRESENTED, never silently booked: one
    // card per awaiting/rejected occurrence, on top of the Payments face.
    final workspaceForSweep = ref.watch(currentWorkspaceProvider).value;
    if (schedOn && workspaceForSweep != null) {
      ref.watch(expenseScheduleSweepProvider(workspaceForSweep.id));
    }
    final myOccurrences = schedOn && workspaceForSweep != null
        ? (ref.watch(expenseOccurrencesProvider(workspaceForSweep.id)).value ??
            const <ExpenseOccurrence>[])
        : const <ExpenseOccurrence>[];
    final awaitingOccurrences = [
      for (final o in myOccurrences)
        if (o.status == OccurrenceStatus.awaitingMember ||
            o.status == OccurrenceStatus.rejected)
          o,
    ];
    final occurrenceCards = awaitingOccurrences.isEmpty
        ? const <Widget>[]
        : <Widget>[
            sectionLabel(l10n?.scheduledAwaitingTitle ??
                'Scheduled expenses awaiting you'),
            for (final o in awaitingOccurrences)
              ExpenseOccurrenceCard(o, currency),
            const SizedBox(height: 8),
          ];
    final actionChildren = <Widget>[
      ...occurrenceCards,
      sectionLabel(l10n?.moneySectionPay ?? 'Pay'),
      recordPayment,
      if (buyPackage != null) ...[const SizedBox(height: 8), buyPackage],
      sectionLabel(l10n?.moneySectionRequests ?? 'Requests'),
      grid(requestButtons),
      sectionLabel(l10n?.moneySectionDocuments ?? 'Documents'),
      if (invoicesButton != null) ...[invoicesButton, const SizedBox(height: 8)],
      if (reportsOn)
        DocumentsFaceActions(
          onAgreement: () => _memberDoc('agreement'),
          onPaymentsReport: () => _memberDoc('payments'),
          onStatementPdf: null,
          showDocumentLibrary: false,
        ),
    ];
    // #720 — the faces. Cards come from the same BillView, one face at a
    // time; the Invoices face adds MY documents as a list.
    final facesOn = features.contains(WorkspaceFeature.financeFaces);
    // #726 — what is open and overdue across MY invoices, judged by the
    // workspace's own payment term.
    final exposure = watchExposure(ref, member?.id ?? '', currencyCode);
    final overdueBanner = exposure == null || exposure.overdue.isEmpty
        ? null
        : OverdueBanner(exposure: exposure);
    final faceCards = <MoneyFace, List<Widget>>{
      MoneyFace.statement: [
        if (account != null && account.isNotable) ...[
          AccountCard(account: account, currencyCode: currencyCode),
          const SizedBox(height: 8),
        ],
        // #739 — my prices against the tariff, and who can see them.
        if (features.contains(WorkspaceFeature.priceNegotiations) &&
            member != null) ...[
          NegotiationCard(memberId: member.id, currency: currency),
          const SizedBox(height: 8),
        ],
        if (visibleStatement != null) bill(MoneyFace.statement),
      ],
      MoneyFace.payments: [
        if (overdueBanner != null) ...[overdueBanner, const SizedBox(height: 8)],
        ...occurrenceCards,
        if (visibleStatement != null) bill(MoneyFace.payments),
      ],
      MoneyFace.invoices: [
        if (overdueBanner != null) ...[overdueBanner, const SizedBox(height: 8)],
        if (exposure != null) ...[
          InvoiceSummaryCard(exposure: exposure),
          const SizedBox(height: 8),
          MyInvoicesList(memberId: member?.id ?? '', exposure: exposure),
        ],
        // #881 — what my invoices print as conditions, read-only here.
        if (member != null &&
            features.contains(WorkspaceFeature.memberPaymentTerms)) ...[
          const SizedBox(height: 8),
          PaymentTermsCard(member: member, isSelf: true),
        ],
      ],
      // #833 — the month's bookings and what each of them costs. The
      // face is always in the tab strip; the flag decides whether it has
      // anything to say, so turning it off never leaves a dead tab.
      MoneyFace.usage: [
        if (features.contains(WorkspaceFeature.usageRecords))
          UsageFace(period: _period),
      ],
      MoneyFace.documents: const [],
    };
    final documentsOn = features.contains(WorkspaceFeature.documents);
    final faceActions = <MoneyFace, List<Widget>>{
      MoneyFace.statement: const [],
      MoneyFace.payments: [
        const SizedBox(height: 8),
        recordPayment,
        if (buyPackage != null) ...[const SizedBox(height: 8), buyPackage],
        const SizedBox(height: 8),
        grid(requestButtons),
      ],
      MoneyFace.invoices: [
        if (invoicesButton != null) ...[const SizedBox(height: 8), invoicesButton],
      ],
      MoneyFace.usage: const [],
      MoneyFace.documents: [
        DocumentsFaceActions(
          onAgreement: reportsOn ? () => _memberDoc('agreement') : null,
          onPaymentsReport: reportsOn ? () => _memberDoc('payments') : null,
          onStatementPdf: features.contains(WorkspaceFeature.pdfExport) &&
                  visibleStatement != null
              ? () => _exportPdf(visibleStatement)
              : null,
          showDocumentLibrary: documentsOn,
        ),
      ],
    };
    // #486 — the landscape side panel leads with the month's BOTTOM
    // LINE so the split reads: my balance and what I can do, left; the
    // detail, right.
    final balanceCard = MoneyBalanceCard(
      balanceCents: visibleStatement?.balanceCents,
      currency: currency,
    );

    return switch (statementAsync) {
      AsyncData() when facesOn => MoneyFacesView(
          periodHeader: periodHeader,
          balanceCard: balanceCard,
          cards: faceCards,
          actions: faceActions,
        ),
      AsyncData() => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > constraints.maxHeight) {
              return Row(
                children: [
                  SizedBox(
                    // #486 — 32% (280–400dp): the bill is the content.
                    width: (constraints.maxWidth * 0.32)
                        .clamp(280.0, 400.0),
                    child: SingleChildScrollView(
                      padding: AppSpacing.mdAll,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // #606 — gated inside the widget.
                          const HelpHint(HelpHintId.money),
                          periodHeader,
                          balanceCard,
                          ...actionChildren,
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: ListView(
                      padding: AppSpacing.mdAll,
                      children: billChildren,
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: AppSpacing.mdAll,
              children: [
                // #606 — contextual how-to; gated inside the widget.
                const HelpHint(HelpHintId.money),
                periodHeader,
                ...billChildren,
                ...actionChildren,
              ],
            );
          },
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
