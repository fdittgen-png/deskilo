// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/accessory.dart';
import '../../providers/accessory_providers.dart';

/// Owner/admin accessory-catalog editor (#167, epic #163): name and
/// per-half-day supplement are configurable; accessories are deactivated,
/// never deleted (seat assignments and future bill lines reference them).
/// Mirrors the services catalog editor (#123).
class AccessoriesScreen extends ConsumerWidget {
  const AccessoriesScreen({super.key});

  Future<void> _editSheet(
    BuildContext context,
    WidgetRef ref, {
    Accessory? accessory,
  }) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final l10n = AppLocalizations.of(context);

    final result = await showModalBottomSheet<_AccessoryDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AccessorySheet(accessory: accessory),
    );
    if (result == null) return;

    try {
      final repo = ref.read(accessoryRepositoryProvider);
      if (accessory == null) {
        // New accessories append to the end of the catalog order.
        final existing = ref
                .read(accessoriesProvider(includeInactive: true))
                .value ??
            const <Accessory>[];
        final nextSortOrder = existing.fold<int>(
              -1,
              (max, a) => a.sortOrder > max ? a.sortOrder : max,
            ) +
            1;
        await repo.createAccessory(
          workspace.id,
          name: result.name,
          supplementCents: result.supplementCents,
          sortOrder: nextSortOrder,
        );
      } else {
        await repo.updateAccessory(
          accessory.id,
          name: result.name,
          supplementCents: result.supplementCents,
          active: result.active,
        );
      }
    } catch (e, st) {
      debugPrint('accessory save failed: $e\n$st');
      TraceLogger.instance
          .error('plan', 'accessory save failed', error: e, stackTrace: st);
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
      return;
    }
    ref.invalidate(accessoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accessoriesAsync =
        ref.watch(accessoriesProvider(includeInactive: true));
    final currency = NumberFormat.simpleCurrency(
      name: ref.watch(currentWorkspaceProvider).value?.currencyCode ?? 'EUR',
    );
    final inactiveColor = Theme.of(context).disabledColor;

    String supplementLabel(Accessory accessory) {
      if (accessory.supplementCents == 0) {
        return l10n?.accessoriesNoSupplement ?? 'No supplement';
      }
      final amount = currency.format(accessory.supplementCents / 100);
      return l10n?.accessoriesPerHalfDay(amount) ?? '$amount / half-day';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.accessoriesTitle ?? 'Accessories'),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n?.accessoriesNew ?? 'New accessory',
        onPressed: () => _editSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: switch (accessoriesAsync) {
        AsyncData(value: final accessories) when accessories.isEmpty =>
          EmptyState(
            icon: Icons.chair_alt_outlined,
            title: l10n?.accessoriesEmpty ?? 'No accessories yet.',
          ),
        AsyncData(value: final accessories) => ListView(
            children: [
              for (final accessory in accessories)
                ListTile(
                  leading: Icon(
                    accessory.active
                        ? Icons.devices_other_outlined
                        : Icons.do_not_disturb_on_outlined,
                    color: accessory.active ? null : inactiveColor,
                  ),
                  title: Text(
                    accessory.name,
                    style: accessory.active
                        ? null
                        : TextStyle(color: inactiveColor),
                  ),
                  subtitle: Text(supplementLabel(accessory)),
                  trailing: accessory.active
                      ? null
                      : Text(l10n?.accessoriesInactive ?? 'Inactive'),
                  onTap: () =>
                      _editSheet(context, ref, accessory: accessory),
                ),
            ],
          ),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}

class _AccessoryDraft {
  const _AccessoryDraft({
    required this.name,
    required this.supplementCents,
    required this.active,
  });

  final String name;
  final int supplementCents;
  final bool active;
}

class _AccessorySheet extends StatefulWidget {
  const _AccessorySheet({this.accessory});

  final Accessory? accessory;

  @override
  State<_AccessorySheet> createState() => _AccessorySheetState();
}

class _AccessorySheetState extends State<_AccessorySheet> {
  late final TextEditingController _name;
  late final TextEditingController _supplement;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final accessory = widget.accessory;
    _name = TextEditingController(text: accessory?.name ?? '');
    _supplement = TextEditingController(
      text: accessory == null ? '' : _money(accessory.supplementCents),
    );
    _active = accessory?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _supplement.dispose();
    super.dispose();
  }

  String _money(int cents) =>
      cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);

  // Mirrors the services catalog editor's cents parser (it is private
  // there, hence not importable).
  int? _parseCents(String raw) {
    if (raw.trim().isEmpty) return 0;
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  void _submit() {
    final name = _name.text.trim();
    final supplement = _parseCents(_supplement.text);
    if (name.isEmpty || supplement == null) return;
    Navigator.of(context).pop(
      _AccessoryDraft(
        name: name,
        supplementCents: supplement,
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
            widget.accessory == null
                ? (l10n?.accessoriesNew ?? 'New accessory')
                : (l10n?.accessoriesEdit ?? 'Edit accessory'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: widget.accessory == null,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: l10n?.accessoriesName ?? 'Name',
            ),
          ),
          TextField(
            controller: _supplement,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  l10n?.accessoriesSupplement ?? 'Supplement per half-day',
            ),
          ),
          if (widget.accessory != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n?.accessoriesActive ?? 'Active'),
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
