// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2051 — the year's public holidays from the open-data source, every day
// a checkbox, imported only on confirmation.
//
// The source lists the days; the server says which are locked (invoiced
// month) or already there; the owner unticks the days the space stays
// open. The apply sends exactly the ticked days, and the server applies
// its rules to them again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/import_public_holidays.dart';
import '../../domain/holiday_import.dart';
import '../../domain/holiday_regions.dart';
import '../../domain/public_holidays.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/holiday_import_providers.dart';
import '../../providers/workspace_providers.dart';

/// The entry on the Availability screen; absent unless holidayImport is
/// effective. The sheet is handed the decision (ADR 0024).
class HolidayImportTile extends ConsumerWidget {
  const HolidayImportTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.holidayImport);
    if (!on) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey('availability-holiday-import'),
      leading: const Icon(Icons.cloud_download_outlined),
      title: Text(
        l10n?.holidayImportAction ?? 'Import public holidays (open data)',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showHolidayImportSheet(
        context,
        ref.read(publicHolidayImportProvider),
      ),
    );
  }
}

Future<void> showHolidayImportSheet(
  BuildContext context,
  PublicHolidayImport command,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => HolidayImportSheet(command: command),
);

class HolidayImportSheet extends ConsumerStatefulWidget {
  const HolidayImportSheet({super.key, required this.command});

  final PublicHolidayImport command;

  @override
  ConsumerState<HolidayImportSheet> createState() => _HolidayImportSheetState();
}

