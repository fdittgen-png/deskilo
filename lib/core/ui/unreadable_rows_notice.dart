// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../data/unreadable_rows.dart';
import '../l10n/context_l10n.dart';
import 'inline_banner.dart';

/// #3884 -- the one line under a list that says rows were left out because
/// this version of the app cannot read them. Nothing when none were.
class UnreadableRowsNotice extends StatelessWidget {
  const UnreadableRowsNotice({super.key, required this.area});

  /// The list's area, as its reader recorded it in `UnreadableRows`.
  final String area;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: UnreadableRows.instance.watch(area),
        builder: (context, count, _) => count == 0
            ? const SizedBox.shrink()
            : InlineBanner(
                key: const ValueKey('unreadable-rows-notice'),
                icon: Icons.visibility_off_outlined,
                severity: InlineBannerSeverity.info,
                text: context.l10n.unreadableRowsNotice(count),
              ),
      );
}
