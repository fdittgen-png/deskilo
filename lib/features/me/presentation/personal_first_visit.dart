// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step B -- the first visit: what a person with no place, no booking
// and nothing waiting meets on Home instead of three empty sections. A
// welcome, one hero card that leads to Discover (a read-only search field and
// "Search near me", the one filled-style action), the invitation card, the
// getting-started card and the way to run a business. Everything is derived
// from data the app already reads; nothing is stored.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/time/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../directory/providers/messenger_providers.dart';
import '../../money/providers/finance_overview_provider.dart';
import '../../profile/providers/profile_providers.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/personal_commitments.dart';
import '../application/personal_overview.dart';
import '../domain/getting_started.dart';
import '../domain/greeting.dart';
import '../domain/my_spaces.dart';
import '../domain/personal_workspace_refs.dart';
import '../providers/me_providers.dart';
import 'kit/me_card.dart';
import 'kit/me_row.dart';
import 'kit/me_section_label.dart';
import 'kit/me_status_chip.dart';
import 'me_shell.dart';

/// A space of this server, of a linked one, or one my account names
/// elsewhere is not "nothing" (#2563).
bool noSpaceAtAll(
  PersonalWorkspaceRefs refs,
  List<Workspace> local,
  List<LinkedServerSpaces> linked,
) =>
    refs.beyondLocalSpaces.isEmpty &&
    local.isEmpty &&
    linked.every((s) => s.spaces.isEmpty);

/// Where the person stands: `firstVisit` is null while a source is still being
/// read (or failed), so the page never claims "nothing here" it has not read;
/// [facts] are the four getting-started facts, each null while unknown.
class HomeState {
  const HomeState({required this.firstVisit, required this.facts});

  final bool? firstVisit;
  final Map<StartedStep, bool?> facts;
}

/// Reads the sources once for the first-visit decision and the checklist.
HomeState homeStateOf(WidgetRef ref) {
  final profile = ref.watch(myProfileProvider);
  final answer = ref.watch(personalWorkspaceRefsProvider);
  final local = ref.watch(myWorkspacesProvider).value;
  final linked = ref.watch(linkedServerSpacesProvider).value ?? const [];
  final refs = answer.hasError && !answer.isLoading
      ? null
      : refsOfCurrentAccount(answer);
  final nothing = refs != null && local != null && noSpaceAtAll(refs, local, linked);
  final pending =
      refs?.refs.any((r) => r.status == RefStatus.pending) ?? false;
  final spaceFact = refs == null || local == null
      ? null
      : (!nothing || pending);

  // A booking ever read: any commitment in the window Home starts with.
  final window = ref.watch(myReservationsWindowControllerProvider).value;
  final composition = window == null
      ? null
      : ref
            .watch(
              myReservationsComposerProvider(
                MyReservationsQuery(from: window.from, to: window.to),
              ),
            )
            .value;
  final now = ref.watch(clockProvider).now();
  final next = composition == null ? null : nextCommitmentOf(composition, now);
  final bookingFact = composition == null || next == null || next.reading
      ? null
      : (composition.visible.isNotEmpty ? true : (next.complete ? false : null));

  // Nothing waiting: no unpaid document, undecided request or unread message.
  final documents = ref.watch(financeOverviewProvider);
  final inbox = ref.watch(messengerInboxProvider);
  final owed = documents.value
      ?.production(ref.watch(myDevelopmentWorkspaceIdsProvider))
      .outstanding;
  final items = owed == null || inbox.value == null || refs == null
      ? null
      : attentionItems(
          documents: [
            for (final d in owed)
              OwedDocument(
                id: d.id,
                workspaceId: d.workspaceId,
                workspaceName: d.workspaceName,
                number: d.number,
                remainingCents: d.remainingCents,
                currency: d.currency,
                overdue: d.overdueAt(now),
              ),
          ],
          refs: refs,
          inbox: inbox.value,
        );

  final standing = next?.commitment != null;
  final bool? firstVisit = spaceFact == null || next == null || items == null
      ? null
      : (!spaceFact && !standing && next.complete && items.isEmpty);

  final account = profile.hasValue ? profile.value != null : null;
  final named = profile.value;
  return HomeState(
    firstVisit: firstVisit,
    facts: {
      StartedStep.account: account,
      StartedStep.space: spaceFact,
      StartedStep.booking: bookingFact,
      StartedStep.profile: named == null
          ? null
          : named.displayName.trim().isNotEmpty && named.hasAvatar,
    },
  );
}

