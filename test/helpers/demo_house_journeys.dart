// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4009 — what is performed in a HOUSE of the reference organisation, because
// the feature is tied to that house's country: the United Kingdom's tax
// submission in London and the United States' sales tax in New York.
import 'package:deskilo/core/demo/demo_london_space.dart';
import 'package:deskilo/core/demo/demo_new_york_space.dart';
import 'package:deskilo/core/demo/seed/demo_london_seed.dart';
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
  Future<HmrcOutcome> submit() => hmrc.submit(
    declarationId: declaration.id,
    connectionId: connection.id,
    boxes: boxes,
    client: _client,
    recoveryMarker: marker,
  );
  final outcome = await submit();
  final filed = london.money.vatDeclarations.single;
  return outcome is HmrcFiled &&
      outcome.demo &&
      outcome.receipt.formBundleNumber.startsWith('DEMO-') &&
      filed.status == 'filed' &&
      filed.submittedChannel == 'hmrc_mtd' &&
      filed.submittedReceipt == outcome.receipt.formBundleNumber &&
      await submit() is HmrcRefused;
}

/// Ada reads New York's sales-tax return of the last month, in dollars:
/// the base is the house's own invoices of the period and the tax each
/// jurisdiction's rate on it; a period without invoices states nothing, and
/// the worksheet she keys into the state portal is in dollars.
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
          !i.issuedAt.isBefore(start) &&
          i.issuedAt.isBefore(end.add(const Duration(days: 1))))
        i,
  ];
  if (rows.isEmpty || invoices.isEmpty) return false;
  final taxable = rows.singleWhere((r) => r.line == SalesTaxLine.taxable);
  final jurisdictions = rows.where((r) => r.line == SalesTaxLine.tax).toList();
  final net = invoices.fold<int>(0, (sum, i) => sum + i.netCents);
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
      taxable.baseCents == net &&
      taxable.invoiceCount == invoices.length &&
      jurisdictions.length == 3 &&
      jurisdictions.every((r) => r.baseCents == net) &&
      taxable.taxCents ==
          jurisdictions.fold<int>(0, (sum, r) => sum + r.taxCents) &&
      jurisdictions.every(
        (r) => (r.baseCents * r.percent / 100).round() == r.taxCents,
      ) &&
      empty.isEmpty &&
      csv != null &&
      csv.contains('"NY",taxable');
}
