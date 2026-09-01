// SPDX-License-Identifier: 0BSD
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_info.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/time/clock.dart';
import '../../../reservations/domain/reservation_export.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// Which trace levels the list shows.
enum _TraceFilter { all, errors, warnings }

extension on _TraceFilter {
  bool matches(TraceEntry e) => switch (this) {
        _TraceFilter.all => true,
        _TraceFilter.errors => e.level == TraceLevel.error,
        _TraceFilter.warnings => e.level == TraceLevel.warn ||
            e.level == TraceLevel.error,
      };
}

/// Developer mode's trace viewer (#144): the always-on error trace,
/// newest first, with export-to-file sharing and clear. Local diagnostics
/// only — reachable by every user who flips the settings toggle.
class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  _TraceFilter _filter = _TraceFilter.all;

  /// The reservation dump reads the whole table, which on a busy
  /// workspace is not instant. Without this the tile looks inert and
  /// gets tapped again.
  bool _exporting = false;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final logger = ref.read(traceLoggerProvider);
    final save = ref.read(fileSaverProvider);
    try {
      // #791 — stamp the export with WHOSE app it is. A trace almost
      // never gets read on the device that wrote it: the member who could
      // not check in exports theirs and sends the file on, and an
      // unlabelled wall of timestamps cannot be matched to the report,
      // the workspace, or the build it came from.
      final content = await logger.exportContent(header: [
        'DesKilo trace',
        'app: ${ref.read(appVersionProvider).value ?? 'unknown'}',
        'workspace: ${ref.read(currentWorkspaceProvider).value?.id ?? '-'}',
        'member: ${ref.read(myMemberProvider).value?.id ?? '-'}',
        'exported: ${ref.read(clockProvider).now().toIso8601String()}',
      ]);
      final stamp = DateFormat('yyyyMMdd-HHmm').format(ref.read(clockProvider).now());
      final path = await save(
        bytes: utf8.encode(content),
        fileName: 'deskilo-trace-$stamp.log',
      );
      if (!mounted) return;
      if (path == null) {
        AppSnack.error(context, l10n?.commonSaveFailed ?? 'Could not save.');
      } else {
        AppSnack.success(
          context,
          l10n?.commonSavedTo(path) ?? 'Saved to $path',
        );
      }
    } catch (e, st) {
      logger.error('developer', 'trace export failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    }
  }

  /// #677 — every reservation the workspace holds, past, present and
  /// future, as raw CSV.
  ///
  /// Deliberately separate from the trace export beside it: a trace says
  /// what the APP did, and most booking bugs are about what the DATA
  /// says. Having only the first is why "it says the seat is taken and
  /// it is not" has been unanswerable from a bug report alone.
  Future<void> _exportReservations() async {
    final l10n = AppLocalizations.of(context);
    final logger = ref.read(traceLoggerProvider);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _exporting = true);
    try {
      final content = buildReservationExportCsv(
        reservations: await ref
            .read(reservationRepositoryProvider)
            .fetchAllForExport(workspace.id),
        generatedAt: ref.read(clockProvider).now(),
        workspaceId: workspace.id,
      );
      final stamp =
          DateFormat('yyyyMMdd-HHmm').format(ref.read(clockProvider).now());
      final path = await ref.read(fileSaverProvider)(
        bytes: utf8.encode(content),
        fileName: 'deskilo-reservations-$stamp.csv',
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      if (path == null) {
        AppSnack.error(context, l10n?.commonSaveFailed ?? 'Could not save.');
      } else {
        AppSnack.success(
          context,
          l10n?.commonSavedTo(path) ?? 'Saved to $path',
        );
      }
    } catch (e, st) {
      logger.error('developer', 'reservation export failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _exporting = false);
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final logger = ref.watch(traceLoggerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.developerTitle ?? 'Developer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n?.developerExport ?? 'Export trace',
            onPressed: _export,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n?.developerClear ?? 'Clear trace',
            onPressed: () => ref.read(traceLoggerProvider).clear(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: const ValueKey('developer-export-reservations'),
            leading: _exporting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_view_outlined),
            title: Text(
              l10n?.developerExportReservations ?? 'Export reservations',
            ),
            subtitle: Text(
              l10n?.developerExportReservationsHint ??
                  'Every booking and check-in — past, present and future, '
                      'every state — as CSV, for analysis and debugging.',
            ),
            onTap: _exporting ? null : _exportReservations,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n?.developerFilterAll ?? 'All'),
                  selected: _filter == _TraceFilter.all,
                  onSelected: (_) =>
                      setState(() => _filter = _TraceFilter.all),
                ),
                ChoiceChip(
                  label: Text(l10n?.developerFilterErrors ?? 'Errors'),
                  selected: _filter == _TraceFilter.errors,
                  onSelected: (_) =>
                      setState(() => _filter = _TraceFilter.errors),
                ),
                ChoiceChip(
                  label: Text(l10n?.developerFilterWarnings ?? 'Warnings+'),
                  selected: _filter == _TraceFilter.warnings,
                  onSelected: (_) =>
                      setState(() => _filter = _TraceFilter.warnings),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<void>(
              stream: logger.changes,
              builder: (context, _) {
                final visible = logger.entries
                    .where(_filter.matches)
                    .toList(growable: false);
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      l10n?.developerEmpty ?? 'No trace entries yet.',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) => _TraceTile(entry: visible[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceTile extends StatelessWidget {
  const _TraceTile({required this.entry});

  final TraceEntry entry;

  static const _levelIcons = {
    TraceLevel.debug: Icons.bug_report_outlined,
    TraceLevel.info: Icons.info_outline,
    TraceLevel.warn: Icons.warning_amber_outlined,
    TraceLevel.error: Icons.error_outline,
  };

  Color _levelColor(ColorScheme scheme) => switch (entry.level) {
        TraceLevel.error => scheme.error,
        TraceLevel.warn => scheme.tertiary,
        TraceLevel.info => scheme.primary,
        TraceLevel.debug => scheme.outline,
      };

  /// First stack lines for the list UI — the exported file always carries
  /// the full stack (#144).
  String? get _stackPreview {
    final stack = entry.stack;
    if (stack == null) return null;
    final lines = stack.trimRight().split('\n');
    final head = lines.take(3).join('\n');
    return lines.length > 3 ? '$head\n…' : head;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _levelColor(theme.colorScheme);
    final mono = theme.textTheme.bodySmall
        ?.copyWith(fontFamily: 'monospace', fontFamilyFallback: ['Courier']);
    final leading = Icon(_levelIcons[entry.level], color: color);
    final title = Text(entry.message);
    final subtitle = Row(
      children: [
        Chip(
          label: Text(entry.area),
          labelStyle: theme.textTheme.labelSmall,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            DateFormat('yyyy-MM-dd HH:mm:ss')
                .format(entry.ts.toLocal()),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );

    if (entry.error == null && entry.stack == null) {
      return ListTile(leading: leading, title: title, subtitle: subtitle);
    }
    return ExpansionTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.error != null) SelectableText(entry.error!, style: mono),
        if (_stackPreview != null) ...[
          const SizedBox(height: 8),
          SelectableText(_stackPreview!, style: mono),
        ],
      ],
    );
  }
}
