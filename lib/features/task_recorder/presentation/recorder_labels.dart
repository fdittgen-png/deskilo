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
import '../../workspace/presentation/screens/roles_screen_labels.dart'
    show permissionLabel;
import '../../workspace/presentation/feature_names.dart';
import '../domain/action_registry.dart';
import '../domain/step_values.dart';
import '../domain/task_recording.dart';
import 'ui_labels.g.dart';

/// The sentence for a registered action; null for one this build does
/// not describe.
String? actionLabel(AppLocalizations? l10n, String? action) => switch (action) {
  RecorderActions.openReserve =>
    l10n?.taskRecorderActionOpenReserve ?? 'Opened Reserve',
  RecorderActions.selectDate =>
    l10n?.taskRecorderActionSelectDate ?? 'Chose the day',
  RecorderActions.selectPeriod =>
    l10n?.taskRecorderActionSelectPeriod ?? 'Chose the period',
  RecorderActions.switchView =>
    l10n?.taskRecorderActionSwitchView ?? 'Switched the view',
  RecorderActions.selectResource =>
    l10n?.taskRecorderActionSelectResource ?? 'Chose a place',
  RecorderActions.changeBookingField =>
    l10n?.taskRecorderActionChangeField ?? 'Changed a booking detail',
  RecorderActions.confirmBooking =>
    l10n?.taskRecorderActionConfirmBooking ?? 'Confirmed the booking',
  RecorderActions.cancelReview =>
    l10n?.taskRecorderActionCancelReview ??
        'Closed the booking without booking',
  RecorderActions.viewDetails =>
    l10n?.taskRecorderActionViewDetails ?? 'Opened the reservation',
  RecorderActions.back => l10n?.taskRecorderActionBack ?? 'Went back',
  RecorderActions.switchFeature =>
    l10n?.taskRecorderActionSwitchFeature ?? 'Switched a feature',
  RecorderActions.declineOptIn =>
    l10n?.taskRecorderActionDeclineOptIn ?? 'Did not switch on a test feature',
  RecorderActions.selectLevel =>
    l10n?.taskRecorderActionSelectLevel ?? 'Chose a level',
  RecorderActions.checkIn => l10n?.taskRecorderActionCheckIn ?? 'Checked in',
  RecorderActions.checkOut => l10n?.taskRecorderActionCheckOut ?? 'Checked out',
  RecorderActions.cancelReservation =>
    l10n?.taskRecorderActionCancelReservation ?? 'Cancelled the reservation',
  RecorderActions.closeMyReservation =>
    l10n?.taskRecorderActionCloseMyReservation ??
        'Closed my reservation without changing it',
  RecorderActions.calendarSwitchView =>
    l10n?.taskRecorderActionCalendarView ?? 'Switched the calendar view',
  RecorderActions.calendarMove =>
    l10n?.taskRecorderActionCalendarMove ?? 'Moved through the dates',
  RecorderActions.calendarSelectDay =>
    l10n?.taskRecorderActionCalendarSelectDay ?? 'Chose a day in the calendar',
  RecorderActions.calendarFilterKind =>
    l10n?.taskRecorderActionCalendarFilterKind ??
        'Changed what the calendar shows',
  RecorderActions.calendarChooseWhose =>
    l10n?.taskRecorderActionCalendarWhose ?? 'Chose whose calendar to see',
  RecorderActions.calendarOpenItem =>
    l10n?.taskRecorderActionCalendarOpenItem ??
        'Opened an entry from the calendar',
  RecorderActions.calendarCancelReservation =>
    l10n?.taskRecorderActionCalendarCancel ??
        'Cancelled a reservation from the calendar',
  RecorderActions.decideEvent =>
    l10n?.taskRecorderActionDecideEvent ?? 'Answered a request for a decision',
  RecorderActions.uiOpenScreen =>
    l10n?.taskRecorderActionUiOpenScreen ?? 'Opened a screen',
  RecorderActions.uiTap => l10n?.taskRecorderActionUiTap ?? 'Tapped',
  RecorderActions.uiCommitField =>
    l10n?.taskRecorderActionUiCommitField ?? 'Filled in a field',
  RecorderActions.uiCommand =>
    l10n?.taskRecorderActionUiCommand ?? 'Ran a command',
  RecorderActions.uiOpenWindow =>
    l10n?.taskRecorderActionUiOpenWindow ?? 'Opened a window',
  RecorderActions.uiCloseWindow =>
    l10n?.taskRecorderActionUiCloseWindow ?? 'Closed a window',
  RecorderActions.togglePermission =>
    l10n?.taskRecorderActionTogglePermission ?? 'Switched a permission',
  RecorderActions.saveRole =>
    l10n?.taskRecorderActionSaveRole ?? 'Saved a role',
  RecorderActions.giveRole =>
    l10n?.taskRecorderActionGiveRole ?? 'Gave or took back a role',
  RecorderActions.cancelRoleEdit =>
    l10n?.taskRecorderActionCancelRoleEdit ?? 'Closed the role without saving',
  RecorderActions.saveValidationRule =>
    l10n?.taskRecorderActionSaveValidationRule ?? 'Saved a validation rule',
  RecorderActions.cancelValidationRule =>
    l10n?.taskRecorderActionCancelValidationRule ??
        'Closed the rule without saving',
  _ => null,
};

