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
      // #4166 — the quotes a business makes to its billing customers, and
      // the one conversion of an accepted quote into an invoice. Asked for,
      // under invoicing.
      WorkspaceFeature.customerQuotes: FeatureManifestEntry(
        feature: WorkspaceFeature.customerQuotes,
        surface: FeatureSurface.money,
        tier: FeatureTier.platform,
        requires: WorkspaceFeature.invoicing,
        defaultOn: false,
      ),
      // #4178 — the engagement a service becomes once it is ordered: its
      // state and history, beside the quote and the invoice. Asked for, under
      // the billing customers it is owed to.
      WorkspaceFeature.serviceFulfilment: FeatureManifestEntry(
        feature: WorkspaceFeature.serviceFulfilment,
        surface: FeatureSurface.money,
        tier: FeatureTier.platform,
        requires: WorkspaceFeature.billingCustomers,
        defaultOn: false,
      ),
    };