String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class _HolidayImportSheetState extends ConsumerState<HolidayImportSheet> {
  late int _year = ref.read(clockProvider).now().year;
  List<ImportedHoliday>? _all;
  String? _region;
  HolidayGeneration? _verdict;
  final Set<String> _kept = {};
  bool _busy = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<ImportedHoliday> get _shown => holidaysFor(_all ?? const [], _region);

  Map<String, HolidayDay> get _byDay => {
    for (final d in _verdict?.days ?? const <HolidayDay>[]) _dayKey(d.day): d,
  };

  bool _offerable(ImportedHoliday d) {
    final v = _byDay[_dayKey(d.day)];
    return v != null && !v.locked && !v.present;
  }

  Future<void> _load() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() {
      _busy = true;
      _unavailable = false;
    });
    try {
      final all = await widget.command.fetch(workspace.countryCode, _year);
      if (!mounted) return;
      _all = all;
      if (_region != null && !holidayRegions(all).contains(_region)) {
        _region = null;
      }
    } catch (e, st) {
      // HolidaySourceUnavailable, or anything else the source threw: the
      // owner is told the source is unreachable, never shown an empty
      // year.
      TraceLogger.instance.error(
        'workspace',
        'holiday source unavailable',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _unavailable = true;
          _busy = false;
        });
      }
      return;
    }
    await _preview();
  }

  /// The server's verdict on the days shown; every offerable day starts
  /// ticked.
  Future<void> _preview() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || !mounted) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    await runGuarded(
      context,
      domain: 'workspace',
      message: 'preview holiday import failed',
      errorText:
          l10n?.holidayImportFailed ??
          'The holidays could not be checked or imported. Nothing was changed.',
      action: () async {
        final verdict = await widget.command.preview(workspace.id, _shown);
        if (!mounted) return;
        setState(() {
          _verdict = verdict;
          _kept
            ..clear()
            ..addAll([
              for (final d in _shown)
                if (_offerable(d)) _dayKey(d.day),
            ]);
        });
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _setRegion(String? region) async {
    setState(() => _region = region);
    await _preview();
  }

  Future<void> _apply() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final l10n = AppLocalizations.of(context);
    final kept = [
      for (final d in _shown)
        if (_offerable(d) && _kept.contains(_dayKey(d.day))) d,
    ];
    setState(() => _busy = true);
    HolidayGeneration? result;
    final done = await runGuarded(
      context,
      domain: 'workspace',
      message: 'apply holiday import failed',
      errorText:
          l10n?.holidayImportFailed ??
          'The holidays could not be checked or imported. Nothing was changed.',
      action: () async {
        result = await widget.command.apply(workspace.id, kept);
      },
    );
    if (!mounted) return;
    final created = result?.created;
    if (!done || created == null) {
      setState(() => _busy = false);
      return;
    }
    ref.invalidate(closureDaysProvider);
    AppSnack.success(
      context,
      l10n?.publicHolidaysCreated(created) ?? '$created closure days created',
    );
    Navigator.of(context).pop();
  }

  void _shiftYear(int by) {
    setState(() {
      _year += by;
      _all = null;
      _verdict = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final all = _all;
    final verdict = _verdict;
    final regions = holidayRegions(all ?? const []);
    final count = _shown
        .where((d) => _offerable(d) && _kept.contains(_dayKey(d.day)))
        .length;
    final yearLabel = '$_year';
    final source =
        l10n?.holidayImportSource(holidaySourceName) ??
        'Source: $holidaySourceName';

    return SafeArea(
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    l10n?.publicHolidaysSheetTitle ?? 'Public holidays',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('holiday-import-year-previous'),
                  tooltip: MaterialLocalizations.of(context)
                      .previousMonthTooltip,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _busy ? null : () => _shiftYear(-1),
                ),
                Text(yearLabel, style: theme.textTheme.titleMedium),
                IconButton(
                  key: const ValueKey('holiday-import-year-next'),
                  tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _busy ? null : () => _shiftYear(1),
                ),
              ],
            ),
            if (regions.isNotEmpty)
              DropdownButtonFormField<String?>(
                key: const ValueKey('holiday-import-region'),
                initialValue: _region,
                decoration: InputDecoration(
                  labelText: l10n?.holidayImportRegion ?? 'Region',
                ),
                items: [
                  DropdownMenuItem<String?>(
                    child: Text(
                      l10n?.holidayImportNationwide ??
                          'Nationwide holidays only',
                    ),
                  ),
                  for (final r in regions)
                    DropdownMenuItem<String?>(
                      value: r,
                      child: _regionLabel(r, theme),
                    ),
                ],
                onChanged: _busy ? null : _setRegion,
              ),
            const SizedBox(height: AppSpacing.sm),
            if (verdict != null && verdict.lockedMonths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  l10n?.publicHolidaysLockedMonths(
                        verdict.lockedMonths.join(', '),
                      ) ??
                      'Skipped, already invoiced: '
                          '${verdict.lockedMonths.join(', ')}',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            Flexible(
              child: _unavailable
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.holidayImportUnavailable ??
                              'The holiday source cannot be reached right '
                                  'now. Try again later, or use “Add public '
                                  'holidays”.',
                          key: const ValueKey('holiday-import-unavailable'),
                        ),
                        TextButton(
                          key: const ValueKey('holiday-import-retry'),
                          onPressed: _busy ? null : _load,
                          child: Text(l10n?.holidayImportRetry ?? 'Try again'),
                        ),
                      ],
                    )
                  : verdict == null
                  ? const LoadingView()
                  : _shown.isEmpty
                  ? Text(
                      l10n?.publicHolidaysPreviewNone ??
                          'No public holidays for this year.',
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final d in _shown) _tile(d, l10n, locale),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(source, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('holiday-import-confirm'),
              onPressed: _busy || count == 0 ? null : _apply,
              child: Text(
                count == 0
                    ? (l10n?.publicHolidaysNothingToCreate ??
                          'Nothing to create')
                    : (l10n?.holidayImportConfirm(count) ??
                          'Import $count closure days'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The region's name, its code beside it as secondary text (#2079); a
  /// code without a name is shown alone.
  Widget _regionLabel(String code, ThemeData theme) {
    final name = holidayRegionName(code);
    return Text.rich(
      TextSpan(
        text: name,
        children: [
          if (name != code)
            TextSpan(
              text: '  $code',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _tile(ImportedHoliday d, AppLocalizations? l10n, String locale) {
    final key = _dayKey(d.day);
    final v = _byDay[key];
    final offerable = _offerable(d);
    final details = [
      DateFormat.yMMMMd(locale).format(d.day),
      if (d.name.isNotEmpty && d.name != d.localName) d.name,
      if (d.regions.isNotEmpty)
        sortHolidayRegions(d.regions).map(holidayRegionName).join(', '),
      if (v?.locked ?? false)
        l10n?.publicHolidaysLocked ?? 'Invoiced month — not created'
      else if (v?.present ?? false)
        l10n?.publicHolidaysPresent ?? 'Already a closure day',
    ].join(' · ');
    return CheckboxListTile(
      key: ValueKey('holiday-import-day-$key'),
      dense: true,
      value: offerable && _kept.contains(key),
      onChanged: !offerable || _busy
          ? null
          : (on) =>
                setState(() => on == true ? _kept.add(key) : _kept.remove(key)),
      title: Text(d.localName),
      subtitle: Text(details),
    );
  }
}
