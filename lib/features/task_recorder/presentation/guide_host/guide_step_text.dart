// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — what a guide step asks, in the reader's words.
//
// The author's own text wins. Otherwise the step is said from what the
// recorder knows about it: the app message the control showed ("Tap
// “Save”"), or the kind of thing to do ("Fill in the highlighted
// field"), or the screen seam's own action. Never raw text that is not
// an app message, never a recorded value.

import '../../../../l10n/app_localizations.dart';
import '../../domain/action_registry.dart';
import '../../guide/task_guide.dart';
import '../../domain/recording_reference.dart';
import '../recorder_labels.dart';
import '../ui_labels.g.dart';

export '../../guide/guide_destination.dart' show guideStepRoute;

/// The words for [step].
String guideStepText(AppLocalizations? l10n, GuideStep step) {
  final own = step.text?.trim();
  if (own != null && own.isNotEmpty) return own;
  switch (step.kind) {
    case GuideStepKind.instruction:
      return l10n?.guideHostInstruction ?? 'Read this, then mark it done.';
    case GuideStepKind.manual:
      final category = step.manualCategory;
      if (category != null) {
        final name = protectedLabel(l10n, category);
        return l10n?.guideHostManualProtected(name) ??
            'This part happens on a protected screen ($name). Do it '
                'yourself, then mark it done.';
      }
      final page = step.destination;
      if (page != null) {
        final form = guideDestinationLabel(l10n, page);
        return l10n?.guideHostManualAt(form) ??
            'Complete this step on “$form”, then mark it done.';
      }
      return l10n?.guideHostDestinationMissing ??
          'Choose a page in the guide editor.';
    case GuideStepKind.perform:
      return _performText(l10n, step);
  }
}

String _performText(AppLocalizations? l10n, GuideStep step) {
  final label = step.label == null || l10n == null
      ? null
      : uiLabel(l10n, step.label!);
  switch (step.action) {
    case RecorderActions.uiTap:
      return label != null
          ? (l10n?.guideHostTapLabel(label) ?? 'Tap “$label”.')
          : (l10n?.guideHostTapControl ?? 'Tap the highlighted control.');
    case RecorderActions.uiCommitField:
      return label != null
          ? (l10n?.guideHostFillLabel(label) ??
                'Fill in “$label”, then leave the field.')
          : (l10n?.guideHostFillField ??
                'Fill in the highlighted field, then leave it.');
    case RecorderActions.uiOpenScreen:
      final page = step.destination ?? guidePageForTarget(step.target);
      final name =
          label ?? (page == null ? null : guideDestinationLabel(l10n, page));
      return name != null
          ? (l10n?.guideHostOpenLabel(name) ?? 'Open “$name”.')
          : (l10n?.guideHostDestinationMissing ??
                'Choose a page in the guide editor.');
    case RecorderActions.changeBookingField:
      final target = step.target;
      if (target != null) {
        final name = targetLabel(l10n, target, action: step.action);
        return l10n?.guideHostTapLabel(name) ?? 'Tap “$name”.';
      }
      return l10n?.guideHostFillField ??
          'Fill in the highlighted field, then leave it.';
    case RecorderActions.uiCommand:
      return l10n?.guideHostCommand ?? 'Confirm, then wait for the result.';
  }
  final action =
      _seamAction(l10n, step.action) ??
      actionLabel(l10n, step.action) ??
      step.action ??
      '';
  return l10n?.guideHostDoAction(action) ?? 'Next: $action.';
}

/// The imperative words of the booking seam's actions.
String? _seamAction(AppLocalizations? l10n, String? action) => switch (action) {
  RecorderActions.openReserve => l10n?.guideActionOpenReserve ?? 'open Reserve',
  RecorderActions.selectDate => l10n?.guideActionSelectDate ?? 'choose the day',
  RecorderActions.selectPeriod =>
    l10n?.guideActionSelectPeriod ?? 'choose the period',
  RecorderActions.selectResource =>
    l10n?.guideActionSelectResource ??
        'choose a place on the plan or in the list',
  RecorderActions.confirmBooking =>
    l10n?.guideActionConfirmBooking ??
        'confirm the booking and wait for the answer',
  _ => null,
};

/// The control a step points at: its recorded target when that names a
/// control, else the existing key of a screen seam's own control. Null
/// when the step happens anywhere (the host then only says it).
String? guideStepAnchor(GuideStep step) {
  final target = step.target;
  if (target != null &&
      (step.action == RecorderActions.uiTap ||
          step.action == RecorderActions.uiCommitField)) {
    return target;
  }
  return switch (step.action) {
    RecorderActions.selectDate => 'reserve-date-button',
    RecorderActions.selectPeriod => 'reserve-window-controls',
    RecorderActions.switchView => 'reserve-seat-view-switch',
    RecorderActions.confirmBooking => 'booking-confirm',
    RecorderActions.changeBookingField => switch (target) {
      'for_whom' => 'booking-for-member',
      'repeat' => 'booking-repeat',
      'check_in' => 'booking-check-in-now',
      'time' => 'booking-from-tile',
      _ => null,
    },
    _ => null,
  };
}

/// Reader-facing page names, including the personal tab within Me.
String guideDestinationLabel(AppLocalizations? l10n, String route) {
  final uri = Uri.parse(route);
  if (uri.path == '/me') {
    final tab = switch (uri.queryParameters['tab']) {
      'discover' => l10n?.meTabDiscover ?? 'Discover',
      'messages' => l10n?.meTabMessages ?? 'Messages',
      'me' => l10n?.meGroupProfile ?? 'My profile',
      _ => l10n?.meTabHome ?? 'Home',
    };
    return '${l10n?.meTabMe ?? 'Me'} · $tab';
  }
  final key = const {
    '/reserve': 'shellReserveButton',
    '/calendar': 'tabCalendar',
    '/members': 'membersTitle',
    '/directory': 'directoryTitle',
    '/discover': 'meTabDiscover',
    '/messages': 'messagesTitle',
    '/money': 'tabMoney',
    '/features': 'featuresTitle',
    '/roles': 'rolesTitle',
    '/validation': 'validationTitle',
    '/settings': 'settingsTitle',
    '/workspace-settings': 'workspaceSettingsTitle',
  }[uri.path];
  final label = l10n == null || key == null ? null : uiLabel(l10n, key);
  if (label != null) return label;
  return uri.path
      .split('/')
      .where((part) => part.isNotEmpty)
      .map((part) {
        final words = part.replaceAll('-', ' ');
        return '${words[0].toUpperCase()}${words.substring(1)}';
      })
      .join(' › ');
}
