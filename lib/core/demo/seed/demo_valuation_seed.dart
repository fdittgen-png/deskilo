// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 — the demo space's valuations: the accountant's book values for last
// year (confirmed, the espresso machine depreciated by 240.00) and a file
// for this year still waiting for confirmation, with the printer unknown.
import '../../../features/money/domain/asset_valuation.dart';
import '../data/asset_valuation_repository.dart';

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
