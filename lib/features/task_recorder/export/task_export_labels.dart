// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 — the words a recording's identifiers become in an export.
//
// Every label comes from a registered identifier or a vocabulary value
// (action_registry.dart, safe_payload.dart), looked up in the chosen
// language. Nothing here reads a value somebody typed: an identifier
// this build does not know becomes the localized "cannot describe"
// label, never the identifier itself, so an imported recording cannot
// put its own text into the document through an id.
import '../../../l10n/app_localizations.dart';
import '../domain/action_registry.dart';
import '../domain/safe_payload.dart';
import '../domain/step_values.dart';
import '../domain/task_recording.dart';

/// Localized labels for one recording export.
class TaskExportLabels {
  const TaskExportLabels(this.l);

  final AppLocalizations l;

  String surface(String? id) => switch (id) {
    RecorderSurfaces.reserve => l.taskExportSurfaceReserve,
    RecorderSurfaces.bookingSheet => l.taskExportSurfaceBookingSheet,
    RecorderSurfaces.reservationDetail => l.taskExportSurfaceReservationDetail,
    'navigation.any' => l.taskExportSurfaceAny,
    _ => l.taskExportSurfaceUnknown,
  };

  String field(String key) => switch (key) {
    'date_relation' => l.taskExportFieldDateRelation,
    'period' => l.taskExportFieldPeriod,
    'view_mode' => l.taskExportFieldViewMode,
    'resource_kind' => l.taskExportFieldResourceKind,
    'for_whom' => l.taskExportFieldForWhom,
    'repeat' => l.taskExportFieldRepeat,
    'check_in' => l.taskExportFieldCheckIn,
    'series_result' => l.taskExportFieldSeriesResult,
    'refusal' => l.taskExportFieldRefusal,
    'time' => l.taskExportFieldTime,
    'accessories' => l.taskExportFieldAccessories,
    _ => l.taskExportFieldUnknown,
  };

  /// A vocabulary value of [key]. Anything outside the vocabulary,
  /// including the placeholder, reads "not recorded".
  String value(String key, String value) => switch ((key, value)) {
    ('date_relation', 'today') => l.taskExportValueToday,
    ('date_relation', 'tomorrow') => l.taskExportValueTomorrow,
    ('date_relation', 'later_this_week') => l.taskExportValueLaterThisWeek,
    ('date_relation', 'later') => l.taskExportValueLater,
    ('date_relation', 'past') => l.taskExportValuePast,
    ('period', 'full_day') => l.taskExportValueFullDay,
    ('period', 'morning') => l.taskExportValueMorning,
    ('period', 'afternoon') => l.taskExportValueAfternoon,
    ('period', 'hours') => l.taskExportValueHours,
    ('period', 'custom') => l.taskExportValueCustom,
    ('view_mode', 'plan') => l.taskExportValuePlan,
    ('view_mode', 'list') => l.taskExportValueList,
    ('resource_kind', 'desk') => l.taskExportValueDesk,
    ('resource_kind', 'room') => l.taskExportValueRoom,
    ('resource_kind', 'other') => l.taskExportValueOtherPlace,
    ('for_whom', 'self') => l.taskExportValueSelf,
    ('for_whom', 'other_member') => l.taskExportValueOtherMember,
    ('repeat', 'once') => l.taskExportValueOnce,
    ('repeat', 'series') => l.taskExportValueSeries,
    ('check_in', 'yes') => l.taskExportValueYes,
    ('check_in', 'no') => l.taskExportValueNo,
    ('series_result', 'all_booked') => l.taskExportValueAllBooked,
    ('series_result', 'partially_booked') => l.taskExportValuePartiallyBooked,
    ('refusal', 'conflict') => l.taskExportValueConflict,
    ('refusal', 'policy') => l.taskExportValuePolicy,
    ('refusal', 'quota') => l.taskExportValueQuota,
    ('refusal', 'permission') => l.taskExportValuePermission,
    ('refusal', 'closed') => l.taskExportValueClosed,
    ('refusal', 'offline') => l.taskExportValueOffline,
    ('refusal', 'other') => l.taskExportValueOtherReason,
    _ => l.taskExportValueWithheld,
  };