/// The sentence for a registered outcome.
String? outcomeLabel(AppLocalizations? l10n, String? outcome) =>
    switch (outcome) {
      RecorderOutcomes.bookingConfirmed =>
        l10n?.taskRecorderOutcomeConfirmed ?? 'Booked',
      RecorderOutcomes.bookingRequested =>
        l10n?.taskRecorderOutcomeRequested ?? 'Sent for confirmation',
      RecorderOutcomes.seriesBooked =>
        l10n?.taskRecorderOutcomeSeries ?? 'Series booked',
      RecorderOutcomes.bookingRefused =>
        l10n?.taskRecorderOutcomeRefused ?? 'Refused',
      RecorderOutcomes.bookingUnknown =>
        l10n?.taskRecorderOutcomeUnknown ?? 'No answer came',
      RecorderOutcomes.settingSaved =>
        l10n?.taskRecorderOutcomeSettingSaved ?? 'Saved',
      RecorderOutcomes.settingNotSaved =>
        l10n?.taskRecorderOutcomeSettingNotSaved ?? 'Not saved',
      RecorderOutcomes.settingUnknown =>
        l10n?.taskRecorderOutcomeUnknown ?? 'No answer came',
      RecorderOutcomes.checkedIn =>
        l10n?.taskRecorderOutcomeCheckedIn ?? 'Checked in',
      RecorderOutcomes.checkedOut =>
        l10n?.taskRecorderOutcomeCheckedOut ?? 'Checked out',
      RecorderOutcomes.cancelled =>
        l10n?.taskRecorderOutcomeCancelled ?? 'Cancelled',
      RecorderOutcomes.reservationRefused =>
        l10n?.taskRecorderOutcomeRefused ?? 'Refused',
      RecorderOutcomes.reservationUnknown =>
        l10n?.taskRecorderOutcomeUnknown ?? 'No answer came',
      RecorderOutcomes.settingPending =>
        l10n?.taskRecorderOutcomeSettingPending ?? 'Sent for validation',
      RecorderOutcomes.eventDecided =>
        l10n?.taskRecorderOutcomeEventDecided ?? 'Answer recorded',
      RecorderOutcomes.eventNotConfirmed =>
        l10n?.taskRecorderOutcomeEventNotConfirmed ??
            'The answer was not confirmed',
      RecorderOutcomes.commandDone =>
        l10n?.taskRecorderOutcomeCommandDone ?? 'Done',
      RecorderOutcomes.commandPending =>
        l10n?.taskRecorderOutcomeCommandPending ?? 'Sent for validation',
      RecorderOutcomes.commandRefused =>
        l10n?.taskRecorderOutcomeRefused ?? 'Refused',
      RecorderOutcomes.commandUnknown =>
        l10n?.taskRecorderOutcomeUnknown ?? 'No answer came',
      _ => null,
    };

