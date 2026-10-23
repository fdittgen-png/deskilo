// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/e_invoice_routing.dart';
import '../../domain/einvoice_channel_check.dart';
import '../../domain/einvoice_mandates.dart';
import '../../domain/invoice_ubl_check.dart';

/// What to do with the generated XML.
enum EInvoiceExport {
  /// Post the document to the government platform (0073).
  send,

  /// Post the document to the customer's delivery service (#568).
  sendCustomer,

  /// The hybrid document: PDF with the XML inside (Factur-X).
  facturXDownload,
  facturXShare,

  download,
  share,

  /// Nothing yet — go and complete the workspace's legal identity, which
  /// is what the file is missing.
  fixIdentity,
}

/// Localized wording of one readiness gap (0069).
String _eInvoiceGapText(AppLocalizations l10n, EInvoiceGap gap) =>
    switch (gap) {
      EInvoiceGap.vatNotSupported => l10n.invoiceGapVatNotSupported,
      EInvoiceGap.missingVatId => l10n.invoiceGapMissingVatId,
      EInvoiceGap.missingLegalId => l10n.invoiceGapMissingLegalId,
      EInvoiceGap.missingExemptionReason =>
        l10n.invoiceGapMissingExemptionReason,
      EInvoiceGap.missingSellerCountry =>
        l10n.invoiceGapMissingSellerCountry,
      EInvoiceGap.missingBuyerCountry => l10n.invoiceGapMissingBuyerCountry,
      EInvoiceGap.missingBuyerVatId => l10n.invoiceGapMissingBuyerVatId,
      EInvoiceGap.mixedNotSubjectLines =>
        l10n.eInvoiceGapMixedNotSubjectLines,
      EInvoiceGap.missingBuyerLegalId =>
        l10n.eInvoiceGapMissingBuyerLegalId,
      EInvoiceGap.buyerLegalIdAdvisable =>
        l10n.eInvoiceGapBuyerLegalIdAdvisable,
      EInvoiceGap.missingPublicSectorReferences =>
          l10n.invoiceGapPublicSectorRefs,
      EInvoiceGap.buyerVatIdFormat => l10n.invoiceGapBuyerVatIdFormat,
      EInvoiceGap.noChargeLines => l10n.invoiceGapNoChargeLines,
      EInvoiceGap.creditNoteWithPayments =>
        l10n.invoiceGapCreditNoteWithPayments,
      EInvoiceGap.missingSellerCity => l10n.invoiceGapMissingSellerCity,
      EInvoiceGap.missingSellerPostalCode =>
        l10n.invoiceGapMissingSellerPostalCode,
    };

/// #2358 — localized wording of what a channel still needs.
String _channelGapText(AppLocalizations l10n, ChannelGap gap) =>
    switch (gap) {
      ChannelGap.sellerEndpoint => l10n.eInvoiceChannelGapSellerEndpoint,
      ChannelGap.buyerEndpoint => l10n.eInvoiceChannelGapBuyerEndpoint,
      ChannelGap.buyerReference => l10n.eInvoiceChannelGapBuyerReference,
      ChannelGap.leitwegId => l10n.eInvoiceChannelGapLeitwegId,
      ChannelGap.paymentAccount => l10n.eInvoiceChannelGapPaymentAccount,
      ChannelGap.sellerContact => l10n.eInvoiceChannelGapSellerContact,
      ChannelGap.subdivision => l10n.eInvoiceChannelGapSubdivision,
      ChannelGap.sellerVatId => l10n.eInvoiceChannelGapSellerVatId,
      ChannelGap.buyerTaxId => l10n.eInvoiceChannelGapBuyerTaxId,
    };

/// #2358 — one dated duty of the national mandate.
String mandateText(
  AppLocalizations l10n,
  EInvoiceMandate mandate,
  DateTime today,
  DateFormat dates,
) {
  final duty = switch (mandate.duty) {
    MandateDuty.receiveAll => l10n.eInvoiceMandateReceiveAll,
    MandateDuty.issueLarge => l10n.eInvoiceMandateIssueLarge,
    MandateDuty.issueAll => l10n.eInvoiceMandateIssueAll,
    MandateDuty.eReporting => l10n.eInvoiceMandateEReporting,
    MandateDuty.invoiceRecords => l10n.eInvoiceMandateInvoiceRecords,
  };
  final date = dates.format(mandate.from);
  return mandate.inForceOn(today)
      ? l10n.eInvoiceMandateSince(date, duty)
      : l10n.eInvoiceMandateFrom(date, duty);
}

