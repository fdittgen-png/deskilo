// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 — the demo space's equipment: the espresso machine of the kitchen,
// capitalised and in use; a second machine still waiting for its treatment;
// and one purchase line nobody has registered yet. #3794 — this month's
// meeting-room screen, capitalised and in use from the first of the month.
import '../../../features/money/domain/workspace_asset.dart';
import '../data/workspace_asset_repository.dart';
import 'demo_purchase_history_seed.dart';

/// What the espresso machine cost, net of its recovered VAT.
const demoMachineCostCents = 120000;

FakeWorkspaceAssetRepository seedDemoAssets(DateTime now) =>
    FakeWorkspaceAssetRepository(
      assets: [
        WorkspaceAsset(
          id: 'demo-asset-machine',
          revision: 2,
          assetNumber: 1,
          description: 'Espresso machine, kitchen',
          currency: 'EUR',
          acquisitionCostCents: demoMachineCostCents,
          supplierName: 'Café du Midi',
          originalReference: 'CM-2026-014',
          decision: AssetDecision.capitalise,
          decisionBasis: 'Lasting equipment: used for years, above the space policy',
          state: AssetState.inUse,
          availableForUseOn: demoEquipmentInUseOn(now),
          purchaseId: 'demo-purchase-machine',
          lineNo: 1,
        ),
        const WorkspaceAsset(
          id: 'demo-asset-printer',
          revision: 1,
          assetNumber: 2,
          description: 'Colour printer, reception',
          currency: 'EUR',
          acquisitionCostCents: 48000,
          supplierName: 'Bureau Plus',
          originalReference: 'BP-8841',
          decision: AssetDecision.pending,
          state: AssetState.candidate,
          purchaseId: 'demo-purchase-printer',
          lineNo: 1,
        ),
        WorkspaceAsset(
          id: 'demo-asset-screen',
          revision: 2,
          assetNumber: 3,
          description: 'Screen, meeting room',
          currency: 'EUR',
          acquisitionCostCents: 90000,
          supplierName: 'Bureau Plus',
          originalReference: 'BP-9107',
          decision: AssetDecision.capitalise,
          decisionBasis: 'Lasting equipment: used for years, above the space policy',
          state: AssetState.inUse,
          availableForUseOn: demoScreenInUseOn(now),
          purchaseId: 'demo-purchase-screen',
          lineNo: 1,
        ),
      ],
      lines: const [
        AssetCandidateLine(
          purchaseId: 'demo-purchase-ladder',
          lineNo: 2,
          description: 'Folding ladder',
          grossCents: 18900,
          currency: 'EUR',
          supplierName: 'Bricolage Pézenas',
          originalReference: 'BP-3320',
        ),
      ],
    );