/// The words for one category value; the raw value is never shown.
String valueLabel(AppLocalizations? l10n, String value) => switch (value) {
  'today' => l10n?.taskRecorderValueToday ?? 'today',
  'tomorrow' => l10n?.taskRecorderValueTomorrow ?? 'tomorrow',
  'later_this_week' =>
    l10n?.taskRecorderValueLaterThisWeek ?? 'later this week',
  'later' => l10n?.taskRecorderValueLater ?? 'a later day',
  'past' => l10n?.taskRecorderValuePast ?? 'a past day',
  'full_day' => l10n?.taskRecorderValueFullDay ?? 'full day',
  'morning' => l10n?.taskRecorderValueMorning ?? 'morning',
  'afternoon' => l10n?.taskRecorderValueAfternoon ?? 'afternoon',
  'hours' => l10n?.taskRecorderValueHours ?? 'by the hour',
  'custom' => l10n?.taskRecorderValueCustom ?? 'custom times',
  'plan' => l10n?.taskRecorderValuePlan ?? 'plan',
  'list' => l10n?.taskRecorderValueList ?? 'list',
  'day' => l10n?.taskRecorderValueDay ?? 'day',
  'on' => l10n?.taskRecorderValueOn ?? 'on',
  'off' => l10n?.taskRecorderValueOff ?? 'off',
  'week' => l10n?.taskRecorderValueWeek ?? 'week',
  'month' => l10n?.taskRecorderValueMonth ?? 'month',
  'desk' => l10n?.taskRecorderValueDesk ?? 'a desk',
  'room' => l10n?.taskRecorderValueRoom ?? 'a room',
  'other' => l10n?.taskRecorderValueOther ?? 'other',
  'self' => l10n?.taskRecorderValueSelf ?? 'for me',
  'other_member' => l10n?.taskRecorderValueOtherMember ?? 'for another member',
  'once' => l10n?.taskRecorderValueOnce ?? 'once',
  'series' => l10n?.taskRecorderValueSeries ?? 'repeating',
  'all_booked' => l10n?.taskRecorderValueAllBooked ?? 'every date booked',
  'partially_booked' =>
    l10n?.taskRecorderValuePartiallyBooked ?? 'some dates refused',
  'conflict' => l10n?.taskRecorderValueConflict ?? 'already taken',
  'policy' => l10n?.taskRecorderValuePolicy ?? 'a booking rule',
  'quota' => l10n?.taskRecorderValueQuota ?? 'an allowance',
  'permission' => l10n?.taskRecorderValuePermission ?? 'a permission',
  'closed' => l10n?.taskRecorderValueClosed ?? 'closed',
  'offline' => l10n?.taskRecorderValueOffline ?? 'offline',
  'agenda' => l10n?.taskRecorderValueAgenda ?? 'agenda',
  'timeline' => l10n?.taskRecorderValueTimeline ?? 'timeline',
  'range' => l10n?.taskRecorderValueRange ?? 'a date range',
  'previous' => l10n?.taskRecorderValuePrevious ?? 'back',
  'next' => l10n?.taskRecorderValueNext ?? 'forward',
  'mine' => l10n?.taskRecorderValueMine ?? 'mine',
  'someone_else' => l10n?.taskRecorderValueSomeoneElse ?? 'another member\'s',
  'everyone' => l10n?.taskRecorderValueEveryone ?? 'everyone\'s',
  'conversation' => l10n?.taskRecorderValueConversation ?? 'a conversation',
  'alert' => l10n?.taskRecorderValueAlert ?? 'an alert',
  'decision' => l10n?.taskRecorderValueDecision ?? 'a decision',
  'payment' => l10n?.taskRecorderValuePayment ?? 'a payment',
  'invoice' => l10n?.taskRecorderValueInvoice ?? 'an invoice',
  'accept' => l10n?.taskRecorderValueAccept ?? 'accepted',
  'decline' => l10n?.taskRecorderValueDecline ?? 'declined',
  'owner' => l10n?.taskRecorderValueRoleOwner ?? 'the owner',
  'co_owner' => l10n?.taskRecorderValueRoleCoOwner ?? 'a co-owner',
  'admin' => l10n?.taskRecorderValueRoleAdmin ?? 'administrators',
  'member' => l10n?.taskRecorderValueRoleMember ?? 'every member',
  'created' => l10n?.taskRecorderValueCreated ?? 'created',
  'edited' => l10n?.taskRecorderValueEdited ?? 'edited',
  'renamed' => l10n?.taskRecorderValueRenamed ?? 'renamed',
  'withheld' => l10n?.taskRecorderValueWithheld ?? 'not recorded',
  _ => l10n?.taskRecorderValueWithheld ?? 'not recorded',
};

/// The words for a booking field a step changed.
String fieldLabel(AppLocalizations? l10n, String field) => switch (field) {
  'for_whom' => l10n?.taskRecorderFieldForWhom ?? 'who it is for',
  'repeat' => l10n?.taskRecorderFieldRepeat ?? 'repeat',
  'check_in' => l10n?.taskRecorderFieldCheckIn ?? 'check-in',
  'time' => l10n?.taskRecorderFieldTime ?? 'time',
  'accessories' => l10n?.taskRecorderFieldAccessories ?? 'accessories',
  _ => l10n?.taskRecorderValueWithheld ?? 'not recorded',
};

/// The words for a kind of protected screen.
String protectedLabel(AppLocalizations? l10n, ProtectedSurface category) =>
    switch (category) {
      ProtectedSurface.authentication =>
        l10n?.taskRecorderProtectedAuthentication ?? 'sign-in',
      ProtectedSurface.payment =>
        l10n?.taskRecorderProtectedPayment ?? 'payment',
      ProtectedSurface.provider =>
        l10n?.taskRecorderProtectedProvider ?? 'a provider\'s screen',
      ProtectedSurface.secrets =>
        l10n?.taskRecorderProtectedSecrets ?? 'keys and secrets',
      ProtectedSurface.messenger =>
        l10n?.taskRecorderProtectedMessenger ?? 'messages',
      ProtectedSurface.identity =>
        l10n?.taskRecorderProtectedIdentity ?? 'identity',
      ProtectedSurface.operator =>
        l10n?.taskRecorderProtectedOperator ?? 'installation operator',
    };

