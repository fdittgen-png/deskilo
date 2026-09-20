// SPDX-License-Identifier: AGPL-3.0-or-later
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

  /// 0252 writes the definition and its choices in ONE transaction, so
  /// this fake must too: a fake where a refused choice left the
  /// definition behind would let a screen test pass on a state the
  /// server cannot produce (#1532).
  @override
  Future<String> saveField(
    String workspaceId,
    WorkspaceField field, {
    List<WorkspaceFieldOption>? options,
  }) async {
    final before = List<WorkspaceField>.of(fields);
    try {
      final id = await _setField(workspaceId, field);
      if (options != null) await _setOptions(id, options);
      return id;
      // ignore: catch_no_st
    } catch (_) {
      // Rethrow-only: the refusal is the caller's to report, and this
      // block exists to put the fake back the way the server would.
      fields
        ..clear()
        ..addAll(before);
      rethrow;
    }
  }

  Future<String> _setField(String workspaceId, WorkspaceField field) async {
    // 0248 refuses a type change while answers exist, and so does this:
    // a fake that allowed it would let the editor ship a Save the server
    // rejects, with every screen test green.
    final at = fields.indexWhere((f) => f.key == field.key);
    if (at >= 0) {
      final existing = fields[at];
      final answered = answers.values.any(
        (byKey) => byKey.containsKey(field.key),
      );
      if (existing.type != field.type && answered) {
        throw StateError('the type of ${field.key} cannot change while it '
            'has answers');
      }
      fields[at] = WorkspaceField(
        id: existing.id,
        key: field.key,
        type: field.type,
        labels: field.labels,
        helpTexts: field.helpTexts,
        required: field.required,
        personalData: field.personalData,
        visibility: field.visibility,
        contexts: field.contexts,
        groupKey: field.groupKey,
        sortOrder: field.sortOrder,
        validation: field.validation,
        active: field.active,
        options: existing.options,
      );
      return existing.id;
    }
    final id = field.id.isEmpty ? 'field-${fields.length + 1}' : field.id;
    fields.add(
      WorkspaceField(
        id: id,
        key: field.key,
        type: field.type,
        labels: field.labels,
        helpTexts: field.helpTexts,
        required: field.required,
        personalData: field.personalData,
        visibility: field.visibility,
        contexts: field.contexts,
        groupKey: field.groupKey,
        sortOrder: field.sortOrder,
        validation: field.validation,
        active: field.active,
      ),
    );
    return id;
  }

  Future<void> _setOptions(
    String definitionId,
    List<WorkspaceFieldOption> options,
  ) async {
    final at = fields.indexWhere((f) => f.id == definitionId);
    if (at < 0) throw StateError('no such question');
    final existing = fields[at];
    // 0248: `a choice key is lower-case letters, digits and
    // underscores`. The fake enforces it because without it a NEW
    // question can never fail on its choices here, and the transaction
    // that takes it back would have no test that could fire (#1532).
    for (final option in options) {
      if (!RegExp(r'^[a-z0-9][a-z0-9_]{0,40}$').hasMatch(option.key)) {
        throw StateError(
            'a choice key is lower-case letters, digits and underscores');
      }
    }

    // 0248: a choice somebody has made cannot simply vanish.
    //
    // A multi-choice answer is a List, a single-choice answer a String.
    // This tested the List shape with `as List?`, which THROWS on a
    // String rather than answering null — so for a single-choice
    // question the rule never fired at all, it crashed (#1532).
    final keys = {for (final o in options) o.key};
    final chosen = <String>{
      for (final byKey in answers.values)
        if (byKey[existing.key] case final List<Object?> made)
          ...made.cast<String>()
        else if (byKey[existing.key] case final String made)
          made,
    };
    for (final made in chosen) {
      if (!keys.contains(made)) {
        throw StateError('a choice that has been made cannot be removed; '
            'deactivate it instead');
      }
    }
    fields[at] = WorkspaceField(
      id: existing.id,
      key: existing.key,
      type: existing.type,
      labels: existing.labels,
      helpTexts: existing.helpTexts,
      required: existing.required,
      personalData: existing.personalData,
      visibility: existing.visibility,
      contexts: existing.contexts,
      groupKey: existing.groupKey,
      sortOrder: existing.sortOrder,
      validation: existing.validation,
      active: existing.active,
      options: options,
    );
  }

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