/// The e-invoice sheet: the XML export used to be two anonymous entries in
/// an overflow menu, leaving the only question that matters unanswered —
/// where does this file have to GO? This says it, for the workspace's own
/// country, before handing the file over.
Future<EInvoiceExport?> showEInvoiceSheet(
  BuildContext context, {
  required EInvoiceRoute route,
  required EInvoiceReadiness readiness,
  required bool canFixIdentity,
  bool canSend = false,
  bool canSendCustomer = false,
  bool identityFixedSince = false,
  String validator = '',
  String sendChannel = '',
  List<ChannelGap> sendGaps = const [],
  List<EInvoiceMandate> mandates = const [],
  required DateTime today,
}) =>
    showAppSheet<EInvoiceExport>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _EInvoiceBody(
        route: route,
        readiness: readiness,
        canFixIdentity: canFixIdentity,
        canSend: canSend,
        canSendCustomer: canSendCustomer,
        identityFixedSince: identityFixedSince,
        validator: validator,
        sendChannel: sendChannel,
        sendGaps: sendGaps,
        mandates: mandates,
        today: today,
      ),
    );

class _EInvoiceBody extends StatelessWidget {
  const _EInvoiceBody({
    required this.route,
    required this.readiness,
    required this.canFixIdentity,
    required this.canSend,
    this.canSendCustomer = false,
    this.identityFixedSince = false,
    this.validator = '',
    this.sendChannel = '',
    this.sendGaps = const [],
    this.mandates = const [],
    required this.today,
  });

  final EInvoiceRoute route;

  /// What the fatal EN 16931 rules say about this document (0069).
  final EInvoiceReadiness readiness;

  /// Only an issuer can complete the workspace's legal identity — a
  /// member is shown what is missing without a button they cannot use.
  final bool canFixIdentity;

  /// A platform is configured and the function is deployed (0073): the
  /// document can LEAVE for the government platform, not just be
  /// downloaded.
  final bool canSend;

  /// The customer's own delivery service is configured too (#568) — the
  /// document can go straight to the customer.
  final bool canSendCustomer;

  /// The workspace's identity WOULD satisfy the norm — it is this
  /// document's snapshot that does not. Without saying so, the sheet asks
  /// for a number the owner is looking at, already filled in.
  final bool identityFixedSince;

  /// #2358 — the official validator the format passes in CI
  /// (einvoice_validation.dart); the readiness line names it.
  final String validator;

  /// #2358 — the configured channel and what it still needs before the
  /// document can be sent through it. Send is not offered meanwhile.
  final String sendChannel;
  final List<ChannelGap> sendGaps;

  /// #2358 — the national mandate's dated duties (FR, DE).
  final List<EInvoiceMandate> mandates;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final transport = switch (route.transport) {
      EInvoiceTransport.peppol => l10n.invoiceEInvoiceTransportPeppol,
      EInvoiceTransport.clearance => l10n.invoiceEInvoiceTransportClearance,
      EInvoiceTransport.accredited =>
        l10n.invoiceEInvoiceTransportAccredited,
      EInvoiceTransport.bilateral => l10n.invoiceEInvoiceTransportBilateral,
    };

