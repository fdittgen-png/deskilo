// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the e-invoice side of the invoice actions: the gateway send and the
// export sheet with its Factur-X and UBL files. Split out of
// invoice_actions.dart (was invoice_actions_part1/2); same behaviour.
import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/files/file_names.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/channel_einvoice_xml.dart';
import '../domain/e_invoice_routing.dart';
import '../domain/einvoice_channel_check.dart';
import '../domain/einvoice_format.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/einvoice_input.dart';
import '../domain/einvoice_mandates.dart';
import '../domain/einvoice_validation.dart';
import '../domain/invoice.dart';
import '../domain/invoice_line_text.dart';
import '../domain/invoice_ubl.dart';
import '../domain/invoice_ubl_check.dart';
import '../providers/money_providers.dart';
import 'e_invoice_identity.dart';
import 'invoice_actions.dart' show requireWorkspaceTaxReference;
import 'invoice_documents.dart';
import 'invoice_pdf_actions.dart';
import 'report_strings_l10n.dart';
import 'widgets/e_invoice_sheet.dart';
import 'widgets/einvoice_environment_picker.dart';

/// SENDS the invoice: builds the document in the syntax the channel
/// wants (#2358 — XML for a network, Factur-X for a person) and posts it
/// to the workspace's platform through the edge function, which holds the
/// credential and records the attempt (0073). The document that leaves is
/// built by the same builder as the download — no second truth.
Future<void> sendEInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String iban,
  required String workspaceId,
  String environment = 'prod',
  String destination = 'government',
  String provider = 'generic',
}) async {
  final l10n = context.l10n;
  EInvoiceSubmission? result;
  final format = eInvoiceFormatFor(
    provider: provider,
    destination: destination,
    buyerEndpointScheme: buyer.endpointScheme,
  );
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'e-invoice submission failed',
    errorText:
        l10n.workspaceGenericError,
    action: () async {
      final ({List<int> bytes, String fileName}) file;
      if (format == EInvoiceFormat.facturX) {
        file = await buildFacturXFile(
          context,
          ref,
          invoice,
          seller: seller,
          buyer: buyer,
          iban: iban,
        );
      } else {
        // #2358 — the network's own syntax, from the inputs the
        // download uses.
        final words = reportStringsOf(l10n);
        final association = ref.read(sellerIsAssociationProvider);
        final xml = buildChannelEInvoiceXml(format, EInvoiceInput(
          invoice: invoice, seller: seller, buyer: buyer, iban: iban,
          lineText: (line) => invoiceLineText(words, line,
              association: association, period: invoice.period),
          dueDate: invoiceDueAt(ref, invoice),
          paymentTerms: invoice.legalClauses?.clauses.paymentTerms ??
              memberTermsFor(ref, invoice.memberId)?.paymentTerms ??
              '',
          reference: requireWorkspaceTaxReference(ref),
        ));
        file = (
          bytes: utf8.encode(xml),
          fileName: '${safeFileSlug('${format.name} ${invoice.number}')}.xml',
        );
      }
      if (file.fileName.isEmpty) return;
      result = await ref
          .read(eInvoiceTransmissionsProvider)
          .sendEInvoice(
            workspaceId: workspaceId,
            invoiceId: invoice.id,
            fileName: file.fileName,
            mimeType: format.mimeType,
            bytes: file.bytes,
            environment: environment,
            destination: destination,
            format: format.name,
            receiverScheme: buyer.endpointScheme,
            receiverId: buyer.endpointId,
          );
    },
  )) {
    return;
  }
  ref.invalidate(invoiceTransmissionsProvider);
  if (!context.mounted) return;
  final submission = result;
  if (submission == null) return;
  _announce(context, submission, environment, destination);
}

/// What the owner is told about a submission (#3335: an unsettled one sends
/// nothing again and points at the platform's record).
void _announce(
  BuildContext context,
  EInvoiceSubmission submission,
  String environment,
  String destination,
) {
  final l10n = context.l10n;
  if (submission.accepted) {
    AppSnack.success(
      context,
      environment != 'prod'
          ? (l10n.invoiceSendAcceptedTest(environment.toUpperCase()))
          : destination == 'customer'
          ? (l10n.invoiceSendCustomerAccepted)
          : (l10n.invoiceSendAccepted),
    );
    return;
  }
  if (submission.status.isUnresolved) {
    AppSnack.error(context, l10n.invoiceSendUnresolved);
    return;
  }
  // The platform's own words beat a generic failure: they are what the
  // owner has to act on.
  AppSnack.error(
    context,
    submission.detail.isEmpty
        ? (l10n.invoiceSendRejected)
        : '${l10n.invoiceSendRejected} '
              '${submission.detail}',
  );
}


/// EN 16931 e-invoice (0066/0069): the sheet first — WHERE the file has to
/// go in this country, and whether it would be ACCEPTED at all — then the
/// UBL 2.1 XML to Downloads or the share sheet.
Future<void> exportEInvoice(
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
    final reference = requireWorkspaceTaxReference(ref);
    final readiness = checkEInvoiceReadiness(
      invoice: s.invoice,
      seller: s.seller,
      buyer: s.buyer,
      // #922 — the sheet's default leg is the government platform; the
      // public-sector references are asked for there, as a warning.
      destination: 'government',
      iban: s.iban,
      reference: reference,
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
          iban: s.iban,
          reference: reference,
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
    // Only an `uncertain` submission stops Send (#3335): a prepared one is
    // claimed by the next send, and one in flight answers "in progress" until
    // its window passes and the server marks it uncertain — hiding those
    // would strand an invoice whose function died.
    final unsettled =
        ref.read(invoiceTransmissionsProvider).value?[s.invoice.id]?.status ==
        EInvoiceSubmissionStatus.uncertain;
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
      // Only an issuer sends, and only when a platform is configured — and
      // not while an earlier submission's outcome is unknown (#3335): the
      // server would refuse it anyway, so the button is not offered.
      canSend:
          gateway.configured && roles.issuer && sendGaps.isEmpty && !unsettled,
      // The customer leg (#568): its own endpoint, its own flag, the same
      // issuer gate.
      canSendCustomer:
          gateway.customerConfigured &&
          roles.issuer &&
          !unsettled &&
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
          reference: requireWorkspaceTaxReference(ref),
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
