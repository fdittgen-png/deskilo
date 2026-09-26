// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_feature.dart';
import 'feature_names.dart';

/// #1659 — a capability's name in the reader's language: a feature by
/// its Features-screen name, a curated outcome by its own label.
String capabilityLabel(AppLocalizations? l10n, String id) {
  if (id.startsWith('feature.')) {
    final feature = WorkspaceFeature.values
        .where((f) => f.name == id.substring('feature.'.length))
        .firstOrNull;
    return feature == null ? id : featureName(l10n, feature);
  }
  return switch (id) {
    'policy.multi_approval' =>
      l10n?.capabilityMultiApproval ?? 'Two or more approvals',
    'policy.multi_approval_refunds' =>
      l10n?.capabilityRefundApprovals ?? 'Two approvals for refunds',
    'model.pay_as_you_go' => l10n?.capabilityPayAsYouGo ?? 'Pay as you go',
    'model.credit_packs' => l10n?.capabilityCreditPacks ?? 'Credit packs',
    'model.subscription_plans' =>
      l10n?.capabilitySubscriptionPlans ?? 'Subscription plans',
    'setting.opening_hours' => l10n?.capabilityOpeningHours ?? 'Opening hours',
    'setting.custom_member_form' =>
      l10n?.capabilityCustomMemberForm ?? 'Custom membership form',
    _ => id,
  };
}

/// The localized names the search vocabulary adds to its synonyms.
Map<String, List<String>> capabilityVocabularyLabels(AppLocalizations? l10n) => {
      for (final f in WorkspaceFeature.values)
        'feature.${f.name}': [featureName(l10n, f)],
      for (final id in const [
        'policy.multi_approval',
        'policy.multi_approval_refunds',
        'model.pay_as_you_go',
        'model.credit_packs',
        'model.subscription_plans',
        'setting.opening_hours',
        'setting.custom_member_form',
      ])
        id: [capabilityLabel(l10n, id)],
    };
