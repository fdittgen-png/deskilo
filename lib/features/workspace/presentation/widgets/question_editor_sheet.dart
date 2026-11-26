// SPDX-License-Identifier: AGPL-3.0-or-later
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
//
// An edit changes what its controls show and keeps the rest. What is saved is
// a copy of the question as it was read: the group, the help texts, the rules
// this sheet has no control for and every choice's key, labels, order and
// state stay as read unless the person changes them here.
import 'package:flutter/material.dart';

import '../../../../core/format/decimal_input.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_field.dart';
import 'question_choice_tile.dart';
import 'workspace_fields_section.dart';

/// The label of [type], in the reader's language.
String questionTypeLabel(AppLocalizations l10n, WorkspaceFieldType type) =>
    switch (type) {
      WorkspaceFieldType.text => l10n.questionTypeText,
      WorkspaceFieldType.longText =>
        l10n.questionTypeLongText,
      WorkspaceFieldType.integer =>
        l10n.questionTypeInteger,
      WorkspaceFieldType.decimal => l10n.questionTypeDecimal,
      WorkspaceFieldType.date => l10n.questionTypeDate,
      WorkspaceFieldType.boolean => l10n.questionTypeBoolean,
      WorkspaceFieldType.singleChoice =>
        l10n.questionTypeSingleChoice,
      WorkspaceFieldType.multiChoice =>
        l10n.questionTypeMultiChoice,
    };

String _visibilityLabel(
  AppLocalizations l10n,
  WorkspaceFieldVisibility visibility,
) =>
    switch (visibility) {
      WorkspaceFieldVisibility.self =>
        l10n.questionEditorVisibilitySelf,
      WorkspaceFieldVisibility.managers =>
        l10n.questionEditorVisibilityManagers,
      WorkspaceFieldVisibility.members =>
        l10n.questionEditorVisibilityMembers,
    };

