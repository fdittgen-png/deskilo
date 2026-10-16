// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 - the codec lives in packages/deskilo_task_recording and takes the
// catalogue as an argument. These two entry points bind it to the
// catalogue this build records against, so existing callers are unchanged.

import 'package:deskilo_task_recording/task_recording.dart' as core;
import 'package:deskilo_task_recording/task_recording_codec.dart' as core;

import 'action_registry.dart';

export 'package:deskilo_task_recording/task_recording_codec.dart'
    hide decodeRecording, decodeRecordingText;

/// Reads [text] against [registry] (this build's by default).
core.RecordingDecodeResult decodeRecordingText(
  String text, {
  ActionRegistry registry = recorderRegistry,
  core.RecordingLimits limits = const core.RecordingLimits(),
}) => core.decodeRecordingText(text, registry: registry, limits: limits);

/// Validates an already parsed recording against [registry].
core.RecordingDecodeResult decodeRecording(
  Object? json, {
  ActionRegistry registry = recorderRegistry,
  core.RecordingLimits limits = const core.RecordingLimits(),
}) => core.decodeRecording(json, registry: registry, limits: limits);
