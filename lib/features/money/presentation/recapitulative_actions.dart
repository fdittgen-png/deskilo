// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/currencies.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/recapitulative_statement.dart';
import '../providers/money_providers.dart';
import 'invoice_actions.dart';
import '../../../core/time/date_text.dart';

/// #2354 — the recapitulative statement (EU sales list) of `[start,
/// end)` as a CSV file, from the issued invoices: what was reverse-charged
/// per customer VAT number and month.
Future<void> saveRecapitulativeCsv(
  BuildContext context,
  WidgetRef ref, {
  required DateTime start,
  required DateTime end,
  required String currency,
}) async {
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('en'));
  final invoices = await ref.read(invoicesProvider.future);
  if (!context.mounted) return;
  final lines = recapitulativeStatement(invoices, from: start, to: end);
  if (lines.isEmpty) {
    AppSnack.info(context, l10n.recapEmpty);
    return;
  }
  final csv = recapitulativeCsv(
    lines,
    minorDigits: Currencies.minorDigits(currency),
  );
  String day(DateTime d) =>
      isoDay(d);
  await savePdfToDownloads(
    context,
    ref,
    bytes: Uint8List.fromList(utf8.encode(csv)),
    fileName: 'eu-sales-list-${day(start)}.csv',
  );
}
