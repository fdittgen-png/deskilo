// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/dictionary_labels.dart';
import '../../domain/setup_levels.dart';
import '../../providers/business_kind_providers.dart';

/// One collapsible group of the setup questions (#3317): each question with
/// a business example (#3283), its yes/no switch and its "Not sure yet".
/// The group names its unresolved questions while folded; [controller]
/// unfolds it and [focusOf] gives each question's switch its focus, so the
/// error summary can take the owner to the first open one.
class SetupQuestionGroup extends ConsumerWidget {
  const SetupQuestionGroup({
    super.key,
    required this.id,
    required this.title,
    required this.questions,
    required this.answers,
    required this.unknown,
    required this.busy,
    required this.controller,
    required this.focusOf,
    required this.onAnswer,
    this.open = false,
  });

  final String id;
  final String title;
  final List<String> questions;
  final SetupAnswers answers;
  final Set<String> unknown;
  final bool busy;
  final bool open;
  final ExpansibleController controller;
  final FocusNode Function(String question) focusOf;

  /// An answer, or "Not sure yet" when [unknown] is true.
  final void Function(String question, {required bool yes, bool unknown})
  onAnswer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #4223 — a business whose kind keeps places off reads its own examples.
    final hasPlaces = ref.watch(businessShapeProvider).places;
    String question(String key) =>
        l10n.setupQuestionFor(key, hasPlaces: hasPlaces);
    return Card(
      child: ExpansionTile(
        key: ValueKey('setup-questions-$id'),
        controller: controller,
        initiallyExpanded: open,
        title: Text(title),
        leading: Icon(switch (id) {
          'bookings' => Icons.calendar_month_outlined,
          'money' => Icons.payments_outlined,
          _ => Icons.settings_outlined,
        }),
        subtitle: questions.any(unknown.contains)
            ? Text(
                questions
                    .where(unknown.contains)
                    .map(question)
                    .join(' · '),
              )
            : null,
        childrenPadding: AppSpacing.mdAll,
        children: [
          for (final key in questions) ...[
            SwitchListTile(
              key: ValueKey('setup-question-$key'),
              focusNode: focusOf(key),
              contentPadding: EdgeInsets.zero,
              title: Text(question(key)),
              value: answers[key],
              onChanged: busy ? null : (v) => onAnswer(key, yes: v),
              // #3283 — the question in business terms, with an example.
              subtitle: Text(
                unknown.contains(key)
                    ? l10n.setupAnswerUnknown
                    : l10n.businessExampleFor(key, hasPlaces: hasPlaces),
                key: ValueKey('setup-question-$key-example'),
              ),
            ),
            // #3076 — the third answer: the safe level, and what stays there.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilterChip(
                key: ValueKey('setup-question-$key-unknown'),
                label: Semantics(
                  label: l10n.setupChoicesQuestionUnknown(question(key)),
                  excludeSemantics: true,
                  child: Text(l10n.setupAnswerUnknown),
                ),
                selected: unknown.contains(key),
                tooltip: l10n.setupChoicesQuestionUnknown(question(key)),
                onSelected: busy
                    ? null
                    : (on) => onAnswer(key, yes: answers[key], unknown: on),
              ),
            ),
            if (unknown.contains(key))
              Text(
                l10n.setupChoicesNeedsDecision,
                key: ValueKey('setup-question-$key-note'),
              ),
          ],
        ],
      ),
    );
  }
}
