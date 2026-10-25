// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../application/accounting_export_source.dart';

export '../application/accounting_export_source.dart' show exportYearBooks;

/// [AccountingExportSource.read] for the export screen (#2365): the one
/// source of the run, read once by [read]. A refused source is said to the
/// person here, after the await, and nothing is exported; a failed read is
/// reported like any other guarded action.
Future<AccountingExportInput?> exportInputOrSay(
  BuildContext context,
  Future<AccountingExportInput?> Function() read,
) async {
  AccountingExportInput? input;
  final done = await runGuarded(
    context,
    domain: 'money',
    message: 'accounting source failed',
    errorText: context.l10n.commonSaveFailed,
    action: () async => input = await read(),
  );
  if (done && input == null && context.mounted) {
    AppSnack.error(context, context.l10n.accountingSourceRefused);
  }
  return done ? input : null;
}

/// A development workspace's books are marked as such (#936).
void noteDevelopmentBooks(BuildContext context, {required bool development}) {
  if (!development) return;
  AppSnack.info(context, context.l10n.accountingExportDevelopment);
}
