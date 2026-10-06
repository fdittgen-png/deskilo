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
import '../recorder_labels.dart';
import '../ui_labels.g.dart';

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
      return l10n?.guideHostManual ??
          'Do this step yourself, then mark it done.';
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
      return label != null
          ? (l10n?.guideHostOpenLabel(label) ?? 'Open “$label”.')
          : (l10n?.guideHostOpenScreen ?? 'Open the next screen.');
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
    RecorderActions.switchView => 'reserve-seat-view-switch',
    RecorderActions.confirmBooking => 'booking-confirm',
    _ => null,
  };
}

/// The page a step happens on, when it can be opened straight away — the
/// "Go to page" button. A screen the recorder has a seam for names its page;
/// any other step happens on the page the guide last opened (the nearest
/// earlier `ui.open_screen` step), and only a page without parameters counts:
/// a route like `/member/:id` has no address without an id, so no button is
/// offered for it rather than a guess.
String? guideStepRoute(List<GuideStep> steps, GuideStep step) {
  final bySurface = _surfaceRoutes[recorderRegistry.action(step.action)?.surface];
  if (bySurface != null) return bySurface;
  // The step may be a recovery step: find the main step that holds it.
  final holder = steps.indexWhere(
    (s) => s.id == step.id || s.recovery.any((r) => r.id == step.id),
  );
  if (holder < 0) return null;
  for (var i = holder; i >= 0; i--) {
    final s = steps[i];
    if (s.action == RecorderActions.uiOpenScreen) {
      final route = s.target;
      return route != null && !route.contains(':') && uiRoutes.contains(route)
          ? route
          : null;
    }
    final named = _surfaceRoutes[recorderRegistry.action(s.action)?.surface];
    if (named != null) return named;
  }
  return null;
}

/// The page each screen seam's surface lives on.
const Map<String, String> _surfaceRoutes = {
  RecorderSurfaces.reserve: '/reserve',
  RecorderSurfaces.bookingSheet: '/reserve',
  RecorderSurfaces.calendar: '/calendar',
  RecorderSurfaces.eventDecisions: '/calendar',
  RecorderSurfaces.workspaceFeatures: '/features',
  RecorderSurfaces.roles: '/roles',
  RecorderSurfaces.validationRules: '/validation',
};
