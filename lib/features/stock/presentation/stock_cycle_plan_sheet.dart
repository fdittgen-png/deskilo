// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295 -- a cycle count plan: what it counts (places with everything inside them, items, or the
// high-value goods with a threshold of its own or the business's), and when (once, or every n days from
// a due day). The mistakes the screen can see (no name, nothing chosen, a threshold or an interval
// that is no number, a due day that is not a day) are said under their field before anything is sent;
// the server decides, and its refusal is said under the sheet. One request id per sheet: a retry
// answers once; the plan's own id is stable, so saving again changes the same plan.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/stock_config.dart';
import '../domain/stock_cycle_counts.dart';
import '../domain/stock_page.dart';
import '../domain/stock_sites.dart';
import 'stock_config_text.dart';

/// What the sheet chooses from.
typedef CountPlanChoices = ({List<StockItem> items, List<StockPlaceConfig> places, String separator, String currency});

/// Opens the sheet of [plan] (null: a new one); true when it was saved.
Future<bool> showCountPlanSheet(
  BuildContext context,
  StockCycleCounts counts, {
  required String workspaceId,
  required CountPlanChoices choices,
  required String today,
  CountPlan? plan,
}) {
  final l10n = context.l10n;
  final draft = _PlanDraft(choices, plan, today);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: l10n.stockCyclePlanTitle,
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('stock-plan-save'),
      onDispose: draft.fields.dispose,
      validate: () => draft.validate(context, l10n),
      onSubmit: () => draft.submit(context, l10n, counts, workspaceId),
      builder: draft.build,
    ),
  );
}

class _PlanDraft {
  _PlanDraft(this.choices, this.plan, String today)
    : scope = plan?.scope ?? CountScope.places,
      places = {...?plan?.locationIds},
      items = {...?plan?.itemIds},
      repeating = plan == null || plan.intervalDays != null,
      active = plan?.active ?? true,
      due = plan?.nextDueOn ?? today,
      fields = FormControllers({
        'name': plan?.name ?? '',
        'threshold': plan?.highValueMinor == null ? '' : '${plan!.highValueMinor! / 100}',
        'every': '${plan?.intervalDays ?? 14}',
      });

  final CountPlanChoices choices;
  final CountPlan? plan;
  final FormControllers fields;
  final String planId = newRequestId();
  final String requestId = newRequestId();
  CountScope scope;
  final Set<String> places;
  final Set<String> items;
  bool repeating;
  bool active;
  String due;

  /// The sites and places a plan may name: real, active places.
  List<StockPlaceConfig> get _places => stockRealPlaces(choices.places);

  String get _id => plan?.id ?? planId;

  /// The sentence under the chosen places or items (the chips have no field of their own).
  String? _choiceError;

  FieldErrors validate(BuildContext context, AppLocalizations l10n) {
    final errors = <String, String>{};
    _choiceError = null;
    if (fields.text('name').trim().isEmpty) errors['name'] = l10n.stockCyclePlanNameRequired;
    if ((scope == CountScope.places && places.isEmpty) || (scope == CountScope.items && items.isEmpty)) {
      _choiceError = l10n.stockCyclePlanScopeRequired;
      errors['scope'] = _choiceError!;
    }
    if (repeating && !_wholeDays(fields.text('every'))) errors['every'] = l10n.stockCycleIntervalInvalid;
    if (scope == CountScope.highValue && fields.text('threshold').trim().isNotEmpty && _threshold(context) == null) {
      errors['threshold'] = l10n.stockCycleThresholdInvalid;
    }
    return errors;
  }

  bool _wholeDays(String text) {
    final n = int.tryParse(text.trim());
    return n != null && n >= 1 && n <= 366;
  }

  int? _threshold(BuildContext context) {
    final text = fields.text('threshold').trim();
    final minor = appFormatOf(context).parseMinor(text);
    return minor != null && minor >= 1 ? minor : null;
  }

