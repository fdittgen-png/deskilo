// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoice_actions.dart';


Future<void> remindInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final currency = moneyFormat(invoice.currency);
  // #1913 — the message states what is still owed, never the total of a
  // half-paid invoice; the server records the same remainder.
  final owed = invoiceRemainingCents(
    invoice,
    ref.read(invoiceMatchesProvider).value?[invoice.id],
  );
  final message =
      l10n.invoiceReminderMessage(
        invoice.number,
        currency.formatMinor(owed),
      );
  // #472: the level of THIS send — one past what was already sent,
  // capped at the configured maximum (extra sends reuse the last
  // letter).
  final rules = ref.read(dunningRulesProvider).value ?? DunningRules.defaults;
  final sent =
      ref.read(invoiceRemindersProvider).value?[invoice.id]?.count ?? 0;
  final level = (sent + 1).clamp(1, rules.levels);
  SendReminderOutcome? outcome;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice reminder failed',
    errorText:
        l10n.workspaceGenericError,
    action: () async {
      // PDF first — it captures its context-derived values before any
      // await (use_build_context_synchronously).
      final pdf = await buildReminderPdfFile(
        context,
        ref,
        invoice,
        level: level,
      );
      // The ORDER is the decision, so it lives in the command (#1532):
      // the letter goes out, and the level is recorded only if it did.
      outcome = await sendReminder(
        repository: ref.read(invoiceCommandsProvider),
        share: ref.read(fileSharerProvider),
        invoiceId: invoice.id,
        level: level,
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        message: message,
      );
    },
  )) {
    return;
  }
  // Nothing left the device and nothing was recorded. "Reminder
  // recorded." would be false, and an error would be false too.
  if (outcome is ReminderNotSent) {
    if (!context.mounted) return;
    AppSnack.info(
        context,
        l10n.invoiceReminderNotSent);
    return;
  }
  ref.invalidate(invoiceRemindersProvider);
  if (!context.mounted) return;
  AppSnack.success(context, l10n.invoiceReminded);
}