/// How complete a recording is, in words.
String completenessLabel(AppLocalizations? l10n, Completeness c) => switch (c) {
  Completeness.complete => l10n?.taskRecorderCompletenessComplete ?? 'Complete',
  Completeness.partial => l10n?.taskRecorderCompletenessPartial ?? 'Partial',
  Completeness.interrupted =>
    l10n?.taskRecorderCompletenessInterrupted ?? 'Interrupted',
};

/// Why a recording ended, in words.
String endReasonLabel(AppLocalizations? l10n, RecordingEndReason? r) =>
    switch (r) {
      RecordingEndReason.stopped =>
        l10n?.taskRecorderEndStopped ?? 'Stopped by you',
      RecordingEndReason.scopeChanged =>
        l10n?.taskRecorderEndScopeChanged ??
            'Ended: the account or workspace changed',
      RecordingEndReason.limitReached =>
        l10n?.taskRecorderEndLimitReached ?? 'Ended: a limit was reached',
      RecordingEndReason.storageFailed =>
        l10n?.taskRecorderEndStorageFailed ??
            'Ended: it could not be saved on this device',
      RecordingEndReason.interrupted || null =>
        l10n?.taskRecorderEndInterrupted ??
            'Interrupted: the app stopped while recording',
    };

/// One step as the person reads it: a title and an optional detail.
({String title, String? detail}) stepText(
  AppLocalizations? l10n,
  RecordedStep step,
) {
  // #2142 — a generic step reads in the app's own words when it has
  // them (its label, shown in the reader's language), else by its name.
  final label = step.payload.values['label'];
  final words = label == null || l10n == null ? null : uiLabel(l10n, label);
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
          (l10n?.taskRecorderStepUnrecorded ??
              'A step the recorder cannot describe'),
      detail: detail,
    ),
    StepKind.observation => (
      title:
          outcomeLabel(l10n, step.outcome) ??
          (l10n?.taskRecorderOutcomeUnknown ?? 'No answer came'),
      detail: detail,
    ),
    StepKind.annotation => (
      title: l10n?.taskRecorderStepNote ?? 'Your note',
      detail: step.note,
    ),
    StepKind.excluded => (
      title:
          l10n?.taskRecorderStepExcluded ?? 'A protected screen — not recorded',
      detail: step.protectedCategory == null
          ? null
          : protectedLabel(l10n, step.protectedCategory!),
    ),
    StepKind.unrecorded => (
      title:
          l10n?.taskRecorderStepUnrecorded ??
          'A step the recorder cannot describe',
      detail: null,
    ),
  };
}

/// #1872 — the steps as readable Markdown, for a package's transcript.
/// Words come from the labels above; nothing the recording does not
/// hold is added, and a note stays marked as the person's own.
String recordingTranscript(AppLocalizations? l10n, TaskRecording recording) {
  final out = StringBuffer(
    '# ${recording.title ?? (l10n?.taskRecorderUntitled ?? 'Untitled task')}\n\n',
  );
  var segment = 0;
  for (final step in recording.steps) {
    if (step.segment != segment) {
      segment = step.segment;
      out.writeln('— ${l10n?.taskRecorderSegmentGap ?? 'Paused here'} —');
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
            l10n?.taskExportValueRedacted(n) ?? 'not kept ($n characters)',
        on: l10n?.taskExportValueOn ?? 'on',
        off: l10n?.taskExportValueOff ?? 'off',
      );
      out.writeln('   ${e.key}: $shown');
    }
  }
  out.writeln();
  out.writeln(
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
String targetLabel(AppLocalizations? l10n, String target, {String? action}) {
  T? find<T>(List<T> values, bool Function(T) test) =>
      values.where(test).firstOrNull;
  switch (action) {
    case RecorderActions.switchFeature:
      final feature = find(WorkspaceFeature.values, (f) => f.name == target);
      if (feature != null) return featureName(l10n, feature);
    case RecorderActions.calendarFilterKind:
      if (target == calendarAllKinds) {
        return l10n?.taskRecorderTargetAllKinds ?? 'every kind';
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
        return l10n?.taskRecorderTargetDefaultRule ?? 'the default rule';
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
String? uiTargetText(AppLocalizations? l10n, String? action, String target) =>
    switch (action) {
      RecorderActions.uiTap || RecorderActions.uiCommitField
          when target == uiUnkeyed =>
        l10n?.taskRecorderTargetUnkeyed ?? 'an unnamed control',
      RecorderActions.uiCommand => target.replaceFirst(
        RegExp(r'\s+failed$'),
        '',
      ),
      RecorderActions.uiTap ||
      RecorderActions.uiCommitField ||
      RecorderActions.uiOpenScreen => target,
      _ => null,
    };
