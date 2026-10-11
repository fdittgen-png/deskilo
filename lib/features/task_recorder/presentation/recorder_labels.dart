// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the words for a recording's identifiers, in five languages.
// A step is stored as identifiers and categories; this is the only
// place they become sentences, so a recording made in French reads in
// German on another device, and nothing the person typed is ever shown
// as if the recorder had observed it.

import '../../../core/calendar/calendar_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/presentation/widgets/calendar_item_row.dart'
    show calendarKindLabel;
import '../../events/domain/workspace_event.dart';
import '../../events/presentation/event_labels.dart' show eventTypeLabel;
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/presentation/feature_names.dart';
import '../../workspace/presentation/screens/roles_screen_labels.dart'
    show permissionLabel;
import '../domain/action_registry.dart';
import '../domain/step_values.dart';
import '../domain/task_recording.dart';
import 'ui_labels.g.dart';

/// The sentence for a registered action; null for one this build does
/// not describe.
String? actionLabel(AppLocalizations l10n, String? action) => switch (action) {
  RecorderActions.openReserve =>
    l10n.taskRecorderActionOpenReserve,
  RecorderActions.selectDate =>
    l10n.taskRecorderActionSelectDate,
  RecorderActions.selectPeriod =>
    l10n.taskRecorderActionSelectPeriod,
  RecorderActions.switchView =>
    l10n.taskRecorderActionSwitchView,
  RecorderActions.selectResource =>
    l10n.taskRecorderActionSelectResource,
  RecorderActions.changeBookingField =>
    l10n.taskRecorderActionChangeField,
  RecorderActions.confirmBooking =>
    l10n.taskRecorderActionConfirmBooking,
  RecorderActions.cancelReview =>
    l10n.taskRecorderActionCancelReview,
  RecorderActions.viewDetails =>
    l10n.taskRecorderActionViewDetails,
  RecorderActions.back => l10n.taskRecorderActionBack,
  RecorderActions.switchFeature =>
    l10n.taskRecorderActionSwitchFeature,
  RecorderActions.declineOptIn =>
    l10n.taskRecorderActionDeclineOptIn,
  RecorderActions.selectLevel =>
    l10n.taskRecorderActionSelectLevel,
  RecorderActions.checkIn => l10n.taskRecorderActionCheckIn,
  RecorderActions.checkOut => l10n.taskRecorderActionCheckOut,
  RecorderActions.cancelReservation =>
    l10n.taskRecorderActionCancelReservation,
  RecorderActions.closeMyReservation =>
    l10n.taskRecorderActionCloseMyReservation,
  RecorderActions.calendarSwitchView =>
    l10n.taskRecorderActionCalendarView,
  RecorderActions.calendarMove =>
    l10n.taskRecorderActionCalendarMove,
  RecorderActions.calendarSelectDay =>
    l10n.taskRecorderActionCalendarSelectDay,
  RecorderActions.calendarFilterKind =>
    l10n.taskRecorderActionCalendarFilterKind,
  RecorderActions.calendarChooseWhose =>
    l10n.taskRecorderActionCalendarWhose,
  RecorderActions.calendarOpenItem =>
    l10n.taskRecorderActionCalendarOpenItem,
  RecorderActions.calendarCancelReservation =>
    l10n.taskRecorderActionCalendarCancel,
  RecorderActions.decideEvent =>
    l10n.taskRecorderActionDecideEvent,
  RecorderActions.uiOpenScreen =>
    l10n.taskRecorderActionUiOpenScreen,
  RecorderActions.uiTap => l10n.taskRecorderActionUiTap,
  RecorderActions.uiCommitField =>
    l10n.taskRecorderActionUiCommitField,
  RecorderActions.uiCommand =>
    l10n.taskRecorderActionUiCommand,
  RecorderActions.uiOpenWindow =>
    l10n.taskRecorderActionUiOpenWindow,
  RecorderActions.uiCloseWindow =>
    l10n.taskRecorderActionUiCloseWindow,
  RecorderActions.togglePermission =>
    l10n.taskRecorderActionTogglePermission,
  RecorderActions.saveRole =>
    l10n.taskRecorderActionSaveRole,
  RecorderActions.giveRole =>
    l10n.taskRecorderActionGiveRole,
  RecorderActions.cancelRoleEdit =>
    l10n.taskRecorderActionCancelRoleEdit,
  RecorderActions.saveValidationRule =>
    l10n.taskRecorderActionSaveValidationRule,
  RecorderActions.cancelValidationRule =>
    l10n.taskRecorderActionCancelValidationRule,
  _ => null,
};

