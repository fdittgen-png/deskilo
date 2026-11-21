// SPDX-License-Identifier: AGPL-3.0-or-later
import 'workspace_feature.dart';

/// #4004 — the organisation of a customer's businesses (decision 0052), and
/// (#4164) the billing customers, after the registry's parts and the stock
/// flags, in display order.
const Map<WorkspaceFeature, FeatureManifestEntry> organisationFeatureManifest =
    {
      // #4004 — the head business makes an organisation of a customer's
      // businesses, one house per country or currency (decision 0052). On by
      // default, in the core tier, so a new business has it: an owner who never
      // makes one sees nothing of it. Leaving an organisation and reading it
      // never depend on it.
      WorkspaceFeature.organisation: FeatureManifestEntry(
        feature: WorkspaceFeature.organisation,
        surface: FeatureSurface.settings,
        tier: FeatureTier.core,
      ),
      // #4164 — the billing customers (people and businesses invoiced with or
      // without an account) and the editor of their billing identity. Asked
      // for, under invoicing: a business that never invoices a customer
      // outside its members never sees it.
      WorkspaceFeature.billingCustomers: FeatureManifestEntry(
        feature: WorkspaceFeature.billingCustomers,
        surface: FeatureSurface.money,
        tier: FeatureTier.platform,
        requires: WorkspaceFeature.invoicing,
        defaultOn: false,
      ),
    };
