// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/room_level_kind.dart';
import '../../domain/room_rental.dart';
import '../../providers/room_rental_providers.dart';
import 'rented_room_dialog.dart';

Future<void> _showRentedRoomsSheet(BuildContext context, String workspaceId) =>
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RentedRoomsView(workspaceId: workspaceId),
    );

/// The Money door to the rented rooms. The caller offers it to those who may
/// manage the plan; the server decides again on every read and write.
class RentedRoomsButton extends StatelessWidget {
  const RentedRoomsButton({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('rented-rooms-button'),
      onPressed: () => _showRentedRoomsSheet(context, workspaceId),
      icon: const Icon(Icons.meeting_room_outlined),
      label: Text(context.l10n.roomRentTitle),
    );
  }
}

/// The floors the space rents rooms in, the rooms on them, and each rental
/// with its window, its cost and what a member pays.
@visibleForTesting
class RentedRoomsView extends ConsumerWidget {
  const RentedRoomsView({required this.workspaceId, super.key});

  final String workspaceId;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    RentableRoom room,
    RoomRental? rental,
  ) async {
    final saved = await showRentedRoomDialog(
      context,
      workspaceId,
      officeId: room.officeId,
      roomName: room.name,
      rental: rental,
    );
    if (saved != true) return;
    ref.invalidate(roomRentalsProvider(workspaceId));
    if (context.mounted) AppSnack.success(context, context.l10n.roomRentSaved);
  }

  Future<void> _setKind(
    BuildContext context,
    WidgetRef ref,
    RoomLevel level,
    bool external,
  ) async {
    final ok = await runGuarded(
      context,
      domain: 'reservations',
      message: 'level kind failed',
      errorText: context.l10n.roomRentLevelRefused,
      action: () => ref
          .read(roomRentalCommandProvider)
          .setLevelKind(
            workspaceId,
            level.id,
            external ? LevelKind.external : LevelKind.own,
          ),
    );
    if (ok) ref.invalidate(roomRentalsProvider(workspaceId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final overview = ref.watch(roomRentalsProvider(workspaceId));
    return SheetShell(
      title: l10n.roomRentTitle,
      children: [
        Text(l10n.roomRentIntro, style: Theme.of(context).textTheme.bodySmall),
        overview.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(l10n.roomRentLoadFailed),
          data: (o) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.roomRentLevels,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final level in o.levels)
                SwitchListTile(
                  key: ValueKey('room-level-${level.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(level.name),
                  subtitle: Text(l10n.roomRentLevelExternal),
                  value: level.kind == LevelKind.external,
                  onChanged: (v) => _setKind(context, ref, level, v),
                ),
              const SizedBox(height: AppSpacing.md),
              if (o.rooms.isEmpty)
                Text(
                  l10n.roomRentEmpty,
                  key: const ValueKey('room-rent-empty'),
                ),
              for (final room in o.rooms)
                _RoomCard(
                  room: room,
                  rental: o.rentals
                      .where((r) => r.officeId == room.officeId)
                      .firstOrNull,
                  material: material,
                  onEdit: (rental) => _edit(context, ref, room, rental),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.rental,
    required this.material,
    required this.onEdit,
  });

  final RentableRoom room;
  final RoomRental? rental;
  final MaterialLocalizations material;
  final ValueChanged<RoomRental?> onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = rental;
    final money = r == null ? null : moneyFormat(r.currency);
    int? generalFee;
    for (final f in r?.fees ?? const <RoomFee>[]) {
      if (f.unit == RoomFeeUnit.halfDay && f.audience.toJson().isEmpty) {
        generalFee = f.feeCents;
      }
    }
    return Card(
      key: ValueKey('room-${room.officeId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${room.levelName} · ${room.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (r == null)
              Text(l10n.roomRentNotRented)
            else ...[
              Text(
                '${roomRentalStatusLabel(l10n, r.status)} · ${r.supplierName}',
                key: ValueKey('room-status-${room.officeId}'),
              ),
              Text(
                r.availableUntil == null
                    ? l10n.roomRentWindowOpen(
                        material.formatMediumDate(r.availableFrom),
                      )
                    : l10n.roomRentWindow(
                        material.formatMediumDate(r.availableFrom),
                        material.formatMediumDate(r.availableUntil!),
                      ),
              ),
              Text(l10n.roomRentCostLine(money!.formatMinor(r.costCents))),
              if (generalFee != null)
                Text(l10n.roomRentFeeLine(money.formatMinor(generalFee))),
              Text(
                r.audienceAll || r.audience.isNotEmpty
                    ? (r.audienceAll
                          ? l10n.roomRentAudienceAll
                          : l10n.roomRentAudienceNamed(r.audience.length))
                    : l10n.roomRentAudienceNobody,
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ValueKey('room-edit-${room.officeId}'),
                onPressed: () => onEdit(r),
                child: Text(r == null ? l10n.roomRentRent : l10n.roomRentEdit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
