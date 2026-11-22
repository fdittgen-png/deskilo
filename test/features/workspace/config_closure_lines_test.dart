// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4322 -- a closure day is a calendar date: it prints as its own date, never moved by a zone. A
// day held as midnight UTC would print the day before on a device west of UTC if it were passed
// through `.toLocal()`; the lint (`format_seam_test`) is what holds the code form on every machine.
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/features/workspace/presentation/config_pdf_lines.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  test('a closure prints as its own date, with its reason when it has one', () async {
    await initializeDateFormatting('en');
    final lines = configClosures('en', [
      ClosureDay(id: 'c1', workspaceId: 'ws', day: DateTime.utc(2026, 12, 31), reason: ''),
      ClosureDay(id: 'c2', workspaceId: 'ws', day: DateTime.utc(2027), reason: 'New Year'),
      ClosureDay(id: 'c3', workspaceId: 'ws', day: DateTime(2026, 12, 25), reason: 'Christmas'),
    ]);
    expect(lines, ['Dec 31, 2026', 'Jan 1, 2027 — New Year', 'Dec 25, 2026 — Christmas']);
  });
}
