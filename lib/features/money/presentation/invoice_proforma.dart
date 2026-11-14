// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The proforma: the month as a quote, before anything is issued.
//
// It lived in `invoice_actions.dart` and moved out under #1125 — that
// file was at its length budget and one import pushed it over, which is
// the moment the house rule says to extract rather than raise the
// number. The proforma is the right seam: two functions, one concern,
// and the only callers are on the invoices screen.
import 'dart:typed_data';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/print_or_retry.dart';
import '../../profile/domain/personal_info.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/invoice_report.dart';
import '../domain/report_data.dart';
import '../providers/money_providers.dart';
import 'invoice_actions.dart' show workspaceTaxReference;
import 'invoice_document_locale.dart';
import 'invoice_documents.dart';
import 'report_actions.dart';
import 'report_defaults.dart';
import 'report_layout_actions.dart';

/// Renders the month as a PROFORMA and hands it to the share sheet — the
/// quote an issuer sends before invoicing, and the payment request they
/// can re-send afterwards. Nothing is issued, nothing is booked.
Future<void> shareProforma(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) =>
    // #3742 — the document's policies are read first, under the print guard.
    printOrRetry(context, 'proforma', () async {
      await readDocumentPolicies(ref);
      if (!context.mounted) return;
    final l10n = context.l10n;
    if (!invoice.lines.any((line) => line.amountCents > 0)) {
      AppSnack.info(
        context,
        l10n.invoiceProformaNothing,
      );
      return;
    }
    // The workspace's own reference states the mentions: without it the person
    // is told, not left with a dead tap.
    final reference = workspaceTaxReference(ref);
    if (reference == null) {
      AppSnack.error(context, l10n.workspaceTaxContextNotReady);
      return;
    }
    // #514 — quick view / save / share, like every report exit.
    await runReportActions(
      context,
      ref,
      keyPrefix: 'proforma',
      logMessage: 'proforma share failed',
      render: () {
        // #3850 — a proforma has no frozen language: the business's.
        final locale = businessDocumentLocale(ref);
        final template = invoicePdfTemplateFor(ref).forLocale(locale.language);
        var bands = template.proformaBands ?? template.invoiceBands;
        if (!bands.hasBands) bands = defaultBandsForDoc('proforma', l10nForLanguage(locale.language));
        return renderReportBands(
          bands: bands,
          data: withOwnerTexts(
            invoiceReportData(
              documentStringsOf(locale),
              invoice,
              memberTerms: memberTermsFor(ref, invoice.memberId),
              memberCapacity: memberCapacityFor(ref, invoice.memberId),
          dueAt: invoiceDueAt(ref, invoice),
              proforma: true,
              copy: false,
              workspace: ref.read(currentWorkspaceProvider).value, reference: reference,
            ),
            template.texts,
          ),
        );
      },
      buildPdf: () async {
        final pdf = await buildInvoicePdfFile(
          context,
          invoice,
      InvoicePdfFileOptions(reference: reference,
        // #920 — through layoutImage, so the shipped layouts' `logo`
        // resolves to whatever the owner actually called theirs.
        reportImage: (String name) => layoutImage(ref, name),
        memberTerms: memberTermsFor(ref, invoice.memberId),
              memberCapacity: memberCapacityFor(ref, invoice.memberId),
          dueAt: invoiceDueAt(ref, invoice),
          proforma: true,
          template: invoicePdfTemplateFor(ref),
          workspace: ref.read(currentWorkspaceProvider).value));
        return (bytes: Uint8List.fromList(pdf.bytes), fileName: pdf.fileName);
      },
    );
    });

/// Builds the proforma of a month that has NOT been invoiced yet: the
/// server's own derivation (the same RPC the issue sheet previews) dressed
/// in the live workspace and member identity. Returns null when the month
/// tracked nothing.
Future<Invoice?> proformaForMonth(
  WidgetRef ref, {
  required String memberId,
  required String period,

  /// #3883 — a number outside the invoice sequence for a sandbox test
  /// document; '' (nothing issued) otherwise.
  String number = '',
}) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return null;
  final preview = await ref
      .read(invoiceQueriesProvider)
      .previewInvoice(
        workspaceId: workspace.id,
        memberId: memberId,
        period: period,
      );
  if (preview.lines.isEmpty) return null;
  final names = await ref.read(memberNamesProvider.future);
  final members = await ref.read(workspaceMembersProvider.future);
  final member = members.where((m) => m.id == memberId).firstOrNull;
  final profiles = await ref.read(memberProfilesProvider.future);
  final profile = member == null || member.isManaged
      ? null
      : profiles[member.userId];
  // #886 — the preview names and addresses the buyer the way
  // create_invoice will freeze them, so the proforma and the invoice
  // put the same block in the envelope window.
  // #887 — a managed member is named from the identity the admin typed.
  final identity =
      profile?.identity ?? member?.managedIdentity ?? PersonalInfo.empty;
  final fullName = profile?.fullName ?? identity.fullName;
  return Invoice(
    // No id and no number: nothing was issued.
    id: '',
    workspaceId: workspace.id,
    memberId: memberId,
    number: number,
    issuedAt: ref.read(clockProvider).now(),
    period: period,
    title: period,
    lines: preview.lines,
    totalCents: preview.totalCents,
    currency: workspace.currencyCode,
    memberName: fullName.isNotEmpty ? fullName : names[memberId] ?? '',
    memberAddress:
        profile?.postalBlock(
          workspaceCountry: workspace.countryCode,
          nameAbove: fullName,
        ) ??
        identity.postalBlock(
          workspaceCountry: workspace.countryCode,
          nameAbove: fullName,
        ),
    buyerParty: profile == null && identity.isEmpty
        ? null
        : InvoiceParty(
            name: fullName.isNotEmpty ? fullName : names[memberId] ?? '',
            company: identity.company,
            street: identity.street.isNotEmpty
                ? identity.street
                : profile?.address ?? '',
            postalCode: identity.postalCode,
            city: identity.city,
            country: identity.countryCode.isNotEmpty
                ? identity.countryCode
                : workspace.countryCode,
            vatId: identity.vatId,
            legalId: identity.legalId,
            email: identity.email,
            phone: identity.phone,
          ),
    workspaceName: workspace.name,
    workspaceAddress: workspace.address,
    issuerName: '',
    signature: '',
  );
}
