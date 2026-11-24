// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4009 — what is performed in a HOUSE of the reference organisation, because
// the feature is tied to that house's country: the United Kingdom's tax
// submission in London and the United States' sales tax in New York.
import 'package:deskilo/core/demo/demo_london_space.dart';
import 'package:deskilo/core/demo/demo_new_york_space.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/hmrc_submission.dart';
import 'package:deskilo/features/money/domain/mtd_boxes.dart';
import 'package:deskilo/features/money/domain/sales_tax_return.dart';
import 'package:deskilo/features/money/providers/sales_tax_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _client = HmrcClientValues(
  browserJsUserAgent: 'Demo',
  deviceId: 'd',
  timezone: 'UTC+00:00',
  screens: 's',
  windowSize: 'w',
  doNotTrack: false,
);

/// Ada connects London to HMRC (the sign-in is simulated), submits the
/// prepared return of the last closed quarter once and reads the receipt;
/// the receipt says Demo, the return is filed as HMRC's, and a second
/// submission is refused.
Future<bool> mtdSubmissionJourney(DemoLondonData london) async {
  final declaration = london.money.vatDeclarations.single;
  if (!declaration.isPrepared) return false;
  final hmrc = london.hmrc;
  await hmrc.startConnect(demoLondonSpaceId, demoLondonSiteId);
  final connection = (await hmrc.state(demoLondonSpaceId)).connection!;
  final marker = (await hmrc.state(demoLondonSpaceId))
      .recoveryMarkers[declaration.id];
  final boxes = mtdBoxPounds(
    declaration,
    reference: ActiveTaxReference.current,
  );
  Future<CommandOutcome<HmrcFiling>> submit() => hmrc.submit(
    declarationId: declaration.id,
    connectionId: connection.id,
    boxes: boxes,
    client: _client,
    recoveryMarker: marker,
  );
  final outcome = await submit();
  final filed = london.money.vatDeclarations.single;
  final filing = hmrcFilingOf(outcome);
  return filing != null &&
      filing.recorded &&
      filing.demo &&
      filing.receipt.formBundleNumber.startsWith('DEMO-') &&
      filed.status == 'filed' &&
      filed.submittedChannel == 'hmrc_mtd' &&
      filed.submittedReceipt == filing.receipt.formBundleNumber &&
      hmrcRefusalOf(await submit()) != null;
}

/// Ada reads New York's sales-tax return of the last full month, as the
/// server states it from the house's invoices (0439): what the invoices froze
/// as taxed, the tax collected per jurisdiction, and what is outside the tax
/// (a licence to occupy space). Every figure is checked against the invoices
/// themselves, in dollars, and a period without invoices states nothing.
Future<bool> salesTaxJourney(
  DemoNewYorkData newYork,
  ProviderContainer container,
  DateTime now,
) async {
  final start = DateTime(now.year, now.month - 1);
  final end = DateTime(now.year, now.month).subtract(const Duration(days: 1));
  final repository = container.read(salesTaxRepositoryProvider);
  final rows = await repository.fetchReturn('ws-4', start: start, end: end);
  final invoices = [
    for (final i in newYork.money.invoices)
      if (i.voidedAt == null &&
          !DateTime(i.issuedAt.year, i.issuedAt.month, i.issuedAt.day)
              .isBefore(start) &&
          !DateTime(i.issuedAt.year, i.issuedAt.month, i.issuedAt.day)
              .isAfter(end))
        i,
  ];
  final totals = [
    for (final i in invoices)
      for (final t in i.vatTotals)
        if (t.isSalesTax) t,
  ];
  int sum(Iterable<int> v) => v.fold(0, (a, b) => a + b);
  final taxed = totals.where((t) => t.category == 'S').toList();
  final outside = totals.where((t) => t.category == 'O').toList();
  final exempt = totals.where((t) => t.category == 'E').toList();
  Iterable<SalesTaxReturnRow> of(SalesTaxLine l) =>
      rows.where((r) => r.line == l);
  final taxable = of(SalesTaxLine.taxable).single;
  final out = of(SalesTaxLine.outside).single;
  final jurisdictions = of(SalesTaxLine.tax).toList();
  final components = [for (final t in taxed) ...t.components];
  final names = {for (final c in components) c.name};
  final net = sum(invoices.map((i) => i.netCents));
  final csv = await container
      .read(salesTaxCommandsProvider)
      .worksheetCsv(
        workspaceId: 'ws-4',
        currency: 'USD',
        start: start,
        end: end,
      );
  final empty = await repository.fetchReturn(
    'ws-4',
    start: DateTime(now.year + 5),
    end: DateTime(now.year + 5, 2),
  );
  return invoices.every((i) => i.currency == 'USD') &&
      invoices.isNotEmpty &&
      invoices.every(
        (i) => i.vatTotals.isNotEmpty && i.vatTotals.every((t) => t.isSalesTax),
      ) &&
      taxed.isNotEmpty &&
      outside.isNotEmpty &&
      taxable.baseCents == sum(taxed.map((t) => t.netCents)) &&
      taxable.taxCents == sum(taxed.map((t) => t.vatCents)) &&
      taxable.invoiceCount == taxed.length &&
      out.baseCents == sum(outside.map((t) => t.netCents)) &&
      out.taxCents == 0 &&
      names.length == 3 &&
      jurisdictions.length == names.length &&
      jurisdictions.every(
        (r) =>
            r.taxCents ==
                sum(
                  components
                      .where((c) => c.name == r.name)
                      .map((c) => c.taxCents),
                ) &&
            r.baseCents ==
                sum(
                  components
                      .where((c) => c.name == r.name)
                      .map((c) => c.baseCents),
                ),
      ) &&
      taxable.taxCents == sum(jurisdictions.map((r) => r.taxCents)) &&
      taxable.baseCents + sum(exempt.map((t) => t.netCents)) + out.baseCents ==
          sum(totals.map((t) => t.netCents)) &&
      sum(totals.map((t) => t.netCents)) == net &&
      empty.isEmpty &&
      csv != null &&
      csv.contains('"NY",taxable') &&
      csv.contains('"NY",outside') &&
      csv.contains('"New York City"');
}
