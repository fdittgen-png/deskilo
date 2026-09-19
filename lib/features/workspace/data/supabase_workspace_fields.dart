// SPDX-License-Identifier: 0BSD
//
// #1288 S2 — the questions and answers of 0248, read through its own
// policies and written through its own definer.
//
// The reads are plain selects: the select policies on the six tables
// decide what comes back, and an answer the caller may not see simply
// does not arrive. The write is `set_member_field_values`, which
// validates every answer and writes none if one fails.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_field.dart';
import '../domain/workspace_fields_repository.dart';

class SupabaseWorkspaceFields implements WorkspaceFieldsRepository {
  const SupabaseWorkspaceFields(this._client);

  final SupabaseClient _client;

  @override
  Future<List<WorkspaceField>> fetchFields(String workspaceId) async {
    final rows = await _client
        .from('workspace_field_definitions')
        .select('id, key, type, required, personal_data, visibility, '
            'contexts, group_key, sort_order, validation, active, '
            'workspace_field_labels(locale, label, help_text), '
            'workspace_field_options(id, key, sort_order, active, '
            'workspace_field_option_labels(locale, label))')
        .eq('workspace_id', workspaceId);

    final fields = <WorkspaceField>[];
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final type = WorkspaceFieldType.of('${map['type']}');
      // A type this app does not know is a server newer than the app.
      // Skipping it renders the rest rather than the error screen.
      if (type == null) continue;

      final labels = <String, String>{};
      final helps = <String, String>{};
      for (final l in (map['workspace_field_labels'] as List? ?? const [])) {
        final label = Map<String, dynamic>.from(l as Map);
        labels['${label['locale']}'] = '${label['label']}';
        final help = '${label['help_text'] ?? ''}';
        if (help.isNotEmpty) helps['${label['locale']}'] = help;
      }

      final options = <WorkspaceFieldOption>[];
      for (final o in (map['workspace_field_options'] as List? ?? const [])) {
        final option = Map<String, dynamic>.from(o as Map);
        final optionLabels = <String, String>{};
        for (final l in (option['workspace_field_option_labels'] as List? ??
            const [])) {
          final label = Map<String, dynamic>.from(l as Map);
          optionLabels['${label['locale']}'] = '${label['label']}';
        }
        options.add(
          WorkspaceFieldOption(
            key: '${option['key']}',
            labels: optionLabels,
            sortOrder: (option['sort_order'] as num?)?.toInt() ?? 0,
            active: option['active'] as bool? ?? true,
          ),
        );
      }

      fields.add(
        WorkspaceField(
          id: '${map['id']}',
          key: '${map['key']}',
          type: type,
          labels: labels,
          helpTexts: helps,
          required: map['required'] as bool? ?? false,
          personalData: map['personal_data'] as bool? ?? true,
          visibility:
              WorkspaceFieldVisibility.of('${map['visibility'] ?? 'self'}'),
          contexts: {
            for (final c in (map['contexts'] as List? ?? const []))
              ?WorkspaceFieldContext.of('$c'),
          },
          groupKey: '${map['group_key'] ?? 'general'}',
          sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
          validation: Map<String, Object?>.from(
            map['validation'] as Map? ?? const {},
          ),
          active: map['active'] as bool? ?? true,
          options: options,
        ),
      );
    }
    return fields;
  }

  @override
  Future<Map<String, Object?>> fetchAnswers(String memberId) async {
    final rows = await _client
        .from('workspace_field_values')
        .select('text_value, integer_value, decimal_value, date_value, '
            'boolean_value, workspace_field_definitions(key, type), '
            'workspace_field_value_options(workspace_field_options(key))')
        .eq('member_id', memberId);

    final answers = <String, Object?>{};
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final definition = map['workspace_field_definitions'] as Map?;
      if (definition == null) continue;
      final key = '${definition['key']}';
      final type = WorkspaceFieldType.of('${definition['type']}');

      if (type == WorkspaceFieldType.multiChoice) {
        answers[key] = [
          for (final c in (map['workspace_field_value_options'] as List? ??
              const []))
            '${(Map<String, dynamic>.from(c as Map)['workspace_field_options'] as Map?)?['key']}',
        ];
        continue;
      }
      answers[key] = map['text_value'] ??
          map['integer_value'] ??
          map['decimal_value'] ??
          map['date_value'] ??
          map['boolean_value'];
    }
    return answers;
  }

  @override
  Future<void> saveAnswers({
    required String memberId,
    required WorkspaceFieldContext context,
    required Map<String, Object?> answers,
  }) =>
      _client.rpc<void>('set_member_field_values', params: {
        'p_member_id': memberId,
        'p_context': context.wireName,
        'p_answers': answers,
      });
}
