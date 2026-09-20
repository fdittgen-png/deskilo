// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1274 — the year's public holidays, previewed before anything is written.
//
// Generation is never automatic and never silent: an owner picks a year,
// sees exactly which dates would become closure days, and confirms. The
// server decides the dates and the refusals; this sheet only renders the
// answer and sends it back with `apply: true`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/generate_public_holidays.dart';
import '../../domain/public_holidays.dart';
import '../../providers/workspace_providers.dart';

/// The localized name of a holiday the SERVER named. The key travels
/// between the two sides; the word never does.
String holidayName(AppLocalizations? l10n, String key) => switch (key) {
      'newYear' => l10n?.holidayNewYear ?? 'New Year',
      'easterMonday' => l10n?.holidayEasterMonday ?? 'Easter Monday',
      'labourDay' => l10n?.holidayLabourDay ?? 'Labour Day',
      'victory1945' => l10n?.holidayVictory1945 ?? 'Victory 1945',
      'ascension' => l10n?.holidayAscension ?? 'Ascension',
      'whitMonday' => l10n?.holidayWhitMonday ?? 'Whit Monday',
      'nationalDay' => l10n?.holidayNationalDay ?? 'National day',
      'assumption' => l10n?.holidayAssumption ?? 'Assumption',
      'allSaints' => l10n?.holidayAllSaints ?? 'All Saints',
      'armistice' => l10n?.holidayArmistice ?? 'Armistice 1918',
      'christmas' => l10n?.holidayChristmas ?? 'Christmas',
      'goodFriday' => l10n?.holidayGoodFriday ?? 'Good Friday',
      'germanUnity' => l10n?.holidayGermanUnity ?? 'German Unity Day',
      'boxingDay' => l10n?.holidayBoxingDay ?? 'Boxing Day',
      // A key this build does not know is shown as itself rather than
      // hidden: a newer server may name a day this client has no word for.
      _ => key,
    };

Future<void> showPublicHolidaysSheet(
  BuildContext context,
  PublicHolidayGeneration command,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PublicHolidaysSheet(command: command),
    );

class PublicHolidaysSheet extends ConsumerStatefulWidget {
  const PublicHolidaysSheet({super.key, required this.command});

  /// The decision, handed in. This widget renders an answer and asks for
  /// a confirmation; it does not know what a repository is (#1234).
  final PublicHolidayGeneration command;

  @override
  ConsumerState<PublicHolidaysSheet> createState() =>
      _PublicHolidaysSheetState();
}

class _PublicHolidaysSheetState extends ConsumerState<PublicHolidaysSheet> {
  late int _year = ref.read(clockProvider).now().year;
  HolidayGeneration? _preview;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _busy = true);
    try {
      final preview = await widget.command.preview(
        workspaceId: workspace.id,
        country: workspace.countryCode,
        year: _year,
      );
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e, st) {
      debugPrint('preview public holidays failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'preview public holidays failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _preview = HolidayGeneration.empty);
      AppSnack.error(
        context,
        AppLocalizations.of(context)?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final result = await widget.command.apply(
        workspaceId: workspace.id,
        country: workspace.countryCode,
        year: _year,
      );
      ref.invalidate(closureDaysProvider);
      if (!mounted) return;
      AppSnack.success(
        context,
        l10n?.publicHolidaysCreated(result.created) ??
            '${result.created} closure days created',
      );
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('apply public holidays failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'apply public holidays failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    }
  }

  void _shiftYear(int by) {
    setState(() {
      _year += by;
      _preview = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final preview = _preview;
    final creatable = preview?.creatable.length ?? 0;
    // Hoisted out of the widget: the no-hard-coded-strings lint matches
    // the Text constructor followed by a quote — including inside a
    // comment, which is how this one first failed — and a year is a
    // number rather than a phrase to translate.
    final yearLabel = '$_year';

    return SafeArea(
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(
                child: Text(
                  l10n?.publicHolidaysSheetTitle ?? 'Public holidays',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Spacer(),
              IconButton(
                key: const ValueKey('holidays-year-previous'),
                tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
                icon: const Icon(Icons.chevron_left),
                onPressed: _busy ? null : () => _shiftYear(-1),
              ),
              Text(yearLabel, style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                key: const ValueKey('holidays-year-next'),
                tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
                icon: const Icon(Icons.chevron_right),
                onPressed: _busy ? null : () => _shiftYear(1),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            if (preview != null && preview.lockedMonths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  l10n?.publicHolidaysLockedMonths(
                        preview.lockedMonths.join(', '),
                      ) ??
                      'Skipped, already invoiced: '
                          '${preview.lockedMonths.join(', ')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Flexible(
              child: switch (preview) {
                null => const Center(child: CircularProgressIndicator()),
                final p when p.days.isEmpty => Text(
                    l10n?.publicHolidaysPreviewNone ??
                        'No public holidays for this year.',
                  ),
                final p => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final d in p.days)
                        ListTile(
                          key: ValueKey('holidays-day-${d.key}'),
                          dense: true,
                          leading: Icon(d.locked
                              ? Icons.lock_outline
                              : d.present
                                  ? Icons.check
                                  : Icons.event_busy_outlined),
                          title: Text(holidayName(l10n, d.key)),
                          subtitle: Text(DateFormat.yMMMMd(locale).format(d.day)),
                          trailing: d.locked
                              ? Text(l10n?.publicHolidaysLocked ??
                                  'Invoiced month')
                              : d.present
                                  ? Text(l10n?.publicHolidaysPresent ??
                                      'Already a closure day')
                                  : null,
                        ),
                    ],
                  ),
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const ValueKey('holidays-confirm'),
              onPressed: _busy || creatable == 0 ? null : _apply,
              child: Text(
                creatable == 0
                    ? (l10n?.publicHolidaysNothingToCreate ??
                        'Nothing to create')
                    : (l10n?.publicHolidaysConfirm(creatable) ??
                        'Create $creatable closure days'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
