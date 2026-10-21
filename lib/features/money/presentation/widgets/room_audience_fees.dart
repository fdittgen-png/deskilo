// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/roles/audience_roles.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/room_rental.dart';
import '../../providers/room_rental_providers.dart';

/// The key of one audience entry's fee field: `role:`, `plan:` or `member:`
/// and its id.
String roomAudienceFeeKey(RoomAudienceEntry e) => e.roleId != null
    ? 'role:${e.roleId}'
    : e.planId != null
    ? 'plan:${e.planId}'
    : 'member:${e.memberId}';

/// #2575 -- a fee per half day for one role, plan or member the rented room
/// is open to; an empty field leaves that entry on the general fee. The
/// controllers are the caller's, one per entry key ([roomAudienceFeeKey]).
class RoomAudienceFees extends ConsumerWidget {
  const RoomAudienceFees({
    super.key,
    required this.workspaceId,
    required this.entries,
    required this.controllerFor,
  });

  final String workspaceId;
  final List<RoomAudienceEntry> entries;
  final TextEditingController Function(String key) controllerFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final roles = {
      for (final r in ref.watch(audienceRolesProvider))
        r.id: r.nameIn(language),
    };
    final plans = {
      for (final p
          in ref.watch(roomPlansProvider(workspaceId)).value ??
              const <RoomPlan>[])
        p.id: p.name,
    };
    final members = ref.watch(audienceMembersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          AppTextField(
            key: ValueKey('room-rent-fee-${roomAudienceFeeKey(e)}'),
            controller: controllerFor(roomAudienceFeeKey(e)),
            label: l10n.roomRentFieldEntryFee(
              roles[e.roleId] ??
                  plans[e.planId] ??
                  members[e.memberId] ??
                  (e.roleId ?? e.planId ?? e.memberId ?? ''),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
      ],
    );
  }
}
