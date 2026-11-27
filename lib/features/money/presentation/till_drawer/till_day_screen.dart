// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 (CS5) -- the day close: someone who may see the finances closes the business day once every till is closed, and
// reads the report: the sessions with their differences and reasons, the takings by tender and by tax rate, the cash paid in
// and out, the refunds and the range of receipt numbers. The report is the server's immutable record; this screen only says
// it. It is the business record, not a country's legal day close.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/till_day.dart';
import '../../providers/business_day_provider.dart';
import '../../providers/till_drawer_providers.dart';
import 'day_report_view.dart';
import 'drawer_text.dart';

/// The day-close screen over [workspaceId], in [currency].
class TillDayScreen extends ConsumerStatefulWidget {
  const TillDayScreen({super.key, required this.workspaceId, required this.currency});

  final String? workspaceId;
  final String currency;

  @override
  ConsumerState<TillDayScreen> createState() => _TillDayScreenState();
}

class _TillDayScreenState extends ConsumerState<TillDayScreen> {
  /// One request id for the day being closed: a retry after a lost answer is answered, not made twice.
  final String _requestId = newRequestId();
  bool _closing = false;
  Object? _problem;

  Future<void> _close(String workspaceId, String day) async {
    setState(() {
      _closing = true;
      _problem = null;
    });
    try {
      final report = await ref.read(tillDrawerPortProvider).closeDay(workspaceId, requestId: _requestId, businessDate: day);
      ref.invalidate(dayClosesProvider(workspaceId));
      if (!mounted) return;
      setState(() => _closing = false);
      await showDayReport(context, report, currency: widget.currency);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the till drawer refused', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _closing = false;
        _problem = e;
      });
    }
  }

  Future<void> _read(String workspaceId, DayCloseRow row) async {
    try {
      final report = await ref.read(tillDrawerPortProvider).dayReport(workspaceId, dayCloseId: row.id);
      if (!mounted) return;
      await showDayReport(context, report, currency: widget.currency);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the till drawer refused', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _problem = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspaceId = widget.workspaceId;
    final format = appFormatOf(context);
    final today = ref.watch(businessDayProvider);
    final day = isoDay(today);
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.tillDayTitle),
        actions: [HelpDot(l10n.tillDayTitle, anchor: HelpAnchor.moneyTillDrawer)],
      ),
      body: workspaceId == null
          ? const LoadingView()
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(l10n.tillDayToday(format.isoDay(day)), style: Theme.of(context).textTheme.titleMedium),
                    const FormGap.small(),
                    Text(l10n.tillDayHelp),
                    const FormGap(),
                    if (_problem != null) ...[
                      Text(drawerProblemText(l10n, _problem!), key: const ValueKey('day-problem'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const FormGap(),
                    ],
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton(
                        key: const ValueKey('day-close'),
                        onPressed: _closing ? null : () => _close(workspaceId, day),
                        child: Text(l10n.tillDayOpen),
                      ),
                    ),
                    const FormGap.large(),
                    Text(l10n.tillDayPast, style: Theme.of(context).textTheme.titleSmall),
                    const FormGap.small(),
                    _Closes(workspaceId: workspaceId, onRead: (r) => _read(workspaceId, r)),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Closes extends ConsumerWidget {
  const _Closes({required this.workspaceId, required this.onRead});

  final String workspaceId;
  final void Function(DayCloseRow) onRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    return AsyncReadBody.part(
          value: ref.watch(dayClosesProvider(workspaceId)),
          isEmpty: (rows) => rows.isEmpty,
          refusal: (e) => drawerRefusalWords(l10n, e),
          retryKey: const ValueKey('day-closes-retry'),
          onRetry: () => ref.invalidate(dayClosesProvider(workspaceId)),
          data: (rows) => rows.isEmpty
              ? Text(l10n.tillDayNone, key: const ValueKey('day-none'))
              : Column(
                  children: [
                    for (final r in rows)
                      ListTile(
                        key: ValueKey('day-row-${r.id}'),
                        title: Text(l10n.tillDayItem(r.number, format.isoDay(r.businessDate))),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => onRead(r),
                      ),
                  ],
                ),
        );
  }
}
