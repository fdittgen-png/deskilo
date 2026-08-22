// SPDX-License-Identifier: 0BSD
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/level.dart';
import '../../reservations/domain/space_code.dart';
import 'space_codes_pdf.dart';

/// The localized kind captions printed under each card name.
typedef SpaceKindLabels = ({
  String level,
  String office,
  String desk,
  String seat,
});

/// Builds the printable card entries for the whole floor plan (#584):
/// one card per level, office, desk and seat. The owner-selected [info]
/// rides each card twice — printed as context lines AND embedded in the
/// QR URI so a generic scanner app shows the names too — in enum order,
/// up to the card's own depth (a room card names no table/chair).
List<SpaceCodeEntry> buildSpaceCodeEntries({
  required String workspaceId,
  required String workspaceName,
  required List<(Level, FloorPlan)> plans,
  required Set<SpaceCardInfo> info,
  required SpaceKindLabels kindLabels,
}) {
  final entries = <SpaceCodeEntry>[];
  List<String> lines(Map<SpaceCardInfo, String?> facts) => [
        for (final i in SpaceCardInfo.values)
          if (info.contains(i) && (facts[i]?.isNotEmpty ?? false)) facts[i]!,
      ];
  String payload(
    SpaceKind kind,
    String id,
    Map<SpaceCardInfo, String?> facts,
  ) =>
      SpaceCodeCodec.encode(
        workspaceId: workspaceId,
        kind: kind,
        id: id,
        info: {
          for (final i in SpaceCardInfo.values)
            if (info.contains(i) && (facts[i]?.isNotEmpty ?? false))
              i.wire: facts[i]!,
        },
      );
  for (final (level, plan) in plans) {
    final levelFacts = <SpaceCardInfo, String?>{
      SpaceCardInfo.workspace: workspaceName,
      SpaceCardInfo.level: level.name,
    };
    entries.add((
      name: level.name,
      kindLabel: kindLabels.level,
      payload: payload(SpaceKind.level, level.id, levelFacts),
      contextLines: lines(levelFacts),
    ));
    for (final office in plan.offices) {
      final officeFacts = {...levelFacts, SpaceCardInfo.room: office.name};
      entries.add((
        name: office.name,
        kindLabel: kindLabels.office,
        payload: payload(SpaceKind.office, office.id, officeFacts),
        contextLines: lines(officeFacts),
      ));
    }
    for (final desk in plan.desks) {
      final deskFacts = {
        ...levelFacts,
        SpaceCardInfo.room: plan.offices
            .where((o) => o.id == desk.officeId)
            .firstOrNull
            ?.name,
        SpaceCardInfo.table: desk.name,
      };
      entries.add((
        name: desk.name,
        kindLabel: kindLabels.desk,
        payload: payload(SpaceKind.desk, desk.id, deskFacts),
        contextLines: lines(deskFacts),
      ));
      // One card per WORKSTATION too (field request): the card names
      // seat and desk — tables share seat letters.
      for (final seat in plan.seats.where((s) => s.deskId == desk.id)) {
        final seatFacts = {...deskFacts, SpaceCardInfo.chair: seat.name};
        entries.add((
          name: '${seat.name} · ${desk.name}',
          kindLabel: kindLabels.seat,
          payload: payload(SpaceKind.seat, seat.id, seatFacts),
          contextLines: lines(seatFacts),
        ));
      }
    }
  }
  return entries;
}
