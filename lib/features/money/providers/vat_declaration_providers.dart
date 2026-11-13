// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/files/file_saver.dart';
import '../../../core/time/clock.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/save_vat_filing_file.dart';
import '../application/vat_register_files.dart';
import '../domain/accounting_view.dart';
import '../domain/vat_filing_files.dart';
import '../domain/vat_return_documents.dart';
import 'money_providers.dart';

part 'vat_declaration_providers.g.dart';

/// The workspace's VAT declarations (0107), newest period first. Own
/// file so money_providers.dart stays at its file_length snapshot.
@riverpod
Future<List<VatDeclaration>> vatDeclarations(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(taxReportingRepositoryProvider)
      .fetchVatDeclarations(workspace.id);
}

/// #2357 — saving the filing file of a return, for the space as it is.
@riverpod
SaveVatFilingFile saveVatFilingFile(Ref ref) {
  final w = ref.watch(currentWorkspaceProvider).value;
  final reference = ref.watch(readyWorkspaceContextProvider)?.taxReference.set;
  final clock = ref.watch(clockProvider);
  return SaveVatFilingFile(
    ref.watch(fileSaverProvider),
    clock.now,
    reference: reference,
    // No party until the workspace's own tax reference is ready: the basis
    // the file is stated on comes from it.
    party: w == null || reference == null
        ? null
        : VatFilingParty(
            countryCode: w.countryCode,
            name: w.name,
            street: w.street,
            postalCode: w.postalCode,
            city: w.city,
            vatId: w.vatId,
            legalId: w.legalId,
            onReceipts: taxPointBasisOf(
              InvoiceLegal.fromJson(w.invoiceLegal),
              w.countryCode,
              reference: reference,
            ).onReceipts,
          ),
  );
}

/// The registers and the annual summary of a Spanish or an Italian space,
/// read from the issued documents and the returns when a file is asked for.
@riverpod
VatRegisterFiles vatRegisterFiles(Ref ref) => VatRegisterFiles(
  party: ref.watch(saveVatFilingFileProvider).party,
  invoices: () => ref.read(invoicesProvider.future),
  declarations: () => ref.read(vatDeclarationsProvider.future),
  reference: ref.watch(readyWorkspaceContextProvider)?.taxReference.set,
  monthly: switch (ref.watch(currentWorkspaceProvider).value) {
    final w? =>
      InvoiceLegal.fromJson(w.invoiceLegal).filingPeriod ==
          VatDeclarationPeriod.month,
    null => false,
  },
);

/// #3616 — the period's tax points read again from the issued invoices,
/// on the space's basis and with the payments the return used (the same
/// engine as the VAT report): what a return's boxes are compared with.
/// Every invoice's points; a return keeps the ones of its period.
final vatTaxPointsTodayProvider =
    FutureProvider.autoDispose<List<VatTaxPointAmount>>((ref) async {
      final workspace = await ref.watch(currentWorkspaceProvider.future);
      final context = ref.watch(readyWorkspaceContextProvider);
      if (workspace == null || context == null) return const [];
      final reference = context.taxReference.set;
      final view = accountingView(
        await ref.watch(invoicesProvider.future),
        await ref.watch(invoiceMatchesProvider.future),
      );
      final instalments = await ref
          .read(invoiceQueriesProvider)
          .fetchInvoiceInstalments(workspace.id);
      return vatTaxPointLedger(
        view.invoices,
        matches: view.matches,
        instalments: instalments,
        basis: taxPointBasisOf(
          InvoiceLegal.fromJson(workspace.invoiceLegal),
          workspace.countryCode,
          reference: reference,
        ),
        reference: reference,
        dayOf: context.calendar.dateOf,
      );
    });

/// #3616 — the return [declarationId] with the documents behind each of its
/// boxes; null while it is not found among the space's returns.
final vatReturnBoxesProvider = FutureProvider.autoDispose
    .family<({VatDeclaration declaration, List<VatBoxDocuments> boxes})?, String>(
      (ref, declarationId) async {
        final declarations = await ref.watch(vatDeclarationsProvider.future);
        final declaration = declarations
            .where((d) => d.id == declarationId)
            .firstOrNull;
        final workspace = await ref.watch(currentWorkspaceProvider.future);
        final reference = ref.watch(readyWorkspaceContextProvider)?.taxReference.set;
        if (declaration == null || workspace == null || reference == null) {
          return null;
        }
        return (
          declaration: declaration,
          boxes: vatBoxDocuments(
            declaration,
            await ref.watch(vatTaxPointsTodayProvider.future),
            country: workspace.countryCode,
            reference: reference,
          ),
        );
      },
    );
