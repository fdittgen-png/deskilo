// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3604 (desk F3) — the measure a page is drawn in, declared by its route
// (route_classes.dart) and applied by the frame, never chosen by the page
// itself. Apart from the widgets (page_measure.dart) so the route table can
// name it without Flutter.

/// The measure of a page.
enum PageMeasure {
  /// Today's frame: the reading column (960), canvas pages 1200
  /// (app_frame.dart). Every route not yet given its own measure.
  framed,

  /// A column to read: [kReadingColumnWidth] at most.
  reading,

  /// A column to fill in: [kFormColumnWidth] at most.
  form,

  /// The whole content area, with gutters, [kWorkAreaMaxWidth] at most.
  work,
}

/// The widest a reading page is drawn.
const double kReadingColumnWidth = 720;

/// The widest a form is drawn.
const double kFormColumnWidth = 640;

/// The widest a work page is drawn, however wide the window.
const double kWorkAreaMaxWidth = 1760;

/// A work page's gutter on each side from the expanded window class, and
/// from the large one. Below the expanded class a work page keeps the padding
/// it has of its own, as it did inside the frame: no gutter is added.
const double kWorkAreaGutterExpanded = 24;
const double kWorkAreaGutterLarge = 32;
