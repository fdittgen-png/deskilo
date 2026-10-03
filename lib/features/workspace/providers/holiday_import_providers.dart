// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2051 — the open-data holiday source, overridable in tests.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/import_public_holidays.dart';
import '../data/nager_holiday_source.dart';
import '../domain/holiday_import.dart';
import 'workspace_providers.dart';

part 'holiday_import_providers.g.dart';

@Riverpod(keepAlive: true)
HolidaySource holidaySource(Ref ref) => NagerHolidaySource();

/// The import decision the sheet is handed (ADR 0024): the source and the
/// repository, resolved here rather than in a widget.
@riverpod
PublicHolidayImport publicHolidayImport(Ref ref) => PublicHolidayImport(
  ref.watch(holidaySourceProvider),
  ref.watch(workspaceRepositoryProvider),
);