/// EN 16931 e-invoice (0066/0069): the sheet first — WHERE the file has to
/// go in this country, and whether it would be ACCEPTED at all — then the
/// UBL 2.1 XML to Downloads or the share sheet.
Future<void> _exportEInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required String countryCode,
}) async {
  final association = ref.read(sellerIsAssociationProvider);
  final route = eInvoiceRouteFor(countryCode);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (route == null || workspace == null) return;
  // The invoice's own snapshot, or the live workspace identity for
  // pre-0069 documents (see sellerOf).
  final seller = sellerOf(invoice, workspace);
  final buyer = buyerOf(invoice, workspace);
  final readiness = checkEInvoiceReadiness(
    invoice: invoice,
    seller: seller,
    buyer: buyer,
    // #922 — the sheet's default leg is the government platform; the
    // public-sector references are asked for there, as a warning.
    destination: 'government',
  );
  // The same judgement against the LIVE identity: if that one passes, the
  // owner is not missing anything — the document is simply older than the
  // identity, and only a replacement can carry the new one.
  final identityFixedSince =
      invoice.sellerParty != null &&
      !readiness.ready &&
      checkEInvoiceReadiness(
        invoice: invoice,
        seller: workspaceParty(workspace),
        buyer: buyer,
      ).ready;
  final me = ref.read(myMemberProvider).value;
  // AWAIT the probe: a cached `.value` is null on the first open, which
  // would hide the Send button exactly when it is most wanted.
  EInvoiceGatewayConfig gateway;
  try {
    gateway = await ref.read(eInvoiceGatewayProvider.future);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'e-invoice gateway probe failed',
      error: e,
      stackTrace: st,
    );
    gateway = EInvoiceGatewayConfig.notConfigured;
  }
  if (!context.mounted) return;
  // #2137 — send-e-invoice accepts whoever holds issueInvoices.
  final isIssuer = me?.actsAsOwner == true ||
      me?.canAdminister == true ||
      ref.read(myPermissionsProvider).contains(WorkspacePermission.issueInvoices);
  // #2358 — what the configured channel receives, what it still needs,
  // and which official validator that format passes.
  final sendFormat = eInvoiceFormatFor(
    provider: gateway.provider,
    destination: 'government',
    buyerEndpointScheme: buyer.endpointScheme,
  );
  final sendGaps = gateway.configured
      ? channelGaps(
          sendFormat,
          seller: seller,
          buyer: buyer,
          iban: workspaceIban(workspace),
        )
      : const <ChannelGap>[];
  final export = await showEInvoiceSheet(
    context,
    route: route,
    readiness: readiness,
    validator: eInvoiceValidators[
            gateway.configured ? sendFormat : EInvoiceFormat.en16931Ubl] ??
        '',
    sendChannel: route.businessChannel,
    sendGaps: sendGaps,
    mandates: mandateWarnings(seller.country, ref.read(clockProvider).now()),
    today: ref.read(clockProvider).now(),
    canFixIdentity: me?.actsAsOwner ?? false,
    identityFixedSince: identityFixedSince,
    // Only an issuer sends, and only when a platform is configured.
    canSend: gateway.configured && isIssuer && sendGaps.isEmpty,
    // The customer leg (#568): its own endpoint, its own flag, the same
    // issuer gate.
    canSendCustomer:
        gateway.customerConfigured &&
        isIssuer &&
        ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.einvoiceCustomerDelivery),
  );
  if (export == null || !context.mounted) return;
  if (export == EInvoiceExport.fixIdentity) {
    unawaited(context.push('/legal-identity'));
    return;
  }
  final l10nForFile = context.l10n;
  if (export == EInvoiceExport.send || export == EInvoiceExport.sendCustomer) {
    final toCustomer = export == EInvoiceExport.sendCustomer;
    // Dev mode + a configured test platform → choose the target (#393);
    // anyone else goes straight to production, no extra tap. The picker
    // judges the DESTINATION's environments (#568).
    final envGateway = toCustomer
        ? EInvoiceGatewayConfig(
            configured: true,
            environments:
                gateway.destinations['customer']?.environments ?? const {},
          )
        : gateway;
    final environment = await pickEInvoiceEnvironment(
      context,
      ref,
      gateway: envGateway,
    );
    if (environment == null || !context.mounted) return;
    await sendEInvoice(
      context,
      ref,
      invoice,
      seller: seller,
      buyer: buyer,
      iban: workspaceIban(workspace),
      workspaceId: workspace.id,
      environment: environment,
      destination: toCustomer ? 'customer' : 'government',
      provider: gateway.provider,
    );
    return;
  }
  if (export == EInvoiceExport.facturXDownload ||
      export == EInvoiceExport.facturXShare) {
    await runGuarded(
      context,
      domain: 'money',
      message: 'factur-x export failed',
      errorText:
          l10nForFile.workspaceGenericError,
      action: () async {
        final file = await buildFacturXFile(
          context,
          ref,
          invoice,
          seller: seller,
          buyer: buyer,
          iban: workspaceIban(workspace),
        );
        if (file.fileName.isEmpty) return;
        final bytes = Uint8List.fromList(file.bytes);
        if (export == EInvoiceExport.facturXShare) {
          await ref.read(fileSharerProvider)(
            bytes: bytes,
            fileName: file.fileName,
            mimeType: 'application/pdf',
          );
          return;
        }
        if (!context.mounted) return;
        await savePdfToDownloads(
          context,
          ref,
          bytes: bytes,
          fileName: file.fileName,
        );
      },
    );
    return;
  }
  final l10n = context.l10n;
  final words = reportStringsOf(l10n);
  await runGuarded(
    context,
    domain: 'money',
    message: 'e-invoice export failed',
    errorText:
        l10n.workspaceGenericError,
    action: () async {
      final xml = buildInvoiceUbl(EInvoiceInput(invoice: invoice,
        seller: seller,
        buyer: buyer,
        iban: workspaceIban(workspace),
        lineText: (line) => invoiceLineText(words, line,
            association: association, period: invoice.period)));
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final fileName = '${safeFileSlug(invoice.number)}.xml';
      if (export == EInvoiceExport.share) {
        await ref.read(fileSharerProvider)(
          bytes: bytes,
          fileName: fileName,
          mimeType: 'application/xml',
        );
        return;
      }
      if (!context.mounted) return;
      await savePdfToDownloads(context, ref, bytes: bytes, fileName: fileName);
    },
  );
}

