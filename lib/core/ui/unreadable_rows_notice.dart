// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../data/unreadable_rows.dart';
import '../l10n/context_l10n.dart';
import 'inline_banner.dart';

/// #3884 -- the one line under a list that says rows were left out because
/// this version of the app cannot read them. Nothing when none were.
class UnreadableRowsNotice extends StatelessWidget {
  const UnreadableRowsNotice({super.key, required this.areas});

  /// One list's area, as its reader recorded it in `UnreadableRows`.
  UnreadableRowsNotice.area(String area, {Key? key})
      : this(key: key, areas: [area]);

  /// The areas whose left-out rows this line counts together.
  final List<String> areas;

  @override
  Widget build(BuildContext context) {
    final listenables = [
      for (final a in areas) UnreadableRows.instance.watch(a),
    ];
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final count = unreadableRowsIn(areas);
        return count == 0
            ? const SizedBox.shrink()
            : InlineBanner(
                key: const ValueKey('unreadable-rows-notice'),
                icon: Icons.visibility_off_outlined,
                severity: InlineBannerSeverity.info,
                text: context.l10n.unreadableRowsNotice(count),
              );
      },
    );
  }
}

/// How many rows the latest reads of [areas] left out, together.
int unreadableRowsIn(List<String> areas) =>
    areas.fold(0, (sum, a) => sum + UnreadableRows.instance.count(a));
