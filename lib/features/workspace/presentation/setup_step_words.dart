// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/dictionary_labels.dart';
import '../domain/setup_status.dart';

/// #3282 — where a step stands, in words that tell apart what is merely
/// switched on, what is configured, what the server checked, and what waits
/// for the owner's own decision (a step the server cannot verify).
String setupStepWord(AppLocalizations l10n, SetupStepStatus step) =>
    switch ((step.state, step.manual)) {
      (SetupStepState.ready, false) => l10n.setupStateVerified,
      (SetupStepState.ready, true) => l10n.setupStateMarkedDone,
      (SetupStepState.needsConfiguration, false) => l10n.setupStateEnabled,
      (SetupStepState.needsConfiguration, true) => l10n.setupStateNeedsDecision,
      (SetupStepState.unknown, _) => l10n.setupOverviewUnchecked,
      (final state, _) => l10n.setupStateName(state.name),
    };

/// Where a step stands, as its mark: the guide's list and the steps beside
/// a step on the desk (#3629) draw the same one.
IconData setupStepIcon(SetupStepState state) => switch (state) {
  SetupStepState.ready => Icons.check_circle_outline,
  SetupStepState.needsConfiguration => Icons.radio_button_unchecked,
  SetupStepState.blocked => Icons.hourglass_empty,
  SetupStepState.needsOperator => Icons.dns_outlined,
  SetupStepState.notApplicable => Icons.remove_circle_outline,
  SetupStepState.deferred => Icons.schedule,
  SetupStepState.unknown => Icons.help_outline,
};
