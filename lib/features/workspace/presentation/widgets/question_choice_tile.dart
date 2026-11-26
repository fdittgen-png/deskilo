// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One existing choice of a choice question, as the question editor edits it:
// its label per language, whether it is still offered, and its place in the
// list. Its key is shown and never edited: the answers point at it, so a label
// can be reworded and a choice retired without one answer losing its meaning.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/workspace_field.dart';

/// What the editor holds of one existing choice: the choice as it was read,
/// and the edits made to it. What the editor does not show stays as read.
class QuestionChoiceDraft {
  QuestionChoiceDraft(this.read, Iterable<String> locales)
    : active = read.active,
      labels = {
        for (final locale in locales)
          locale: TextEditingController(text: read.labels[locale] ?? ''),
      };

  /// The choice as the server answered it.
  final WorkspaceFieldOption read;

  /// The label typed per language the editor offers.
  final Map<String, TextEditingController> labels;
  bool active;

  /// The choice with its edits: a language the editor offers takes what was
  /// typed (and is removed when emptied); every other language, and the key,
  /// stay as read. [sortOrder] is given only when the list was reordered.
  WorkspaceFieldOption edited({int? sortOrder}) {
    final merged = {...read.labels};
    for (final MapEntry(key: locale, value: typed) in labels.entries) {
      final text = typed.text.trim();
      if (text.isEmpty) {
        merged.remove(locale);
      } else {
        merged[locale] = text;
      }
    }
    return read.copyWith(
      labels: merged,
      active: active,
      sortOrder: sortOrder,
    );
  }

  void dispose() {
    for (final c in labels.values) {
      c.dispose();
    }
  }
}

/// The tile of one existing choice.
class QuestionChoiceTile extends StatelessWidget {
  const QuestionChoiceTile({
    super.key,
    required this.choice,
    required this.workspaceLocale,
    required this.enabled,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final QuestionChoiceDraft choice;
  final String workspaceLocale;
  final bool enabled;
  final VoidCallback onChanged;

  /// Null at the ends of the list.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  static Key keyFor(String choiceKey) =>
      ValueKey('question-editor-choice-$choiceKey');
  static Key labelKeyFor(String choiceKey, String locale) =>
      ValueKey('question-editor-choice-$choiceKey-label-$locale');
  static Key activeKeyFor(String choiceKey) =>
      ValueKey('question-editor-choice-$choiceKey-active');
  static Key upKeyFor(String choiceKey) =>
      ValueKey('question-editor-choice-$choiceKey-up');
  static Key downKeyFor(String choiceKey) =>
      ValueKey('question-editor-choice-$choiceKey-down');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final words = WidgetsLocalizations.of(context);
    final key = choice.read.key;
    final typed = choice.labels[workspaceLocale]?.text.trim() ?? '';
    return ExpansionTile(
      key: keyFor(key),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      title: Text(
        typed.isEmpty ? choice.read.labelIn(workspaceLocale) : typed,
        style: choice.active
            ? null
            : const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      // The key, as stored: it is what the answers hold.
      subtitle: Text(key),
      children: [
        for (final MapEntry(key: locale, value: controller)
            in choice.labels.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TextField(
              key: labelKeyFor(key, locale),
              controller: controller,
              enabled: enabled,
              decoration: InputDecoration(
                labelText: l10n.questionEditorLabelFor(locale),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        SwitchListTile(
          key: activeKeyFor(key),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.questionEditorActive),
          value: choice.active,
          onChanged: enabled
              ? (on) {
                  choice.active = on;
                  onChanged();
                }
              : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              key: upKeyFor(key),
              tooltip: words.reorderItemUp,
              onPressed: enabled ? onMoveUp : null,
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              key: downKeyFor(key),
              tooltip: words.reorderItemDown,
              onPressed: enabled ? onMoveDown : null,
              icon: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
      ],
    );
  }
}
