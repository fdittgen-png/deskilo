// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C2 — the allocation rules, edited from the cost allocation card: a
// rule spreads the operating costs of one purchase category over levels and
// offices by whole weights. Saving appends a revision (0531); retiring is a
// revision too, so a past month keeps the rule it was spread by. Only
// manageBilling may edit; the server checks it again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/save_allocation_rule.dart';
import '../../domain/cost_allocation.dart';
import '../../domain/cost_allocation_rules.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/bi_providers.dart';
import '../../providers/cost_allocation_providers.dart';
import '../../providers/workspace_providers.dart';
import 'bi_module_section.dart';

/// The card's way into the rules, for who may change them.
class CostAllocationRulesButton extends ConsumerWidget {
  const CostAllocationRulesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final may = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.manageBilling);
    if (!may) return const SizedBox.shrink();
    return TextButton.icon(
      key: const ValueKey('allocation-rules'),
      icon: const Icon(Icons.tune),
      label: Text(context.l10n.allocationRulesButton),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const CostAllocationRulesDialog(),
      ),
    );
  }
}

/// The rules, newest revision of each, with what they spread.
class CostAllocationRulesDialog extends ConsumerWidget {
  const CostAllocationRulesDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace == null) return const SizedBox.shrink();
    final rules = ref.watch(allocationRulesProvider(workspace.id));
    final locale = Localizations.localeOf(context).toString();
    Future<void> edit(AllocationRule? rule, {bool retire = false}) =>
        showDialog<void>(
          context: context,
          builder: (_) => retire
              ? _RetireDialog(workspaceId: workspace.id, rule: rule!)
              : _RuleForm(workspaceId: workspace.id, rule: rule),
        );
    return AlertDialog(
      title: Text(l10n.allocationRulesTitle),
      content: SizedBox(
        width: 480,
        child: switch (rules) {
          AsyncData(:final value) when latestRevisions(value).isEmpty => Text(
            l10n.allocationRulesEmpty,
            key: const ValueKey('allocation-rules-empty'),
          ),
          AsyncData(:final value) => ListView(
            shrinkWrap: true,
            children: [
              for (final rule in latestRevisions(value))
                ListTile(
                  key: ValueKey('allocation-rule-${rule.ruleId}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    rule.category.isEmpty
                        ? l10n.allocationRuleOneLine
                        : rule.category,
                  ),
                  subtitle: Text(
                    [
                      l10n.allocationRuleSummary(
                        rule.basis,
                        DateFormat.yMd(locale).format(rule.effectiveFrom),
                        '${rule.revision}',
                      ),
                      if (rule.retired) l10n.allocationRuleRetired,
                    ].join(' · '),
                  ),
                  trailing: rule.retired
                      ? null
                      : Wrap(
                          children: [
                            IconButton(
                              key: ValueKey('allocation-edit-${rule.ruleId}'),
                              tooltip: l10n.allocationRuleEdit,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => edit(rule),
                            ),
                            IconButton(
                              key: ValueKey('allocation-retire-${rule.ruleId}'),
                              tooltip: l10n.allocationRuleRetire,
                              icon: const Icon(Icons.block),
                              onPressed: () => edit(rule, retire: true),
                            ),
                          ],
                        ),
                ),
            ],
          ),
          AsyncError() => Text(l10n.biUnavailable),
          _ => const LinearProgressIndicator(),
        },
      ),
      actions: [
        TextButton(
          key: const ValueKey('allocation-new'),
          onPressed: () => edit(null),
          child: Text(l10n.allocationRuleNew),
        ),
        TextButton(
          key: const ValueKey('allocation-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

/// Runs [save]; a refusal is traced and said, never swallowed. True when
/// it was saved.
Future<bool> _saved(BuildContext context, Future<void> Function() save) async {
  final l10n = context.l10n;
  try {
    await save();
    return true;
  } on Object catch (e, st) {
    TraceLogger.instance.error(
      'workspace',
      'save cost allocation rule failed',
      error: e,
      stackTrace: st,
    );
    if (context.mounted) AppSnack.error(context, l10n.allocationRuleSaveFailed);
    return false;
  }
}

class _RetireDialog extends ConsumerWidget {
  const _RetireDialog({required this.workspaceId, required this.rule});

  final String workspaceId;
  final AllocationRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.allocationRuleRetire),
      content: Text(l10n.allocationRuleRetireBody),
      actions: [
        TextButton(
          key: const ValueKey('allocation-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('allocation-retire-confirm'),
          onPressed: () async {
            final today = ref.read(clockProvider).now();
            final save = ref.read(saveAllocationRuleProvider);
            final saved = await _saved(
              context,
              () => save(
                workspaceId,
                rule,
                AllocationRuleDraft(
                  category: rule.category,
                  purchaseLineId: rule.purchaseLineId,
                  effectiveFrom: DateTime(today.year, today.month),
                  basis: rule.basis,
                  weights: const [],
                  retired: true,
                ),
              ),
            );
            if (saved && context.mounted) Navigator.of(context).pop();
          },
          child: Text(l10n.allocationRuleRetire),
        ),
      ],
    );
  }
}

/// One revision: the category, from when, why, and a weight per level and
/// office. A weight left empty or 0 names no share.
class _RuleForm extends ConsumerStatefulWidget {
  const _RuleForm({required this.workspaceId, required this.rule});

  final String workspaceId;
  final AllocationRule? rule;

  @override
  ConsumerState<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<_RuleForm> {
  late final _category = TextEditingController(
    text: widget.rule?.category ?? '',
  );
  late final _basis = TextEditingController(text: widget.rule?.basis ?? '');
  late DateTime _from = widget.rule?.effectiveFrom ?? _monthStart();
  final _weights = <String, TextEditingController>{};
  String? _error;
  bool _saving = false;

  DateTime _monthStart() {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month);
  }

  TextEditingController _weight(String kind, String id) =>
      _weights.putIfAbsent('$kind:$id', () {
        final known = widget.rule?.weights
            .where((w) => w.resourceKind == kind && w.resourceId == id)
            .firstOrNull;
        return TextEditingController(
          text: known == null ? '' : '${known.weight}',
        );
      });

  @override
  void initState() {
    super.initState();
    // Every weight the revision had, even of a desk or seat not listed
    // below, carries into the next revision.
    for (final w in widget.rule?.weights ?? const <AllocationWeight>[]) {
      _weight(w.resourceKind, w.resourceId);
    }
  }

  @override
  void dispose() {
    _category.dispose();
    _basis.dispose();
    for (final c in _weights.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<AllocationWeight> _entered() => [
    for (final MapEntry(:key, :value) in _weights.entries)
      if (int.tryParse(value.text.trim()) case final w? when w > 0)
        AllocationWeight(
          resourceKind: key.split(':').first,
          resourceId: key.substring(key.indexOf(':') + 1),
          weight: w,
        ),
  ];

  Future<void> _submit(AppLocalizations l10n) async {
    final weights = _entered();
    final lineScoped = widget.rule?.purchaseLineId != null;
    final String? error;
    if (!lineScoped && _category.text.trim().isEmpty) {
      error = l10n.allocationRuleNeedsCategory;
    } else if (_basis.text.trim().isEmpty) {
      error = l10n.allocationRuleNeedsBasis;
    } else if (weights.isEmpty) {
      error = l10n.allocationRuleNeedsWeight;
    } else {
      error = null;
    }
    setState(() => _error = error);
    if (error != null) return;
    setState(() => _saving = true);
    final save = ref.read(saveAllocationRuleProvider);
    final saved = await _saved(
      context,
      () => save(
        widget.workspaceId,
        widget.rule,
        AllocationRuleDraft(
          category: _category.text.trim(),
          purchaseLineId: widget.rule?.purchaseLineId,
          effectiveFrom: _from,
          basis: _basis.text.trim(),
          weights: weights,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final material = MaterialLocalizations.of(context);
    final currency = ref.watch(currentWorkspaceProvider).value?.currencyCode;
    final preview = allocateByLargestRemainder(10000, _entered());
    return AlertDialog(
      title: Text(
        widget.rule == null ? l10n.allocationRuleNew : l10n.allocationRuleEdit,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.rule?.purchaseLineId == null)
                AppTextField(
                  key: const ValueKey('allocation-category'),
                  controller: _category,
                  maxLength: 80,
                  label: l10n.allocationRuleCategory,
                )
              else
                Text(l10n.allocationRuleOneLine),
              AppTextField(
                key: const ValueKey('allocation-basis'),
                controller: _basis,
                maxLength: 300,
                label: l10n.allocationRuleBasis,
              ),
              ListTile(
                key: const ValueKey('allocation-from'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.allocationRuleFrom),
                subtitle: Text(DateFormat.yMd(locale).format(_from)),
                trailing: const Icon(Icons.event),
                onTap: () async {
                  final day = await showDatePicker(
                    context: context,
                    initialDate: _from,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(_from.year + 5),
                  );
                  if (day != null) setState(() => _from = day);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.allocationRuleWeights,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final (kind, id, name) in allocationResourcesOf(ref))
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: kind == 'office' ? AppSpacing.lg : 0,
                  ),
                  child: AppTextField(
                    key: ValueKey('allocation-weight-$kind-$id'),
                    label: name,
                    controller: _weight(kind, id),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    l10n.allocationRulePreview(
                      biMoneyCell(10000, locale, currency),
                      [
                        for (final s in preview)
                          biMoneyCell(s.minor, locale, currency),
                      ].join(' / '),
                    ),
                    key: const ValueKey('allocation-preview'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_error case final error?)
                Text(
                  error,
                  key: const ValueKey('allocation-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('allocation-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('allocation-save'),
          onPressed: _saving ? null : () => _submit(l10n),
          child: Text(material.saveButtonLabel),
        ),
      ],
    );
  }
}