String _contextLabel(AppLocalizations l10n, WorkspaceFieldContext context) =>
    switch (context) {
      WorkspaceFieldContext.profile =>
        l10n.questionEditorContextProfile,
      WorkspaceFieldContext.managedMember =>
        l10n.questionEditorContextManaged,
      WorkspaceFieldContext.joinRequest =>
        l10n.questionEditorContextJoin,
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
  static const Key personalSwitchKey = Key('question-editor-personal');
  static const Key notPersonalWarningKey =
      Key('question-editor-not-personal-warning');

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

  /// The choices the question already has, each with its edits.
  late final List<QuestionChoiceDraft> _existing;

  /// Whether the person moved a choice: only then is the order rewritten.
  bool _reordered = false;

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
    // New choices only: the existing ones are edited as what they are, below.
    _choices = TextEditingController();
    _existing = [
      for (final o in initial?.options ?? const <WorkspaceFieldOption>[])
        QuestionChoiceDraft(o, _locales),
    ];
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
    for (final choice in _existing) {
      choice.dispose();
    }
    super.dispose();
  }

  bool get _isNew => widget.initial == null;

  /// The question as it stands, which is also what the preview renders: the
  /// question as it was read, with what this sheet's controls own changed.
  WorkspaceField get _draft {
    final read = widget.initial;
    final labels = {...?read?.labels};
    for (final MapEntry(key: locale, value: typed) in _labels.entries) {
      final text = typed.text.trim();
      if (text.isEmpty) {
        labels.remove(locale);
      } else {
        labels[locale] = text;
      }
    }
    // The rules belong to the answer type: they are kept while it is the
    // same, and this sheet owns one of them, the maximum.
    final validation = <String, Object?>{
      if (read != null && read.type == _type) ...read.validation,
    };
    final rule = parseDecimalInput(_rule.text, grouping: false);
    if (_isTextual) _setRule(validation, 'max_length', rule?.toInt());
    if (_isNumeric) _setRule(validation, 'max', rule);
    return (read ??
            WorkspaceField(id: '', key: '', type: _type, labels: const {}))
        .copyWith(
          key: _isNew ? _key.text.trim() : null,
          type: _type,
          labels: labels,
          validation: validation,
          options: _draftOptions,
        )
        .asked(
          required: _required,
          personalData: _personal,
          visibility: _visibility,
          contexts: _contexts,
          active: _active,
        );
  }

  static void _setRule(Map<String, Object?> rules, String key, Object? value) {
    if (value == null) {
      rules.remove(key);
    } else {
      rules[key] = value;
    }
  }

  /// The choices as they stand: the existing ones with their edits, in their
  /// order (renumbered only when the person moved one), then the lines typed
  /// as new choices. A new line never takes the key of another choice.
  List<WorkspaceFieldOption> get _draftOptions {
    final options = [
      for (final (i, choice) in _existing.indexed)
        choice.edited(sortOrder: _reordered ? i : null),
    ];
    final taken = {for (final o in options) o.key};
    var next = options.fold(-1, (last, o) => o.sortOrder > last ? o.sortOrder : last) + 1;
    for (final line in _choices.text.split('\n')) {
      final label = line.trim();
      if (label.isEmpty) continue;
      final base = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      var key = base;
      for (var n = 2; !taken.add(key); n++) {
        key = '${base}_$n';
      }
      options.add(
        WorkspaceFieldOption(
          key: key,
          labels: {for (final l in _locales) l: label},
          sortOrder: next++,
        ),
      );
    }
    return options;
  }

  void _refresh() => setState(() {});

  void _move(int from, int to) {
    _existing.insert(to, _existing.removeAt(from));
    _reordered = true;
    _refresh();
  }

  /// The choices of a choice question: the existing ones, each edited as what
  /// it is, then the lines that add new ones.
  List<Widget> _choiceFields(AppLocalizations l10n) => [
    for (final (i, choice) in _existing.indexed)
      QuestionChoiceTile(
        key: QuestionChoiceTile.keyFor(choice.read.key),
        choice: choice,
        workspaceLocale: widget.workspaceLocale,
        enabled: !widget.saving,
        onChanged: _refresh,
        onMoveUp: i == 0 ? null : () => _move(i, i - 1),
        onMoveDown: i == _existing.length - 1 ? null : () => _move(i, i + 1),
      ),
    TextField(
      key: QuestionEditorSheet.choicesKey,
      controller: _choices,
      maxLines: 4,
      decoration: InputDecoration(labelText: l10n.questionEditorChoices),
      onChanged: (_) => _refresh(),
    ),
  ];

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
      (!_type.isChoice ||
          (_draft.options.isNotEmpty &&
              // 0248 wants every choice worded in the workspace's language.
              _existing.every(
                (c) =>
                    c.labels[widget.workspaceLocale]?.text.trim().isNotEmpty ??
                    true,
              )));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                    labelText: l10n.repartitionWeight,
                    helperText: l10n.questionEditorKeyHelp,
                    helperMaxLines: 3,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<WorkspaceFieldType>(
                key: QuestionEditorSheet.typeKey,
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: l10n.questionEditorType,
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
                          l10n.questionEditorLabelFor(locale),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              if (_type.isChoice) ..._choiceFields(l10n),
              if (_isTextual || _isNumeric)
                TextField(
                  key: const ValueKey('question-editor-sheet-editor-max-length'),
                  controller: _rule,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _isTextual
                        ? (l10n.questionEditorMaxLength)
                        : (l10n.questionEditorMax),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              SwitchListTile(
                key: const ValueKey('question-editor-sheet-editor-required'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.questionEditorRequired),
                value: _required,
                onChanged: widget.saving
                    ? null
                    : (on) => setState(() => _required = on),
              ),
              SwitchListTile(
                key: QuestionEditorSheet.personalSwitchKey,
                contentPadding: EdgeInsets.zero,
                title:
                    Text(l10n.questionEditorPersonal),
                // #1912 — the switch no longer exempts an answer from
                // export or erasure: an answer is stored against a member,
                // so it is personal whatever the switch says, and the
                // subtitle says so in both positions.
                subtitle: Text(
                  _personal
                      ? (l10n.questionEditorPersonalHelp)
                      : (l10n.questionEditorNotPersonalWarning),
                  key: _personal
                      ? null
                      : QuestionEditorSheet.notPersonalWarningKey,
                ),
                value: _personal,
                onChanged: widget.saving
                    ? null
                    : (on) => setState(() => _personal = on),
              ),
              SwitchListTile(
                key: const ValueKey('question-editor-sheet-editor-active'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.questionEditorActive),
                value: _active,
                onChanged:
                    widget.saving ? null : (on) => setState(() => _active = on),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.questionEditorVisibility,
                style: theme.textTheme.labelLarge,
              ),
              for (final visibility in WorkspaceFieldVisibility.values)
                RadioListTile<WorkspaceFieldVisibility>(
                  key: ValueKey('question-editor-sheet-radio-list-tile-${visibility.name}'),
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
                l10n.questionEditorContexts,
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
                l10n.questionEditorPreview,
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
                  enabled: false, // field-locked: the question as a member sees it
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: QuestionEditorSheet.saveKey,
                onPressed: _canSave ? () => widget.onSave(_draft) : null,
                child: Text(
                  l10n.questionEditorSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
