// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3432/#3403 -- every accounting export states the workspace's own tax
// reference (the tax-point basis of its ledger, the codes and rates of its
// writer): with the workspace context not ready the person is told before
// anything is built, instead of the tap doing nothing.
import '../../../core/ui/app_snack.dart';
import 'accounting_export_run.dart';
import 'invoice_actions.dart' show workspaceTaxReference;

extension AccountingExportContext on AccountingExportRun {
  /// Whether the workspace's reference is not ready: the snack is shown and
  /// the export stops.
  bool refusedForMissingReference() {
    final ready = workspaceTaxReference(ref);
    if (ready == null) {
      AppSnack.error(context, l10n.accountingExportContextNotReady);
      return true;
    }
    // Read once: every later step of this run states this reference, even if
    // the context goes away while the books load.
    taxReference = ready;
    return false;
  }
}
