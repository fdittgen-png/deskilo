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

  /// Defines or redefines a question **and its choices**, in one
  /// server transaction (#1288 S4, made atomic by #1532).
  ///
  /// Owner-only on the server; the key identifies the question and may
  /// not change, which is what makes the answers keep meaning
  /// something.
  ///
  /// The choices travel with the definition because the two are one
  /// decision. Saving them separately meant a refused choice — a
  /// malformed key, or removing one somebody had already made — left a
  /// live choice question with no choices, under a message saying the
  /// question had not been saved.
  ///
  /// [options] is null for a question that has no choices, which is not
  /// the same as an empty list: an empty list asks for every existing
  /// choice to be removed, and the server refuses that once somebody has
  /// chosen one.
  Future<String> saveField(
    String workspaceId,
    WorkspaceField field, {
    List<WorkspaceFieldOption>? options,
  });
}