/// Matches an open invoice to its payment (0067) — the only way an invoice
/// closes and archives. Over/under payments resolve in the dialog; the
/// server re-validates and files the invoice_payment event (pending when a
/// validation rule exists).
Future<void> matchInvoiceToPayment(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = context.l10n;
  final currency = moneyFormat(invoice.currency);
  // 0068 — the candidates: the member's registered payments (incl. settled
  // online payments) not yet consumed by another match.
  final invoiceQueries = ref.read(invoiceQueriesProvider);
  final ledger = await ref
      .read(memberAccountQueriesProvider)
      .fetchLedger(invoice.memberId);
  final matches = ref.read(invoiceMatchesProvider).value ?? const {};
  // #506 — the junction knows EVERY consumed payment (an aggregate
  // match only remembers its last one).
  final workspace = ref.read(currentWorkspaceProvider).value;
  final consumed = {
    for (final match in matches.values) ?match.paymentLedgerId,
    if (workspace != null) ...await invoiceQueries.fetchConsumedPaymentIds(workspace.id),
  };
  // A standing PARTIAL match shifts the target: further payments are
  // measured against what is STILL DUE.
  final existing = matches[invoice.id];
  final dueCents =
      existing != null &&
          !existing.pending &&
          existing.resolution == 'under_accepted' &&
          existing.writeoffAt == null
      ? invoice.totalCents - existing.paidCents
      : invoice.totalCents;
  // #512 — a credit BAKED into an issued invoice (negative line at
  // derivation) was spent there; the server refuses it too.
  final memberInvoices = ref.read(invoicesProvider).value ?? const <Invoice>[];
  bool baked(LedgerEntry entry) => memberInvoices.any(
    (i) =>
        i.memberId == invoice.memberId &&
        !i.isVoided &&
        i.period == entry.period &&
        i.issuedAt.isAfter(entry.createdAt),
  );
  final payments = [
    for (final entry in ledger)
      if (entry.kind == LedgerKind.credit &&
          // #512 — account credits (avoir excess) settle too: the
          // imputation of a credit note on any outstanding invoice.
          (entry.category == LedgerCategory.payment ||
              entry.category == LedgerCategory.adjustment) &&
          !consumed.contains(entry.id) &&
          !baked(entry))
        entry,
    // Newest PAYMENT first — by the day the money moved (0070), not by
    // the day it happened to be typed in.
  ]..sort((a, b) => b.on.compareTo(a.on));
  if (!context.mounted) return;
  final choice = await showDialog<MatchChoice>(
    context: context,
    builder: (context) => MatchInvoiceDialog(
      dueCents: dueCents,
      currency: currency,
      payments: payments,
    ),
  );
  if (choice == null || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice match failed',
    errorText:
        l10n.workspaceGenericError,
    action: () => ref
        .read(invoiceCommandsProvider)
        .matchInvoice(
          invoiceId: invoice.id,
          paymentLedgerId: choice.paymentLedgerId,
          resolution: choice.resolution,
          note: choice.note,
        ),
  )) {
    return;
  }
  ref
    ..invalidate(invoiceMatchesProvider)
    ..invalidate(myAccountProvider)
    ..invalidate(invoicesProvider);
  invalidateBookingData(ref);
  if (!context.mounted) return;
  AppSnack.success(context, l10n.invoiceMatched);
}

/// One tap invoices every listed member for [period] — behind a confirm
/// naming what is about to become N immutable documents. Per-member
/// guarded, so one failing statement neither stops the sweep nor hides
/// itself: the snack reports what did NOT go through.
Future<void> issueInvoicesForAll(
  BuildContext context,
  WidgetRef ref,
  List<ToInvoiceEntry> entries,
  String period,
  MoneyFormat currency,
) async {
  final l10n = context.l10n;
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null || entries.isEmpty) return;
  final total = entries.fold(0, (sum, e) => sum + e.totalCents);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.invoiceIssueAll),
      content: Text(
        l10n.invoiceIssueAllConfirm(
              entries.length,
              monthLabel(context, period),
              currency.formatMinor(total),
            ),
      ),
      actions: [
        TextButton(
          key: ValueKey('invoice-actions-cancel-4-$period'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('invoice-issue-all-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.invoiceIssueAll),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  var issued = 0;
  for (final entry in entries) {
    try {
      await ref
          .read(invoiceCommandsProvider)
          .createInvoice(
            workspaceId: workspace.id,
            memberId: entry.memberId,
            period: period,
          );
      issued++;
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'invoice sweep entry failed',
        error: e,
        stackTrace: st,
      );
    }
  }
  ref.invalidate(invoicesProvider);
  if (!context.mounted) return;
  final failed = entries.length - issued;
  if (failed > 0) {
    AppSnack.error(
      context,
      l10n.invoiceIssuedPartial(issued, failed),
    );
    return;
  }
  AppSnack.success(
    context,
    l10n.invoiceIssuedCount(issued),
  );
}
