// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 - the guide state machine (#1867) lives in
// packages/deskilo_task_recording; the host binds it to its own catalogue.
import 'package:deskilo_task_recording/guide_run.dart' as core;

import '../domain/action_registry.dart';

export 'package:deskilo_task_recording/guide_run.dart' hide GuideRun;

/// The core state machine, defaulting to Deskilo's catalogue.
class GuideRun extends core.GuideRun {
  GuideRun(super.guide, {super.registry = recorderRegistry});
}
