// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4158 (A3 of #4174) — the words for a recorded target the recorder does not
// own. A step is stored as identifiers; the recorder turns most of them into
// sentences itself, but the target of a validation-rule step is an event type,
// and the events feature owns that wording. Instead of importing the events
// feature to name it, the recorder asks a small read-only contract, and the
// app composes the events implementation into it (lib/app). The contract takes
// the recorded primitives and returns a label or "not mine"; it exposes no
// event type, aggregate, repository or registration.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';

/// Resolves a recorded [action]'s [target] to words in [l10n]'s language.
abstract interface class RecorderTargetVocabulary {
  /// The label of [target] as recorded under [action], or null when this
  /// vocabulary does not describe it (the recorder then reads it as it reads
  /// any target it cannot name).
  String? labelOf(AppLocalizations l10n, String action, String target);
}

/// What the app composes in. There is NO default: a scope that shows or
/// exports a recording without composing one fails loudly (a missed injection
/// would otherwise read every validation rule as an unknown target).
final recorderTargetVocabularyProvider = Provider<RecorderTargetVocabulary>(
  (ref) => throw StateError(
    'recorderTargetVocabularyProvider is not composed: the app wires it '
    '(lib/app/recorder_target_wiring.dart) in main, the Demo scope and tests',
  ),
);
