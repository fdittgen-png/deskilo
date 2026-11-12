// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 — the demo space's valuations: the accountant's book values for last
// year (confirmed, the espresso machine depreciated by 240.00) and a file
// for this year still waiting for confirmation, with the printer unknown.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import '../../../features/money/domain/asset_valuation.dart';
import '../data/asset_valuation_repository.dart';
import 'demo_asset_seed.dart';
import 'demo_purchase_history_seed.dart';

@visibleForTesting
FakeAssetValuationRepository seedDemoValuations(DateTime now) =>
    FakeAssetValuationRepository(
      batches: [
        ValuationBatch(
          id: 'demo-valuation-last',
          revision: 2,
          basis: ValuationBasis.book,
          sourceSystem: 'Cabinet Martin',
          sourceReference: 'FY${now.year - 1}',
          periodFrom: DateTime(now.year - 1),
          periodTo: DateTime(now.year - 1, 12, 31),
          currency: 'EUR',
          movements: 'period',
          completeScope: true,
          status: ValuationStatus.confirmed,
          rowCount: 1,
        ),
      ],
      rows: const {
        'demo-valuation-last': [
          ValuationRow(
            assetId: 'demo-asset-machine',
            assetNumber: 1,
            description: 'Espresso machine, kitchen',
            externalReference: 'FA-0001',
            openingMinor: 120000,
            additionsMinor: 0,
            disposalsMinor: 0,
            depreciationMinor: 24000,
            impairmentMinor: 0,
            closingMinor: 96000,
            bridge: ValuationBridge.ok,
          ),
        ],
      },
    );

/// The months over which the espresso machine is depreciated.
const _machineLifeMonths = 60;

/// #3794 — the valuations with this year's monthly closing: for each month
/// of this year before this one, from the month the machine came into use,
/// the accountant's confirmed book values with the month's movements, the
/// machine depreciated straight-line over five years. The month under way
/// is not closed yet: its depreciation is unknown, and the analysis says
/// why.
FakeAssetValuationRepository seedDemoBookValues(DateTime now) {
  final repo = seedDemoValuations(now);
  final inUse = demoEquipmentInUseOn(now);
  const monthly = demoMachineCostCents ~/ _machineLifeMonths;
  for (
    var month = inUse.year < now.year ? DateTime(now.year) : inUse;
    month.isBefore(DateTime(now.year, now.month));
    month = DateTime(month.year, month.month + 1)
  ) {
    final period = yearMonth(month.year, month.month);
    final elapsed = (month.year - inUse.year) * 12 + month.month - inUse.month;
    final opening = demoMachineCostCents - monthly * elapsed;
    final id = 'demo-valuation-$period';
    repo.batches.add(
      ValuationBatch(
        id: id,
        revision: 2,
        basis: ValuationBasis.book,
        sourceSystem: 'Cabinet Martin',
        sourceReference: period,
        periodFrom: month,
        periodTo: DateTime(month.year, month.month + 1, 0),
        currency: 'EUR',
        movements: 'period',
        completeScope: true,
        status: ValuationStatus.confirmed,
        rowCount: 1,
      ),
    );
    repo.rows[id] = [
      ValuationRow(
        assetId: 'demo-asset-machine',
        assetNumber: 1,
        description: 'Espresso machine, kitchen',
        externalReference: 'FA-0001',
        openingMinor: elapsed == 0 ? 0 : opening,
        additionsMinor: elapsed == 0 ? demoMachineCostCents : 0,
        disposalsMinor: 0,
        depreciationMinor: monthly,
        impairmentMinor: 0,
        closingMinor: opening - monthly,
        bridge: ValuationBridge.ok,
      ),
    ];
  }
  return repo;
}
