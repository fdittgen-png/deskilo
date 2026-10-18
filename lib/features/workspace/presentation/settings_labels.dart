// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2484 -- the words of the registry. A setting's name, its hint and its
// group are user-facing text, so they come from the ARB files; the registry
// row carries only the key. A key with no entry here still shows (as its
// key), so a missing label is visible, never blank -- and
// `settings_labels_test` fails until a seeded key has one.
import '../../../core/settings/settings.dart';
import '../../../l10n/app_localizations.dart';

String settingLabel(AppLocalizations l10n, String key) => switch (key) {
      'messaging.edit_window_minutes' => l10n.settingLabelMessagingEditWindowMinutes,
      'messaging.thread_poll_seconds' => l10n.settingLabelMessagingThreadPollSeconds,
      'messaging.inbox_poll_seconds' => l10n.settingLabelMessagingInboxPollSeconds,
      'booking.check_in_leeway_minutes' => l10n.settingLabelBookingCheckInLeewayMinutes,
      'booking.check_in_reminder_lead_minutes' => l10n.settingLabelBookingCheckInReminderLeadMinutes,
      'booking.check_in_reminder_lookahead_days' => l10n.settingLabelBookingCheckInReminderLookaheadDays,
      'booking.walk_up_window_minutes' => l10n.settingLabelBookingWalkUpWindowMinutes,
      'booking.walk_up_floor_minutes' => l10n.settingLabelBookingWalkUpFloorMinutes,
      'booking.intent_ledger_cap' => l10n.settingLabelBookingIntentLedgerCap,
      'billing.max_advance_days' => l10n.settingLabelBillingMaxAdvanceDays,
      'directory.upcoming_window_days' => l10n.settingLabelDirectoryUpcomingWindowDays,
      'presence.online_window_minutes' => l10n.settingLabelPresenceOnlineWindowMinutes,
      'dunning.first_after_days' => l10n.settingLabelDunningFirstAfterDays,
      'security.badge_lockout_failures' => l10n.settingLabelSecurityBadgeLockoutFailures,
      'security.badge_lockout_minutes' => l10n.settingLabelSecurityBadgeLockoutMinutes,
      'security.invitation_expiry_days' => l10n.settingLabelSecurityInvitationExpiryDays,
      'mcp.confirmation_expiry_minutes' => l10n.settingLabelMcpConfirmationExpiryMinutes,
      'mcp.probe_freshness_minutes' => l10n.settingLabelMcpProbeFreshnessMinutes,
      'messaging.group_creation_per_hour' => l10n.settingLabelMessagingGroupCreationPerHour,
      'messaging.message_requests_per_day' => l10n.settingLabelMessagingMessageRequestsPerDay,
      _ => _rangeSettingLabel(l10n, key),
    };

/// #2487 -- the export window and the four read-only query-range guardrails.
String _rangeSettingLabel(AppLocalizations l10n, String key) => switch (key) {
      'readiness.recent_export_days' => l10n.settingLabelReadinessRecentExportDays,
      'mcp.notice_read_retention_days' => l10n.settingLabelMcpNoticeReadRetentionDays,
      'vat.vies_evidence_days' => l10n.settingLabelVatViesEvidenceDays,
      'mcp.read_range_days' => l10n.settingLabelMcpReadRangeDays,
      'calendar.range_days' => l10n.settingLabelCalendarRangeDays,
      'kpi.capacity_range_days' => l10n.settingLabelKpiCapacityRangeDays,
      'kpi.finance_range_months' => l10n.settingLabelKpiFinanceRangeMonths,
      _ => key,
    };