  Future<String?> submit(BuildContext context, AppLocalizations l10n, StockCycleCounts counts, String workspaceId) async {
    final threshold = scope == CountScope.highValue && fields.text('threshold').trim().isNotEmpty ? _threshold(context) : null;
    try {
      await counts.savePlan(workspaceId, (
        planId: _id,
        requestId: requestId,
        name: fields.text('name').trim(),
        scope: scope,
        locationIds: scope == CountScope.places ? places.toList() : const [],
        itemIds: scope == CountScope.items ? items.toList() : const [],
        nextDueOn: due,
        active: active,
        highValueMinor: threshold,
        intervalDays: repeating ? int.parse(fields.text('every').trim()) : null,
      ));
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a count plan was not saved', error: e, stackTrace: st);
      return stockSaveProblem(l10n, e);
    }
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    return [
      AppTextField(
        key: const ValueKey('stock-plan-name'),
        controller: fields['name'],
        fieldKey: 'name',
        label: l10n.stockCyclePlanName,
      ),
      const FormGap(),
      SegmentedButton<CountScope>(
        key: const ValueKey('stock-plan-scope'),
        segments: [
          ButtonSegment(value: CountScope.places, label: Text(l10n.stockCycleScopePlaces)),
          ButtonSegment(value: CountScope.items, label: Text(l10n.stockItemsTitle)),
          ButtonSegment(value: CountScope.highValue, label: Text(l10n.stockCycleScopeHighValue)),
        ],
        selected: {scope},
        onSelectionChanged: (s) {
          scope = s.first;
          refresh();
        },
      ),
      const FormGap.small(),
      ..._scope(context, l10n, refresh),
      const FormGap(),
      ..._cadence(context, l10n, refresh),
      SwitchListTile(
        key: const ValueKey('stock-plan-active'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.stockCyclePlanActive),
        value: active,
        onChanged: (v) {
          active = v;
          refresh();
        },
      ),
    ];
  }

  List<Widget> _scope(BuildContext context, AppLocalizations l10n, VoidCallback refresh) => switch (scope) {
    CountScope.places => [
      Text(l10n.stockCyclePlanPlaces),
      Wrap(
        spacing: 8,
        children: [
          for (final p in _places)
            FilterChip(
              key: ValueKey('stock-plan-place-${p.id}'),
              label: Text(stockAddress(p, choices.separator)),
              selected: places.contains(p.id),
              onSelected: (on) {
                on ? places.add(p.id) : places.remove(p.id);
                refresh();
              },
            ),
        ],
      ),
      ?_choiceText(context),
    ],
    CountScope.items => [
      Text(l10n.stockItemsTitle),
      Wrap(
        spacing: 8,
        children: [
          for (final i in choices.items)
            FilterChip(
              key: ValueKey('stock-plan-item-${i.id}'),
              label: Text(i.name),
              selected: items.contains(i.id),
              onSelected: (on) {
                on ? items.add(i.id) : items.remove(i.id);
                refresh();
              },
            ),
        ],
      ),
      ?_choiceText(context),
    ],
    CountScope.highValue => [
      AppTextField(
        key: const ValueKey('stock-plan-threshold'),
        controller: fields['threshold'],
        fieldKey: 'threshold',
        label: l10n.stockCyclePlanThreshold(choices.currency),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      ),
    ],
  };

  Widget? _choiceText(BuildContext context) => _choiceError == null
      ? null
      : Text(_choiceError!, key: const ValueKey('stock-plan-scope-error'), style: TextStyle(color: Theme.of(context).colorScheme.error));

  List<Widget> _cadence(BuildContext context, AppLocalizations l10n, VoidCallback refresh) => [
    SegmentedButton<bool>(
      key: const ValueKey('stock-plan-cadence'),
      segments: [
        ButtonSegment(value: false, label: Text(l10n.stockCycleCadenceOnce)),
        ButtonSegment(value: true, label: Text(l10n.stockCycleCadenceEvery)),
      ],
      selected: {repeating},
      onSelectionChanged: (s) {
        repeating = s.first;
        refresh();
      },
    ),
    if (repeating) ...[
      const FormGap.small(),
      AppTextField(
        key: const ValueKey('stock-plan-every'),
        controller: fields['every'],
        fieldKey: 'every',
        label: l10n.stockCycleEveryDays,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    ],
    const FormGap.small(),
    // the due day is always a business day in `YYYY-MM-DD` (the sheet starts from the business's today)
    AppDateField(
      key: const ValueKey('stock-plan-due'),
      fieldKey: 'due',
      label: l10n.purchasesDueDate,
      value: DateTime.parse(due),
      first: DateTime.parse(due).subtract(const Duration(days: 366)),
      last: DateTime.parse(due).add(const Duration(days: 366 * 5)),
      onChanged: (read) {
        final day = read.date;
        if (day != null) due = day.toIso8601String().substring(0, 10);
      },
    ),
  ];
}