  /// The payload as "Field: value" lines, in the payload's stable order.
  List<String> details(SafePayload payload) => [
    for (final e in payload.toJson().entries)
      l.taskExportDetail(field(e.key), value(e.key, e.value)),
  ];

  /// The values a step carries as "name: value" lines (none when the
  /// recording did not capture values).
  List<String> valueLines(StepValues values) => [
    for (final e in values.entries.entries)
      l.taskExportDetail(
        e.key,
        valueText(
          e.value,
          redacted: l.taskExportValueRedacted,
          on: l.taskExportValueOn,
          off: l.taskExportValueOff,
        ),
      ),
  ];

  String action(RecordedStep s) => switch (s.action) {
    RecorderActions.openReserve => l.taskExportActionOpenReserve,
    RecorderActions.selectDate => l.taskExportActionSelectDate,
    RecorderActions.selectPeriod => l.taskExportActionSelectPeriod,
    RecorderActions.switchView => l.taskExportActionSwitchView,
    RecorderActions.selectResource => l.taskExportActionSelectResource,
    RecorderActions.changeBookingField => l.taskExportActionChangeField(
      field(s.target ?? ''),
    ),
    RecorderActions.confirmBooking => l.taskExportActionConfirmBooking,
    RecorderActions.cancelReview => l.taskExportActionCancelReview,
    RecorderActions.viewDetails => l.taskExportActionViewDetails,
    RecorderActions.back => l.taskExportActionBack,
    _ => l.taskExportActionUnknown,
  };

  String outcome(String? id) => switch (id) {
    RecorderOutcomes.bookingConfirmed => l.taskExportOutcomeConfirmed,
    RecorderOutcomes.bookingRequested => l.taskExportOutcomeRequested,
    RecorderOutcomes.seriesBooked => l.taskExportOutcomeSeriesBooked,
    RecorderOutcomes.bookingRefused => l.taskExportOutcomeRefused,
    RecorderOutcomes.bookingUnknown => l.taskExportOutcomeUnknown,
    _ => l.taskExportOutcomeUnregistered,
  };

  String protectedSurface(ProtectedSurface? p) => switch (p) {
    ProtectedSurface.authentication => l.taskExportProtectedAuthentication,
    ProtectedSurface.payment => l.taskExportProtectedPayment,
    ProtectedSurface.provider => l.taskExportProtectedProvider,
    ProtectedSurface.secrets => l.taskExportProtectedSecrets,
    ProtectedSurface.messenger => l.taskExportProtectedMessenger,
    ProtectedSurface.identity => l.taskExportProtectedIdentity,
    ProtectedSurface.operator || null => l.taskExportProtectedOperator,
  };

  String prerequisite(Prerequisite p) => switch (p.id) {
    'signed_in' => l.taskExportPrereqSignedIn,
    'workspace_member' => l.taskExportPrereqWorkspaceMember,
    'starts_on' => l.taskExportPrereqStartsOn(surface(p.value)),
    'bookable_place' => l.taskExportPrereqBookablePlace,
    _ => l.taskExportPrereqUnknown,
  };

  String completeness(Completeness c) => switch (c) {
    Completeness.complete => l.taskExportCompletenessComplete,
    Completeness.partial => l.taskExportCompletenessPartial,
    Completeness.interrupted => l.taskExportCompletenessInterrupted,
  };

  String? endReason(RecordingEndReason? r) => switch (r) {
    RecordingEndReason.stopped => l.taskExportEndStopped,
    RecordingEndReason.scopeChanged => l.taskExportEndScopeChanged,
    RecordingEndReason.limitReached => l.taskExportEndLimitReached,
    RecordingEndReason.storageFailed => l.taskExportEndStorageFailed,
    RecordingEndReason.interrupted => l.taskExportEndInterrupted,
    null => null,
  };

  /// Platform families are product names and stay untranslated; an
  /// unknown platform is simply not stated.
  static String? platformName(RecordingPlatform p) => switch (p) {
    RecordingPlatform.android => 'Android',
    RecordingPlatform.ios => 'iOS',
    RecordingPlatform.web => 'Web',
    RecordingPlatform.macos => 'macOS',
    RecordingPlatform.windows => 'Windows',
    RecordingPlatform.linux => 'Linux',
    RecordingPlatform.unknown => null,
  };
}
