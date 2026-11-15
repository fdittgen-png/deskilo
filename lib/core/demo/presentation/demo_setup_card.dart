// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup guide, inside the demo, first says what the demo is: nothing
// leaves the device, it can be reset at any time, which space and which
// persona the visitor is looking through — and the other space one tap
// away. #4009 — and says the demo is one organisation, Atelier du Marché
// with its houses in several countries and currencies, offering each house
// (and the business outside it) to enter. The guide below reports actual
// setup status for the current space.
// Outside the demo it is nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/space_entry.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/providers/organisation_providers.dart';
import '../../../features/workspace/providers/workspace_providers.dart';
import '../../i18n/country_names.dart';
import '../../l10n/context_l10n.dart';
import '../../theme/app_spacing.dart';
import 'demo_environment.dart';

class DemoSetupCard extends ConsumerWidget {
  const DemoSetupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = DemoEnvironment.maybeOf(context);
    if (env == null) return const SizedBox.shrink();
    final space = ref.watch(currentWorkspaceProvider).value;
    if (space == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('demo-setup-card'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.demoSetupCardTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.demoSetupCardBody),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.demoSetupCardWhere(
                space.name,
                DemoControls.personaLabel(l10n, env.persona),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _DemoOrganisation(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton.icon(
                  key: const ValueKey('demo-setup-reset'),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.demoSessionReset),
                  onPressed: () => DemoControls.resetWithNotice(context, env),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The houses of the Demo's organisation and the business outside it, from
/// the Demo's own read of the person's organisations and businesses.
class _DemoOrganisation extends ConsumerWidget {
  const _DemoOrganisation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organisations = ref.watch(myOrganisationsProvider).value;
    final spaces = ref.watch(myWorkspacesProvider).value;
    if (organisations == null || organisations.isEmpty || spaces == null) {
      return const SizedBox.shrink();
    }
    final organisation = organisations.first;
    final byId = {for (final s in spaces) s.id: s};
    final houses = [
      for (final h in organisation.byCountry)
        if (byId[h.workspaceId] case final w?) (house: h, space: w),
    ];
    final outside = [
      for (final s in spaces)
        if (s.environment == 'prod' && organisation.houseOf(s.id) == null) s,
    ];
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.demoOrganisationBody(
              organisation.name,
              {for (final h in organisation.houses) h.countryCode}.length,
              {for (final h in organisation.houses) h.currencyCode}.length,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.demoOrganisationEnter,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (:house, :space) in houses)
                _EnterButton(
                  key: ValueKey('demo-house-${house.workspaceId}'),
                  space: space,
                  line: countryAndCurrency(
                    l10n,
                    countryCode: house.countryCode,
                    currencyCode: house.currencyCode,
                  ),
                ),
            ],
          ),
          for (final s in outside) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.demoOrganisationOutside(s.name)),
            OutlinedButton(
              key: const ValueKey('demo-organisation-outside'),
              onPressed: () => enterSpace(context, ref, s),
              child: Text(l10n.demoSetupCardOpenSpace(s.name)),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnterButton extends ConsumerWidget {
  const _EnterButton({super.key, required this.space, required this.line});

  final Workspace space;
  final String line;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton(
    onPressed: () => enterSpace(context, ref, space),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Text(space.name), Text(line)],
    ),
  );
}
