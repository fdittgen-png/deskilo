// SPDX-License-Identifier: 0BSD
//
// #1288 S2 — the questions and answers, in memory.
//
// It enforces the rules 0248 enforces, because a fake that accepts what
// the server refuses lets a screen ship a Save the server will reject.
// The rules it CANNOT enforce — who may read an answer, which is a
// policy — it does not pretend to: the database test owns those.
import '../../../features/workspace/domain/workspace_field.dart';
import '../../../features/workspace/domain/workspace_field_answer.dart';
import '../../../features/workspace/domain/workspace_fields_repository.dart';

class FakeWorkspaceFields implements WorkspaceFieldsRepository {
  final fields = <WorkspaceField>[];

  /// member id → field key → answer.
  final answers = <String, Map<String, Object?>>{};

  /// Every save the screens made, in order, for assertions.
  final saved = <({String memberId, WorkspaceFieldContext context})>[];

  @override
  Future<List<WorkspaceField>> fetchFields(String workspaceId) async =>
      List.of(fields);

  @override
  Future<Map<String, Object?>> fetchAnswers(String memberId) async =>
      Map.of(answers[memberId] ?? const {});

  @override
  Future<void> saveAnswers({
    required String memberId,
    required WorkspaceFieldContext context,
    required Map<String, Object?> answers,
  }) async {
    final asked = fieldsForContext(fields, context);
    final byKey = {for (final f in asked) f.key: f};

    for (final entry in answers.entries) {
      final field = byKey[entry.key];
      // 0248: `% is not a question asked here`.
      if (field == null) {
        throw StateError('${entry.key} is not a question asked here');
      }
      final problem = fieldProblem(field, entry.value);
      if (problem != null) throw StateError('${entry.key}: ${problem.name}');
    }

    final stored = this.answers[memberId] ??= {};
    stored.addAll(answers);

    // 0248 refuses to leave a required question of the context
    // unanswered, and judges that AFTER the writes, over everything the
    // member has — not only over what this call sent.
    for (final field in asked) {
      if (!field.required) continue;
      if (fieldProblem(field, stored[field.key]) == FieldProblem.required) {
        throw StateError('${field.key}: required');
      }
    }
    saved.add((memberId: memberId, context: context));
  }
}
