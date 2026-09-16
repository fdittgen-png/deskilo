// SPDX-License-Identifier: 0BSD
//
// #1274 — the decision to generate a year's closure days, out of the widget.
//
// ADR 0024 and `reservations/application/book_seat.dart` are the shape:
// `presentation/` says what the owner asked for, `application/` decides
// which write that is, `data/` performs it. Pure Dart — no Flutter, no
// `BuildContext`, no localization — so the preview and the apply can be
// exercised without pumping a screen.
//
// It does not catch. A refusal from the server is information the owner
// needs verbatim: "only an owner may generate closure days" is the
// server's own sentence, and swallowing it here to return a tidier type
// would throw away the only explanation there is.
import '../domain/public_holidays.dart';
import '../domain/workspace_repository.dart';

/// Previewing and applying are the SAME server call with one flag, which
/// is what keeps the list an owner confirms equal to the list that gets
/// written. This type exists so that a widget cannot call the writing
/// one while meaning to look.
class PublicHolidayGeneration {
  const PublicHolidayGeneration(this._workspaces);

  final WorkspaceRepository _workspaces;

  /// What WOULD happen. Writes nothing.
  Future<HolidayGeneration> preview({
    required String workspaceId,
    required String country,
    required int year,
  }) =>
      _workspaces.generateClosureDays(workspaceId,
          country: country, year: year);

  /// Creates the days that are neither locked to an invoiced month nor
  /// already present. Returns what the server actually did.
  Future<HolidayGeneration> apply({
    required String workspaceId,
    required String country,
    required int year,
  }) =>
      _workspaces.generateClosureDays(workspaceId,
          country: country, year: year, apply: true);
}
