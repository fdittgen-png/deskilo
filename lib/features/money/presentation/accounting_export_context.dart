// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3432 -- the writer families that state the workspace's own tax reference
// (codes, rates, clocks) do not run on a guess: with the workspace context
// not ready the person is told before anything is built, instead of the tap
// doing nothing.
import '../../../core/ui/app_snack.dart';
import '../domain/accounting_format.dart';
import 'accounting_export_run.dart';
import 'invoice_actions.dart' show workspaceTaxReference;

const _needsWorkspaceReference = {
  ExportKind.sage,
  ExportKind.swissKmu,
  ExportKind.swissBanana,
  ExportKind.saft,
  ExportKind.saftPortugal,
  ExportKind.saftFinancial,
  ExportKind.archiveBundle,
  ExportKind.gobd,
};

extension AccountingExportContext on AccountingExportRun {
  /// Whether the chosen format needs the workspace's reference and it is not
  /// ready: the snack is shown and the export stops.
  bool refusedForMissingReference() {
    if (!_needsWorkspaceReference.contains(format.kind) ||
        workspaceTaxReference(ref) != null) {
      return false;
    }
    AppSnack.error(context, l10n.accountingExportContextNotReady);
    return true;
  }
}
