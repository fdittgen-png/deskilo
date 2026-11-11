// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-g -- a day on the invoicing screens: month and day within the
// current year ("Aug 19"), the whole date in any other ("Aug 19, 2025"), so
// a date from last year is never read as this year's.
import '../../../../core/i18n/app_format.dart';

String invoicingDay(AppFormat format, DateTime day, DateTime today) => format
    .dates(day.year == today.year ? DateShape.monthDay : DateShape.date)
    .format(day);
