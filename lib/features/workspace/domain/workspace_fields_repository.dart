// SPDX-License-Identifier: 0BSD
//
// #1288 S2 — reading the questions and writing the answers.
//
// Two reads and one write. The write is deliberately the whole context's
// answers at once, because that is what 0248's `set_member_field_values`
// takes: it refuses to leave a required question of the context
// unanswered, which it can only judge when it sees them together.
import 'workspace_field.dart';

abstract class WorkspaceFieldsRepository {
  /// Every question the workspace defines, with its labels and choices.
  Future<List<WorkspaceField>> fetchFields(String workspaceId);

  /// One member's answers, by field key, in the wire shapes
  /// [fieldProblem] reads: `String`, `num`, `bool`, `List<String>`.
  ///
  /// A question the caller may not read is simply absent — the server
  /// decides that through the definition's visibility, and the form
  /// renders what came back rather than asking again.
  Future<Map<String, Object?>> fetchAnswers(String memberId);

  /// Saves [answers] for [memberId] in [context].
  ///
  /// The server validates every one and writes none if any fails, so a
  /// refusal leaves the member's answers exactly as they were.
  Future<void> saveAnswers({
    required String memberId,
    required WorkspaceFieldContext context,
    required Map<String, Object?> answers,
  });

  /// Defines or redefines a question (#1288 S4). Owner-only on the
  /// server; the key identifies it and may not change, which is what
  /// makes the answers keep meaning something.
  ///
  /// Returns the definition's id, so the choices can be written next.
  Future<String> setField(String workspaceId, WorkspaceField field);

  /// Replaces the choices of a choice question, wholesale.
  ///
  /// Wholesale because that is the only shape that can express "this one
  /// is gone" — and the server refuses to remove a choice somebody has
  /// already made, which is a conflict a person decides rather than a
  /// cascade.
  Future<void> setOptions(String definitionId, List<WorkspaceFieldOption> options);
}
