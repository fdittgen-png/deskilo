// SPDX-License-Identifier: 0BSD
//
// #1288 S4 — defining a question, and seeing it as a member will.
//
// The order the issue asks for: what to ask, where, what kind of answer,
// whether it is required, who can see it, its rule, its translations —
// and then a preview rendered by the SAME widget the identity form uses,
// so the owner is looking at the thing rather than at a description of
// it.
//
// The key is written once and never again. Answers point at it, so a
// renamed key is a lost answer; the server enforces that too, and the
// field is simply not offered when editing an existing question.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_field.dart';
import 'workspace_fields_section.dart';

/// The label of [type], in the reader's language.
String questionTypeLabel(AppLocalizations? l10n, WorkspaceFieldType type) =>
    switch (type) {
      WorkspaceFieldType.text => l10n?.questionTypeText ?? 'A short answer',
      WorkspaceFieldType.longText =>
        l10n?.questionTypeLongText ?? 'A long answer',
      WorkspaceFieldType.integer =>
        l10n?.questionTypeInteger ?? 'A whole number',
      WorkspaceFieldType.decimal => l10n?.questionTypeDecimal ?? 'A number',
      WorkspaceFieldType.date => l10n?.questionTypeDate ?? 'A date',
      WorkspaceFieldType.boolean => l10n?.questionTypeBoolean ?? 'Yes or no',
      WorkspaceFieldType.singleChoice =>
        l10n?.questionTypeSingleChoice ?? 'One of a list',
      WorkspaceFieldType.multiChoice =>
        l10n?.questionTypeMultiChoice ?? 'Several of a list',
    };

String _visibilityLabel(
  AppLocalizations? l10n,
  WorkspaceFieldVisibility visibility,
) =>
    switch (visibility) {
      WorkspaceFieldVisibility.self =>
        l10n?.questionEditorVisibilitySelf ?? 'Only the member',
      WorkspaceFieldVisibility.managers =>
        l10n?.questionEditorVisibilityManagers ??
            'The member, and whoever may see personal data',
      WorkspaceFieldVisibility.members =>
        l10n?.questionEditorVisibilityMembers ?? 'Every member of the space',
    };

String _contextLabel(AppLocalizations? l10n, WorkspaceFieldContext context) =>
    switch (context) {
      WorkspaceFieldContext.profile =>
        l10n?.questionEditorContextProfile ?? "A member's own information",
      WorkspaceFieldContext.managedMember =>
        l10n?.questionEditorContextManaged ??
            "A managed member's information",
      WorkspaceFieldContext.joinRequest =>
        l10n?.questionEditorContextJoin ?? 'When joining',
    };

/// Edits [initial], or defines a new question when it is null.
class QuestionEditorSheet extends StatefulWidget {
  const QuestionEditorSheet({
    super.key,
    this.initial,
    required this.workspaceName,
    required this.workspaceLocale,
    required this.onSave,
    this.saving = false,
  });

  final WorkspaceField? initial;
  final String workspaceName;

  /// The language the workspace reads. Its label is the one 0248 insists
  /// on, so the Save is disabled until it is filled in.
  final String workspaceLocale;

  /// Receives the question, and its choices when it has any.
  final Future<void> Function(WorkspaceField field) onSave;
  final bool saving;

  static const Key saveKey = Key('question-editor-save');
  static const Key keyFieldKey = Key('question-editor-key');
  static const Key typeKey = Key('question-editor-type');
  static const Key choicesKey = Key('question-editor-choices');

  static Key labelKeyFor(String locale) =>
      ValueKey('question-editor-label-$locale');

  @override
  State<QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends State<QuestionEditorSheet> {
  static const _locales = ['en', 'fr', 'de', 'es', 'it'];

  late final TextEditingController _key;
  late final Map<String, TextEditingController> _labels;
  late final TextEditingController _choices;
  late final TextEditingController _rule;

  late WorkspaceFieldType _type;
  late Set<WorkspaceFieldContext> _contexts;
  late WorkspaceFieldVisibility _visibility;
  late bool _required;
  late bool _personal;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _key = TextEditingController(text: initial?.key ?? '');
    _labels = {
      for (final locale in _locales)
        locale: TextEditingController(text: initial?.labels[locale] ?? ''),
    };
    _choices = TextEditingController(
      text: [for (final o in initial?.options ?? const []) o.key].join('\n'),
    );
    _rule = TextEditingController(
      text: '${initial?.validation['max_length'] ?? initial?.validation['max'] ?? ''}',
    );
    _type = initial?.type ?? WorkspaceFieldType.text;
    _contexts = {...?initial?.contexts};
    if (_contexts.isEmpty) _contexts = {WorkspaceFieldContext.profile};
    _visibility = initial?.visibility ?? WorkspaceFieldVisibility.self;
    _required = initial?.required ?? false;
    _personal = initial?.personalData ?? true;
    _active = initial?.active ?? true;
  }

  @override
  void dispose() {
    _key.dispose();
    for (final c in _labels.values) {
      c.dispose();
    }
    _choices.dispose();
    _rule.dispose();
    super.dispose();
  }

  bool get _isNew => widget.initial == null;

