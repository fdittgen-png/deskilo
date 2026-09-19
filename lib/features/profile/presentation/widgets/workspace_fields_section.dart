// SPDX-License-Identifier: 0BSD
//
// #1288 S2b — the workspace's own questions, inside the one identity
// form.
//
// `PersonalInfoForm` stays the only identity form (HARD RULE). This is a
// section of it, not a second form: the host passes the questions and
// the answers, and the same Save sends both halves.
//
// Nothing here decides whether an answer is acceptable. That is
// `fieldProblem`, which mirrors the server's `field_answer_problem`;
// this widget only turns its verdict into words, which is why the
// messages live in the ARB and the decision does not.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_field.dart';
import '../../../workspace/domain/workspace_field_answer.dart';

/// The answers a section holds, so the host's Save can read them without
/// the section having to own a save of its own.
class WorkspaceFieldsController extends ChangeNotifier {
  WorkspaceFieldsController({Map<String, Object?> initial = const {}})
      : _answers = Map.of(initial);

  final Map<String, Object?> _answers;

  Map<String, Object?> get answers => Map.unmodifiable(_answers);

  void set(String key, Object? value) {
    if (_answers[key] == value) return;
    _answers[key] = value;
    notifyListeners();
  }

  /// Whether every question is answered acceptably — what a Save checks
  /// before it is worth sending.
  bool isValid(Iterable<WorkspaceField> fields) =>
      fieldProblems(fields, _answers).isEmpty;
}

/// The words for [problem], in the reader's language.
String fieldProblemText(
  AppLocalizations? l10n,
  WorkspaceField field,
  FieldProblem problem,
) {
  final rules = field.validation;
  String s(Object? v) => '$v';
  return switch (problem) {
    FieldProblem.required => l10n?.fieldProblemRequired ?? 'Please answer this.',
    FieldProblem.tooShort => l10n?.fieldProblemTooShort(
              (rules['min_length'] as num?)?.toInt() ?? 0,
            ) ??
        'Too short.',
    FieldProblem.tooLong => l10n?.fieldProblemTooLong(
              (rules['max_length'] as num?)?.toInt() ?? 0,
            ) ??
        'Too long.',
    FieldProblem.tooSmall =>
      l10n?.fieldProblemTooSmall(s(rules['min'])) ?? 'Too small.',
    FieldProblem.tooLarge =>
      l10n?.fieldProblemTooLarge(s(rules['max'])) ?? 'Too large.',
    FieldProblem.notWhole =>
      l10n?.fieldProblemNotWhole ?? 'A whole number, please.',
    FieldProblem.notANumber =>
      l10n?.fieldProblemNotANumber ?? 'A number, please.',
    FieldProblem.notADate => l10n?.fieldProblemNotADate ?? 'A date, please.',
    FieldProblem.notAChoice =>
      l10n?.fieldProblemNotAChoice ?? 'Please pick from the list.',
    FieldProblem.tooEarly =>
      l10n?.fieldProblemTooEarly(s(rules['min_date'])) ?? 'Too early.',
    FieldProblem.tooLate =>
      l10n?.fieldProblemTooLate(s(rules['max_date'])) ?? 'Too late.',
    FieldProblem.notAnEmail =>
      l10n?.fieldProblemNotAnEmail ?? 'That is not an e-mail address.',
    FieldProblem.notAPhone =>
      l10n?.fieldProblemNotAPhone ?? 'That is not a telephone number.',
    FieldProblem.notAUrl =>
      l10n?.fieldProblemNotAUrl ?? 'That is not a web address.',
  };
}

/// The questions of one context, rendered.
class WorkspaceFieldsSection extends StatefulWidget {
  const WorkspaceFieldsSection({
    super.key,
    required this.fields,
    required this.controller,
    required this.workspaceName,
    this.locale = 'en',
    this.enabled = true,
  });

  final List<WorkspaceField> fields;
  final WorkspaceFieldsController controller;
  final String workspaceName;
  final String locale;
  final bool enabled;

  static const Key sectionKey = Key('workspace-fields-section');

  /// The key of one question's control, for tests and for focus.
  static Key keyOf(String fieldKey) => ValueKey('workspace-field-$fieldKey');

  @override
  State<WorkspaceFieldsSection> createState() => _WorkspaceFieldsSectionState();
}

