// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 — the owner's answers to the setup questions and the levels they
// chose, as the server keeps them (workspace_setup_journeys): one per
// workspace, shared by everyone who configures it, so the levels screen
// reopens with them on any device. Never configuration: the features are
// what applying the levels wrote; the journey only remembers why. Every
// write is made against the version it read. A file web/setup.html wrote
// carries the same answers and levels as its `<profile>`.
import 'package:xml/xml.dart';

import '../../../core/data/json_reader.dart';
import 'setup_levels.dart';

/// The level of each process in [levels] (process name → level id) that
/// this app knows; any other process or level is left out.
SetupLevelVector _knownSetupLevels(Map<String, Object?> levels) => {
  for (final p in SetupProcess.values)
    if (levels[p.name] case final String level
        when setupLevels[p]!.any((l) => l.id == level))
      p: level,
};

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
      levels: _knownSetupLevels(levels),
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

/// #2868 — the `<profile>` web/setup.html writes inside `<setup>` once its
/// questions step was used: each answer, and the level each process
/// reached.
class SetupProfile {
  const SetupProfile({required this.answers, required this.levels});

  final SetupAnswers answers;
  final SetupLevelVector levels;

  /// The profile of the workspace file [xml]; null when it carries none
  /// (made without the questions step, or exported by the app). Answers
  /// and levels this app does not know are left out, as in a stored
  /// journey.
  static SetupProfile? fromWorkspaceXml(String xml) {
    final profile = XmlDocument.parse(
      xml,
    ).rootElement.getElement('setup')?.getElement('profile');
    if (profile == null) return null;
    return SetupProfile(
      answers: SetupAnswers.fromJson({
        for (final a in profile.findElements('answer'))
          if (a.getAttribute('question') case final String q)
            q: a.getAttribute('value') == 'true',
      }),
      levels: _knownSetupLevels({
        for (final l in profile.findElements('level'))
          if (l.getAttribute('of') case final String p)
            p: l.getAttribute('value'),
      }),
    );
  }
}
