// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 — the VAT number check and the analysis export of the reference
// business, as the scenario checklist performs them.
import 'package:deskilo/features/money/domain/vies_check.dart';
import 'package:deskilo/features/money/providers/vies_providers.dart';
import 'package:deskilo/features/workspace/application/bi_snapshot_export.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_snapshot.dart';
import 'package:deskilo/features/workspace/providers/workbook_export_providers.dart';

import 'bi_report_fixture.dart';
import 'demo_outbox_journeys.dart';

/// Ada checks three customers' VAT numbers: one valid, one invalid, and one
/// whose member state does not answer; what the page reads is what was
/// recorded.
Future<bool> viesJourney() => withDemoSession((f, o, c) async {
  final vies = c.read(viesRepositoryProvider);
  final valid = await vies.checkVies('ws-1', 'member-1');
  final invalid = await vies.checkVies('ws-1', 'member-2');
  final outage = await vies.checkVies('ws-1', 'member-3');
  return valid.status == ViesStatus.valid &&
      valid.consultation.isNotEmpty &&
      invalid.status == ViesStatus.invalid &&
      outage.status == ViesStatus.unavailable &&
      (await vies.fetchViesCheck('member-1')).status == ViesStatus.valid &&
      (await vies.fetchViesCheck('member-3')).status == ViesStatus.unavailable;
});

/// The report of the Demo is exported for last month: the snapshot holds
/// euros only, the figure the Demo does not answer is left out and said, and
/// the same ask is the same snapshot.
Future<bool> exportJourney() => withDemoSession((f, o, c) async {
  final month = BiPeriod(BiGrain.month, f.seededAt.year, f.seededAt.month - 1);
  final plan = biSnapshotPlan(
    fixtureReport(),
    period: month,
    seriesLength: 3,
    window: fixtureWindow,
    limit: 60,
  );
  final export = BiSnapshotExport(
    c.read(biExportRepositoryProvider),
    isCurrent: () => true,
  );
  Future<BiReportSnapshot> take() =>
      export.take(plan, source: fixtureSource, format: BiExportFormat.csv);
  final a = await take();
  final b = await take();
  final money = a.visuals
      .expand((v) => v.figures)
      .where((x) => x.currency.isNotEmpty);
  return money.isNotEmpty &&
      money.every((m) => m.currency == 'EUR') &&
      a.plan.leftOut.any((l) => l.visual.id == 'v6') &&
      a.hash == b.hash;
});
