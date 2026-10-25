// SPDX-License-Identifier: AGPL-3.0-or-later
//
// "Export the report" on the Web-BI page: the person picks a file, the
// server answers the report's figures once (checking the right to export
// and every figure's own rights at that moment), the sheet shows that
// frozen snapshot as the printout it becomes, and Save writes exactly it —
// as a PDF, a CSV or a workbook — through the platform's truthful delivery.
// Reading again is an explicit choice that makes a new snapshot with its
// own time and digest. Opening, previewing and closing write nothing; one
// click asks once.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_delivery.dart';
import '../../../../core/files/file_delivery_notice.dart';
import '../../../../core/files/file_names.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/active_settings.dart';
import '../../../../core/settings/setting_defaults.g.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_export.dart';
import '../../domain/bi_report_print.dart';
import '../../domain/bi_report_snapshot.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workbook_export_providers.dart';
import '../../providers/workspace_providers.dart';
import '../bi_print_strings_l10n.dart';
import 'bi_export.dart' show BiSnapshotPrinter, exportBiPdf;
import 'bi_print_preview.dart';

/// The files this reader may export here, in the order offered: none
/// without the right to export data; a PDF while PDF export is on, the
/// data files while data export is on. The server checks the same.
@visibleForTesting
List<BiExportFormat> biExportFormats(
  Set<WorkspaceFeature> features,
  Set<WorkspacePermission> permissions,
) => [
  if (permissions.contains(WorkspacePermission.exportData)) ...[
    if (features.contains(WorkspaceFeature.pdfExport)) BiExportFormat.pdf,
    if (features.contains(WorkspaceFeature.dataExport)) ...[
      BiExportFormat.csv,
      BiExportFormat.xlsx,
    ],
  ],
];

/// What an export is of: the report on screen, its period and source.
class _Target {
  const _Target({
    required this.report,
    required this.period,
    required this.source,
    required this.formats,
  });

  final BiReportDefinition report;
  final BiPeriod period;
  final BiSnapshotSource source;
  final List<BiExportFormat> formats;
}

/// The page's file actions: "Export the report" for a reader who may
/// export, and the dashboard's own PDF.
class BiExportActions extends ConsumerWidget {
  const BiExportActions({
    super.key,
    required this.workspaceId,
    required this.openId,
    required this.query,
    required this.modules,
  });

  final String workspaceId;

  /// The open saved view's id, or null.
  final String? openId;
  final BiQueryContext query;

  /// The modules the page shows, in its order.
  final List<BiModule> modules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formats = biExportFormats(
      ref.watch(enabledFeaturesSyncProvider),
      ref.watch(myPermissionsProvider),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (formats.isNotEmpty)
          IconButton(
            key: const ValueKey('bi-export-report'),
            tooltip: l10n.biExportAction,
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => showAppSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => _BiExportSheet(target: _target(ref, l10n, formats)),
            ),
          ),
        IconButton(
          key: const ValueKey('bi-export-pdf'),
          tooltip: l10n.biExportPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () => exportBiPdf(
            context,
            ref,
            workspaceId: workspaceId,
            workspaceName: ref.read(currentWorkspaceProvider).value?.name ?? 'DesKilo',
            modules: modules,
            query: query,
          ),
        ),
      ],
    );
  }

  /// The open saved report (or question) by its id and revision, else the
  /// analysis on screen as one unsaved page of its cards, for the period
  /// the page shows on the workspace's clock.
  _Target _target(WidgetRef ref, AppLocalizations l10n, List<BiExportFormat> formats) {
    final views = ref.read(biViewsProvider(workspaceId)).value ?? const [];
    final open = views.where((v) => v.id == openId).firstOrNull;
    final calendar = ref.read(workspaceContextProvider).value?.calendar;
    final now = ref.read(clockProvider).now();
    final today = calendar?.dateOf(now) ?? DateTime.utc(now.year, now.month, now.day);
    return _Target(
      report: open?.definition?.report ??
          BiReportDefinition.standard(
            query: query,
            cards: [for (final m in modules) m.id],
            pageTitle: l10n.biReportPageTitle,
          ),
      period: query.current(today),
      source: BiSnapshotSource(
        workspaceId: workspaceId,
        workspaceName: ref.read(currentWorkspaceProvider).value?.name ?? '',
        reportName: open?.name ?? l10n.biViewStandard,
        reportId: open?.id,
        reportRevision: open?.revision,
      ),
      formats: formats,
    );
  }
}

class _BiExportSheet extends ConsumerStatefulWidget {
  const _BiExportSheet({required this.target});

  final _Target target;

  @override
  ConsumerState<_BiExportSheet> createState() => _BiExportSheetState();
}

class _BiExportSheetState extends ConsumerState<_BiExportSheet> {
  late BiExportFormat _format = widget.target.formats.first;
  BiReportSnapshot? _snapshot;
  BiExportFailure? _failure;
  var _busy = false;
  var _reads = 0;

  /// The bytes last delivered, kept so "download again" re-delivers the
  /// same file instead of asking the server a second time.
  Uint8List? _bytes;

  int get _limit {
    final settings = ref.read(activeSettingsProvider);
    const key = 'bi.batch_max_requests';
    return settings != null && settings.definitions.containsKey(key)
        ? settings.read<int>(key)
        : SettingDefaults.biBatchMaxRequests;
  }