class _WorkspaceFieldsSectionState extends State<WorkspaceFieldsSection> {
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      if (field.type.isChoice ||
          field.type == WorkspaceFieldType.boolean) {
        continue;
      }
      final value = widget.controller.answers[field.key];
      _controllers[field.key] =
          TextEditingController(text: value == null ? '' : '$value');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// What the wire wants for [field], from what was typed.
  Object? _parsed(WorkspaceField field, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return switch (field.type) {
      WorkspaceFieldType.integer => int.tryParse(trimmed) ?? trimmed,
      WorkspaceFieldType.decimal => num.tryParse(trimmed) ?? trimmed,
      _ => trimmed,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fields.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final problems = fieldProblems(widget.fields, widget.controller.answers);
        return Column(
          key: WorkspaceFieldsSection.sectionKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n?.workspaceFieldsTitle(widget.workspaceName) ??
                  'Questions from ${widget.workspaceName}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final field in widget.fields) ...[
              _control(field, problems[field.key], l10n, theme),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }

  Widget _control(
    WorkspaceField field,
    FieldProblem? problem,
    AppLocalizations? l10n,
    ThemeData theme,
  ) {
    final label = field.labelIn(widget.locale);
    final help = field.helpIn(widget.locale);
    final optional = l10n?.workspaceFieldsOptional ?? 'optional';
    final title = field.required ? label : '$label ($optional)';
    // A problem is shown only once the field has been answered: telling
    // somebody their empty form is wrong before they start is noise.
    final answered = widget.controller.answers.containsKey(field.key);
    final error = (answered && problem != null)
        ? fieldProblemText(l10n, field, problem)
        : null;

    switch (field.type) {
      case WorkspaceFieldType.boolean:
        return SwitchListTile(
          key: WorkspaceFieldsSection.keyOf(field.key),
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: help == null ? null : Text(help),
          value: widget.controller.answers[field.key] as bool? ?? false,
          onChanged: widget.enabled
              ? (on) => widget.controller.set(field.key, on)
              : null,
        );

      case WorkspaceFieldType.singleChoice:
        return DropdownButtonFormField<String>(
          key: WorkspaceFieldsSection.keyOf(field.key),
          initialValue: widget.controller.answers[field.key] as String?,
          decoration: InputDecoration(
            labelText: title,
            helperText: help,
            errorText: error,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final option in field.liveOptions)
              DropdownMenuItem(
                value: option.key,
                child: Text(option.labelIn(widget.locale)),
              ),
          ],
          onChanged: widget.enabled
              ? (value) => widget.controller.set(field.key, value)
              : null,
        );

      case WorkspaceFieldType.multiChoice:
        final chosen = {
          ...?(widget.controller.answers[field.key] as List?)?.cast<String>(),
        };
        return Column(
          key: WorkspaceFieldsSection.keyOf(field.key),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodyMedium),
            if (help != null)
              Text(help, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            // Wrap, not Row: a question with six choices must not push
            // the form sideways at 360 dp.
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final option in field.liveOptions)
                  FilterChip(
                    key: ValueKey('workspace-field-${field.key}-${option.key}'),
                    label: Text(option.labelIn(widget.locale)),
                    selected: chosen.contains(option.key),
                    onSelected: widget.enabled
                        ? (on) {
                            final next = {...chosen};
                            if (on) {
                              next.add(option.key);
                            } else {
                              next.remove(option.key);
                            }
                            widget.controller.set(field.key, next.toList());
                          }
                        : null,
                  ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        );

      case WorkspaceFieldType.text:
      case WorkspaceFieldType.longText:
      case WorkspaceFieldType.integer:
      case WorkspaceFieldType.decimal:
      case WorkspaceFieldType.date:
        return TextField(
          key: WorkspaceFieldsSection.keyOf(field.key),
          controller: _controllers[field.key],
          enabled: widget.enabled,
          maxLines: field.type == WorkspaceFieldType.longText ? 4 : 1,
          keyboardType: switch (field.type) {
            WorkspaceFieldType.integer => TextInputType.number,
            WorkspaceFieldType.decimal =>
              const TextInputType.numberWithOptions(decimal: true),
            _ => TextInputType.text,
          },
          decoration: InputDecoration(
            labelText: title,
            helperText: help,
            errorText: error,
            border: const OutlineInputBorder(borderRadius: AppRadius.mdAll),
          ),
          onChanged: (text) =>
              widget.controller.set(field.key, _parsed(field, text)),
        );
    }
  }
}
