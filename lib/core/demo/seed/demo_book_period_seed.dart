// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the demo space's books: last year closed by its owner and exported
// once to the accountant.
import '../../../features/money/domain/book_period.dart';
import '../data/book_period_repository.dart';

FakeBookPeriodRepository seedDemoBookPeriods(DateTime now) =>
    FakeBookPeriodRepository(
      today: now,
      periods: [
        BookPeriod(
          id: 'demo-period-last-year',
          from: DateTime(now.year - 1),
          to: DateTime(now.year - 1, 12, 31),
          reason: BookPeriodReason.owner,
        ),
      ],
      exports: [
        BookExport(
          id: 'demo-export-last-year',
          formatId: 'fec',
          from: DateTime(now.year - 1),
          to: DateTime(now.year - 1, 12, 31),
          sha256: 'a' * 64,
          byteCount: 18234,
          rowCount: 212,
          documentCount: 41,
          closedPeriod: true,
          exportedAt: DateTime(now.year, 1, 15),
        ),
      ],
    );