String? settingHint(AppLocalizations l10n, String key) => switch (key) {
      'messaging.edit_window_minutes' => l10n.settingHintMessagingEditWindowMinutes,
      'messaging.thread_poll_seconds' => l10n.settingHintMessagingThreadPollSeconds,
      'messaging.inbox_poll_seconds' => l10n.settingHintMessagingInboxPollSeconds,
      'booking.check_in_leeway_minutes' => l10n.settingHintBookingCheckInLeewayMinutes,
      'booking.check_in_reminder_lead_minutes' => l10n.settingHintBookingCheckInReminderLeadMinutes,
      'booking.check_in_reminder_lookahead_days' => l10n.settingHintBookingCheckInReminderLookaheadDays,
      'booking.walk_up_window_minutes' => l10n.settingHintBookingWalkUpWindowMinutes,
      'booking.walk_up_floor_minutes' => l10n.settingHintBookingWalkUpFloorMinutes,
      'booking.intent_ledger_cap' => l10n.settingHintBookingIntentLedgerCap,
      'billing.max_advance_days' => l10n.settingHintBillingMaxAdvanceDays,
      'directory.upcoming_window_days' => l10n.settingHintDirectoryUpcomingWindowDays,
      'presence.online_window_minutes' => l10n.settingHintPresenceOnlineWindowMinutes,
      'dunning.first_after_days' => l10n.settingHintDunningFirstAfterDays,
      'security.badge_lockout_failures' => l10n.settingHintSecurityBadgeLockoutFailures,
      'security.badge_lockout_minutes' => l10n.settingHintSecurityBadgeLockoutMinutes,
      'security.invitation_expiry_days' => l10n.settingHintSecurityInvitationExpiryDays,
      'mcp.confirmation_expiry_minutes' => l10n.settingHintMcpConfirmationExpiryMinutes,
      'mcp.probe_freshness_minutes' => l10n.settingHintMcpProbeFreshnessMinutes,
      'messaging.group_creation_per_hour' => l10n.settingHintMessagingGroupCreationPerHour,
      'messaging.message_requests_per_day' => l10n.settingHintMessagingMessageRequestsPerDay,
      _ => _rangeSettingHint(l10n, key),
    };

String? _rangeSettingHint(AppLocalizations l10n, String key) => switch (key) {
      'readiness.recent_export_days' => l10n.settingHintReadinessRecentExportDays,
      'mcp.notice_read_retention_days' => l10n.settingHintMcpNoticeReadRetentionDays,
      'vat.vies_evidence_days' => l10n.settingHintVatViesEvidenceDays,
      'mcp.read_range_days' => l10n.settingHintMcpReadRangeDays,
      'calendar.range_days' => l10n.settingHintCalendarRangeDays,
      'kpi.capacity_range_days' => l10n.settingHintKpiCapacityRangeDays,
      'kpi.finance_range_months' => l10n.settingHintKpiFinanceRangeMonths,
      _ => null,
    };

String settingGroupLabel(AppLocalizations l10n, String group) => switch (group) {
      'dunning' => l10n.settingGroupDunning,
      'security' => l10n.settingGroupSecurity,
      'booking' => l10n.settingGroupBooking,
      'billing' => l10n.settingGroupBilling,
      'directory' => l10n.settingGroupDirectory,
      'presence' => l10n.settingGroupPresence,
      'messaging' => l10n.settingGroupMessaging,
      'readiness' => l10n.settingGroupReadiness,
      'vat' => l10n.settingGroupVat,
      'kpi' => l10n.settingGroupKpi,
      _ => group,
    };

String settingUnitLabel(AppLocalizations l10n, String unit) => switch (unit) {
      'seconds' => l10n.settingUnitSeconds,
      'minutes' => l10n.settingUnitMinutes,
      'hours' => l10n.settingUnitHours,
      'days' => l10n.settingUnitDays,
      'months' => l10n.settingUnitMonths,
      'attempts' => l10n.settingUnitAttempts,
      'per hour' => l10n.settingUnitPerHour,
      'per day' => l10n.settingUnitPerDay,
      'entries' => l10n.settingUnitEntries,
      _ => unit,
    };

String settingProblemLabel(AppLocalizations l10n, SettingProblem p) => switch (p) {
      SettingProblem.notANumber => l10n.settingProblemNotANumber,
      SettingProblem.belowMin => l10n.settingProblemBelowMin,
      SettingProblem.aboveMax => l10n.settingProblemAboveMax,
      SettingProblem.belowFloor => l10n.settingProblemBelowFloor,
      SettingProblem.wrongType => l10n.settingProblemWrongType,
      SettingProblem.notAChoice => l10n.settingProblemNotAChoice,
    };

String settingOriginLabel(AppLocalizations l10n, SettingOrigin o) => switch (o) {
      SettingOrigin.workspace => l10n.settingOriginWorkspace,
      SettingOrigin.platform => l10n.settingOriginPlatform,
      SettingOrigin.registryDefault => l10n.settingOriginDefault,
    };

/// "Between 1 and 365 days", "At least 1 day"... for a numeric definition.
String? settingRangeLabel(AppLocalizations l10n, SettingDefinition d) {
  if (d.type != SettingType.integer && d.type != SettingType.duration) return null;
  final unit = settingUnitLabel(l10n, d.unit);
  final min = d.min, max = d.max;
  if (min != null && max != null) return l10n.settingRange('$min', '$max', unit);
  if (min != null) return l10n.settingMinOnly('$min', unit);
  if (max != null) return l10n.settingMaxOnly('$max', unit);
  return null;
}
