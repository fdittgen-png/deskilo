// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the measures of the desk calendar's grids. They are fits
// of content, never postures of the window: the window's class decides which
// page is drawn (the calendar branch), the room the grid has decides its
// zoom (desk_zoom.dart).

/// The grids' dimensions.
abstract final class DeskCalendarMetrics {
  /// The place column: a seat's name and the level it stands on.
  // content-fit: a place name of a normal length, without a cut
  static const double placeColumn = 168;

  /// One row of places: a mouse hits it at 36, a block inside it is the row
  /// less its inset.
  // content-fit: the row a block of a booking and its time fit in
  static const double rowHeight = 44;

  /// A level's header row between groups of places.
  // content-fit: one line of text, not a target
  static const double levelHeader = 28;

  /// The hour ruler and the week's day headers.
  // content-fit: one line of text above the rows
  static const double ruler = 40;

  /// The inset of a block inside its row.
  static const double blockInset = 4;

  /// The narrowest an hour is drawn before the grid zooms or scrolls instead
  /// of squeezing it: a booking of one hour still shows its start and a word.
  // content-fit: the least width at which an hour's block stays selectable
  static const double minHourWidth = 56;

  /// The narrowest a day of the week grid is drawn.
  // content-fit: a day cell holds one booking's name and its hours
  static const double minDayWidth = 104;

  /// A booking line in a month cell: as high as a row the mouse hits.
  // content-fit: a line a mouse hits (36) with the booking's name
  static const double monthLine = 36;

  /// The day number's line in a month cell.
  // content-fit: a line a mouse hits (36) with the day's number
  static const double monthDayHeader = 36;

  /// The least height of a month cell: its header and one booking line.
  static const double monthCellMin = monthDayHeader + monthLine;

  /// What one click on the zoom buttons multiplies the hour's width by.
  static const double zoomStep = 1.5;

  /// The most the day view zooms in.
  static const double zoomMax = 4;
}

/// How a day's opening hours are laid across the room a grid has.
typedef DeskDayScale = ({double pixelsPerMinute, double width, bool scrolls});

/// The scale of [minutes] of opening hours in [room] pixels, zoomed by
/// [zoom] (1 = fit). The default fits every hour in the room; where that would
/// squeeze an hour under [DeskCalendarMetrics.minHourWidth] the hours keep that
/// width and the grid scrolls sideways, the zoom buttons widening it further.
DeskDayScale deskDayScale({
  required double room,
  required int minutes,
  double zoom = 1,
}) {
  if (minutes <= 0 || room <= 0) {
    return (pixelsPerMinute: 0, width: room, scrolls: false);
  }
  final fit = room / minutes;
  const floor = DeskCalendarMetrics.minHourWidth / Duration.minutesPerHour;
  final perMinute = (fit < floor ? floor : fit) * zoom;
  final width = perMinute * minutes;
  return (pixelsPerMinute: perMinute, width: width, scrolls: width > room + 0.5);
}
