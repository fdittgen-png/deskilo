// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/presentation/widgets/consumption_sheet.dart';
import '../../../money/providers/money_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';

/// Owner-only member management: role overview, subscription percentage
/// assignment (#128, ADR 0008), pause/reactivate (spec §7.2).
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  Future<void> _pickSubscription(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) async {
    final l10n = AppLocalizations.of(context);
    final offered =
        (await ref.read(subscriptionLevelsProvider.future)).offeredLevels;
    if (!context.mounted) return;

    final custom = TextEditingController();
    final pct = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.memberSubscriptionLabel ?? 'Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final level in offered)
                  ChoiceChip(
                    label: Text(l10n?.percentValue(level) ?? '$level%'),
                    selected: member.subscriptionPct == level,
                    onSelected: (_) => Navigator.of(context).pop(level),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // The owner may always negotiate a free value, even when
            // allow_custom hides it from member-facing pickers.
            TextField(
              controller: custom,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n?.memberSubscriptionCustom ?? 'Custom (1–100)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(custom.text.trim());
              if (value == null || value < 1 || value > 100) return;
              Navigator.of(context).pop(value);
            },
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
    if (pct == null || pct == member.subscriptionPct) return;

    try {
      await ref
          .read(workspaceRepositoryProvider)
          .updateMemberSubscription(member.id, pct);
    } catch (e, st) {
      debugPrint('subscription update failed: $e\n$st');
      TraceLogger.instance.error(
          'workspace', 'member subscription update failed',
          error: e, stackTrace: st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      );
      return;
    }
    ref.invalidate(workspaceMembersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(workspaceMembersProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    // Consumption entry points follow the services feature (#146).
    final servicesOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.services);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.membersTitle ?? 'Members & plans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n?.billingTitle ?? 'Billing',
            onPressed: () => context.push('/billing'),
          ),
        ],
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
                      Text(
                        l10n?.percentValue(member.subscriptionPct) ??
                            '${member.subscriptionPct}%',
                      ),
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Consumed services land on the member's bill only
                      // after the member confirms (#129).
                      if (servicesOn && member.status == MemberStatus.active)
                        IconButton(
                          icon: const Icon(Icons.room_service_outlined),
                          tooltip: l10n?.consumptionAddForMember(
                                names[member.id] ?? '',
                              ) ??
                              'Add service for ${names[member.id] ?? ''}',
                          onPressed: () => showConsumptionSheet(
                            context,
                            ref,
                            subjectMemberId: member.id,
                            subjectName: names[member.id] ?? '',
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.percent),
                        tooltip:
                            l10n?.memberSubscriptionLabel ?? 'Subscription',
                        onPressed: () =>
                            _pickSubscription(context, ref, member),
                      ),
                    ],
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
