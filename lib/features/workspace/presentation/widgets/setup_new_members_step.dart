// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "new members": how somebody joining starts — the workspace
// settings screen's own rows, prefilled from the stored rule and saved
// through [SaveNewMemberDefaults] — and the questions they answer when they
// ask to join, as stored; those are written in the questions editor, one
// tap away. The preview is what a newcomer meets: the join form with its
// questions, and the subscription they start on.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/save_new_member_defaults.dart';
import '../../domain/new_member_defaults.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_field.dart';
import '../../providers/workspace_fields_providers.dart';
import '../../providers/workspace_providers.dart';
import 'new_member_defaults_tiles.dart';
import 'workspace_fields_section.dart';

class SetupNewMembersStep extends ConsumerStatefulWidget {
  const SetupNewMembersStep({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<SetupNewMembersStep> createState() =>
      _SetupNewMembersStepState();
}

class _SetupNewMembersStepState extends ConsumerState<SetupNewMembersStep> {
  /// What the owner set on this page; null until they touch a row, so the
  /// rows show the stored rule until then.
  final _draft = ValueNotifier<NewMemberDefaults?>(null);
  final _busy = ValueNotifier<bool>(false);
  final _answers = WorkspaceFieldsController();

  @override
  void dispose() {
    _draft.dispose();
    _busy.dispose();
    _answers.dispose();
    super.dispose();
  }

  String get _locale => widget.workspace.defaultLocale.isEmpty
      ? 'en'
      : widget.workspace.defaultLocale;

  Future<void> _save(NewMemberDefaults defaults) async {
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup new member defaults failed',
      errorText: l10n.setupNewMembersSaveFailed,
      action: () => ref
          .read(saveNewMemberDefaultsProvider)
          .save(widget.workspace.id, defaults),
    );
    ref.invalidate(newMemberDefaultsProvider);
    if (!mounted) return;
    _busy.value = false;
    if (!ok) return;
    _draft.value = null;
    AppSnack.success(context, l10n.workspaceSettingsSaved);
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(newMemberDefaultsProvider);
    final questions = fieldsForContext(
      ref.watch(workspaceFieldsProvider).value ?? const [],
      WorkspaceFieldContext.joinRequest,
    );
    final questionsOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.customFields);
    return ListenableBuilder(
      listenable: Listenable.merge([_draft, _busy]),
      builder: (context, _) {
        final defaults = _draft.value ?? stored.value;
        return SetupStepLayout(
          form: _form(
            context,
            defaults: defaults,
            failed: stored.hasError && !stored.hasValue,
            questions: questions,
            questionsOn: questionsOn,
          ),
          preview: _Preview(
            defaults: defaults,
            questions: questions,
            answers: _answers,
            workspaceName: widget.workspace.name,
            locale: _locale,
          ),
        );
      },
    );
  }

  Widget _form(
    BuildContext context, {
    required NewMemberDefaults? defaults,
    required bool failed,
    required List<WorkspaceField> questions,
    required bool questionsOn,
  }) {
    final l10n = context.l10n;
    final busy = _busy.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('new_members')),
        const SizedBox(height: AppSpacing.md),
        NewMemberDefaultsTiles(
          key: const ValueKey('setup-new-members-defaults'),
          defaults: defaults,
          failed: failed,
          onRetry: () => ref.invalidate(newMemberDefaultsProvider),
          enabled: !busy,
          onSubscriptionChanged: (pct) =>
              _draft.value = defaults?.copyWith(subscriptionPct: pct),
          onOveragePolicyChanged: (policy) =>
              _draft.value = defaults?.copyWith(overagePolicy: policy),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            key: const ValueKey('setup-new-members-save'),
            onPressed: busy || defaults == null ? null : () => _save(defaults),
            child: Text(l10n.commonSave),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.setupNewMembersQuestions,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (questions.isEmpty)
          Text(
            l10n.setupNewMembersNoQuestions,
            key: const ValueKey('setup-new-members-no-questions'),
          ),
        for (final q in questions)
          ListTile(
            key: ValueKey('setup-new-members-question-${q.key}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.help_outline),
            title: Text(q.labelIn(_locale)),
          ),
        if (questionsOn)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('setup-new-members-questions'),
              onPressed: () => context.push('/settings/questions'),
              child: Text(l10n.setupNewMembersEditQuestions),
            ),
          ),
      ],
    );
  }
}

/// What somebody asking to join meets: the questions of the join form, as
/// the identity form draws them, then the subscription they start on.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.defaults,
    required this.questions,
    required this.answers,
    required this.workspaceName,
    required this.locale,
  });

  final NewMemberDefaults? defaults;
  final List<WorkspaceField> questions;
  final WorkspaceFieldsController answers;
  final String workspaceName;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final defaults = this.defaults;
    return Column(
      key: const ValueKey('setup-new-members-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (questions.isEmpty)
          Text(l10n.setupNewMembersPreviewNoQuestions)
        else ...[
          Text(l10n.setupNewMembersPreviewJoin),
          const SizedBox(height: AppSpacing.sm),
          // A picture of the join form: nothing in it is answered here.
          IgnorePointer(
            child: WorkspaceFieldsSection(
              fields: questions,
              controller: answers,
              workspaceName: workspaceName,
              locale: locale,
              enabled: false,
            ),
          ),
        ],
        if (defaults != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.setupNewMembersPreviewStart(
              defaults.subscriptionPct,
              newMemberOverageLabel(l10n, defaults.overagePolicy),
            ),
            key: const ValueKey('setup-new-members-preview-start'),
          ),
        ],
      ],
    );
  }
}
