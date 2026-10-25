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
  final route = eInvoiceRouteFor(countryCode);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (route == null || workspace == null) return;
  // The invoice's own snapshot, or the live workspace identity for
  // pre-0069 documents (see sellerOf).
  final subject = (
    invoice: invoice,
    seller: sellerOf(invoice, workspace),
    buyer: buyerOf(invoice, workspace),
    liveSeller: workspaceParty(workspace),
    iban: workspaceIban(workspace),
    workspaceId: workspace.id,
  );
  final roles = _eInvoiceRoles(ref);
  final gateway = await _probeEInvoiceGateway(ref);
  if (!context.mounted) return;
  final run = _EInvoiceExportRun(context, ref, subject);
  final export = await run.ask(
    route: route,
    gateway: gateway,
    roles: roles,
  );
  if (export == null || !context.mounted) return;
  if (export == EInvoiceExport.fixIdentity) {
    unawaited(context.push('/legal-identity'));
    return;
  }
  if (export == EInvoiceExport.send || export == EInvoiceExport.sendCustomer) {
    await run.send(
      gateway: gateway,
      toCustomer: export == EInvoiceExport.sendCustomer,
    );
    return;
  }
  if (export == EInvoiceExport.facturXDownload ||
      export == EInvoiceExport.facturXShare) {
    await run.facturX(share: export == EInvoiceExport.facturXShare);
    return;
  }
  await run.ublXml(share: export == EInvoiceExport.share);
}

/// One invoice on its way out as an e-invoice: the parties it names (its
/// own snapshot), the LIVE seller identity, and the workspace's IBAN.
typedef _EInvoiceSubject = ({
  Invoice invoice,
  InvoiceParty seller,
  InvoiceParty buyer,
  InvoiceParty liveSeller,
  String iban,
  String workspaceId,
});

/// Who may fix the identity (the owner) and who may send (#2137:
/// whoever holds issueInvoices).
({bool owner, bool issuer}) _eInvoiceRoles(WidgetRef ref) {
  final me = ref.read(myMemberProvider).value;
  return (
    owner: me?.actsAsOwner ?? false,
    issuer: me?.actsAsOwner == true ||
        me?.canAdminister == true ||
        ref
            .read(myPermissionsProvider)
            .contains(WorkspacePermission.issueInvoices),
  );
}

/// AWAITS the probe: a cached `.value` is null on the first open, which
/// would hide the Send button exactly when it is most wanted. A failed
/// probe reads as "not configured".
Future<EInvoiceGatewayConfig> _probeEInvoiceGateway(WidgetRef ref) async {
  try {
    return await ref.read(eInvoiceGatewayProvider.future);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'e-invoice gateway probe failed',
      error: e,
      stackTrace: st,
    );
    return EInvoiceGatewayConfig.notConfigured;
  }
}

/// The steps of one e-invoice export, over the invoice it sends and the
/// context and ref the export started from.
class _EInvoiceExportRun {
  _EInvoiceExportRun(this.context, this.ref, this.s);

  final BuildContext context;
  final WidgetRef ref;
  final _EInvoiceSubject s;

