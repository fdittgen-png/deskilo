// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4008 — under an organisation's group on Me, the houses of it the person
// is not a member of: each with its country and currency, and either a way
// to ask to join or the request already made. Before anything is sent, one
// question says what joining means: the person's profile becomes visible to
// that house, which is a business of its own, and what happens there stays
// apart from the other houses.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/country_names.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_snack.dart';
import '../../workspace/domain/organisation.dart';
import '../../workspace/presentation/widgets/organisation_sheet.dart';
import '../../workspace/providers/organisation_providers.dart';

/// The houses of [organisationId] the person may ask to join; nothing while
/// they are read, when they cannot be, or when there is none.
class MeOtherHouses extends ConsumerWidget {
  const MeOtherHouses({super.key, required this.organisationId});

  final String organisationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final houses = [
      for (final h
          in ref.watch(joinableHousesProvider).value ??
              const <
                JoinableHouse
              >[]) // empty-ok: a section that waits shows nothing
        if (h.organisationId == organisationId) h,
    ];
    if (houses.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('me-other-houses-$organisationId'),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              l10n.houseJoinOthers(houses.first.organisationName),
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final house in houses)
            ListTile(
              key: ValueKey('me-other-house-${house.workspaceId}'),
              title: Text(house.name),
              subtitle: Text(
                house.welcome && !house.asked
                    ? l10n.houseJoinWelcomes
                    : l10n.houseJoinWhere(
                        localizedCountryName(l10n, house.countryCode),
                        house.currencyCode,
                      ),
              ),
              trailing: house.asked
                  ? Text(
                      l10n.houseJoinAsked(house.name),
                      key: ValueKey('house-join-asked-${house.workspaceId}'),
                      style: theme.textTheme.bodySmall,
                    )
                  : TextButton(
                      key: ValueKey('house-join-${house.workspaceId}'),
                      onPressed: () => _askToJoin(context, ref, house),
                      child: Text(l10n.houseJoinAsk),
                    ),
            ),
        ],
      ),
    );
  }

  /// Says what joining [house] means and, once the person confirms, asks it;
  /// the answer is said in one notice.
  Future<void> _askToJoin(
    BuildContext context,
    WidgetRef ref,
    JoinableHouse house,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('house-join-sheet'),
        title: Text(l10n.houseJoinSheetTitle(house.name)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.houseJoinSheetProfile(house.name)),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.houseJoinSheetOwn(house.name, house.currencyCode)),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.houseJoinSheetApart),
              const SizedBox(height: AppSpacing.sm),
              Text(
                house.welcome
                    ? l10n.houseJoinSheetWelcome(
                        house.name,
                        house.organisationName,
                      )
                    : l10n.houseJoinSheetDecides(house.name),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('house-join-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('house-join-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              house.welcome
                  ? l10n.houseJoinConfirmJoin
                  : l10n.houseJoinConfirmAsk,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final answer = await ref
        .read(organisationCommandsProvider)
        .askToJoin(house.workspaceId);
    if (!context.mounted) return;
    if (answer.refused case final refused?) {
      AppSnack.error(context, organisationRefusalText(l10n, refused));
      return;
    }
    AppSnack.success(
      context,
      answer.joined == HouseJoin.member
          ? l10n.houseJoinDoneMember(house.name)
          : l10n.houseJoinDoneAsked(house.name),
    );
  }
}
