// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_config_report.dart';

/// Localized labels shared by the editable configuration report.
WorkspaceConfigPdfStrings workspaceConfigurationStrings(
  AppLocalizations l10n,
) => WorkspaceConfigPdfStrings(
  title: l10n.workspaceConfigPdfTitle,
  overview: l10n.workspaceConfigOverview,
  country: l10n.workspaceCountryLabel,
  currency: l10n.workspaceCurrencyLabel,
  timezone: l10n.workspaceTimezoneLabel,
  granularity: l10n.workspaceConfigGranularity,
  members: l10n.workspaceConfigMembersSection,
  colName: l10n.workspaceConfigColName,
  colRole: l10n.workspaceConfigColRole,
  colStatus: l10n.workspaceConfigColStatus,
  features: l10n.workspaceConfigFeatures,
  none: l10n.workspaceConfigNone,
  availability: l10n.workspaceConfigAvailability,
  openDays: l10n.workspaceConfigOpenDays,
  closures: l10n.workspaceConfigClosures,
  floorPlan: l10n.workspaceConfigFloorPlan,
  bookableWhole: l10n.workspaceConfigBookableWhole,
  seatsLabel: l10n.workspaceConfigSeats,
  emptyLevel: l10n.workspaceConfigEmptyLevel,
  levelBookable: (price) => price.isEmpty
      ? (l10n.levelBookableToggle)
      : '${l10n.levelBookableToggle}'
            ' — $price / '
            '${l10n.levelPriceLabel}',
  invitations: l10n.workspaceConfigInvitations,
  invitationCustomTemplate:
      l10n.workspaceConfigInvitationCustom,
  invitationDefault:
      l10n.workspaceConfigInvitationDefault,
  invitationSingleUse:
      l10n.workspaceConfigInvitationSingleUse,
  workingHours: l10n.availabilityWorkHoursTitle,
  vatRates: l10n.vatRatesTile,
  sites: l10n.sitesTitle,
);
