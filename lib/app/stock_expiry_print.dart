// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4431 (G17) -- the expiry report behind the stock's `StockExpiryPrinter` port: the report engine of the money feature
// renders and prints it (the `stock_expiry` kind: quick view, save or share, with the layout the business edits), and the
// stock never imports it. This is the composition root, as for a new item's service.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format/decimal_input.dart';
import '../core/i18n/format_controller.dart';
import '../core/l10n/context_l10n.dart';
import '../core/time/clock.dart';
import '../core/ui/print_or_retry.dart';
import '../features/money/domain/stock_expiry_report.dart';
import '../features/money/presentation/invoice_documents.dart';
import '../features/money/presentation/report_actions.dart';
import '../features/money/presentation/report_layout_actions.dart';
import '../features/stock/domain/stock_expiry.dart';
import '../features/stock/presentation/stock_expiry_printer.dart';
import '../features/workspace/providers/workspace_providers.dart';

class MoneyStockExpiryPrinter implements StockExpiryPrinter {
  const MoneyStockExpiryPrinter();

  @override
  Future<void> print(BuildContext context, WidgetRef ref, {required ExpiryReport report, required ExpiryQuery query}) =>
      printOrRetry(context, 'stock expiry report', () async {
        await readDocumentPolicies(ref); // the template, read
        if (!context.mounted) return;
        final l10n = context.l10n;
        final locale = appFormatOf(context).locale;
        final separator = decimalSeparatorOf(locale);
        final workspace = ref.read(currentWorkspaceProvider).value;
        final asOf = report.asOf ?? query.on ?? ref.read(clockProvider).now();
        final data = stockExpiryReportData(
          lines: [
            for (final r in report.rows)
              StockExpiryLine(
                item: r.itemName,
                variant: r.variantLabel,
                lot: r.lotCode,
                tag: r.tag,
                expiresOn: r.expiresOn,
                days: r.days,
                // the quantity as the reader writes it: its own decimal sign, no trailing zeros
                quantity: '${r.quantity.text.replaceAll('.', separator)} ${r.unit}'.trim(),
                place: r.locationName.isEmpty ? r.locationCode : '${r.locationCode} · ${r.locationName}',
              ),
          ],
          asOf: asOf,
          scope: query.scope.wire,
          locale: locale,
          letter: (workspace: workspace?.name ?? '', address: '', issuedBy: '', issued: ref.read(clockProvider).now()),
        );
        final rendered = renderLetterDoc(context, ref, docId: 'stock_expiry', data: data);
        final day = isoDay(asOf);
        await runReportActions(
          context,
          ref,
          keyPrefix: 'stock-expiry',
          logMessage: 'stock expiry report pdf failed',
          render: () => rendered,
          buildPdf: () async {
            final pdf = await letterDocPdf(
              context,
              ref,
              report: rendered,
              letter: PrintedLetter(kind: 'stock_expiry', title: l10n.reportDocStockExpiry),
              layoutXml: letterLayoutXml(ref, docId: 'stock_expiry'),
              data: data,
            );
            return (bytes: pdf.bytes, fileName: 'expiry-$day.pdf');
          },
        );
      });
}
