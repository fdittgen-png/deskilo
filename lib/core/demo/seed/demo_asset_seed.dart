// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 — the demo space's equipment: the espresso machine of the kitchen,
// capitalised and in use; a second machine still waiting for its treatment;
// and one purchase line nobody has registered yet.
import '../../../features/money/domain/workspace_asset.dart';
import '../data/workspace_asset_repository.dart';

FakeWorkspaceAssetRepository seedDemoAssets(DateTime now) =>
    FakeWorkspaceAssetRepository(
      assets: [
        WorkspaceAsset(
          id: 'demo-asset-machine',
          revision: 2,
          assetNumber: 1,
          description: 'Espresso machine, kitchen',
          currency: 'EUR',
          acquisitionCostCents: 120000,
          supplierName: 'Café du Midi',
          originalReference: 'CM-2026-014',
          decision: AssetDecision.capitalise,
          decisionBasis: 'Lasting equipment: used for years, above the space policy',
          state: AssetState.inUse,
          availableForUseOn: DateTime(now.year, 3),
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
