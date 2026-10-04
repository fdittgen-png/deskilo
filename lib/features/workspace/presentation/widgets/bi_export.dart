// SPDX-License-Identifier: AGPL-3.0-or-later
//
// "Export as PDF" on the Business analytics page: gathers, for the
// analyses the page is showing, the same content the dashboards render,
// and lays it out as a report. A section whose analysis cannot be read is
// left out of the report and said — never printed with a made-up figure.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/files/file_saver.dart';
import '../../../../core/files/file_names.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_report_pdf.dart';
import '../../domain/bi_result.dart';
import '../../providers/bi_providers.dart';
import 'bi_dashboard_content.dart';
import 'bi_module_section.dart' show biModuleViews;
import 'bi_toolbar.dart' show biPeriodLabel;

/// Builds and saves the report of [modules] for [query].
Future<void> exportBiPdf(
  BuildContext context,
  WidgetRef ref, {
  required String workspaceId,
  required String workspaceName,
  required List<BiModule> modules,
  required BiQueryContext query,
}) async {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final now = ref.read(clockProvider).now();
  final today = WorkspaceTime.dateOf(now);
  try {
    final sections = <BiDashboardContent>[];
    var left = 0;
    for (final m in modules) {
      final view = biModuleViews[m.id];
      if (view == null || m.unsupported(query).isNotEmpty) {
        left++;
        continue;
      }
      try {
        // The same reads the page makes (and shares), period by period.
        final period = BiQueryContext(grain: query.grain, period: query.period);
        final result = await ref.read(
          biModuleResultProvider(workspaceId, m.id, period).future,
        );
        final grain = result.period.grain;
        final series = await ref.read(
          biModuleSeriesProvider(
            workspaceId,
            m.id,
            grain,
            result.period,
            biSeriesLength(grain),
          ).future,
        );
        BiResult? grouped;
        if (m.groupings.contains('level')) {
          grouped = await ref
              .read(
                biModuleResultProvider(
                  workspaceId,
                  m.id,
                  BiQueryContext(
                    grain: grain,
                    period: BiPeriodRef.fixed(result.period),
                    groupBy: 'level',
                    sort: BiSort.valueDescending,
                  ),
                ).future,
              )
              .then<BiResult?>((r) => r, onError: (Object _) => null);
        }
        BiResult? invoiced;
        if (m.id == 'finance.collected') {
          invoiced = await ref
              .read(
                biModuleResultProvider(
                  workspaceId,
                  'finance.invoiced',
                  BiQueryContext(
                    grain: grain,
                    period: BiPeriodRef.fixed(result.period),
                  ),
                ).future,
              )
              .then<BiResult?>((r) => r, onError: (Object _) => null);
        }
        final interval = biInterval(result.period);
        sections.add(
          biDashboardContent(
            module: m,
            view: view,
            result: result,
            series: series,
            extras: BiDashboardExtras(groupedByLevel: grouped, invoiced: invoiced),
            l10n: l10n,
            locale: locale,
            from: interval.from,
            to: interval.to,
            now: now,
          ),
        );
      } on Object catch (e, st) {
        TraceLogger.instance.warn('bi', 'report section left out (${e.runtimeType})', stackTrace: st);
        left++;
      }
    }
    if (sections.isEmpty) throw StateError('nothing to report');
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final period = query.current(today);
    final bytes = await buildBiReportPdf(
      title: l10n?.biPdfTitle ?? 'Business analytics',
      workspaceName: workspaceName,
      subtitle: biPeriodLabel(period, l10n, locale),
      producedOn:
          l10n?.biPdfProduced(DateFormat.yMMMMd(locale).format(now)) ??
          'Produced on ${DateFormat.yMMMMd(locale).format(now)}',
      estimateNote:
          l10n?.biPdfEstimateNote ??
          'Dashed lines and shaded bands are estimates from past periods, not measurements.',
      sections: sections,
      baseFont: pw.Font.ttf(regular),
      boldFont: pw.Font.ttf(bold),
    );
    final path = await ref.read(fileSaverProvider)(
      bytes: bytes,
      fileName: '${safeFileSlug(workspaceName)}-analytics-${period.wire}.pdf',
    );
    if (!context.mounted) return;
    if (path == null) {
      AppSnack.error(context, l10n?.commonSaveFailed ?? 'Could not save.');
      return;
    }
    AppSnack.success(context, l10n?.commonSavedTo(path) ?? 'Saved to $path');
    if (left > 0 && context.mounted) {
      AppSnack.error(
        context,
        l10n?.biCardsUnavailable('$left') ??
            '$left analyses could not be included.',
      );
    }
  } on Object catch (e, st) {
    TraceLogger.instance.warn('bi', 'report not made (${e.runtimeType})', stackTrace: st);
    if (context.mounted) {
      AppSnack.error(
        context,
        l10n?.biPdfFailed ?? 'The PDF could not be made.',
      );
    }
  }
}
