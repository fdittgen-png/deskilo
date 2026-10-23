// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A setup step's unfinished answers as the server keeps them
// (setup_step_drafts): one per step and per workspace, shared by everyone
// who configures the space, and never configuration — the step's own
// command applies what the owner confirms, and readiness is computed from
// what was applied. Every write is made against the version it read.
import '../../../core/data/json_reader.dart';

/// The draft the server holds for one step.
class SetupStepDraft {
  const SetupStepDraft({
    required this.payload,
    required this.version,
    required this.updatedAt,
    this.updatedByName,
  });

  /// The step's answers, keyed as the step page writes them.
  final Map<String, Object?> payload;

  /// The version a later save or discard is made against.
  final int version;
  final DateTime updatedAt;

  /// Who saved it last, as documents print a name; null when unknown.
  final String? updatedByName;

  /// `get_setup_step_draft`'s answer; null when there is no draft.
  static SetupStepDraft? fromJson(Object? json) {
    if (json == null) return null;
    final r = JsonReader.of(json, context: 'get_setup_step_draft');
    return SetupStepDraft(
      payload: r.objectOrEmpty('payload'),
      version: r.integer('version'),
      updatedAt: r.dateTime('updated_at'),
      updatedByName: r.stringOrNull('updated_by_name'),
    );
  }
}

/// What a save answered: the stored version and when it was written.
class SetupDraftWrite {
  const SetupDraftWrite({required this.version, required this.updatedAt});

  final int version;
  final DateTime updatedAt;

  static SetupDraftWrite fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'save_setup_step_draft');
    return SetupDraftWrite(
      version: r.integer('version'),
      updatedAt: r.dateTime('updated_at'),
    );
  }
}

/// The draft moved since it was read — another configurer saved or
/// discarded it. Nothing was written: the caller shows the other answers
/// and lets the person choose, never retries over them.
class SetupDraftConflict implements Exception {
  const SetupDraftConflict(this.message);

  /// The server raises this state with a message starting with
  /// [messagePrefix] (setup_step_drafts' functions).
  static const String sqlState = '40001';
  static const String messagePrefix = 'setup draft changed:';

  /// Whether a server error with [code] and [message] is this conflict.
  static bool isConflict(String? code, String? message) =>
      code == sqlState && (message?.startsWith(messagePrefix) ?? false);

  final String message;

  @override
  String toString() => 'SetupDraftConflict: $message';
}
