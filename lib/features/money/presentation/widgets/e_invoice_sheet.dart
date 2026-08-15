// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/e_invoice_routing.dart';
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
String eInvoiceGapText(AppLocalizations? l10n, EInvoiceGap gap) =>
    switch (gap) {
      EInvoiceGap.vatNotSupported => l10n?.invoiceGapVatNotSupported ??
          'The workspace charges VAT but this invoice carries no rate — '
              'add your VAT rates, then issue it again.',
      EInvoiceGap.missingVatId => l10n?.invoiceGapMissingVatId ??
          'The VAT number is missing — an exempt seller must state one.',
      EInvoiceGap.missingLegalId => l10n?.invoiceGapMissingLegalId ??
          'The company registration number is missing.',
      EInvoiceGap.missingExemptionReason =>
        l10n?.invoiceGapMissingExemptionReason ??
            'The reason for not charging VAT is missing.',
      EInvoiceGap.missingSellerCountry =>
        l10n?.invoiceGapMissingSellerCountry ??
            'The workspace country is missing.',
      EInvoiceGap.missingBuyerCountry => l10n?.invoiceGapMissingBuyerCountry ??
          "The customer's country is missing.",
      EInvoiceGap.noChargeLines => l10n?.invoiceGapNoChargeLines ??
          'This invoice has no charge line — there is no invoice to send.',
      EInvoiceGap.missingSellerCity => l10n?.invoiceGapMissingSellerCity ??
          'the city of the workspace address',
      EInvoiceGap.missingSellerPostalCode =>
        l10n?.invoiceGapMissingSellerPostalCode ??
            'the post code of the workspace address',
    };

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
}) =>
    showModalBottomSheet<EInvoiceExport>(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final transport = switch (route.transport) {
      EInvoiceTransport.peppol => l10n?.invoiceEInvoiceTransportPeppol ??
          'An access point delivers it to the customer — no government '
              'platform in between.',
      EInvoiceTransport.clearance => l10n?.invoiceEInvoiceTransportClearance ??
          'The national platform receives the invoice first and hands it '
              'on — sending it straight to the customer is not an option.',
      EInvoiceTransport.accredited =>
        l10n?.invoiceEInvoiceTransportAccredited ??
            'An accredited platform carries the invoice and reports it to '
                'the tax administration for you.',
      EInvoiceTransport.bilateral => l10n?.invoiceEInvoiceTransportBilateral ??
          'No channel is imposed: e-mail, a portal or Peppol — whatever '
              'you agree with the customer.',
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
              Text(
                l10n?.invoiceEInvoiceAction ?? 'E-invoice (XML)',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n?.invoiceEInvoiceExplain ??
                    'The machine-readable EN 16931 invoice — what tax '
                        'administrations and business customers ask for.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              fact(
                Icons.business_outlined,
                l10n?.invoiceEInvoiceBusinessRoute(
                      route.businessChannel,
                      route.businessFormat,
                    ) ??
                    'Business customers: ${route.businessChannel} '
                        '(${route.businessFormat}).',
                strong: true,
              ),
              fact(Icons.route_outlined, transport),
              fact(
                Icons.account_balance_outlined,
                l10n?.invoiceEInvoicePublicRoute(route.publicChannel) ??
                    'Public-sector customers: ${route.publicChannel}.',
              ),
              // Where the domestic mandate runs on a national syntax, this
              // file is not the one the platform accepts — say so instead
              // of letting the export look compliant.
              if (!route.ublAccepted) ...[
                const SizedBox(height: AppSpacing.sm),
                InlineBanner(
                  key: const ValueKey('invoice-einvoice-format-warning'),
                  icon: Icons.warning_amber_outlined,
                  text: l10n?.invoiceEInvoiceFormatMismatch(
                        route.businessChannel,
                        route.businessFormat,
                      ) ??
                      '${route.businessChannel} accepts only '
                          '${route.businessFormat}: this EN 16931 file '
                          'serves Peppol, public buyers and foreign '
                          'customers — your platform converts the rest.',
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              // READINESS (0069): the fatal EN 16931 rules, judged before
              // the file exists. Handing out an XML that the receiving
              // platform silently rejects is worse than refusing here.
              if (readiness.ready)
                fact(
                  Icons.verified_outlined,
                  l10n?.invoiceEInvoiceReady ??
                      'Ready — this file satisfies EN 16931.',
                  strong: true,
                )
              else
                InlineBanner(
                  key: const ValueKey('invoice-einvoice-blocked'),
                  icon: Icons.report_outlined,
                  text: [
                    l10n?.invoiceEInvoiceBlockedTitle ??
                        'A validator would reject this file:',
                    for (final gap in readiness.blocking)
                      '• ${eInvoiceGapText(l10n, gap)}',
                  ].join('\n'),
                ),
              // Why a complete identity still leaves a rejected file: the
              // document answers for the identity it was SIGNED with.
              if (!readiness.ready && identityFixedSince) ...[
                const SizedBox(height: AppSpacing.sm),
                InlineBanner(
                  key: const ValueKey('invoice-einvoice-stale-identity'),
                  icon: Icons.history_outlined,
                  text: l10n?.invoiceEInvoiceStaleIdentity ??
                      'Your legal identity is complete now, but this '
                          'invoice was signed before it and keeps what it '
                          'was issued with. Mark it erroneous and issue a '
                          'replacement to carry the new identity.',
                ),
              ],
              if (readiness.ready && readiness.warnings.isNotEmpty)
                fact(
                  Icons.info_outlined,
                  [
                    l10n?.invoiceEInvoiceIncompleteTitle ??
                        'Valid, but the strict national profiles also want:',
                    for (final gap in readiness.warnings)
                      '• ${eInvoiceGapText(l10n, gap)}',
                  ].join('\n'),
                ),
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
                      l10n?.invoiceSendAction ??
                          'Send to the government platform',
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
                      l10n?.invoiceSendCustomerAction ??
                          "Send to the customer's service",
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
                    l10n?.invoiceFacturXDownload ??
                        'Download Factur-X (PDF)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-facturx-share'),
                  onPressed: () =>
                      Navigator.of(context).pop(EInvoiceExport.facturXShare),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(
                    l10n?.invoiceFacturXShare ?? 'Share Factur-X (PDF)',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.md,
                  ),
                  child: Text(
                    l10n?.invoiceFacturXExplain ??
                        'One file: the invoice a human reads, with the '
                            'machine-readable XML inside it.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-einvoice-download'),
                  onPressed: () =>
                      Navigator.of(context).pop(EInvoiceExport.download),
                  icon: const Icon(Icons.code_outlined),
                  label: Text(
                    l10n?.invoiceEInvoiceDownload ??
                        'Download e-invoice (XML)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-einvoice-share'),
                  onPressed: () =>
                      Navigator.of(context).pop(EInvoiceExport.share),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(
                    l10n?.invoiceEInvoiceShare ?? 'Share e-invoice (XML)',
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
                    l10n?.invoiceEInvoiceFixIdentity ??
                        'Complete the legal identity',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
