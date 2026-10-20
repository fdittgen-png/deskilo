// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/roles/audience_roles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/room_rental.dart';
import '../../providers/room_rental_providers.dart';

/// #2575 -- who else a rented room is open to: roles and plans as chips,
/// members picked from the space's own and shown as removable chips. The
/// sets are the caller's; [onEdited] is called after each edit of them.
class RoomAudiencePickers extends ConsumerWidget {
  const RoomAudiencePickers({
    super.key,
    required this.workspaceId,
    required this.roleIds,
    required this.planIds,
    required this.memberIds,
    required this.onEdited,
  });

  final String workspaceId;
  final Set<String> roleIds;
  final Set<String> planIds;
  final Set<String> memberIds;
  final VoidCallback onEdited;

  void _toggle(Set<String> ids, String id, {required bool on}) {
    if (on) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    onEdited();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final label = Theme.of(context).textTheme.labelLarge;
    final language = Localizations.localeOf(context).languageCode;
    final roles = ref.watch(audienceRolesProvider);
    final plans =
        ref.watch(roomPlansProvider(workspaceId)).value ?? const <RoomPlan>[];
    final members = ref.watch(audienceMembersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (roles.isNotEmpty) ...[
          Text(l10n.roomRentFieldRoles, style: label),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final role in roles)
                FilterChip(
                  key: ValueKey('room-rent-role-${role.id}'),
                  label: Text(role.nameIn(language)),
                  selected: roleIds.contains(role.id),
                  onSelected: (on) => _toggle(roleIds, role.id, on: on),
                ),
            ],
          ),
        ],
        if (plans.isNotEmpty) ...[
          Text(l10n.roomRentFieldPlans, style: label),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final plan in plans)
                FilterChip(
                  key: ValueKey('room-rent-plan-${plan.id}'),
                  label: Text(plan.name),
                  selected: planIds.contains(plan.id),
                  onSelected: (on) => _toggle(planIds, plan.id, on: on),
                ),
            ],
          ),
        ],
        if (members.isNotEmpty) ...[
          Text(l10n.roomRentFieldMembers, style: label),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final id in memberIds)
                InputChip(
                  key: ValueKey('room-rent-member-$id'),
                  label: Text(members[id] ?? id),
                  onDeleted: () => _toggle(memberIds, id, on: false),
                ),
            ],
          ),
          // Re-created after each pick, so the field is ready again.
          KeyedSubtree(
            key: ValueKey(memberIds.length),
            child: DropdownButtonFormField<String>(
              key: const ValueKey('room-rent-member-add'),
              decoration: InputDecoration(labelText: l10n.roomRentAddMember),
              items: [
                for (final e in members.entries)
                  if (!memberIds.contains(e.key))
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) _toggle(memberIds, v, on: true);
              },
            ),
          ),
        ],
      ],
    );
  }
}
