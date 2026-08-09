// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/desk.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/office.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/space_code.dart';
import '../../providers/reservation_providers.dart';
import 'reservation_detail_sheet.dart';
import 'space_scan.dart';

/// A space fully resolved against the live floor plan — what
/// [showSpaceSheet] wants. Null members follow the kind.
typedef ResolvedSpace = ({
  Level? level,
  Office? office,
  Desk? desk,
  Seat? seat,
  FloorPlan? plan,
});

/// Resolves a space id against the current floor plans — the same walk
/// the QR scan performs, shared so message references (#523) and any
/// future deep link open spaces one way. Returns null when the space
/// no longer exists (deleted since the reference was written).
Future<ResolvedSpace?> resolveSpaceById(
  WidgetRef ref,
  SpaceKind kind,
  String id,
) async {
  final levels = await ref.read(levelsProvider.future);
  if (kind == SpaceKind.level) {
    final level = levels.where((l) => l.id == id).firstOrNull;
    if (level == null) return null;
    return (level: level, office: null, desk: null, seat: null, plan: null);
  }
  final plans = await Future.wait([
    for (final candidate in levels)
      ref
          .read(floorPlanProvider(candidate.id).future)
          .then<({Level level, FloorPlan plan})?>(
            (p) => (level: candidate, plan: p),
            onError: (_, _) => null,
          ),
  ]);
  for (final entry in plans.whereType<({Level level, FloorPlan plan})>()) {
    final p = entry.plan;
    Office? office;
    Desk? desk;
    Seat? seat;
    switch (kind) {
      case SpaceKind.office:
        office = p.offices.where((o) => o.id == id).firstOrNull;
      case SpaceKind.desk:
        desk = p.desks.where((d) => d.id == id).firstOrNull;
      case SpaceKind.seat:
        seat = p.seats.where((s) => s.id == id).firstOrNull;
        desk = seat == null
            ? null
            : p.desks.where((d) => d.id == seat!.deskId).firstOrNull;
      case SpaceKind.level:
        break;
    }
    if (office != null || desk != null || seat != null) {
      office ??= p.offices.where((o) => o.id == desk?.officeId).firstOrNull;
      return (
        level: entry.level,
        office: office,
        desk: desk,
        seat: seat,
        plan: p,
      );
    }
  }
  return null;
}

/// Opens the booking sheet for a referenced SPACE — tapping a
/// `[space:…]` link in a message. A vanished space reports like a
/// stale QR card instead of crashing.
Future<void> openSpaceById(
  BuildContext context,
  WidgetRef ref, {
  required SpaceKind kind,
  required String id,
}) async {
  final l10n = AppLocalizations.of(context);
  final resolved = await resolveSpaceById(ref, kind, id);
  if (!context.mounted) return;
  if (resolved == null) {
    AppSnack.error(
      context,
      l10n?.spaceScanUnknown ??
          'This code does not match any space here anymore.',
    );
    return;
  }
  await showSpaceSheet(
    context,
    kind: kind,
    level: resolved.level,
    office: resolved.office,
    desk: resolved.desk,
    seat: resolved.seat,
    plan: resolved.plan,
  );
}

/// Opens the detail sheet of a referenced RESERVATION — tapping a
/// `[res:…]` link in a message. Resolves live by id, so the sheet
/// always shows the reservation's CURRENT state (moved, checked in,
/// cancelled-and-gone).
Future<void> openReservationById(
  BuildContext context,
  WidgetRef ref,
  String reservationId,
) async {
  final l10n = AppLocalizations.of(context);
  final reservation = await ref
      .read(reservationRepositoryProvider)
      .fetchById(reservationId);
  if (!context.mounted) return;
  if (reservation == null) {
    AppSnack.error(
      context,
      l10n?.noteRefGone ?? 'This reservation no longer exists.',
    );
    return;
  }
  await showReservationDetail(context, ref, reservation);
}
