// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 — the error reports the apps sent to this installation, for its
// operator (the server refuses anyone else, 0953): newest first, each with its
// kind, code, app version, platform and time, and its stack as the app
// redacted it. Read only; a business member never reaches it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/help_row.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../workspace/domain/instance_trace_report.dart';
import '../../../workspace/providers/instance_providers.dart';

/// The console's row that opens the reports.
class InstanceErrorReportsTile extends StatelessWidget {
  const InstanceErrorReportsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HelpRow(
      key: const ValueKey('instance-error-reports'),
      leading: const Icon(Icons.bug_report_outlined),
      title: l10n.instanceErrorReports,
      subtitle: Text(l10n.instanceErrorReportsHint),
      topic: l10n.instanceErrorReports,
      anchor: HelpAnchor.advancedErrorReports,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showAppSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _ErrorReportsSheet(),
      ),
    );
  }
}

class _ErrorReportsSheet extends ConsumerStatefulWidget {
  const _ErrorReportsSheet();

  @override
  ConsumerState<_ErrorReportsSheet> createState() => _ErrorReportsSheetState();
}

class _ErrorReportsSheetState extends ConsumerState<_ErrorReportsSheet> {
  /// The pages read so far, each by the instant its reports are older than.
  final _pages = <DateTime?>[null];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final children = <Widget>[
      Text(
        l10n.instanceErrorReports,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
    List<InstanceTraceReport>? last;
    for (final before in _pages) {
      final provider = instanceTraceReportsProvider(before);
      switch (ref.watch(provider)) {
        case AsyncData(:final value):
          children.addAll([for (final r in value) _ReportTile(report: r)]);
          last = value;
        case AsyncError(:final error):
          children.add(
            ReadFailureBanner(
              error: error,
              onRetry: () => ref.invalidate(provider),
            ),
          );
          last = null;
        default:
          children.add(const LoadingView());
          last = null;
      }
    }
    if (_pages.length == 1 && last != null && last.isEmpty) {
      children.add(
        Text(
          l10n.instanceErrorReportsNone,
          key: const ValueKey('instance-error-reports-none'),
        ),
      );
    }
    if (last != null && last.length == traceReportsPageSize) {
      final oldest = last.last.reportedAt;
      children.add(
        TextButton(
          key: const ValueKey('instance-error-reports-older'),
          onPressed: () => setState(() => _pages.add(oldest)),
          child: Text(l10n.instanceErrorReportsOlder),
        ),
      );
    }
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: AppSpacing.lgAll,
        children: children,
      ),
    );
  }
}

/// One report: what kind, which app, when; opened, its redacted stack.
class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final InstanceTraceReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = report;
    final facts = l10n.instanceErrorReportFacts(
      r.appVersion,
      r.platform,
      appFormatOf(context).dateTime(r.reportedAt.toLocal()),
    );
    return ExpansionTile(
      key: ValueKey('instance-error-report-${r.id}'),
      tilePadding: EdgeInsets.zero,
      title: Text(r.failureType),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(facts),
          if (r.failureCode case final code?)
            Text(l10n.instanceErrorReportCode(code)),
        ],
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.instanceErrorReportStack,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          r.stack,
          key: ValueKey('instance-error-report-stack-${r.id}'),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
