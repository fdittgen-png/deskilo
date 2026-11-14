// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3629 — the setup guide's pages by their address under `/setup`: the
// router builds them as pages of their own below the desk, and the guide
// draws them beside its steps on the desk. One builder for both, so a step
// is the same page wherever it is drawn.
import 'package:flutter/widgets.dart';

import '../../core/ui/wizard_navigation.dart';
import '../../features/plan/presentation/widgets/setup_places_step.dart';
import '../../features/workspace/presentation/screens/setup_launch_screen.dart';
import '../../features/workspace/presentation/screens/setup_levels_screen.dart';
import '../../features/workspace/presentation/screens/setup_step_screen.dart';
import 'setup_grow_pages.dart';
import 'setup_run_pages.dart';

/// The step open now's way out, asked by the router's `onExit` of a step:
/// the step mounted last answers it.
final setupStepNavigation = WizardNavigationController();

/// The page [address] names under `/setup`: `levels`, `launch` or
/// `step/<id>`; null for any other.
Widget? setupPageFor(String address) => switch (address.split('/')) {
  ['levels'] => const SetupLevelsScreen(),
  ['launch'] => const SetupLaunchScreen(),
  ['step', final id] => SetupStepScreen(
    stepId: id,
    placesStep: SetupPlacesStep.new,
    runPages: setupRunPages,
    growPages: setupGrowPages,
    moneyRecorded: setupMoneyRecorded,
    navigation: setupStepNavigation,
  ),
  _ => null,
};