  /// The question as it stands, which is also what the preview renders.
  WorkspaceField get _draft {
    final rule = num.tryParse(_rule.text.trim());
    return WorkspaceField(
      id: widget.initial?.id ?? '',
      key: _key.text.trim(),
      type: _type,
      labels: {
        for (final entry in _labels.entries)
          if (entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
      },
      required: _required,
      personalData: _personal,
      visibility: _visibility,
      contexts: _contexts,
      sortOrder: widget.initial?.sortOrder ?? 0,
      validation: {
        if (rule != null && _isTextual) 'max_length': rule.toInt(),
        if (rule != null && _isNumeric) 'max': rule,
      },
      active: _active,
      options: [
        for (final line in _choices.text.split('\n'))
          if (line.trim().isNotEmpty)
            WorkspaceFieldOption(
              key: line.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_'),
              labels: {for (final l in _locales) l: line.trim()},
            ),
      ],
    );
  }

  bool get _isTextual =>
      _type == WorkspaceFieldType.text || _type == WorkspaceFieldType.longText;
  bool get _isNumeric =>
      _type == WorkspaceFieldType.integer ||
      _type == WorkspaceFieldType.decimal;

  /// 0248 refuses a key that is not an identifier, a question asked
  /// nowhere, and a label missing in the workspace's own language. The
  /// Save is disabled rather than letting the owner meet those as errors.
  bool get _canSave =>
      !widget.saving &&
      RegExp(r'^[a-z][a-z0-9_]{1,40}$').hasMatch(_key.text.trim()) &&
      _contexts.isNotEmpty &&
      (_labels[widget.workspaceLocale]?.text.trim().isNotEmpty ?? false) &&
      (!_type.isChoice || _draft.options.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isNew)
                TextField(
                  key: QuestionEditorSheet.keyFieldKey,
                  controller: _key,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n?.questionEditorKey ?? 'Key',
                    helperText: l10n?.questionEditorKeyHelp ??
                        'Lower-case letters, digits and underscores. It '
                            'never changes: the answers point at it.',
                    helperMaxLines: 3,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<WorkspaceFieldType>(
                key: QuestionEditorSheet.typeKey,
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: l10n?.questionEditorType ?? 'Answer type',
                ),
                items: [
                  for (final type in WorkspaceFieldType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(questionTypeLabel(l10n, type)),
                    ),
                ],
                onChanged: widget.saving
                    ? null
                    : (type) => setState(() => _type = type ?? _type),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final locale in _locales)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextField(
                    key: QuestionEditorSheet.labelKeyFor(locale),
                    controller: _labels[locale],
                    decoration: InputDecoration(
                      labelText:
                          l10n?.questionEditorLabelFor(locale) ?? 'Label ($locale)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              if (_type.isChoice)
                TextField(
                  key: QuestionEditorSheet.choicesKey,
                  controller: _choices,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText:
                        l10n?.questionEditorChoices ?? 'Choices, one per line',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (_isTextual || _isNumeric)
                TextField(
                  controller: _rule,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _isTextual
                        ? (l10n?.questionEditorMaxLength ??
                            'Longest answer (characters)')
                        : (l10n?.questionEditorMax ?? 'Largest number'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n?.questionEditorRequired ?? 'Must be answered'),
                value: _required,
                onChanged: widget.saving
                    ? null
                    : (on) => setState(() => _required = on),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title:
                    Text(l10n?.questionEditorPersonal ?? 'This is personal data'),
                subtitle: Text(
                  l10n?.questionEditorPersonalHelp ??
                      'Erased when the member leaves, and carried in their '
                          'data export.',
                ),
                value: _personal,
                onChanged: widget.saving
                    ? null
                    : (on) => setState(() => _personal = on),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n?.questionEditorActive ?? 'Asked now'),
                value: _active,
                onChanged:
                    widget.saving ? null : (on) => setState(() => _active = on),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n?.questionEditorVisibility ?? 'Who can see the answer',
                style: theme.textTheme.labelLarge,
              ),
              for (final visibility in WorkspaceFieldVisibility.values)
                RadioListTile<WorkspaceFieldVisibility>(
                  contentPadding: EdgeInsets.zero,
                  value: visibility,
                  // ignore: deprecated_member_use
                  groupValue: _visibility,
                  title: Text(_visibilityLabel(l10n, visibility)),
                  // ignore: deprecated_member_use
                  onChanged: widget.saving
                      ? null
                      : (v) => setState(() => _visibility = v ?? _visibility),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n?.questionEditorContexts ?? 'Where it is asked',
                style: theme.textTheme.labelLarge,
              ),
              // Wrap, not Row: three contexts do not fit one 360 dp line.
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final context in WorkspaceFieldContext.values)
                    FilterChip(
                      key: ValueKey('question-editor-context-${context.name}'),
                      label: Text(_contextLabel(l10n, context)),
                      selected: _contexts.contains(context),
                      onSelected: widget.saving
                          ? null
                          : (on) => setState(() {
                                if (on) {
                                  _contexts.add(context);
                                } else {
                                  _contexts.remove(context);
                                }
                              }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n?.questionEditorPreview ?? 'How it will look',
                style: theme.textTheme.labelLarge,
              ),
              // The SAME widget the identity form uses, so the owner is
              // looking at the thing rather than at a description of it.
              if (_draft.labels.isNotEmpty)
                WorkspaceFieldsSection(
                  fields: [_draft],
                  controller: WorkspaceFieldsController(),
                  workspaceName: widget.workspaceName,
                  locale: widget.workspaceLocale,
                  enabled: false,
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: QuestionEditorSheet.saveKey,
                onPressed: _canSave ? () => widget.onSave(_draft) : null,
                child: Text(
                  l10n?.questionEditorSave ?? 'Save the question',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
