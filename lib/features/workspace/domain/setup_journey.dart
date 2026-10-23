// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 — the owner's answers to the setup questions and the levels they
// chose, as the server keeps them (workspace_setup_journeys): one per
// workspace, shared by everyone who configures it, so the levels screen
// reopens with them on any device. Never configuration: the features are
// what applying the levels wrote; the journey only remembers why. Every
// write is made against the version it read.
import '../../../core/data/json_reader.dart';
import 'setup_levels.dart';

/// The journey the server holds for one workspace.
class SetupJourney {
  const SetupJourney({
    required this.answers,
    required this.levels,
    required this.version,
    this.updatedByName,
  });

  final SetupAnswers answers;

  /// The level of each process the owner applied; a process this app does
  /// not know, or a level it does not have, is left out.
  final SetupLevelVector levels;

  /// The version a later save is made against.
  final int version;

  /// Who saved it last, as documents print a name; null when unknown.
  final String? updatedByName;

  /// `get_setup_journey`'s answer; null when nothing was saved yet.
  static SetupJourney? fromJson(Object? json) {
    if (json == null) return null;
    final r = JsonReader.of(json, context: 'get_setup_journey');
    final levels = r.objectOrEmpty('levels');
    return SetupJourney(
      answers: SetupAnswers.fromJson(r.objectOrEmpty('answers')),
      levels: {
        for (final p in SetupProcess.values)
          if (levels[p.name] case final String level
              when setupLevels[p]!.any((l) => l.id == level))
            p: level,
      },
      version: r.integer('version'),
      updatedByName: r.stringOrNull('updated_by_name'),
    );
  }
}

/// The journey moved since it was read — another configurer saved theirs.
/// Nothing was written: the caller shows the stored answers again.
class SetupJourneyConflict implements Exception {
  const SetupJourneyConflict(this.message);

  /// The server raises this state with a message starting with
  /// [messagePrefix] (save_setup_journey).
  static const String sqlState = '40001';
  static const String messagePrefix = 'setup journey changed:';

  /// Whether a server error with [code] and [message] is this conflict.
  static bool isConflict(String? code, String? message) =>
      code == sqlState && (message?.startsWith(messagePrefix) ?? false);

  final String message;

  @override
  String toString() => 'SetupJourneyConflict: $message';
}