  /// The sheet: the route, the readiness verdict, what the configured
  /// channel still needs, and which legs this member may send on.
  Future<EInvoiceExport?> ask({
    required EInvoiceRoute route,
    required EInvoiceGatewayConfig gateway,
    required ({bool owner, bool issuer}) roles,
  }) {
    final readiness = checkEInvoiceReadiness(
      invoice: s.invoice,
      seller: s.seller,
      buyer: s.buyer,
      // #922 — the sheet's default leg is the government platform; the
      // public-sector references are asked for there, as a warning.
      destination: 'government',
    );
    // The same judgement against the LIVE identity: if that one passes, the
    // owner is not missing anything — the document is simply older than the
    // identity, and only a replacement can carry the new one.
    final identityFixedSince =
        s.invoice.sellerParty != null &&
        !readiness.ready &&
        checkEInvoiceReadiness(
          invoice: s.invoice,
          seller: s.liveSeller,
          buyer: s.buyer,
        ).ready;
    // #2358 — what the configured channel receives, what it still needs,
    // and which official validator that format passes.
    final sendFormat = eInvoiceFormatFor(
      provider: gateway.provider,
      destination: 'government',
      buyerEndpointScheme: s.buyer.endpointScheme,
    );
    final sendGaps = gateway.configured
        ? channelGaps(sendFormat, seller: s.seller, buyer: s.buyer, iban: s.iban)
        : const <ChannelGap>[];
    return showEInvoiceSheet(
      context,
      route: route,
      readiness: readiness,
      validator: eInvoiceValidators[
              gateway.configured ? sendFormat : EInvoiceFormat.en16931Ubl] ??
          '',
      sendChannel: route.businessChannel,
      sendGaps: sendGaps,
      mandates: mandateWarnings(s.seller.country, ref.read(clockProvider).now()),
      today: ref.read(clockProvider).now(),
      canFixIdentity: roles.owner,
      identityFixedSince: identityFixedSince,
      // Only an issuer sends, and only when a platform is configured.
      canSend: gateway.configured && roles.issuer && sendGaps.isEmpty,
      // The customer leg (#568): its own endpoint, its own flag, the same
      // issuer gate.
      canSendCustomer:
          gateway.customerConfigured &&
          roles.issuer &&
          ref
              .read(enabledFeaturesSyncProvider)
              .contains(WorkspaceFeature.einvoiceCustomerDelivery),
    );
  }

  /// Posts the document to the government platform or the customer leg.
  /// Dev mode + a configured test platform → choose the target (#393);
  /// anyone else goes straight to production, no extra tap. The picker
  /// judges the DESTINATION's environments (#568).
  Future<void> send({
    required EInvoiceGatewayConfig gateway,
    required bool toCustomer,
  }) async {
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
      s.invoice,
      seller: s.seller,
      buyer: s.buyer,
      iban: s.iban,
      workspaceId: s.workspaceId,
      environment: environment,
      destination: toCustomer ? 'customer' : 'government',
      provider: gateway.provider,
    );
  }

  /// The hybrid Factur-X PDF (the XML inside) to the share sheet or
  /// Downloads.
  Future<void> facturX({required bool share}) => runGuarded(
    context,
    domain: 'money',
    message: 'factur-x export failed',
    errorText: context.l10n.workspaceGenericError,
    action: () async {
      final file = await buildFacturXFile(
        context,
        ref,
        s.invoice,
        seller: s.seller,
        buyer: s.buyer,
        iban: s.iban,
      );
      if (file.fileName.isEmpty) return;
      final bytes = Uint8List.fromList(file.bytes);
      if (share) {
        await ref.read(fileSharerProvider)(
          bytes: bytes,
          fileName: file.fileName,
          mimeType: 'application/pdf',
        );
        return;
      }
      if (!context.mounted) return;
      await savePdfToDownloads(context, ref, bytes: bytes, fileName: file.fileName);
    },
  );

  /// The UBL 2.1 XML to the share sheet or Downloads.
  Future<void> ublXml({required bool share}) {
    final association = ref.read(sellerIsAssociationProvider);
    final l10n = context.l10n;
    final words = reportStringsOf(l10n);
    return runGuarded(
      context,
      domain: 'money',
      message: 'e-invoice export failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        final xml = buildInvoiceUbl(EInvoiceInput(
          invoice: s.invoice,
          seller: s.seller,
          buyer: s.buyer,
          iban: s.iban,
          lineText: (line) => invoiceLineText(words, line,
              association: association, period: s.invoice.period),
        ));
        final bytes = Uint8List.fromList(utf8.encode(xml));
        final fileName = '${safeFileSlug(s.invoice.number)}.xml';
        if (share) {
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
