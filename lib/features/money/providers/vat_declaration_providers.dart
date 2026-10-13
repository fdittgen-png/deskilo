// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/files/file_saver.dart';
import '../../../core/time/clock.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/save_vat_filing_file.dart';
import '../domain/invoice_legal.dart';
import '../domain/vat_declaration.dart';
import '../domain/vat_filing_files.dart';
import 'money_providers.dart';

part 'vat_declaration_providers.g.dart';

/// The workspace's VAT declarations (0107), newest period first. Own
/// file so money_providers.dart stays at its file_length snapshot.
@riverpod
Future<List<VatDeclaration>> vatDeclarations(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(moneyRepositoryProvider)
      .fetchVatDeclarations(workspace.id);
}

/// #2357 — saving the filing file of a return, for the space as it is.
@riverpod
SaveVatFilingFile saveVatFilingFile(Ref ref) {
  final w = ref.watch(currentWorkspaceProvider).value;
  final clock = ref.watch(clockProvider);
  return SaveVatFilingFile(
    ref.watch(fileSaverProvider),
    clock.now,
    party: w == null
        ? null
        : VatFilingParty(
            countryCode: w.countryCode,
            name: w.name,
            street: w.street,
            postalCode: w.postalCode,
            city: w.city,
            vatId: w.vatId,
            legalId: w.legalId,
            onReceipts: InvoiceLegal.fromJson(w.invoiceLegal)
                .taxPointBasis(w.countryCode)
                .onReceipts,
          ),
  );
}
