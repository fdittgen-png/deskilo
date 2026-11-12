// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3817 — the Week grid in a pocket. On a phone (the compact window class)
// the week exists to see the week, a thumb needs 48 dp, and a finger
// scrolls through seats, not sideways through a grid: the morning half
// stands above the afternoon one, each at least 48 × 48, a day column is
// at least 54 wide, the day headers and the seat names stay in place while
// the body scrolls, and the grid opens with the selected day in sight. On a
// wider window the grid is as it was.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import 'week_grid_cells.dart';

/// The grid's geometry for the window it is shown in.
enum WeekGridShape {
  /// A wider window: the halves side by side ([WeekGridMetrics]).
  desk(
    headerHeight: WeekGridMetrics.headerHeight,
    rowHeight: WeekGridMetrics.rowHeight,
    minDayWidth: WeekGridMetrics.minDayWidth,
    stacked: false,
  ),

  /// A phone: the halves stacked, each a 48 dp target.
  pocket(
    headerHeight: kMinInteractiveDimension + 2 * WeekGridMetrics.cellInset,
    rowHeight:
        2 * kMinInteractiveDimension +
        WeekGridMetrics.halfSlotGap +
        2 * WeekGridMetrics.cellInset,
    minDayWidth: kMinInteractiveDimension + 2 * WeekGridMetrics.cellInset,
    stacked: true,
  );

  const WeekGridShape({
    required this.headerHeight,
    required this.rowHeight,
    required this.minDayWidth,
    required this.stacked,
  });

  /// The width of a day column in [available] width: seven fitted, or the
  /// minimum and the day area scrolls. In a pocket as many whole columns
  /// as fit, so no column stands cut at the edge.
  double dayWidth(double available) {
    final fitted = available / WeekGridMetrics.daysPerWeek;
    if (fitted >= minDayWidth) return fitted;
    if (!stacked) return minDayWidth;
    final whole = (available / minDayWidth).floor();
    return whole < 1 ? minDayWidth : available / whole;
  }

  /// The shape for the window [context] is shown in.
  static WeekGridShape of(BuildContext context) =>
      WindowClass.of(context) == WindowClass.compact ? pocket : desk;

  final double headerHeight;
  final double rowHeight;
  final double minDayWidth;

  /// The morning half above the afternoon one.
  final bool stacked;
}

/// What a screen reader says for one half of a day cell.
enum WeekHalfState { free, mine, taken, blocked, closed }

/// Where [day] is among [days], 0 when it is not one of them: the column
/// the pocket opens on.
int weekDayIndex(List<DateTime> days, DateTime day) {
  final i = days.indexWhere((d) => DateUtils.isSameDay(d, day));
  return i < 0 ? 0 : i;
}

/// The state of one half: who holds it, or why nobody can.
WeekHalfState weekHalfStateOf({
  required bool mine,
  required bool covered,
  required bool filled,
  required bool open,
}) => switch ((covered, filled)) {
  (true, _) => mine ? WeekHalfState.mine : WeekHalfState.taken,
  (false, false) => WeekHalfState.free,
  (false, true) => open ? WeekHalfState.blocked : WeekHalfState.closed,
};

/// "Seat 4, Mon 11, morning, free".
String weekHalfLabel(
  BuildContext context, {
  required String seat,
  required DateTime day,
  required bool morning,
  required WeekHalfState state,
}) => context.l10n.weekHalfSlotLabel(
  seat,
  _dayText(context, day),
  morning ? 'morning' : 'afternoon',
  state.name,
);

/// "Seat 4, Mon 11": a day cell that opens who has it.
String weekCellLabel(BuildContext context, String seat, DateTime day) =>
    '$seat, ${_dayText(context, day)}';

String _dayText(BuildContext context, DateTime day) =>
    appFormatOf(context).dates(DateShape.weekdayMonthDay).format(day);

/// The pocket's body: the day headers pinned above, the seat names pinned
/// beside, the day area scrolling sideways in step with its headers and
/// opening at [initialOffset].
class WeekGridPinnedBody extends StatefulWidget {
  const WeekGridPinnedBody({
    super.key,
    required this.header,
    required this.headerHeight,
    required this.leading,
    required this.rows,
    required this.gridWidth,
    required this.initialOffset,
  });

  final Widget header;
  final double headerHeight;
  final List<Widget> leading;
  final List<Widget> rows;
  final double gridWidth;
  final double initialOffset;

  @override
  State<WeekGridPinnedBody> createState() => _WeekGridPinnedBodyState();
}

class _WeekGridPinnedBodyState extends State<WeekGridPinnedBody> {
  late final ScrollController _days = ScrollController(
    initialScrollOffset: widget.initialOffset,
  );
  late final ScrollController _headers = ScrollController(
    initialScrollOffset: widget.initialOffset,
  );

  @override
  void initState() {
    super.initState();
    _days.addListener(_follow);
  }

  /// The headers follow the day area, never the other way round.
  void _follow() {
    if (_headers.hasClients && _headers.offset != _days.offset) {
      _headers.jumpTo(_days.offset.clamp(0, _headers.position.maxScrollExtent));
    }
  }

  @override
  void dispose() {
    _days.dispose();
    _headers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const SizedBox(width: WeekGridMetrics.leadingWidth),
          Expanded(
            child: SingleChildScrollView(
              controller: _headers,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: widget.gridWidth,
                height: widget.headerHeight,
                child: widget.header,
              ),
            ),
          ),
        ],
      ),
      Expanded(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: WeekGridMetrics.leadingWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.leading,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _days,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: widget.gridWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.rows,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
