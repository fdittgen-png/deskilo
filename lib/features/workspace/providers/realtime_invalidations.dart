// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what the workspace feature caches, by table. Account-scoped
// entries span workspaces (the person's list, memberships, default
// workspace, the messenger); a workspace target never applies them.
// Composed in lib/app/realtime_invalidations.dart.
import '../../../core/realtime/invalidation_registry.dart';
import 'conversation_providers.dart';
import 'workspace_providers.dart';

final workspaceInvalidations = [
  InvalidationContribution(
    const ['members'],
    [workspaceMembersProvider, memberEmailsProvider, myMemberProvider],
  ),
  InvalidationContribution(
    const ['members'],
    [myMembershipsProvider],
    scope: InvalidationScope.account,
  ),
  // Flags, granularity, rules and the availability config all derive from
  // the workspace row.
  InvalidationContribution(
    const ['workspaces'],
    [
      openWeekdaysProvider,
      bookingGranularityProvider,
      workHoursProvider,
      // #1277 — a renamed word is a workspaces-row change like any other.
      lexiconProvider,
    ],
  ),
  InvalidationContribution(
    const ['workspaces'],
    [myWorkspacesProvider],
    scope: InvalidationScope.account,
  ),
  InvalidationContribution(const ['closure_days'], [closureDaysProvider]),
  // #458: the default-workspace choice rides the profile row.
  InvalidationContribution(
    const ['profiles'],
    [defaultWorkspaceIdProvider],
    scope: InvalidationScope.account,
  ),
  InvalidationContribution(const ['member_notes'], [myNotesProvider]),
  // #702 — a MESSAGE lands live or not at all. The family, so whichever
  // thread is open repaints too.
  InvalidationContribution(
    const ['member_notes'],
    [conversationsProvider, conversationMessagesProvider],
    scope: InvalidationScope.account,
  ),
  // A conversation you were just added to, and the roster of one you are in.
  InvalidationContribution(
    const ['conversations', 'conversation_participants'],
    [conversationsProvider, conversationParticipantsProvider],
    scope: InvalidationScope.account,
  ),
];
