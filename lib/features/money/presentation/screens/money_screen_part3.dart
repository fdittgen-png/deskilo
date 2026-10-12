// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'money_screen.dart';

// #2386 — part 3 of _MoneyScreenState, split out of money_screen.dart so no
// file holds the whole class.
extension _MoneyScreenStatePart3 on _MoneyScreenState {

  Widget _buildImpl(BuildContext context) {
    // #718 — the calendar hub asks for a month; consume it once.
    ref.listen(moneyFocusControllerProvider, (_, period) => _applyFocus(period));
    ref.listen(invoiceFocusProvider, (_, focus) => _applyInvoiceFocus(focus));
    // The space may arrive after the request: try again once it does.
    ref.listen(currentWorkspaceProvider, (_, _) =>
        _applyInvoiceFocus(ref.read(invoiceFocusProvider)));
    final l10n = context.l10n;
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
    // #1637 — the month's online attempts the provider has not confirmed.
    final onlineAttempts = OnlinePaymentStatusCard.shown(
      ref.watch(myPaymentIntentsProvider).value ?? const [],
      _period,
    );
    final attemptsCard = <Widget>[
      if (onlineAttempts.isNotEmpty) ...[
        OnlinePaymentStatusCard(
          intents: onlineAttempts,
          currencyCode: workspace?.currencyCode ?? 'EUR',
        ),
        const SizedBox(height: 8),
      ],
    ];
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
          key: const ValueKey('money-chevron-left'),
          tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
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
          key: const ValueKey('money-chevron-right'),
          tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
          icon: const Icon(Icons.chevron_right),
          onPressed: _isCurrentPeriod ? null : () => _shiftMonth(1),
        ),
        if (features.contains(WorkspaceFeature.pdfExport))
          IconButton(
            key: const ValueKey('money-bill-pdf-export'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.billPdfExport,
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
      ...attemptsCard,
      if (visibleStatement != null) bill(null),
    ];
    // #486 UX — actions grouped by MEANING: what pays, what asks, what
    // documents. The arrangement itself explains payment vs invoicing.
    // #720 — the same partition IS the three faces; each button is built
    // once and placed by whichever layout is on.
    Widget sectionLabel(String text) => moneySectionLabel(context, text);
    Widget fitted(String text) => fittedLabel(text);
    final recordPayment = FilledButton.icon(
      key: const ValueKey('money-record-payment'),
      onPressed: () => _recordPaymentSheet(currency),
      icon: const Icon(Icons.payments_outlined),
      label: Text(l10n.moneyRecordPayment),
    );
    // Buy-a-package entry point (0042): only for members the owner
    // put on the package plan — it PAYS, so it lives here.
    final buyPackage = member?.overagePolicy == OveragePolicy.package
        ? FilledButton.tonalIcon(
            key: const ValueKey('buy-package-button'),
            onPressed: () => _buyPackageSheet(currency),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(l10n.buyPackageButton),
          )
        : null;
    final submitExpense = OutlinedButton.icon(
      key: const ValueKey('money-submit-expense'),
      onPressed: () => _submitExpenseSheet(currency),
      icon: const Icon(Icons.receipt_long_outlined),
      label: fitted(l10n.moneySubmitExpense),
    );
    final requestQuota = OutlinedButton.icon(
      key: const ValueKey('quota-request-button'),
      onPressed: _requestQuotaSheet,
      icon: const Icon(Icons.hourglass_top_outlined),
      label: fitted(l10n.quotaRequestButton),
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
                l10n.scheduledExpensesTitle),
          )
        : null;
    // Consumption follows the services feature (#146).
    final addConsumption = features.contains(WorkspaceFeature.services)
        ? OutlinedButton.icon(
            key: const ValueKey('money-consumption-add'),
            onPressed: () {
              final me = ref.read(myMemberProvider).value;
              if (me == null) return;
              unawaited(showConsumptionSheet(context, ref, subjectMemberId: me.id));
            },
            icon: const Icon(Icons.room_service_outlined),
            label: fitted(l10n.consumptionAdd),
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
            title: Text(l10n.invoicesManage),
            subtitle:
                Text(l10n.uxNavFinance),
            // Not chevron_right: the period bar owns that icon on this screen.
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/invoices'),
          )
        : null;
    // #934 — the treasurer's view and the guided repartition, for those
    // who manage the money.
    final statusButton = features.contains(WorkspaceFeature.workspaceStatus) &&
            (ref.watch(myMemberProvider).value?.isAdmin ?? false)
        ? ListTile(
            key: const ValueKey('workspace-status-button'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(l10n.statusTitle),
            subtitle: Text(l10n.statusSubtitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/money/status'),
          )
        : null;
    final wizardButton =
        features.contains(WorkspaceFeature.expenseRepartitionWizard) &&
                (ref.watch(myMemberProvider).value?.isAdmin ?? false)
            ? ListTile(
                key: const ValueKey('repartition-wizard-button'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pie_chart_outline),
                title: Text(l10n.repartitionWizardTitle),
                subtitle: Text(l10n.repartitionWizardSubtitle),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/money/repartition-wizard'),
              )
            : null;
    // #494 — member self-service reports: the standing financial
    // agreement and the month's payments, viewable/downloadable/
    // shareable without asking anyone. Gated by memberReports (#502).
    final reportsOn = features.contains(WorkspaceFeature.memberReports);
    // #873 — the consumption report needs the records AND the letters.
    final usageReportOn =
        reportsOn && features.contains(WorkspaceFeature.usageReport);
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
            sectionLabel(l10n.scheduledAwaitingTitle),
            for (final o in awaitingOccurrences)
              ExpenseOccurrenceCard(o, currency),
            const SizedBox(height: 8),
          ];
    final actionChildren = <Widget>[
      ...occurrenceCards,
      sectionLabel(l10n.moneySectionPay),
      recordPayment,
      if (buyPackage != null) ...[const SizedBox(height: 8), buyPackage],
      sectionLabel(l10n.moneySectionRequests),
      grid(requestButtons),
      sectionLabel(l10n.moneySectionDocuments),
      if (invoicesButton != null) ...[invoicesButton, const SizedBox(height: 8)],
      if (statusButton != null) ...[statusButton, const SizedBox(height: 8)],
      if (wizardButton != null) ...[wizardButton, const SizedBox(height: 8)],
      if (reportsOn)
        DocumentsFaceActions(
          onAgreement: () => _memberDoc('agreement'),
          onPaymentsReport: () => _memberDoc('payments'),
          onUsageReport: usageReportOn ? () => _memberDoc('usage') : null,
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
        ...attemptsCard,
        if (visibleStatement != null) bill(MoneyFace.statement),
        if (account != null && account.isNotable) ...[
          const SizedBox(height: 8),
          AccountCard(account: account, currencyCode: currencyCode, collapsible: true),
        ],
      ],
      MoneyFace.payments: [
        if (overdueBanner != null) ...[overdueBanner, const SizedBox(height: 8)],
        ...attemptsCard,
        ...occurrenceCards,
        sectionLabel(l10n.moneySectionPay),
        if (visibleStatement != null) bill(MoneyFace.payments),
      ],
      MoneyFace.invoices: [
        if (invoicesButton != null || statusButton != null || wizardButton != null)
          MoneyWorkspaceTools(actions: [?invoicesButton, ?statusButton, ?wizardButton]),
        if (exposure != null) ...[
          InvoiceSummaryCard(exposure: exposure),
          const SizedBox(height: 8),
          MyInvoicesList(memberId: member?.id ?? '', exposure: exposure),
        ],
      ],
      // #833 — the month's bookings and what each of them costs. The
      // face is always in the tab strip; the flag decides whether it has
      // anything to say, so turning it off never leaves a dead tab.
      MoneyFace.usage: [
        // #873 — the month's consumption as a letter, from this face too.
        if (usageReportOn)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              key: const ValueKey('usage-report-button-face'),
              onPressed: () => _memberDoc('usage'),
              icon: const Icon(Icons.insights_outlined),
              label: Text(l10n.usageReportButton),
            ),
          ),
        if (features.contains(WorkspaceFeature.usageRecords))
          UsageFace(period: _period),
      ],
      MoneyFace.documents: [
        if (features.contains(WorkspaceFeature.priceNegotiations) && member != null)
          NegotiationCard(memberId: member.id, currency: currency),
      ],
    };
    final documentsOn = features.contains(WorkspaceFeature.documents);
    final faceActions = <MoneyFace, List<Widget>>{
      MoneyFace.statement: const [],
      MoneyFace.payments: [
        const SizedBox(height: 8),
        recordPayment,
        if (buyPackage != null) ...[const SizedBox(height: 8), buyPackage],
        sectionLabel(l10n.moneySectionRequests),
        grid(requestButtons),
        MyFinancesLinkCard(
          workspaceId: workspaceForSweep?.id,
          workspaceName: workspaceForSweep?.name,
        ),
      ],
      MoneyFace.invoices: [
        MyFinancesLinkCard(
          workspaceId: workspaceForSweep?.id,
          workspaceName: workspaceForSweep?.name,
        ),
      ],
      MoneyFace.usage: const [],
      MoneyFace.documents: [
        DocumentsFaceActions(
          onAgreement: reportsOn ? () => _memberDoc('agreement') : null,
          onPaymentsReport: reportsOn ? () => _memberDoc('payments') : null,
          onUsageReport: usageReportOn ? () => _memberDoc('usage') : null,
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

    return MoneyAttentionBody(enabled: features.contains(WorkspaceFeature.eventsTab), child: switch (statementAsync) {
      AsyncData() when facesOn => MoneyFacesView(
          periodHeader: periodHeader,
          cards: faceCards,
          actions: faceActions,
        ),
      AsyncData() => LayoutBuilder(
          builder: (context, constraints) {
            if (phoneLandscape(constraints)) {
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
            l10n.workspaceGenericError,
          ),
        ),
      _ => const LoadingView(),
    });
  }
}
