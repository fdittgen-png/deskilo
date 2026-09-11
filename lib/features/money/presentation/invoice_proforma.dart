// SPDX-License-Identifier: 0BSD
//
// The proforma: the month as a quote, before anything is issued.
//
// It lived in `invoice_actions.dart` and moved out under #1125 — that
// file was at its length budget and one import pushed it over, which is
// the moment the house rule says to extract rather than raise the
// number. The proforma is the right seam: two functions, one concern,
// and the only callers are on the invoices screen.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../members/providers/directory_providers.dart';
import '../../profile/domain/personal_info.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../domain/invoice.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/invoice_report.dart';
import '../providers/money_providers.dart';
import 'invoice_actions.dart';
import 'report_strings_l10n.dart';
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
) async {
  final l10n = AppLocalizations.of(context);
  if (!invoice.lines.any((line) => line.amountCents > 0)) {
    AppSnack.info(
      context,
      l10n?.invoiceProformaNothing ??
          'Nothing tracked for this month — no proforma to send.',
    );
    return;
  }
  // #514 — quick view / save / share, like every report exit.
  await runReportActions(
    context,
    ref,
    keyPrefix: 'proforma',
    logMessage: 'proforma share failed',
    render: () {
      final template = invoicePdfTemplateFor(ref);
      var bands = template.proformaBands ?? template.invoiceBands;
      if (!bands.hasBands) bands = defaultBandsForDoc('proforma', l10n);
      return renderReportBands(
        bands: bands,
        data: withOwnerTexts(
          invoiceReportData(
            reportStringsFor(context),
            invoice,
            memberTerms: memberTermsFor(ref, invoice.memberId),
        dueAt: invoiceDueAt(ref, invoice),
            proforma: true,
            copy: false,
            workspace: ref.read(currentWorkspaceProvider).value,
          ),
          template.texts,
        ),
      );
    },
    buildPdf: () async {
      final pdf = await buildInvoicePdfFile(
        context,
        invoice,
        memberTerms: memberTermsFor(ref, invoice.memberId),
        dueAt: invoiceDueAt(ref, invoice),
        proforma: true,
        template: invoicePdfTemplateFor(ref),
        workspace: ref.read(currentWorkspaceProvider).value,
        // #920 — through layoutImage, so the shipped layouts' `logo`
    // resolves to whatever the owner actually called theirs.
    reportImage: (name) => layoutImage(ref, name),
      );
      return (bytes: Uint8List.fromList(pdf.bytes), fileName: pdf.fileName);
    },
  );
}

/// Builds the proforma of a month that has NOT been invoiced yet: the
/// server's own derivation (the same RPC the issue sheet previews) dressed
/// in the live workspace and member identity. Returns null when the month
/// tracked nothing.
Future<Invoice?> proformaForMonth(
  WidgetRef ref, {
  required String memberId,
  required String period,
}) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return null;
  final preview = await ref
      .read(moneyRepositoryProvider)
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
    number: '',
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