/// The sentence for a registered outcome.
String? outcomeLabel(AppLocalizations l10n, String? outcome) =>
    switch (outcome) {
      RecorderOutcomes.bookingConfirmed =>
        l10n.taskRecorderOutcomeConfirmed,
      RecorderOutcomes.bookingRequested =>
        l10n.taskRecorderOutcomeRequested,
      RecorderOutcomes.seriesBooked =>
        l10n.taskRecorderOutcomeSeries,
      RecorderOutcomes.bookingRefused =>
        l10n.taskRecorderOutcomeRefused,
      RecorderOutcomes.bookingUnknown =>
        l10n.taskRecorderOutcomeUnknown,
      RecorderOutcomes.settingSaved =>
        l10n.taskRecorderOutcomeSettingSaved,
      RecorderOutcomes.settingNotSaved =>
        l10n.taskRecorderOutcomeSettingNotSaved,
      RecorderOutcomes.settingUnknown =>
        l10n.taskRecorderOutcomeUnknown,
      RecorderOutcomes.checkedIn =>
        l10n.taskRecorderOutcomeCheckedIn,
      RecorderOutcomes.checkedOut =>
        l10n.taskRecorderOutcomeCheckedOut,
      RecorderOutcomes.cancelled =>
        l10n.taskRecorderOutcomeCancelled,
      RecorderOutcomes.reservationRefused =>
        l10n.taskRecorderOutcomeRefused,
      RecorderOutcomes.reservationUnknown =>
        l10n.taskRecorderOutcomeUnknown,
      RecorderOutcomes.settingPending =>
        l10n.taskRecorderOutcomeSettingPending,
      RecorderOutcomes.eventDecided =>
        l10n.taskRecorderOutcomeEventDecided,
      RecorderOutcomes.eventNotConfirmed =>
        l10n.taskRecorderOutcomeEventNotConfirmed,
      RecorderOutcomes.commandDone =>
        l10n.taskRecorderOutcomeCommandDone,
      RecorderOutcomes.commandPending =>
        l10n.taskRecorderOutcomeCommandPending,
      RecorderOutcomes.commandRefused =>
        l10n.taskRecorderOutcomeRefused,
      RecorderOutcomes.commandUnknown =>
        l10n.taskRecorderOutcomeUnknown,
      _ => null,
    };

/// The words for one category value; the raw value is never shown.
String valueLabel(AppLocalizations l10n, String value) => switch (value) {
  'today' => l10n.taskRecorderValueToday,
  'tomorrow' => l10n.taskRecorderValueTomorrow,
  'later_this_week' =>
    l10n.taskRecorderValueLaterThisWeek,
  'later' => l10n.taskRecorderValueLater,
  'past' => l10n.taskRecorderValuePast,
  'full_day' => l10n.taskRecorderValueFullDay,
  'morning' => l10n.taskRecorderValueMorning,
  'afternoon' => l10n.taskRecorderValueAfternoon,
  'hours' => l10n.taskRecorderValueHours,
  'custom' => l10n.taskRecorderValueCustom,
  'plan' => l10n.taskRecorderValuePlan,
  'list' => l10n.taskRecorderValueList,
  'day' => l10n.taskRecorderValueDay,
  'on' => l10n.taskRecorderValueOn,
  'off' => l10n.taskRecorderValueOff,
  'week' => l10n.taskRecorderValueWeek,
  'month' => l10n.taskRecorderValueMonth,
  'desk' => l10n.taskRecorderValueDesk,
  'room' => l10n.taskRecorderValueRoom,
  'other' => l10n.taskRecorderValueOther,
  'self' => l10n.taskRecorderValueSelf,
  'other_member' => l10n.taskRecorderValueOtherMember,
  'once' => l10n.taskRecorderValueOnce,
  'series' => l10n.taskRecorderValueSeries,
  'all_booked' => l10n.taskRecorderValueAllBooked,
  'partially_booked' =>
    l10n.taskRecorderValuePartiallyBooked,
  'conflict' => l10n.taskRecorderValueConflict,
  'policy' => l10n.taskRecorderValuePolicy,
  'quota' => l10n.taskRecorderValueQuota,
  'permission' => l10n.taskRecorderValuePermission,
  'closed' => l10n.taskRecorderValueClosed,
  'offline' => l10n.taskRecorderValueOffline,
  'agenda' => l10n.taskRecorderValueAgenda,
  'timeline' => l10n.taskRecorderValueTimeline,
  'range' => l10n.taskRecorderValueRange,
  'previous' => l10n.taskRecorderValuePrevious,
  'next' => l10n.taskRecorderValueNext,
  'mine' => l10n.taskRecorderValueMine,
  'someone_else' => l10n.taskRecorderValueSomeoneElse,
  'everyone' => l10n.taskRecorderValueEveryone,
  'conversation' => l10n.taskRecorderValueConversation,
  'alert' => l10n.taskRecorderValueAlert,
  'decision' => l10n.taskRecorderValueDecision,
  'payment' => l10n.taskRecorderValuePayment,
  'invoice' => l10n.taskRecorderValueInvoice,
  'accept' => l10n.taskRecorderValueAccept,
  'decline' => l10n.taskRecorderValueDecline,
  'owner' => l10n.taskRecorderValueRoleOwner,
  'co_owner' => l10n.taskRecorderValueRoleCoOwner,
  'admin' => l10n.taskRecorderValueRoleAdmin,
  'member' => l10n.taskRecorderValueRoleMember,
  'created' => l10n.taskRecorderValueCreated,
  'edited' => l10n.taskRecorderValueEdited,
  'renamed' => l10n.taskRecorderValueRenamed,
  'withheld' => l10n.taskRecorderValueWithheld,
  _ => l10n.taskRecorderValueWithheld,
};

