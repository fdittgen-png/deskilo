// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2051 — importing a year's public holidays from the open-data source.
//
// Three steps, one decision each: [fetch] asks the source which days
// exist; [preview] asks the server what it would do with them (locked,
// already present); [apply] sends exactly the days the owner kept. The
// preview and the apply are the same server call with one flag, so the
// days written are the days confirmed. Pure Dart; it does not catch — a
// [HolidaySourceUnavailable] or a server refusal reaches the owner as is.
import '../domain/holiday_import.dart';
import '../domain/public_holidays.dart';
import '../domain/workspace_repository.dart';

class PublicHolidayImport {
  const PublicHolidayImport(this._source, this._workspaces);

  final HolidaySource _source;
  final WorkspaceRepository _workspaces;

  /// Every public holiday of [country] in [year], nationwide and regional.
  Future<List<ImportedHoliday>> fetch(String country, int year) =>
      _source.fetch(country, year);

  /// What WOULD happen to [days]. Writes nothing.
  Future<HolidayGeneration> preview(
    String workspaceId,
    List<ImportedHoliday> days,
  ) => _workspaces.importClosureDays(workspaceId, days: _rows(days));

  /// Writes the [kept] days that are neither locked nor already present.
  Future<HolidayGeneration> apply(
    String workspaceId,
    List<ImportedHoliday> kept,
  ) => _workspaces.importClosureDays(
    workspaceId,
    days: _rows(kept),
    apply: true,
  );

  static List<({DateTime day, String name})> _rows(
    List<ImportedHoliday> days,
  ) => [for (final d in days) (day: d.day, name: d.localName)];
}
