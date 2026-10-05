// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_config_report.dart';

/// Localized labels shared by the editable configuration report.
WorkspaceConfigPdfStrings workspaceConfigurationStrings(
  AppLocalizations? l10n,
) => WorkspaceConfigPdfStrings(
  title: l10n?.workspaceConfigPdfTitle ?? 'Workspace configuration',
  overview: l10n?.workspaceConfigOverview ?? 'Overview',
  country: l10n?.workspaceCountryLabel ?? 'Country',
  currency: l10n?.workspaceCurrencyLabel ?? 'Currency',
  timezone: l10n?.workspaceTimezoneLabel ?? 'Time zone',
  granularity: l10n?.workspaceConfigGranularity ?? 'Booking granularity',
  members: l10n?.workspaceConfigMembersSection ?? 'Members',
  colName: l10n?.workspaceConfigColName ?? 'Name',
  colRole: l10n?.workspaceConfigColRole ?? 'Role',
  colStatus: l10n?.workspaceConfigColStatus ?? 'Status',
  features: l10n?.workspaceConfigFeatures ?? 'Enabled features',
  none: l10n?.workspaceConfigNone ?? 'None',
  availability: l10n?.workspaceConfigAvailability ?? 'Availability',
  openDays: l10n?.workspaceConfigOpenDays ?? 'Open days',
  closures: l10n?.workspaceConfigClosures ?? 'Closures',
  floorPlan: l10n?.workspaceConfigFloorPlan ?? 'Floor plan',
  bookableWhole: l10n?.workspaceConfigBookableWhole ?? 'bookable as a whole',
  seatsLabel: l10n?.workspaceConfigSeats ?? 'Seats',
  emptyLevel: l10n?.workspaceConfigEmptyLevel ?? 'No rooms',
  levelBookable: (price) => price.isEmpty
      ? (l10n?.levelBookableToggle ?? 'Bookable as a whole')
      : '${l10n?.levelBookableToggle ?? 'Bookable as a whole'}'
            ' — $price / '
            '${l10n?.levelPriceLabel ?? 'Price per half-day'}',
  invitations: l10n?.workspaceConfigInvitations ?? 'Invitations',
  invitationCustomTemplate:
      l10n?.workspaceConfigInvitationCustom ??
      'Custom invitation message configured',
  invitationDefault:
      l10n?.workspaceConfigInvitationDefault ??
      'Built-in invitation message (all languages)',
  invitationSingleUse:
      l10n?.workspaceConfigInvitationSingleUse ??
      'Personal invitation codes are single-use and '
          'expire after 14 days; new members need '
          'admin approval',
);