/// The words for a booking field a step changed.
String fieldLabel(AppLocalizations l10n, String field) => switch (field) {
  'for_whom' => l10n.taskRecorderFieldForWhom,
  'repeat' => l10n.taskRecorderFieldRepeat,
  'check_in' => l10n.taskRecorderFieldCheckIn,
  'time' => l10n.taskRecorderFieldTime,
  'accessories' => l10n.taskRecorderFieldAccessories,
  _ => l10n.taskRecorderValueWithheld,
};

/// The words for a kind of protected screen.
String protectedLabel(AppLocalizations l10n, ProtectedSurface category) =>
    switch (category) {
      ProtectedSurface.authentication =>
        l10n.taskRecorderProtectedAuthentication,
      ProtectedSurface.payment =>
        l10n.taskRecorderProtectedPayment,
      ProtectedSurface.provider =>
        l10n.taskRecorderProtectedProvider,
      ProtectedSurface.secrets =>
        l10n.taskRecorderProtectedSecrets,
      ProtectedSurface.messenger =>
        l10n.taskRecorderProtectedMessenger,
      ProtectedSurface.identity =>
        l10n.taskRecorderProtectedIdentity,
      ProtectedSurface.operator =>
        l10n.taskRecorderProtectedOperator,
    };

/// How complete a recording is, in words.
String completenessLabel(AppLocalizations l10n, Completeness c) => switch (c) {
  Completeness.complete => l10n.taskRecorderCompletenessComplete,
  Completeness.partial => l10n.taskRecorderCompletenessPartial,
  Completeness.interrupted =>
    l10n.taskRecorderCompletenessInterrupted,
};

/// Why a recording ended, in words.
String endReasonLabel(AppLocalizations l10n, RecordingEndReason? r) =>
    switch (r) {
      RecordingEndReason.stopped =>
        l10n.taskRecorderEndStopped,
      RecordingEndReason.scopeChanged =>
        l10n.taskRecorderEndScopeChanged,
      RecordingEndReason.limitReached =>
        l10n.taskRecorderEndLimitReached,
      RecordingEndReason.storageFailed =>
        l10n.taskRecorderEndStorageFailed,
      RecordingEndReason.referenceMissing =>
        l10n.taskRecorderEndReferenceMissing,
      RecordingEndReason.interrupted || null =>
        l10n.taskRecorderEndInterrupted,
    };

