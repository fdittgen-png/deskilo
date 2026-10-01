// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../application/assistant_setup.dart';

/// #1827 — the words of the setup checklist, one function per dimension.
String assistantSetupStepTitle(
  AppLocalizations? l10n,
  AssistantSetupStep step,
) => switch (step) {
  AssistantSetupStep.identity =>
    l10n?.assistantSetupStepIdentity ?? 'Link your identity',
  AssistantSetupStep.workspace =>
    l10n?.assistantSetupStepWorkspace ??
        'Turn assistants on for this workspace',
  AssistantSetupStep.policy =>
    l10n?.assistantSetupStepPolicy ?? 'Choose what assistants may do',
  AssistantSetupStep.eligibility =>
    l10n?.assistantSetupStepEligibility ?? 'Ask for your assistant access',
  AssistantSetupStep.installation =>
    l10n?.assistantSetupStepInstallation ??
        'Assistants switched on for this database',
  AssistantSetupStep.connect =>
    l10n?.assistantSetupStepConnect ?? 'Connect your assistant',
};

/// Why the step exists, in one plain sentence.
String assistantSetupStepReason(
  AppLocalizations? l10n,
  AssistantSetupStep step,
) => switch (step) {
  AssistantSetupStep.identity =>
    l10n?.assistantSetupReasonIdentity ??
        'An assistant acts as you, so this database must know it is you.',
  AssistantSetupStep.workspace =>
    l10n?.assistantSetupReasonWorkspace ??
        'While it is off, the workspace refuses every assistant call.',
  AssistantSetupStep.policy =>
    l10n?.assistantSetupReasonPolicy ??
        'Nothing is offered to assistants until someone chooses the '
            'operations.',
  AssistantSetupStep.eligibility =>
    l10n?.assistantSetupReasonEligibility ??
        'This database\'s administrators approve each person once, for every '
            'workspace on it.',
  AssistantSetupStep.installation =>
    l10n?.assistantSetupReasonInstallation ??
        'The instance owner or a delegate switches assistants on for every '
            'workspace on this database.',
  AssistantSetupStep.connect =>
    l10n?.assistantSetupReasonConnect ??
        'Add the connector in your assistant, sign in, and approve this '
            'workspace.',
};

String assistantSetupStateLabel(
  AppLocalizations? l10n,
  AssistantSetupState state,
) => switch (state) {
  AssistantSetupState.done => l10n?.assistantSetupStateDone ?? 'Done',
  AssistantSetupState.todo => l10n?.assistantSetupStateTodo ?? 'To do',
  AssistantSetupState.waiting => l10n?.assistantSetupStateWaiting ?? 'Waiting',
  AssistantSetupState.blocked =>
    l10n?.assistantSetupStateBlocked ?? 'After the steps above',
  AssistantSetupState.unavailable =>
    l10n?.assistantSetupStateUnavailable ?? 'Could not be asked',
};

IconData assistantSetupStateIcon(AssistantSetupState state) => switch (state) {
  AssistantSetupState.done => Icons.check_circle,
  AssistantSetupState.todo => Icons.radio_button_unchecked,
  AssistantSetupState.waiting => Icons.hourglass_empty,
  AssistantSetupState.blocked => Icons.lock_outline,
  AssistantSetupState.unavailable => Icons.cloud_off_outlined,
};

String assistantSetupActorLabel(
  AppLocalizations? l10n,
  AssistantSetupActor actor,
) => switch (actor) {
  AssistantSetupActor.you => l10n?.assistantSetupActorYou ?? 'Who: you',
  AssistantSetupActor.configurer =>
    l10n?.assistantSetupActorConfigurer ??
        'Who: someone who manages this workspace\'s configuration',
  AssistantSetupActor.integrations =>
    l10n?.assistantSetupActorIntegrations ??
        'Who: someone who manages this workspace\'s integrations',
  AssistantSetupActor.databaseAdministrator =>
    l10n?.assistantSetupActorDatabaseAdministrator ??
        'Who: a database administrator',
  AssistantSetupActor.instanceOperator =>
    l10n?.assistantSetupActorInstanceOperator ??
        'Who: the instance owner or a delegate',
};

/// The banner over the list: the first step not done, and what it needs.
String assistantSetupNextText(AppLocalizations? l10n, AssistantSetupItem item) {
  final title = assistantSetupStepTitle(l10n, item.step);
  return switch (item.state) {
    AssistantSetupState.unavailable =>
      l10n?.mcpNextUnavailable ??
          'The server could not answer. Nothing is assumed; try again later.',
    AssistantSetupState.waiting =>
      l10n?.assistantSetupNextWaiting(
            title,
            assistantSetupActorLabel(l10n, item.actor),
          ) ??
          'Next: $title. ${assistantSetupActorLabel(l10n, item.actor)}.',
    _ => l10n?.assistantSetupNextTodo(title) ?? 'Next: $title.',
  };
}

String assistantSetupFailedText(AppLocalizations? l10n) =>
    l10n?.assistantSetupFailed ?? 'Could not save. Nothing changed; try again.';
