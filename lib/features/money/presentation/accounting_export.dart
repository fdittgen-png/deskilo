// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/print_or_retry.dart';
import 'accounting_export_run.dart';

/// THE ACCOUNTING EXPORT (0074, extended by #669).
///
/// Its own file because it is its own concern — and because
/// invoice_actions.dart was at its length budget to the line, which is
/// the gate doing its job rather than an obstacle to route around.
///
/// Everything here is driven by the registry in
/// `domain/accounting_format.dart`, and that indirection earns its keep:
/// the registry is the single place that says what each file CLAIMS
/// about itself, so a new format cannot be added without someone
/// deciding whether it is a regulatory filing, an accountant exchange or
/// a declared subset. Wiring formats up ad hoc is how one eventually
/// ships claiming more than it can support.
///
/// The files go to Downloads: they are destined for someone else's
/// software.
Future<void> exportAccountingFile(
  BuildContext context,
  WidgetRef ref,
  List<Invoice> invoices, {
  required String label,
}) {
  final run = AccountingExportRun(context, ref, invoices, label: label);
  return printOrRetry(context, 'accounting export', run.start,
      refresh: run.refreshSources);
}
