// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../i18n/format_controller.dart';
import '../i18n/week_start.dart';

/// #3648 — the header of a month grid: seven equal columns, the locale's
/// NARROW weekday names (never the first letter of a short name), first
/// column = the reader's first day of the week. Two days that share a letter
/// stay apart for a screen reader, which hears the full name.
class WeekdayHeaderRow extends StatelessWidget {
  const WeekdayHeaderRow({super.key, this.style});

  /// The letters' style; the small label style when null.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final headers = weekdayHeaders(appFormatOf(context));
    return Row(
      children: [
        for (final header in headers)
          Expanded(
            child: Center(
              child: Text(
                header.narrow,
                semanticsLabel: header.full,
                style: style ?? Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
      ],
    );
  }
}
