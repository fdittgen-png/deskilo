// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/room_level_kind.dart';
import '../domain/room_rental.dart';

/// #2568 — what is sent for a rented room. A command sends nothing when the
/// entry cannot be right (the server decides again on every write); null
/// tells the caller nothing was sent.
class RoomRentalCommands {
  const RoomRentalCommands(this._repository);

  final RoomRentalRepository _repository;

  Future<RoomRental?> save(String workspaceId, RoomRentalCommand command) {
    final until = command.availableUntil;
    if (command.officeId.isEmpty ||
        command.supplierId.isEmpty ||
        command.costCents < 0 ||
        command.fees.any((f) => f.feeCents < 0) ||
        (until != null && until.isBefore(command.availableFrom))) {
      return Future.value();
    }
    return _repository.saveRental(workspaceId, command);
  }

  Future<void> setLevelKind(
    String workspaceId,
    String levelId,
    LevelKind kind,
  ) => _repository.setLevelKind(workspaceId, levelId, kind);
}
