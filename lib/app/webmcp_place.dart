// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — get_place on the page: one place described from the plan the app
// draws (levels, offices, desks, seats), with its seats, its amenities, the
// person's favourite mark and the place's rating, field for field as the
// facade's answer (0371, 0375). The label follows the facade's rule: a desk
// without a name is "Desk N", and a seat is never labelled by its own name,
// which may name a person (#1645). The page draws no picture: a requested
// image answers image_available false, as the facade does for a plan it
// cannot draw.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/plan/domain/desk.dart';
import '../features/plan/domain/floor_plan.dart';
import '../features/plan/domain/level.dart';
import '../features/plan/domain/office.dart';
import '../features/plan/domain/seat.dart';
import '../features/plan/providers/floor_plan_providers.dart';
import '../features/reservations/domain/place_feedback.dart';
import '../features/reservations/providers/place_feedback_providers.dart';
import '../features/reservations/providers/reservation_providers.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'webmcp_writes.dart';

const _notFound = WebMcpRefused('not_found', 'No such place here.');

/// Describes the place the input names: a reservation of the person's own,
/// or exactly one seat, desk, office or level.
Future<Map<String, Object?>> webMcpPlace(
  Ref ref,
  Map<String, Object?> input,
) async {
  String? id(String key) {
    final value = input[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  var seatId = id('seat_id');
  var deskId = id('desk_id');
  var officeId = id('office_id');
  var levelId = id('level_id');
  final reservationId = id('reservation_id');
  if ([seatId, deskId, officeId, levelId, reservationId].nonNulls.length != 1) {
    throw const WebMcpRefused(
      'validation_error',
      'Name exactly one of reservation_id, seat_id, desk_id, office_id or '
          'level_id.',
    );
  }
  final workspace = await ref.read(currentWorkspaceProvider.future);
  if (workspace == null) throw _notFound;
  if (reservationId != null) {
    final me = await ref.read(myMemberProvider.future);
    final booking = await ref
        .read(reservationRepositoryProvider)
        .fetchById(reservationId);
    if (booking == null ||
        me == null ||
        booking.memberId != me.id ||
        booking.workspaceId != workspace.id) {
      throw const WebMcpRefused('not_found', 'No such booking of yours here.');
    }
    seatId = booking.seatId;
    deskId = booking.deskId;
    officeId = booking.officeId;
    levelId = booking.levelId;
  }
  for (final level in await ref.read(levelsProvider.future)) {
    final plan = await ref.read(floorPlanProvider(level.id).future);
    final seat = plan.seats.where((s) => s.id == seatId).firstOrNull;
    final desk = plan.desks
        .where((d) => d.id == (seat?.deskId ?? deskId))
        .firstOrNull;
    final office = plan.offices
        .where((o) => o.id == (desk?.officeId ?? officeId))
        .firstOrNull;
    final found = seatId != null
        ? seat != null
        : deskId != null
        ? desk != null
        : officeId != null
        ? office != null
        : level.id == levelId;
    if (!found) continue;
    return {
      ..._describe(level, plan, office, desk, seat),
      'reservation_id': ?reservationId,
      ...await _feedback(ref, level, office, desk, seat),
      'image_requested': input['include_image'] == true,
      'image_available': input['include_image'] != true,
    };
  }
  throw _notFound;
}

Map<String, Object?> _describe(
  Level level,
  FloorPlan plan,
  Office? office,
  Desk? desk,
  Seat? seat,
) {
  final officeOf = {for (final d in plan.desks) d.id: d.officeId};
  final inside = [
    for (final s in plan.seats)
      if (officeOf[s.deskId] case final o?)
        if (seat != null
            ? s.id == seat.id
            : desk != null
            ? s.deskId == desk.id
            : office == null || o == office.id)
          s,
  ];
  return {
    'kind': _kind(office, desk, seat).name,
    'level_id': level.id,
    'office_id': ?office?.id,
    'desk_id': ?desk?.id,
    'seat_id': ?seat?.id,
    'label': [
      level.name.trim(),
      ?office?.name.trim(),
      if (desk != null) _deskLabel(plan, desk),
      if (seat != null) _seatLabel(plan, seat),
    ].join(' · '),
    'name': seat?.name ?? desk?.name ?? office?.name ?? level.name,
    'seats': inside.length,
    'amenities': ({
      for (final s in inside) ...s.amenities,
    }.toList()..sort()).take(20).toList(),
    'bookable_as_whole': ?(seat != null
        ? null
        : desk?.bookableAsWhole ??
              office?.bookableAsWhole ??
              level.bookableAsWhole),
  };
}

PlaceKind _kind(Office? office, Desk? desk, Seat? seat) => seat != null
    ? PlaceKind.seat
    : desk != null
    ? PlaceKind.desk
    : office != null
    ? PlaceKind.office
    : PlaceKind.level;

/// Orders as the facade does: by row, then column, then id.
int _byPosition((int, int, String) a, (int, int, String) b) => a.$1 != b.$1
    ? a.$1.compareTo(b.$1)
    : a.$2 != b.$2
    ? a.$2.compareTo(b.$2)
    : a.$3.compareTo(b.$3);

String _deskLabel(FloorPlan plan, Desk desk) {
  if (desk.name.trim().isNotEmpty) return desk.name.trim();
  final key = (desk.rect.y, desk.rect.x, desk.id);
  final n = plan.desks
      .where(
        (d) =>
            d.officeId == desk.officeId &&
            _byPosition((d.rect.y, d.rect.x, d.id), key) <= 0,
      )
      .length;
  return 'Desk $n';
}

String _seatLabel(FloorPlan plan, Seat seat) {
  final key = (seat.y, seat.x, seat.id);
  final n = plan.seats
      .where(
        (s) =>
            s.deskId == seat.deskId && _byPosition((s.y, s.x, s.id), key) <= 0,
      )
      .length;
  return 'Seat ${n >= 1 && n <= 26 ? String.fromCharCode(64 + n) : n}';
}

/// The favourite mark and the rating, while the workspace has place
/// feedback on.
Future<Map<String, Object?>> _feedback(
  Ref ref,
  Level level,
  Office? office,
  Desk? desk,
  Seat? seat,
) async {
  if (!ref
      .read(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.placeFeedback)) {
    return const {};
  }
  final id = seat?.id ?? desk?.id ?? office?.id ?? level.id;
  final f = await ref.read(
    placeFeedbackProvider(_kind(office, desk, seat), id).future,
  );
  return {
    'favorite': f.favorite,
    'rating': {'average': f.average, 'count': f.count, 'mine': f.mine},
  };
}
