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
      'messaging.inbox_page_size' => l10n.settingLabelMessagingInboxPageSize,
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
      'retention.us_years' => l10n.settingLabelRetentionUsYears,
      'assets.valuation_max_rows' => l10n.settingLabelAssetsValuationMaxRows,
      'bi.batch_max_requests' => l10n.settingLabelBiBatchMaxRequests,
      'purchase.single_approval_below_units' => l10n.settingLabelPurchaseSingleApproval,
      'purchase.payment_checker_from_units' => l10n.settingLabelPurchasePaymentChecker,
      'purchase.supplier_lookup_timeout_seconds' => l10n.settingLabelPurchaseSupplierLookupTimeoutSeconds,
      'purchase.supplier_lookup_per_minute' => l10n.settingLabelPurchaseSupplierLookupPerMinute,
      'mcp.read_range_days' => l10n.settingLabelMcpReadRangeDays,
      'calendar.range_days' => l10n.settingLabelCalendarRangeDays,
      'kpi.capacity_range_days' => l10n.settingLabelKpiCapacityRangeDays,
      'kpi.finance_range_months' => l10n.settingLabelKpiFinanceRangeMonths,
      'personal.read_concurrency' => l10n.settingLabelPersonalReadConcurrency,
      'personal.read_timeout_seconds' => l10n.settingLabelPersonalReadTimeoutSeconds,
      'personal.reservation_page_size' => l10n.settingLabelPersonalReservationPageSize,
      'personal.reservation_window_days' => l10n.settingLabelPersonalReservationWindowDays,
      'personal.reservation_max_window_days' => l10n.settingLabelPersonalReservationMaxWindowDays,
      'personal.message_directory_page_size' => l10n.settingLabelPersonalMessageDirectoryPageSize,
      'personal.message_directory_query_length' => l10n.settingLabelPersonalMessageDirectoryQueryLength,
      _ => _federationSettingLabel(l10n, key),
    };

/// #2562/#2563 -- the identity freshness, the backchannel retention and answer wait.
String _federationSettingLabel(AppLocalizations l10n, String key) => switch (key) {
      'identity.status_assertion_lifetime_seconds' => l10n.settingLabelIdentityStatusAssertionLifetimeSeconds,
      'identity.status_reconcile_seconds' => l10n.settingLabelIdentityStatusReconcileSeconds,
      'identity.clock_skew_seconds' => l10n.settingLabelIdentityClockSkewSeconds,
      'federation.retention_hours' => l10n.settingLabelFederationRetentionHours,
      'federation.answer_wait_seconds' => l10n.settingLabelFederationAnswerWaitSeconds,
      _ => _biReportSettingLabel(l10n, key),
    };

/// #2579 -- the bounds of a saved report.
String _biReportSettingLabel(AppLocalizations l10n, String key) => switch (key) {
      'bi.batch_time_budget_ms' => l10n.settingLabelBiBatchTimeBudgetMs,
      'bi.series_months' => l10n.settingLabelBiSeriesMonths,
      'bi.series_quarters' => l10n.settingLabelBiSeriesQuarters,
      'bi.series_years' => l10n.settingLabelBiSeriesYears,
      'bi.report_max_pages' => l10n.settingLabelBiReportMaxPages,
      'bi.report_max_visuals' => l10n.settingLabelBiReportMaxVisuals,
      'bi.report_max_bytes' => l10n.settingLabelBiReportMaxBytes,
      _ => _bankSettingLabel(l10n, key),
    };

/// #2380 -- the bank statement import's bounds and suggestion window.
String _bankSettingLabel(AppLocalizations l10n, String key) => switch (key) {
      'bank.import_max_bytes' => l10n.settingLabelBankImportMaxBytes,
      'bank.import_max_lines' => l10n.settingLabelBankImportMaxLines,
      'bank.match_window_days' => l10n.settingLabelBankMatchWindowDays,
      _ => _recordsSettingLabel(l10n, key),
    };

/// #2378 -- where the records are kept: the operator's declaration and the
/// CRA authorisation of a Canadian space.
String _recordsSettingLabel(AppLocalizations l10n, String key) => switch (key) {
      'records.hosting_country' => l10n.settingLabelRecordsHostingCountry,
      'records.cra_authorisation_reference' => l10n.settingLabelRecordsCraReference,
      'security.badge_pin_min_length' => l10n.settingLabelSecurityBadgePinMinLength,
      'security.badge_workspace_failure_limit' => l10n.settingLabelSecurityBadgeWorkspaceFailureLimit,
      _ => _liveUpdateSettingLabel(l10n, key),
    };

/// #3098, #3099 -- how often the app re-reads: after an absence, and the
/// inbox's timeout sweep.
String _liveUpdateSettingLabel(AppLocalizations l10n, String key) => switch (key) {
      'presence.resync_after_away_minutes' => l10n.settingLabelPresenceResyncAfterAwayMinutes,
      'messaging.inbox_sweep_interval_seconds' => l10n.settingLabelMessagingInboxSweepIntervalSeconds,
      _ => key,
    };

