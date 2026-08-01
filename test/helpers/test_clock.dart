// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/money/domain/bill_sections.dart'
    show currentPeriod;

/// The instant every widget test believes it is running at.
///
/// A Wednesday in the middle of a month, so nothing lands on a weekend, a
/// month boundary or a DST transition by accident.
///
/// Seed test data relative to THIS, never to the wall clock. Two tests
/// asserted against the wall clock — one on the literal month name, one on
/// a fake whose statement period was pinned to `'2026-07'` while the screen
/// asked for the running month. Both passed for three weeks and went red
/// together at the 2026-08-01 boundary with no commit in between. A time
/// bomb is not a regression, and bumping the string only resets the fuse.
///
/// It lives in its own file so the fakes can share it with
/// `standardTestOverrides` without importing `mock_providers.dart`, which
/// imports them.
final DateTime kTestNow = DateTime(2026, 5, 13, 10);

/// `kTestNow` as a ledger period — the month a statement, bill or
/// invoice belongs to when a test does not say otherwise. Derived through
/// the app's own [currentPeriod] so this can never silently disagree with
/// the period keys the app actually writes.
final String kTestPeriod = currentPeriod(kTestNow);
