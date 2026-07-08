// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/plan.dart';
import '../../providers/money_providers.dart';

/// Owner-only plan editor (#105): name ("percentage" tier), base fee,
/// included half-days quota and overage price are all configurable;
/// plans are deactivated, never deleted (ledger history references them).
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  Future<void> _editSheet(
    BuildContext context,
    WidgetRef ref, {
    Plan? plan,
  }) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final l10n = AppLocalizations.of(context);

    final result = await showModalBottomSheet<_PlanDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PlanSheet(plan: plan),
    );
    if (result == null) return;

    try {
      final repo = ref.read(moneyRepositoryProvider);
      if (plan == null) {
        await repo.createPlan(
          workspaceId: workspace.id,
          name: result.name,
          baseFeeCents: result.baseFeeCents,
          includedHalfDays: result.includedHalfDays,
          overageFeeCents: result.overageFeeCents,
        );
      } else {
        await repo.updatePlan(
          plan.copyWith(
            name: result.name,
            baseFeeCents: result.baseFeeCents,
            includedHalfDays: result.includedHalfDays,
            overageFeeCents: result.overageFeeCents,
            active: result.active,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('plan save failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      );
      return;
    }
    ref
      ..invalidate(allPlansProvider)
      ..invalidate(plansProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plansAsync = ref.watch(allPlansProvider);
    final currency = NumberFormat.simpleCurrency(
      name: ref.watch(currentWorkspaceProvider).value?.currencyCode ?? 'EUR',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.plansEditorTitle ?? 'Plans'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n?.plansEditorNew ?? 'New plan',
        onPressed: () => _editSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: switch (plansAsync) {
        AsyncData(value: final plans) => ListView(
            children: [
              for (final plan in plans)
                ListTile(
                  leading: Icon(
                    plan.active
                        ? Icons.workspace_premium_outlined
                        : Icons.do_not_disturb_on_outlined,
                  ),
                  title: Text(plan.name),
                  subtitle: Text(_summary(l10n, plan, currency)),
                  trailing: plan.active
                      ? null
                      : Text(l10n?.plansEditorInactive ?? 'Inactive'),
                  onTap: () => _editSheet(context, ref, plan: plan),
                ),
            ],
          ),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  String _summary(
    AppLocalizations? l10n,
    Plan plan,
    NumberFormat currency,
  ) {
    final base = currency.format(plan.baseFeeCents / 100);
    final quota = plan.includedHalfDays == null
        ? (l10n?.plansEditorUnlimited ?? 'unlimited half-days')
        : (l10n?.plansEditorQuota(plan.includedHalfDays!) ??
            '${plan.includedHalfDays} half-days');
    final overage = plan.overageFeeCents == 0
        ? ''
        : ' · ${l10n?.plansEditorPerExtra(currency.format(plan.overageFeeCents / 100)) ?? '${currency.format(plan.overageFeeCents / 100)}/extra'}';
    return '$base · $quota$overage';
  }
}

class _PlanDraft {
  const _PlanDraft({
    required this.name,
    required this.baseFeeCents,
    required this.includedHalfDays,
    required this.overageFeeCents,
    required this.active,
  });

  final String name;
  final int baseFeeCents;
  final int? includedHalfDays;
  final int overageFeeCents;
  final bool active;
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({this.plan});

  final Plan? plan;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  late final TextEditingController _name;
  late final TextEditingController _baseFee;
  late final TextEditingController _included;
  late final TextEditingController _overage;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _name = TextEditingController(text: plan?.name ?? '');
    _baseFee = TextEditingController(
      text: plan == null ? '' : _money(plan.baseFeeCents),
    );
    _included = TextEditingController(
      text: plan?.includedHalfDays?.toString() ?? '',
    );
    _overage = TextEditingController(
      text: plan == null ? '' : _money(plan.overageFeeCents),
    );
    _active = plan?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _baseFee.dispose();
    _included.dispose();
    _overage.dispose();
    super.dispose();
  }

  String _money(int cents) =>
      cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);

  int? _parseCents(String raw) {
    if (raw.trim().isEmpty) return 0;
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  void _submit() {
    final name = _name.text.trim();
    final base = _parseCents(_baseFee.text);
    final overage = _parseCents(_overage.text);
    final includedRaw = _included.text.trim();
    final included = includedRaw.isEmpty ? null : int.tryParse(includedRaw);
    final valid = name.isNotEmpty &&
        base != null &&
        overage != null &&
        (includedRaw.isEmpty || (included != null && included >= 0));
    if (base == null || overage == null || !valid) return;
    Navigator.of(context).pop(
      _PlanDraft(
        name: name,
        baseFeeCents: base,
        includedHalfDays: included,
        overageFeeCents: overage,
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.plan == null
                ? (l10n?.plansEditorNew ?? 'New plan')
                : (l10n?.plansEditorEdit ?? 'Edit plan'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: widget.plan == null,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: l10n?.planNameLabel ?? 'Name',
            ),
          ),
          TextField(
            controller: _baseFee,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n?.planBaseFeeLabel ?? 'Monthly base fee',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _included,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  l10n?.planIncludedLabel ?? 'Included half-days',
              helperText: l10n?.planIncludedHelper ??
                  'Leave empty for unlimited',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _overage,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n?.planOverageLabel ??
                  'Price per extra half-day',
            ),
          ),
          if (widget.plan != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n?.planActiveLabel ?? 'Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submit,
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
  }
}