String? settingHint(AppLocalizations l10n, String key) => switch (key) {
      'messaging.edit_window_minutes' => l10n.settingHintMessagingEditWindowMinutes,
      'messaging.thread_poll_seconds' => l10n.settingHintMessagingThreadPollSeconds,
      'messaging.inbox_poll_seconds' => l10n.settingHintMessagingInboxPollSeconds,
      'messaging.inbox_page_size' => l10n.settingHintMessagingInboxPageSize,
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
      'retention.us_years' => l10n.settingHintRetentionUsYears,
      'assets.valuation_max_rows' => l10n.settingHintAssetsValuationMaxRows,
      'bi.batch_max_requests' => l10n.settingHintBiBatchMaxRequests,
      'purchase.single_approval_below_units' => l10n.settingHintPurchaseSingleApproval,
      'purchase.payment_checker_from_units' => l10n.settingHintPurchasePaymentChecker,
      'purchase.supplier_lookup_timeout_seconds' => l10n.settingHintPurchaseSupplierLookupTimeoutSeconds,
      'purchase.supplier_lookup_per_minute' => l10n.settingHintPurchaseSupplierLookupPerMinute,
      'mcp.read_range_days' => l10n.settingHintMcpReadRangeDays,
      'calendar.range_days' => l10n.settingHintCalendarRangeDays,
      'kpi.capacity_range_days' => l10n.settingHintKpiCapacityRangeDays,
      'kpi.finance_range_months' => l10n.settingHintKpiFinanceRangeMonths,
      'personal.read_concurrency' => l10n.settingHintPersonalReadConcurrency,
      'personal.read_timeout_seconds' => l10n.settingHintPersonalReadTimeoutSeconds,
      'personal.reservation_page_size' => l10n.settingHintPersonalReservationPageSize,
      'personal.reservation_window_days' => l10n.settingHintPersonalReservationWindowDays,
      'personal.reservation_max_window_days' => l10n.settingHintPersonalReservationMaxWindowDays,
      'personal.message_directory_page_size' => l10n.settingHintPersonalMessageDirectoryPageSize,
      'personal.message_directory_query_length' => l10n.settingHintPersonalMessageDirectoryQueryLength,
      _ => _federationSettingHint(l10n, key),
    };

/// #2562/#2563 -- the identity freshness, the backchannel retention and answer wait.
String? _federationSettingHint(AppLocalizations l10n, String key) => switch (key) {
      'identity.status_assertion_lifetime_seconds' => l10n.settingHintIdentityStatusAssertionLifetimeSeconds,
      'identity.status_reconcile_seconds' => l10n.settingHintIdentityStatusReconcileSeconds,
      'identity.clock_skew_seconds' => l10n.settingHintIdentityClockSkewSeconds,
      'federation.retention_hours' => l10n.settingHintFederationRetentionHours,
      'federation.answer_wait_seconds' => l10n.settingHintFederationAnswerWaitSeconds,
      _ => _biReportSettingHint(l10n, key),
    };

/// #2579 -- the bounds of a saved report.
String? _biReportSettingHint(AppLocalizations l10n, String key) => switch (key) {
      'bi.batch_time_budget_ms' => l10n.settingHintBiBatchTimeBudgetMs,
      'bi.series_months' => l10n.settingHintBiSeriesMonths,
      'bi.series_quarters' => l10n.settingHintBiSeriesQuarters,
      'bi.series_years' => l10n.settingHintBiSeriesYears,
      'bi.report_max_pages' => l10n.settingHintBiReportMaxPages,
      'bi.report_max_visuals' => l10n.settingHintBiReportMaxVisuals,
      'bi.report_max_bytes' => l10n.settingHintBiReportMaxBytes,
      _ => _bankSettingHint(l10n, key),
    };

String? _bankSettingHint(AppLocalizations l10n, String key) => switch (key) {
      'bank.import_max_bytes' => l10n.settingHintBankImportMaxBytes,
      'bank.import_max_lines' => l10n.settingHintBankImportMaxLines,
      'bank.match_window_days' => l10n.settingHintBankMatchWindowDays,
      'records.hosting_country' => l10n.settingHintRecordsHostingCountry,
      'records.cra_authorisation_reference' => l10n.settingHintRecordsCraReference,
      'security.badge_pin_min_length' => l10n.settingHintSecurityBadgePinMinLength,
      'security.badge_workspace_failure_limit' => l10n.settingHintSecurityBadgeWorkspaceFailureLimit,
      _ => _liveUpdateSettingHint(l10n, key),
    };

String? _liveUpdateSettingHint(AppLocalizations l10n, String key) => switch (key) {
      'presence.resync_after_away_minutes' => l10n.settingHintPresenceResyncAfterAwayMinutes,
      'messaging.inbox_sweep_interval_seconds' => l10n.settingHintMessagingInboxSweepIntervalSeconds,
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
      'personal' => l10n.settingGroupPersonal,
      'records' => l10n.settingGroupRecords,
      _ => group,
    };

String settingUnitLabel(AppLocalizations l10n, String unit) => switch (unit) {
      'seconds' => l10n.settingUnitSeconds,
      'milliseconds' => l10n.settingUnitMilliseconds,
      'minutes' => l10n.settingUnitMinutes,
      'hours' => l10n.settingUnitHours,
      'days' => l10n.settingUnitDays,
      'months' => l10n.settingUnitMonths,
      'quarters' => l10n.settingUnitQuarters,
      'years' => l10n.settingUnitYears,
      'currency units' => l10n.settingUnitCurrencyUnits,
      'rows' => l10n.settingUnitRows,
      'requests' => l10n.settingUnitRequests,
      'attempts' => l10n.settingUnitAttempts,
      'per hour' => l10n.settingUnitPerHour,
      'per day' => l10n.settingUnitPerDay,
      'entries' => l10n.settingUnitEntries,
      'characters' => l10n.settingUnitCharacters,
      'pages' => l10n.settingUnitPages,
      'cards' => l10n.settingUnitCards,
      'bytes' => l10n.settingUnitBytes,
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
