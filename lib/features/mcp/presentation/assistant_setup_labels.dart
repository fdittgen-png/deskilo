// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../application/assistant_setup.dart';

/// #1827 — the words of the setup checklist, one function per dimension.
String assistantSetupStepTitle(
  AppLocalizations l10n,
  AssistantSetupStep step,
) => switch (step) {
  AssistantSetupStep.identity =>
    l10n.assistantSetupStepIdentity,
  AssistantSetupStep.workspace =>
    l10n.assistantSetupStepWorkspace,
  AssistantSetupStep.policy =>
    l10n.assistantSetupStepPolicy,
  AssistantSetupStep.eligibility =>
    l10n.assistantSetupStepEligibility,
  AssistantSetupStep.installation =>
    l10n.assistantSetupStepInstallation,
  AssistantSetupStep.connect =>
    l10n.assistantSetupStepConnect,
};

/// Why the step exists, in one plain sentence.
String assistantSetupStepReason(
  AppLocalizations l10n,
  AssistantSetupStep step,
) => switch (step) {
  AssistantSetupStep.identity =>
    l10n.assistantSetupReasonIdentity,
  AssistantSetupStep.workspace =>
    l10n.assistantSetupReasonWorkspace,
  AssistantSetupStep.policy =>
    l10n.assistantSetupReasonPolicy,
  AssistantSetupStep.eligibility =>
    l10n.assistantSetupReasonEligibility,
  AssistantSetupStep.installation =>
    l10n.assistantSetupReasonInstallation,
  AssistantSetupStep.connect =>
    l10n.assistantSetupReasonConnect,
};

String assistantSetupStateLabel(
  AppLocalizations l10n,
  AssistantSetupState state,
) => switch (state) {
  AssistantSetupState.done => l10n.assistantSetupStateDone,
  AssistantSetupState.todo => l10n.assistantSetupStateTodo,
  AssistantSetupState.waiting => l10n.assistantSetupStateWaiting,
  AssistantSetupState.blocked =>
    l10n.assistantSetupStateBlocked,
  AssistantSetupState.unavailable =>
    l10n.assistantSetupStateUnavailable,
};

IconData assistantSetupStateIcon(AssistantSetupState state) => switch (state) {
  AssistantSetupState.done => Icons.check_circle,
  AssistantSetupState.todo => Icons.radio_button_unchecked,
  AssistantSetupState.waiting => Icons.hourglass_empty,
  AssistantSetupState.blocked => Icons.lock_outline,
  AssistantSetupState.unavailable => Icons.cloud_off_outlined,
};

String assistantSetupActorLabel(
  AppLocalizations l10n,
  AssistantSetupActor actor,
) => switch (actor) {
  AssistantSetupActor.you => l10n.assistantSetupActorYou,
  AssistantSetupActor.configurer =>
    l10n.assistantSetupActorConfigurer,
  AssistantSetupActor.integrations =>
    l10n.assistantSetupActorIntegrations,
  AssistantSetupActor.databaseAdministrator =>
    l10n.assistantSetupActorDatabaseAdministrator,
  AssistantSetupActor.instanceOperator =>
    l10n.assistantSetupActorInstanceOperator,
};

/// The banner over the list: the first step not done, and what it needs.
String assistantSetupNextText(AppLocalizations l10n, AssistantSetupItem item) {
  final title = assistantSetupStepTitle(l10n, item.step);
  return switch (item.state) {
    AssistantSetupState.unavailable =>
      l10n.mcpNextUnavailable,
    AssistantSetupState.waiting =>
      l10n.assistantSetupNextWaiting(
            title,
            assistantSetupActorLabel(l10n, item.actor),
          ),
    _ => l10n.assistantSetupNextTodo(title),
  };
}

String assistantSetupFailedText(AppLocalizations l10n) =>
    l10n.assistantSetupFailed;
