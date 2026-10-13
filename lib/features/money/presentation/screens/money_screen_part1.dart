// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'money_screen.dart';

// #2386 — part 1 of _MoneyScreenState, split out of money_screen.dart so no
// file holds the whole class.
extension _MoneyScreenStatePart1 on _MoneyScreenState {

  void _applyFocus(String? period) {
    if (period == null) return;
    final parts = period.split('-');
    if (parts.length == 2) {
      _update(() => _month = DateTime(int.parse(parts[0]), int.parse(parts[1])));
    }
    ref.read(moneyFocusControllerProvider.notifier).clear();
  }

  /// Me › Finances asked for one invoice of this space: open it here.
  Future<void> _applyInvoiceFocus(
    ({String workspaceId, String invoiceId})? focus,
  ) {
    final workspace = ref.read(currentWorkspaceProvider).value;
    return openFocusedInvoice(
      context,
      ref,
      focus,
      workspaceId: workspace?.id,
      countryCode: workspace?.countryCode ?? '',
    );
  }

  void _shiftMonth(int delta) {
    _update(() => _month = DateTime(_month.year, _month.month + delta));
  }

  /// Renders the visible period's bill as a PDF — the exact sections
  /// [BillView] shows via [buildBillSections] — and hands it to the system
  /// share sheet (#133, ADR 0008).
  /// #494 — one of the member's self-service letter documents: quick
  /// in-app view, download, or share.
  Future<void> _memberDoc(String docId) async {
    final l10n = context.l10n;
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
              ref.read(myMemberProvider).value?.preferredLocaleOverride ??
              ref.read(myProfileProvider).value?.preferredLocale ?? '');
    } on AmbiguousReportLanguage {
      AppSnack.error(
        context,
        l10n.reportLanguageAmbiguous,
      );
      return;
    }
    final docL10n = l10nForLanguage(language);
    if (docId == 'usage') {
      // #873 — the figures come from the statement and the records.
      await ref.read(memberStatementProvider(me.id, _period).future);
      await ref.read(usageRecordsProvider(_period).future);
      if (!mounted) return;
    }
    final data = switch (docId) {
      'agreement' => agreementReportData(
          reportStringsFor(context, l10n: docL10n, localeName: language),
          agreementFactsOf(ref),
          memberName: names[me.id] ?? '',
          subscriptionPct: me.subscriptionPct),
      'usage' => usageReportData(context, ref,
          period: _period,
          memberId: me.id,
          memberName: names[me.id] ?? '',
          l10nOverride: docL10n,
          localeName: language),
      _ => paymentsReportData(
          reportStringsFor(context, l10n: docL10n, localeName: language),
          paymentsFactsOf(ref, _period),
          period: _period,
          memberName: names[me.id] ?? ''),
    };
    final report = renderLetterDoc(context, ref,
        docId: docId, data: data, language: language);
    final title = switch (docId) {
      'agreement' => docL10n.reportDocAgreement,
      'usage' => docL10n.reportDocUsage,
      _ => docL10n.reportDocPayments,
    };
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
    final l10n = context.l10n;
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
      title: l10n.billPdfTitle,
      subscription: subscriptionLabel(reportStringsOf(l10n), statement.subscriptionPct,
          association: ref.watch(sellerIsAssociationProvider),
          // #1000 — the bill's position names its month too.
          month: monthNameOf(locale,
              yearMonth(_month.year, _month.month))),
      entitlement: l10n.billEntitlement(
            statement.usedHalfDays,
            statement.includedHalfDays,
            statement.openDays,
          ),
      overage: l10n.billOverage(statement.extraHalfDays),
      accessorySupplements:
          l10n.billAccessorySupplements,
      services: l10n.billServices,
      servicesTotal: l10n.billServicesTotal,
      serviceFallback: l10n.ledgerCategoryService,
      packages: l10n.billPackages,
      openPositions: l10n.billOpenPositions,
      pendingBadge: l10n.billPendingBadge,
      paymentsCredits: l10n.billPaymentsCredits,
      paymentFallback: l10n.ledgerCategoryPayment,
      expenseFallback:
          l10n.ledgerCategoryExpense,
      adjustmentFallback: l10n.ledgerCategoryAdjustment,
      eventPayment: l10n.eventTypePayment,
      eventExpense: l10n.eventTypeExpense,
      eventAdjustment: l10n.eventTypeAdjustment,
      balance: l10n.billBalance,
      settled: l10n.billSettled,
      outstanding: l10n.billOutstanding,
    );

    final sections = buildBillSections(
      period: statement.period, memberId: member.id, ledger: ledger,
      pendingEvents: pendingEvents, nowPeriod: _nowPeriod,
    );

    // #514 — the shared triad, for the bill too: the statement report
    // (owner template or default bands) is the quick view; download and
    // share build the same PDF the save-only path used to.
    InvoiceReport? renderStatement() {
      final data = statementReportData(
        reportStringsFor(context),
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
          buildBillReport(BillDocument(statement: statement, sections: sections,
              currencyCode: workspace.currencyCode, workspaceName: workspace.name,
              memberName: memberName, periodLabel: monthLabel,
              strings: strings, locale: locale));
    }

    final report = renderStatement()!;
    await runReportActions(
      context,
      ref,
      keyPrefix: 'bill-export',
      logMessage: 'bill PDF export failed',
      render: () => report,
      buildPdf: () async {
        // Embedded Roboto: base-14 PDF fonts cannot encode '€'/'−' (#133).
        final regular =
            await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        final bytes = await buildBillPdf(BillDocument(statement: statement,
            sections: sections,
            currencyCode: workspace.currencyCode,
            workspaceName: workspace.name,
            memberName: memberName,
            periodLabel: monthLabel,
            strings: strings,
            locale: locale,
            report: report,
            reportImages: await resolveReportImages(ref, report)),
            baseFont: pw.Font.ttf(regular),
            boldFont: pw.Font.ttf(bold),
            pageLabel: l10n.invoicePdfPage,
            watermark: workspace.isDevelopment
                ? (l10n.developmentWatermark) : '');
        return (
          bytes: bytes,
          fileName: 'deskilo-bill-${statement.period}.pdf',
        );
      },
    );
  }

  Future<void> _recordPaymentSheet(MoneyFormat currency) async {
    final context = this.context;
    final l10n = context.l10n;
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
      setSheetState(() => period = yearMonth(next.year, next.month));
    }
    final submitted = await showAppSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SheetShell(
          title: l10n.moneyRecordPayment,
          children: [
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                decoration: InputDecoration(
                  labelText: l10n.moneyAmountLabel,
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
                      key: ValueKey('money-choice-chip-${candidate.name}'),
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
                title: Text(l10n.moneyPaymentDateLabel),
                subtitle: Text(dayFormat.format(paidOn)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: paidOn,
                    firstDate: DateTime(today.year - 2),
                    lastDate: DateTime(today.year, today.month, today.day),
                    helpText: l10n.moneyPaymentDateLabel,
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
                title: Text(l10n.moneyPaymentPeriodLabel),
                subtitle: Text(
                  monthFormat.format(monthOf(period)),
                  key: const ValueKey('payment-period-label'),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
                    key: const ValueKey('payment-period-prev'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => shiftPeriod(setSheetState, -1),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
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
                  labelText: l10n.moneyNoteLabel,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('money-submit-payment'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  l10n.moneySubmitPayment,
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
      errorText: l10n.workspaceGenericError,
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
      l10n.moneyPaymentPending,
    );
    ref.invalidate(eventsProvider);
  }

  Future<void> _submitExpenseSheet(MoneyFormat currency) =>
      showExpenseSheet(context, ref, currency);
}
