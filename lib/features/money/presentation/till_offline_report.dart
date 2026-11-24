// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- what the server answered when the offline sales were sent: how many it took, each one it refused with its reason
// (its cash stays in the drawer count), the numbers it finds missing, and, when it refused the whole send because the session was
// closed (DKL12), that the sales stay on the device for a manager.
import 'package:flutter/material.dart';

import '../../../core/codes/dk_code.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/refusal_text.dart';
import 'till_offline_mode.dart';
import 'till_text.dart';

/// Says the answer of a send; completes when it has been read.
Future<void> showOfflineReport(BuildContext context, OfflineReport report) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    key: const ValueKey('till-offline-report'),
    scrollable: true,
    title: Text(c.l10n.tillOfflineReportTitle),
    content: _OfflineReportBody(report: report),
    actions: [
      TextButton(key: const ValueKey('till-offline-report-ok'), onPressed: () => Navigator.of(c).pop(), child: Text(MaterialLocalizations.of(c).okButtonLabel)),
    ],
  ),
);

/// The words of the answer, one line each.
class _OfflineReportBody extends StatelessWidget {
  const _OfflineReportBody({required this.report});

  final OfflineReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = report.failure;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (report.accepted > 0) Text(l10n.tillOfflineReportAccepted(report.accepted), key: const ValueKey('till-offline-accepted')),
        for (final r in report.refused) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.tillOfflineReportRefused(r.seq, tillOfflineReasonText(l10n, r.reason)), key: ValueKey('till-offline-refused-${r.seq}')),
        ],
        if (report.gaps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.tillOfflineGaps(report.gaps.join(', ')), key: const ValueKey('till-offline-gaps')),
        ],
        if (failure != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            refusalCodeOf(failure).code == DkCode.dkl12 ? l10n.tillOfflineClosedSession : tillProblemText(l10n, failure),
            key: const ValueKey('till-offline-failure'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (report.kept > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.tillOfflineKept(report.kept), key: const ValueKey('till-offline-kept')),
        ],
      ],
    );
  }
}