/// One step as the person reads it: a title and an optional detail.
({String title, String? detail}) stepText(
  AppLocalizations l10n,
  RecordedStep step,
) {
  // #2142 — a generic step reads in the app's own words when it has
  // them (its label, shown in the reader's language), else by its name.
  final label = step.payload.values['label'];
  final words = label == null ? null : uiLabel(l10n, label);
  final details = [
    if (words != null)
      words
    else if (step.target != null)
      uiTargetText(l10n, step.action, step.target!) ??
          targetLabel(l10n, step.target!, action: step.action),
    for (final e in step.payload.toJson().entries)
      if (e.key != 'label') valueLabel(l10n, e.value),
  ];
  final detail = details.isEmpty ? null : details.join(' · ');
  return switch (step.kind) {
    StepKind.action => (
      title:
          actionLabel(l10n, step.action) ??
          (l10n.taskRecorderStepUnrecorded),
      detail: detail,
    ),
    StepKind.observation => (
      title:
          outcomeLabel(l10n, step.outcome) ??
          (l10n.taskRecorderOutcomeUnknown),
      detail: detail,
    ),
    StepKind.annotation => (
      title: l10n.taskRecorderStepNote,
      detail: step.note,
    ),
    StepKind.excluded => (
      title:
          l10n.taskRecorderStepExcluded,
      detail: step.protectedCategory == null
          ? null
          : protectedLabel(l10n, step.protectedCategory!),
    ),
    StepKind.unrecorded => (
      title:
          l10n.taskRecorderStepUnrecorded,
      detail: null,
    ),
  };
}

/// #1872 — the steps as readable Markdown, for a package's transcript.
/// Words come from the labels above; nothing the recording does not
/// hold is added, and a note stays marked as the person's own.
String recordingTranscript(AppLocalizations l10n, TaskRecording recording) {
  final out = StringBuffer(
    '# ${recording.title ?? (l10n.taskRecorderUntitled)}\n\n',
  );
  var segment = 0;
  for (final step in recording.steps) {
    if (step.segment != segment) {
      segment = step.segment;
      out.writeln('— ${l10n.taskRecorderSegmentGap} —');
    }
    final text = stepText(l10n, step);
    out.write('${step.seq}. ${text.title}');
    if (text.detail != null) out.write(' — ${text.detail}');
    out.writeln();
    // What was entered or chosen, when the recording captured it.
    for (final e in step.values.entries.entries) {
      final shown = valueText(
        e.value,
        redacted: (n) =>
            l10n.taskExportValueRedacted(n),
        on: l10n.taskExportValueOn,
        off: l10n.taskExportValueOff,
      );
      out.writeln('   ${e.key}: $shown');
    }
  }
  out
    ..writeln()
    ..writeln(
    '${completenessLabel(l10n, recording.completeness)} · '
    '${endReasonLabel(l10n, recording.endReason)}',
  );
  return out.toString();
}

/// The words for a step's target: a booking field, or a workspace
/// feature by its own name (#1884).
/// A step's target in words. The vocabulary depends on the action (a
/// calendar kind and an event type can share a wire name), so the action
/// picks it; a target outside it reads "not recorded".
String targetLabel(AppLocalizations l10n, String target, {String? action}) {
  T? find<T>(List<T> values, bool Function(T) test) =>
      values.where(test).firstOrNull;
  switch (action) {
    case RecorderActions.switchFeature:
      final feature = find(WorkspaceFeature.values, (f) => f.name == target);
      if (feature != null) return featureName(l10n, feature);
    case RecorderActions.calendarFilterKind:
      if (target == calendarAllKinds) {
        return l10n.taskRecorderTargetAllKinds;
      }
      final kind = find(CalendarKind.values, (k) => k.wire == target);
      if (kind != null) return calendarKindLabel(l10n, kind);
    case RecorderActions.togglePermission:
      final permission = find(
        WorkspacePermission.values,
        (p) => p.wireName == target,
      );
      if (permission != null) return permissionLabel(l10n, permission);
    case RecorderActions.saveValidationRule:
      if (target == validationDefaultRule) {
        return l10n.taskRecorderTargetDefaultRule;
      }
      final rule = find(
        EventType.values,
        (t) => t != EventType.unknown && t.dbName == target,
      );
      if (rule != null) return eventTypeLabel(l10n, rule);
  }
  final kind = CalendarKind.values.where((k) => k.wire == target);
  if (kind.isNotEmpty) return calendarKindLabel(l10n, kind.first);
  return fieldLabel(l10n, target);
}

/// #2142 — a generic step's name, as a reader sees it; null when the
/// step is not a generic one.
String? uiTargetText(AppLocalizations l10n, String? action, String target) =>
    switch (action) {
      RecorderActions.uiTap || RecorderActions.uiCommitField
          when target == uiUnkeyed =>
        l10n.taskRecorderTargetUnkeyed,
      RecorderActions.uiCommand => target.replaceFirst(
        RegExp(r'\s+failed$'),
        '',
      ),
      RecorderActions.uiTap ||
      RecorderActions.uiCommitField ||
      RecorderActions.uiOpenScreen => target,
      _ => null,
    };