    Widget fact(IconData icon, String text, {bool strong = false}) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: muted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                style: strong
                    ? theme.textTheme.bodyMedium
                    : theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ]),
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    l10n.invoiceEInvoiceAction,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                // #1393 — the gate refuses with a named missing item,
                // and that is exactly the moment somebody wants the
                // chapter explaining what EN 16931 requires.
                HelpDot(
                  l10n.helpTopicReadiness,
                  anchor: HelpAnchor.einvoiceOverview,
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.invoiceEInvoiceExplain,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              fact(
                Icons.business_outlined,
                l10n.invoiceEInvoiceBusinessRoute(
                      route.businessChannel,
                      route.businessFormat,
                    ),
                strong: true,
              ),
              fact(Icons.route_outlined, transport),
              fact(
                Icons.account_balance_outlined,
                l10n.invoiceEInvoicePublicRoute(route.publicChannel),
              ),
              // Where the domestic mandate runs on a national syntax, this
              // file is not the one the platform accepts — say so instead
              // of letting the export look compliant.
              if (!route.ublAccepted) ...[
                const SizedBox(height: AppSpacing.sm),
                InlineBanner(
                  key: const ValueKey('invoice-einvoice-format-warning'),
                  icon: Icons.warning_amber_outlined,
                  text: l10n.invoiceEInvoiceFormatMismatch(
                        route.businessChannel,
                        route.businessFormat,
                      ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              // READINESS (0069): the fatal EN 16931 rules, judged before
              // the file exists. Handing out an XML that the receiving
              // platform silently rejects is worse than refusing here.
              if (mandates.isNotEmpty)
                InlineBanner(
                  key: const ValueKey('invoice-einvoice-mandates'),
                  icon: Icons.event_outlined,
                  text: [
                    l10n.eInvoiceMandateTitle,
                    for (final m in mandates)
                      '• ${mandateText(
                        l10n,
                        m,
                        today,
                        DateFormat.yMMMd(
                          Localizations.maybeLocaleOf(context)?.toString(),
                        ),
                      )}',
                  ].join('\n'),
                ),
              if (mandates.isNotEmpty) const SizedBox(height: AppSpacing.sm),
              if (readiness.ready)
                fact(
                  Icons.verified_outlined,
                  l10n.invoiceEInvoiceValidated(validator),
                  strong: true,
                )
              else
                InlineBanner(
                  key: const ValueKey('invoice-einvoice-blocked'),
                  icon: Icons.report_outlined,
                  text: [
                    l10n.invoiceEInvoiceBlockedTitle,
                    for (final gap in readiness.blocking)
                      '• ${_eInvoiceGapText(l10n, gap)}',
                  ].join('\n'),
                ),
              // Why a complete identity still leaves a rejected file: the
              // document answers for the identity it was SIGNED with.
              if (!readiness.ready && identityFixedSince) ...[
                const SizedBox(height: AppSpacing.sm),
                InlineBanner(
                  key: const ValueKey('invoice-einvoice-stale-identity'),
                  icon: Icons.history_outlined,
                  text: l10n.invoiceEInvoiceStaleIdentity,
                ),
              ],
              if (readiness.ready && readiness.warnings.isNotEmpty)
                fact(
                  Icons.info_outlined,
                  [
                    l10n.invoiceEInvoiceIncompleteTitle,
                    for (final gap in readiness.warnings)
                      '• ${_eInvoiceGapText(l10n, gap)}',
                  ].join('\n'),
                ),
              if (readiness.ready && sendGaps.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                InlineBanner(
                  key: const ValueKey('invoice-einvoice-channel-gaps'),
                  icon: Icons.outbox_outlined,
                  text: [
                    l10n.eInvoiceChannelGapsTitle(sendChannel),
                    for (final gap in sendGaps)
                      '• ${_channelGapText(l10n, gap)}',
                  ].join('\n'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (readiness.ready) ...[
                // Sending beats saving: if the platform is there, the file
                // never has to touch the user's downloads folder. Two legs
                // (#568): the government platform the mandate points at,
                // and the customer's own delivery service.
                if (canSend) ...[
                  FilledButton.icon(
                    key: const ValueKey('invoice-einvoice-send'),
                    onPressed: () =>
                        Navigator.of(context).pop(EInvoiceExport.send),
                    icon: const Icon(Icons.account_balance_outlined),
                    label: Text(
                      l10n.invoiceSendAction,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (canSendCustomer) ...[
                  (canSend ? OutlinedButton.icon : FilledButton.icon)(
                    key: const ValueKey('invoice-einvoice-send-customer'),
                    onPressed: () => Navigator.of(context)
                        .pop(EInvoiceExport.sendCustomer),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      l10n.invoiceSendCustomerAction,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                // The hybrid document first: one file, both readers.
                ((canSend || canSendCustomer)
                    ? OutlinedButton.icon
                    : FilledButton.icon)(
                  key: const ValueKey('invoice-facturx-download'),
                  onPressed: () => Navigator.of(context)
                      .pop(EInvoiceExport.facturXDownload),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    l10n.invoiceFacturXDownload,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-facturx-share'),
                  onPressed: () =>
                      Navigator.of(context).pop(EInvoiceExport.facturXShare),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(
                    l10n.invoiceFacturXShare,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.md,
                  ),
                  child: Text(
                    l10n.invoiceFacturXExplain,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-einvoice-download'),
                  onPressed: () =>
                      Navigator.of(context).pop(EInvoiceExport.download),
                  icon: const Icon(Icons.code_outlined),
                  label: Text(
                    l10n.invoiceEInvoiceDownload,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-einvoice-share'),
                  onPressed: () =>
                      Navigator.of(context).pop(EInvoiceExport.share),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(
                    l10n.invoiceEInvoiceShare,
                  ),
                ),
              ] else if (canFixIdentity &&
                  !identityFixedSince &&
                  readiness.blocking.any((g) => g.fixableInSettings))
                FilledButton.icon(
                  key: const ValueKey('invoice-einvoice-fix-identity'),
                  onPressed: () =>
                      Navigator.of(context).pop(EInvoiceExport.fixIdentity),
                  icon: const Icon(Icons.badge_outlined),
                  label: Text(
                    l10n.invoiceEInvoiceFixIdentity,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
