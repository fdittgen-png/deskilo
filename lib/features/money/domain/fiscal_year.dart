// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The fiscal year of a book: the exercise that holds a day, on the start
// month and day the issuer's book profile states; a FEC written from the
// documents, with no book profile, keeps the calendar year. The FEC is one
// file per fiscal year, named after its closing day, and its entries are
// dated inside it.
import '../../../core/time/date_text.dart';
import 'book_period.dart';
import 'book_profile.dart';

/// One fiscal year: its first and last day, both inside it.
class FiscalYear {
  const FiscalYear(this.from, this.to);

  /// The calendar year [year].
  FiscalYear.calendar(int year) : this(DateTime(year), DateTime(year, 12, 31));

  final DateTime from;
  final DateTime to;

  bool contains(DateTime day) =>
      isoDay(day).compareTo(isoDay(from)) >= 0 &&
      isoDay(day).compareTo(isoDay(to)) <= 0;

  @override
  bool operator ==(Object other) =>
      other is FiscalYear &&
      isoDay(other.from) == isoDay(from) &&
      isoDay(other.to) == isoDay(to);

  @override
  int get hashCode => Object.hash(isoDay(from), isoDay(to));

  @override
  String toString() => 'FiscalYear(${isoDay(from)}..${isoDay(to)})';
}

/// The fiscal year of [profile] that holds [day] (`fiscalYearOf`).
FiscalYear bookYearOf(BookProfile profile, DateTime day) {
  final (:start, :end, label: _) = fiscalYearOf(profile, day);
  return FiscalYear(start, end);
}

/// Every day of [year] lies inside a closed period of [overview]: the
/// year's FEC is final. Otherwise it is provisional and never archived as
/// final.
bool fiscalYearClosed(BookPeriodsOverview overview, FiscalYear year) {
  for (
    var day = year.from;
    !day.isAfter(year.to);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (overview.closedOn(day) == null) return false;
  }
  return true;
}