  /// Asks the server for the figures once; a second click while it is
  /// asking does nothing.
  Future<void> _take() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
      _bytes = null;
    });
    BiReportSnapshot? snapshot;
    BiExportFailure? failure;
    try {
      final target = widget.target;
      final plan = biSnapshotPlan(
        target.report,
        period: target.period,
        seriesLength: biSeriesLength(target.period.grain),
        window: biInterval,
        limit: _limit,
      );
      snapshot = await ref
          .read(biSnapshotExportProvider)
          .take(plan, source: target.source, format: _format);
    } on BiExportRefused catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'export refused: ${e.failure.name}',
        stackTrace: st,
      );
      failure = e.failure;
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'export not answered (${e.runtimeType})',
        stackTrace: st,
      );
      failure = BiExportFailure.unavailable;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
      // A refused read drops the figures shown before it (a right revoked
      // since is not answered by an older copy).
      _snapshot = snapshot;
      if (snapshot != null) _reads++;
    });
  }

  Future<void> _save() async {
    final snapshot = _snapshot;
    if (_busy || snapshot == null) return;
    setState(() => _busy = true);
    BiExportFailure? failure;
    try {
      _bytes ??= switch (snapshot.format) {
        BiExportFormat.pdf => await BiSnapshotPrinter(context, ref).pdf(snapshot),
        BiExportFormat.csv => biExportCsv(snapshot, _title),
        BiExportFormat.xlsx => biExportWorkbook(snapshot, _title),
      };
      if (mounted) await _deliver(snapshot, _bytes!);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'export file not made (${e.runtimeType})',
        stackTrace: st,
      );
      failure = BiExportFailure.invalid;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failure ?? _failure;
        });
      }
    }
  }

  Future<void> _deliver(BiReportSnapshot snapshot, Uint8List bytes) async {
    final name = biExportFileName(
      snapshot,
      safeFileSlug(snapshot.source.workspaceName),
    );
    final delivery = await deliverFile(
      context,
      ref,
      bytes: bytes,
      fileName: name,
    );
    if (!mounted) return;
    announceFileDelivery(
      context,
      delivery,
      retry: () => _deliver(snapshot, bytes),
    );
  }

  String _title(String metricId) => biMetricTitle(context.l10n, metricId);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = _snapshot;
    return SheetShell(
      title: l10n.biExportTitle,
      children: [
        SegmentedButton<BiExportFormat>(
          key: const ValueKey('bi-export-format'),
          segments: [
            for (final f in widget.target.formats)
              ButtonSegment(
                value: f,
                label: Text(
                  _formatName(l10n, f),
                  key: ValueKey('bi-export-format-${f.name}'),
                ),
              ),
          ],
          selected: {_format},
          onSelectionChanged: _busy
              ? null
              : (s) => setState(() {
                  // Another file is another export: its own snapshot.
                  _format = s.single;
                  _snapshot = null;
                  _bytes = null;
                  _failure = null;
                }),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_busy) ...[
          const LinearProgressIndicator(),
          Text(l10n.biExportTaking),
        ],
        if (_failure != null)
          Text(
            _failureText(l10n, _failure!),
            key: const ValueKey('bi-export-failure'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (snapshot == null)
          FilledButton.icon(
            key: const ValueKey('bi-export-take'),
            icon: const Icon(Icons.preview_outlined),
            label: Text(l10n.biExportPreview),
            onPressed: _busy ? null : _take,
          )
        else
          ..._preview(context, snapshot),
      ],
    );
  }

  List<Widget> _preview(BuildContext context, BiReportSnapshot snapshot) {
    final l10n = context.l10n;
    final strings = biPrintStringsFor(context, ref);
    final at = strings.formats.dateTime(snapshot.computedAt);
    return [
      Text(
        _reads > 1 ? l10n.biExportRefreshedAt(at) : l10n.biExportComputedAt(at),
        key: const ValueKey('bi-export-computed'),
      ),
      Text(
        l10n.biExportDigest(snapshot.hash),
        key: const ValueKey('bi-export-digest'),
      ),
      if (snapshot.plan.leftOut.isNotEmpty)
        Text(l10n.biExportLeftOut('${snapshot.plan.leftOut.length}')),
      Text(
        l10n.biExportRecallNote,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        children: [
          FilledButton.icon(
            key: const ValueKey('bi-export-save'),
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.biExportSave),
            onPressed: _busy ? null : _save,
          ),
          OutlinedButton.icon(
            key: const ValueKey('bi-export-refresh'),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.biExportRefresh),
            onPressed: _busy ? null : _take,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      BiPrintPreview(document: biPrintDocument(snapshot, strings)),
    ];
  }
}

String _formatName(AppLocalizations l10n, BiExportFormat f) => switch (f) {
  BiExportFormat.pdf => l10n.biExportFormatPdf,
  BiExportFormat.csv => l10n.biExportFormatCsv,
  BiExportFormat.xlsx => l10n.biExportFormatXlsx,
};

String _failureText(AppLocalizations l10n, BiExportFailure f) => switch (f) {
  BiExportFailure.forbidden => l10n.biExportFailedForbidden,
  BiExportFailure.off => l10n.biExportFailedOff,
  BiExportFailure.tooLarge => l10n.biExportFailedTooLarge,
  BiExportFailure.stale => l10n.biExportFailedStale,
  BiExportFailure.empty => l10n.biExportFailedEmpty,
  BiExportFailure.invalid => l10n.biExportFailedInvalid,
  BiExportFailure.unavailable => l10n.biExportFailedUnavailable,
};
