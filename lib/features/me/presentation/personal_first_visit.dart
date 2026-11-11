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
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/personal_kit/me_card.dart';
import '../../../core/ui/personal_kit/me_filled_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/domain/profile.dart';
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
import 'kit/me_row.dart';
import 'kit/me_section_label.dart';
import 'kit/me_status_chip.dart';
import 'me_shell.dart';
import 'personal_overview_attention.dart';

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

/// What the spaces say: the place fact (a place, or a pending request) and
/// whether the person has none at all; both null while a source is unread.
({bool? fact, bool? none, PersonalWorkspaceRefs? refs}) _spacesRead(
  WidgetRef ref,
) {
  final answer = ref.watch(personalWorkspaceRefsProvider);
  final local = ref.watch(myWorkspacesProvider).value;
  final linked = ref.watch(linkedServerSpacesProvider).value ?? const [];
  final refs = answer.hasError && !answer.isLoading
      ? null
      : refsOfCurrentAccount(answer);
  if (refs == null || local == null) return (fact: null, none: null, refs: refs);
  final nothing = noSpaceAtAll(refs, local, linked);
  final pending = refs.refs.any((r) => r.status == RefStatus.pending);
  return (fact: !nothing || pending, none: nothing, refs: refs);
}

/// What the bookings say: the next commitment (null until read) and the
/// booking fact -- any commitment in the window Home starts with.
({NextCommitment? next, bool? fact}) _bookingsRead(WidgetRef ref, DateTime now) {
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
  final next = composition == null ? null : nextCommitmentOf(composition, now);
  if (composition == null || next == null || next.reading) {
    return (next: next, fact: null);
  }
  final read = composition.visible.isNotEmpty;
  return (next: next, fact: read ? true : (next.complete ? false : null));
}

/// The profile fact: a name and a photo; null while it is being read.
bool? _profileFact(AsyncValue<Profile?> profile) {
  final p = profile.value;
  return p == null ? null : p.displayName.trim().isNotEmpty && p.hasAvatar;
}

/// Reads the sources once for the first-visit decision and the checklist.
HomeState homeStateOf(WidgetRef ref) {
  final profile = ref.watch(myProfileProvider);
  final now = ref.watch(clockProvider).now();
  final spaces = _spacesRead(ref);
  final bookings = _bookingsRead(ref, now);
  // Nothing waiting: no unpaid document, undecided request or unread message.
  final items = attentionItemsOf(ref, now, spaces.refs);
  final next = bookings.next;
  final bool? firstVisit =
      spaces.none == null || next == null || items == null
      ? null
      : (spaces.none! &&
            !spaces.fact! &&
            next.commitment == null &&
            next.complete &&
            items.isEmpty);
  return HomeState(
    firstVisit: firstVisit,
    facts: {
      StartedStep.account: profile.hasValue ? profile.value != null : null,
      StartedStep.space: spaces.fact,
      StartedStep.booking: bookings.fact,
      StartedStep.profile: _profileFact(profile),
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
class _FirstStepsCard extends StatelessWidget {
  const _FirstStepsCard({required this.facts});

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
              onTap: _openStep(context, row.step),
            ),
        ],
      ),
    );
  }
}

/// While first steps remain, ONE line at the end of Home: how many are left
/// and which comes next ("One step left · Add your name and photo"), one tap
/// to it. The full card is the first visit's.
class FirstStepsRow extends StatelessWidget {
  const FirstStepsRow({super.key, required this.facts});

  final Map<StartedStep, bool?> facts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = startedRows(facts);
    final left = rows.where((r) => r.state != StartedState.done).toList();
    final next = rows.firstWhere((r) => r.state == StartedState.next).step;
    final text = l10n.meStartedLeft(left.length, _stepLabel(l10n, next));
    return MeCard(
      key: const ValueKey('me-first-steps-row'),
      child: MeRow(
        key: const ValueKey('me-first-steps-open'),
        title: text,
        semanticLabel: text,
        leading: Icon(_stepIcon(next)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openStep(context, next),
      ),
    );
  }
}

VoidCallback? _openStep(BuildContext context, StartedStep step) =>
    switch (step) {
      StartedStep.account => null,
      StartedStep.space ||
      StartedStep.booking => () => context.go(MeTab.discover.path),
      StartedStep.profile => () => context.go(MeTab.me.path),
    };

/// Discover with its search box focused (a person who asked for a place wants
/// to type or look, not to see an empty list first).
const String _discoverFocus = '/me/discover?focus=search';

/// The first visit.
class PersonalFirstVisit extends ConsumerStatefulWidget {
  const PersonalFirstVisit({super.key, required this.facts});

  final Map<StartedStep, bool?> facts;

  @override
  ConsumerState<PersonalFirstVisit> createState() => _FirstVisitState();
}

class _FirstVisitState extends ConsumerState<PersonalFirstVisit> {
  /// The search field only opens Discover; its controller is never typed in.
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              MeFilledField(
                child: AppTextField(
                  key: const ValueKey('me-first-visit-search'),
                  controller: _search,
                  label: '',
                  readOnly: true,
                  onTap: discover,
                  hint: l10n.meFindPlaceHint,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonal(
                  key: const ValueKey('me-first-visit-browse'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, PersonalShellMetrics.minTarget),
                  ),
                  onPressed: () => context.go(MeTab.discover.path),
                  child: Text(l10n.meFindPlaceBrowse),
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
                l10n.titleAndBody(l10n.meInvitationTitle, l10n.meInvitationBody),
            leading: const Icon(Icons.qr_code_2_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/onboarding?join=1'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _FirstStepsCard(facts: widget.facts),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          key: const ValueKey('me-first-visit-run'),
          style: TextButton.styleFrom(
            alignment: AlignmentDirectional.centerStart,
            minimumSize: const Size(0, PersonalShellMetrics.minTarget),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          onPressed: () => context.push('/onboarding'),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${l10n.meRunASpace} ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.secondaryText,
                  ),
                ),
                TextSpan(
                  text: l10n.meRunASpaceAction,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: tokens.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