String _stepLabel(AppLocalizations l10n, StartedStep step) => switch (step) {
  StartedStep.account => l10n.meStartedAccount,
  StartedStep.space => l10n.meStartedSpace,
  StartedStep.booking => l10n.meStartedBooking,
  StartedStep.profile => l10n.meStartedProfile,
};

IconData _stepIcon(StartedStep step) => switch (step) {
  StartedStep.account => Icons.person_outline,
  StartedStep.space => Icons.travel_explore_outlined,
  StartedStep.booking => Icons.event_available_outlined,
  StartedStep.profile => Icons.account_circle_outlined,
};

/// The card of the four first steps: a finished one is checked, the next is
/// bold, the others quiet.
class GettingStartedCard extends StatelessWidget {
  const GettingStartedCard({super.key, required this.facts});

  final Map<StartedStep, bool?> facts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = PersonalTheme.of(context);
    return MeCard(
      key: const ValueKey('me-getting-started'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MeSectionLabel(l10n.meStartedTitle),
          const SizedBox(height: AppSpacing.xs),
          for (final row in startedRows(facts))
            MeRow(
              key: ValueKey('me-started-${row.step.name}'),
              title: _stepLabel(l10n, row.step),
              semanticLabel:
                  '${_stepLabel(l10n, row.step)}, ${switch (row.state) {
                    StartedState.done => l10n.meStartedDone,
                    StartedState.next => l10n.meStartedNext,
                    StartedState.later => '',
                  }}'.replaceAll(RegExp(r',\s*$'), ''),
              leading: Icon(
                row.state == StartedState.done
                    ? Icons.check_circle
                    : _stepIcon(row.step),
                color: row.state == StartedState.done
                    ? tokens.success
                    : row.state == StartedState.later
                    ? tokens.secondaryText
                    : tokens.primary,
              ),
              trailing: switch (row.state) {
                StartedState.done => MeStatusChip(
                  kind: MeChipKind.ok,
                  label: l10n.meStartedDone,
                ),
                StartedState.next => MeStatusChip(
                  kind: MeChipKind.neutral,
                  label: l10n.meStartedNext,
                ),
                StartedState.later => null,
              },
              onTap: switch (row.step) {
                StartedStep.account => null,
                StartedStep.space ||
                StartedStep.booking => () => context.go(_discoverFocus),
                StartedStep.profile => () => context.go(MeTab.me.path),
              },
            ),
        ],
      ),
    );
  }
}

/// Discover with its search box focused (a person who asked for a place wants
/// to type or look, not to see an empty list first).
const String _discoverFocus = '/me/discover?focus=search';

/// The first visit.
class PersonalFirstVisit extends ConsumerWidget {
  const PersonalFirstVisit({super.key, required this.facts});

  final Map<StartedStep, bool?> facts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = PersonalTheme.of(context);
    final profile = ref.watch(myProfileProvider).value;
    final name = firstNameOf(
      firstName: profile?.identity.firstName,
      displayName: profile?.displayName,
    );
    void discover() => context.go(_discoverFocus);
    return Column(
      key: const ValueKey('me-first-visit'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          name == null ? l10n.meGreetingNoName : l10n.meWelcomeTitle(name),
          style: theme.textTheme.headlineSmall?.copyWith(color: tokens.text),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.meWelcomeSubtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: tokens.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        MeCard(
          key: const ValueKey('me-first-visit-hero'),
          tone: MeCardTone.hero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.meFindPlaceTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: tokens.onPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey('me-first-visit-search'),
                readOnly: true,
                onTap: discover,
                decoration: InputDecoration(
                  hintText: l10n.meFindPlaceHint,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: tokens.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonal(
                  key: const ValueKey('me-first-visit-near-me'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, PersonalShellMetrics.minTarget),
                  ),
                  onPressed: discover,
                  child: Text(l10n.meFindPlaceNearMe),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        MeCard(
          child: MeRow(
            key: const ValueKey('me-first-visit-invitation'),
            title: l10n.meInvitationTitle,
            subtitle: l10n.meInvitationBody,
            semanticLabel:
                '${l10n.meInvitationTitle}. ${l10n.meInvitationBody}',
            leading: const Icon(Icons.qr_code_2_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/onboarding?join=1'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GettingStartedCard(facts: facts),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${l10n.meRunASpace} ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
            TextButton(
              key: const ValueKey('me-first-visit-run'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, PersonalShellMetrics.minTarget),
              ),
              onPressed: () => context.push('/onboarding'),
              child: Text(l10n.meRunASpaceAction),
            ),
          ],
        ),
      ],
    );
  }
}
