// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4158 — the events feature's wording of a recorded target, composed into the
// task recorder where the app is assembled. The recorder owns the contract
// (`RecorderTargetVocabulary`); the events feature keeps owning the canonical
// event-type labels; neither imports the other for this.
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/events/domain/workspace_event.dart';
import '../features/events/presentation/event_labels.dart' show eventTypeLabel;
import '../features/task_recorder/domain/action_registry.dart';
import '../features/task_recorder/presentation/recorder_target_vocabulary.dart';
import '../l10n/app_localizations.dart';

/// A validation-rule step's target is an event type's database name.
@visibleForTesting
class EventTargetVocabulary implements RecorderTargetVocabulary {
  const EventTargetVocabulary();

  @override
  String? labelOf(AppLocalizations l10n, String action, String target) {
    if (action != RecorderActions.saveValidationRule) return null;
    for (final type in EventType.values) {
      if (type != EventType.unknown && type.dbName == target) {
        return eventTypeLabel(l10n, type);
      }
    }
    return null;
  }
}

/// Composes [EventTargetVocabulary] into a scope (main.dart, the Demo scope,
/// the test helper).
final List<Override> recorderTargetsFromApp = [
  recorderTargetVocabularyProvider.overrideWithValue(
    const EventTargetVocabulary(),
  ),
];
