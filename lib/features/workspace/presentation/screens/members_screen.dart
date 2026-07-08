// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/providers/money_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member.dart';
import '../../providers/workspace_providers.dart';

/// Owner-only member management: role overview, plan assignment,
/// pause/reactivate (spec §7.2).
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(workspaceMembersProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final plans = ref.watch(plansProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.membersTitle ?? 'Members & plans'),
      ),
      body: switch (membersAsync) {
        AsyncData(value: final members) => ListView(
            children: [
              for (final member in members)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (names[member.id] ?? '?').isEmpty
                          ? '?'
                          : (names[member.id] ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                    ),
                  ),
                  title: Text(names[member.id] ?? ''),
                  subtitle: Wrap(
                    spacing: 6,
                    children: [
                      if (member.isOwner)
                        Text(l10n?.memberRoleOwner ?? 'Owner'),
                      if (member.isAdmin && !member.isOwner)
                        Text(l10n?.memberRoleAdmin ?? 'Admin'),
                      if (member.status == MemberStatus.paused)
                        Text(l10n?.memberStatusPaused ?? 'Paused'),
                      if (member.status == MemberStatus.exited)
                        Text(l10n?.memberStatusExited ?? 'Exited'),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 130,
                    child: DropdownButton<String?>(
                      value: plans.any((p) => p.id == member.planId)
                          ? member.planId
                          : null,
                      isExpanded: true,
                      hint: Text(l10n?.membersPlanNone ?? 'No plan'),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n?.membersPlanNone ?? 'No plan'),
                        ),
                        for (final plan in plans)
                          DropdownMenuItem<String?>(
                            value: plan.id,
                            child: Text(plan.name),
                          ),
                      ],
                      onChanged: (planId) async {
                        await ref
                            .read(workspaceRepositoryProvider)
                            .updateMemberPlan(member.id, planId);
                        ref.invalidate(workspaceMembersProvider);
                      },
                    ),
                  ),
                  onLongPress: member.status == MemberStatus.exited
                      ? null
                      : () async {
                          final paused =
                              member.status == MemberStatus.paused;
                          await ref
                              .read(workspaceRepositoryProvider)
                              .updateMemberStatus(
                                member.id,
                                paused
                                    ? MemberStatus.active
                                    : MemberStatus.paused,
                              );
                          ref.invalidate(workspaceMembersProvider);
                        },
                ),
            ],
          ),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
